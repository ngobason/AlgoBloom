# Tài liệu Thiết kế Hệ thống (Design Document) — AlgoBloom

Tài liệu này mô tả chi tiết mô hình tài nguyên REST, sơ đồ cơ sở dữ liệu PostgreSQL, sự tách biệt giữa Resource Model và Database Schema, kiến trúc SOA (Gateway Orchestration), luồng tuần tự trọng tâm và chiến lược kiểm thử của **AlgoBloom**.

---

## 1. Mô hình Tài nguyên (Resource Model) & Quy ước Đặt tên

### 1.1 Quy ước Đặt tên & Định danh
- **Base path:** `/api/v1`
- **Tên tài nguyên:** Danh từ số nhiều, chữ thường, phân cách bằng dấu gạch ngang (`kebab-case`) cho đường dẫn: `/problems`, `/submissions`, `/tags`, `/jobs`, `/students/{studentId}/weaknesses`.
- **Trường JSON:** `snake_case` thống nhất toàn hệ thống (OpenAPI, PostgreSQL, Redis Streams, AI Service).
- **Định danh (Identifiers):** Tất cả thực thể chính sử dụng **UUID v4** (`string`, format `uuid`) để tránh lộ quy mô dữ liệu và hỗ trợ tạo ID không xung đột giữa các dịch vụ.
- **Caching:** Các endpoint đọc tài nguyên bất biến hoặc ít thay đổi (`GET /api/v1/problems/{problemId}`, `GET /api/v1/submissions/{submissionId}`) trả về weak `ETag` (ví dụ `W/"problem-<uuid>-v1"`) và hỗ trợ `If-None-Match` -> `304 Not Modified`.
- **Tác vụ bất đồng bộ:** Các thao tác tốn thời gian (`POST /api/v1/problems/generate`, `POST /api/v1/submissions`) trả về `202 Accepted` kèm `job_id` để client polling tại `GET /api/v1/jobs/{jobId}`.

### 1.2 Sơ đồ Mô hình Tài nguyên (Resource Model Diagram)

```mermaid
classDiagram
    class User {
        +UUID id
        +string email
        +string full_name
        +enum role [TEACHER, STUDENT]
        +datetime created_at
    }

    class Tag {
        +UUID id
        +string slug
        +string name
        +enum category [ALGORITHM, DATA_STRUCTURE, TECHNIQUE]
    }

    class Problem {
        +UUID id
        +string slug
        +string title
        +string statement_md
        +int difficulty
        +int time_limit_ms
        +int memory_limit_mb
        +string target_complexity
        +Tag[] tags
        +SampleCase[] sample_cases
        +SubtaskTier[] subtask_tiers
        +enum status [DRAFT, VERIFYING, PUBLISHED, FAILED]
    }

    class Submission {
        +UUID id
        +UUID problem_id
        +UUID student_id
        +enum language [cpp17, cpp20, python3]
        +string source_code
        +enum status [PENDING, RUNNING, AC, WA, TLE, MLE, RE, CE, IE]
        +int score
        +int max_time_ms
        +int max_memory_kb
        +SubtaskTiming[] subtask_timings
    }

    class BigOAnalysis {
        +UUID submission_id
        +string detected_complexity
        +string target_complexity
        +string bottleneck_summary
        +string socratic_hint
        +string[] guiding_questions
        +boolean cached
    }

    class Job {
        +UUID id
        +enum type [PROBLEM_GENERATE, SUBMISSION_JUDGE]
        +enum status [PENDING, RUNNING, COMPLETED, FAILED]
        +string resource_type
        +UUID resource_id
        +object result
        +string error_code
        +string error_message
    }

    class StudentWeakness {
        +UUID student_id
        +WeakTagStat[] weak_tags
        +int recommended_difficulty
        +datetime computed_at
    }

    User "1" --> "*" Problem : creates (TEACHER)
    User "1" --> "*" Submission : submits (STUDENT)
    User "1" --> "1" StudentWeakness : computed projection
    Problem "*" --> "*" Tag : embeds tags[]
    Problem "1" --> "*" Submission : receives
    Submission "1" --> "0..1" BigOAnalysis : on-demand /analyze
    Job ..> Problem : tracks PROBLEM_GENERATE
    Job ..> Submission : tracks SUBMISSION_JUDGE
```

---

## 2. Sơ đồ Cơ sở Dữ liệu PostgreSQL (ERD)

Core Gateway (`services/gateway/`) là thành phần **duy nhất** sở hữu schema và kết nối trực tiếp tới PostgreSQL. Định nghĩa DDL chuẩn nằm tại `services/gateway/migrations/001_init.sql`.

```mermaid
erDiagram
    users ||--o{ problems : "created_by"
    users ||--o{ submissions : "student_id"
    users ||--o{ jobs : "requested_by"
    problems ||--o{ problem_tags : "has"
    tags ||--o{ problem_tags : "tagged_in"
    problems ||--o{ submissions : "target"
    problems ||--o{ ai_cache : "cached_for"

    users {
        uuid id PK
        text email UK
        text password_hash
        text full_name
        text role
        timestamptz created_at
        timestamptz updated_at
    }

    tags {
        uuid id PK
        text slug UK
        text name
        text category
    }

    problems {
        uuid id PK
        text slug UK
        text title
        text statement_md
        text input_format_md
        text output_format_md
        text constraints_md
        int difficulty
        int time_limit_ms
        int memory_limit_mb
        text target_complexity
        jsonb sample_cases
        jsonb subtask_tiers
        text generator_code
        text reference_solution_cpp
        text storage_path
        text status
        uuid created_by FK
        int version
        timestamptz created_at
        timestamptz updated_at
    }

    problem_tags {
        uuid problem_id PK,FK
        uuid tag_id PK,FK
    }

    submissions {
        uuid id PK
        uuid problem_id FK
        uuid student_id FK
        text language
        text source_code
        char64 source_code_sha256
        text status
        int score
        int max_time_ms
        int max_memory_kb
        jsonb subtask_timings
        text compiler_output
        int version
        timestamptz created_at
        timestamptz judged_at
    }

    jobs {
        uuid id PK
        text type
        text status
        uuid requested_by FK
        text resource_type
        uuid resource_id
        jsonb payload
        jsonb result
        text error_code
        text error_message
        timestamptz created_at
        timestamptz updated_at
        timestamptz completed_at
    }

    ai_cache {
        uuid id PK
        uuid problem_id FK
        char64 source_code_sha256
        text language
        text detected_complexity
        text target_complexity
        text bottleneck_summary
        text socratic_hint
        jsonb guiding_questions
        text model_version
        timestamptz created_at
    }
```

---

## 3. Vì sao Resource Model KHÁC với Database Schema?

Việc tách biệt API Resource Model khỏi cấu trúc bảng quan hệ là nguyên tắc thiết kế bắt buộc để tránh rò rỉ chi tiết lưu trữ nội bộ, bảo vệ thông tin nhạy cảm và tối ưu hóa trải nghiệm client:

| Khía cạnh | Trong PostgreSQL Schema | Trong Public REST Resource Model | Lý do tách biệt |
| :--- | :--- | :--- | :--- |
| **Quan hệ nhiều-nhiều `problems` <-> `tags`** | Bảng trung gian `problem_tags(problem_id, tag_id)` chuẩn hóa 3NF | Mảng nhúng `tags: Tag[]` ngay bên trong đối tượng `Problem` | Tránh bài toán N+1 request phía Frontend; bảng `problem_tags` không có ý nghĩa độc lập với người dùng API. |
| **Hồ sơ điểm yếu học sinh (`StudentWeakness`)** | **Không có bảng riêng** (tính toán tổng hợp động qua `JOIN` giữa `submissions`, `problems`, `problem_tags`, `tags`) | Tài nguyên chỉ đọc `GET /api/v1/students/{studentId}/weaknesses` | Dữ liệu dẫn xuất (computed projection), tính trực tiếp từ lịch sử nộp bài để tránh đồng bộ dư thừa ở MVP. |
| **Bảng `ai_cache`** | Lưu trữ khóa duy nhất `(problem_id, source_code_sha256)` cùng metadata `model_version` | **Ẩn hoàn toàn** khỏi public API; chỉ biểu diễn qua cờ `cached: boolean` trong response của `POST /submissions/{id}/analyze` | Caching là chiến lược tối ưu hạ tầng nội bộ; client không cần biết hay thao tác trực tiếp bảng cache. |
| **Trường nhạy cảm / nội bộ trên `users` và `problems`** | `users.password_hash`, `problems.generator_code`, `problems.reference_solution_cpp`, `problems.storage_path`, `submissions.source_code_sha256` | **Loại bỏ hoàn toàn** khỏi response công khai (đặc biệt ngăn học sinh thấy `reference_solution_cpp` hay đường dẫn filesystem `/data/problems/...`) | Bảo mật xác thực, chống gian lận lời giải mẫu và che giấu cấu trúc hệ thống tập tin máy chủ. |
| **Cột `version` cho concurrency/caching** | Cột số nguyên `version INT` trong `problems` và `submissions` | Ánh xạ thành HTTP Header `ETag: W/"problem-<id>-v<version>"` | Tận dụng cơ chế chuẩn HTTP `304 Not Modified` thay vì buộc client tự quản lý số phiên bản trong JSON body. |
| **Tài nguyên bất đồng bộ `Job`** | Bảng `jobs` lưu cả `payload` nội bộ và liên kết mềm `(resource_type, resource_id)` | Trả về trạng thái chuẩn hóa (`PENDING`/`RUNNING`/`COMPLETED`/`FAILED`) kèm `resource_id` khi hoàn tất | Che giấu chi tiết hàng đợi Redis Streams và cho phép mở rộng thêm loại job mới mà không phá vỡ hợp đồng REST. |

---

## 4. Kiến trúc Hệ thống SOA (System Architecture Diagram)

Sơ đồ dưới đây thể hiện rõ 4 thành phần dịch vụ, Redis Streams Broker và các **ranh giới tin cậy (Trust Boundaries)**:

```mermaid
flowchart LR
    subgraph ClientZone["Vùng Client (Trình duyệt)"]
        SPA["Client SPA<br/>React + Plain Monaco (No LSP)"]
    end

    subgraph CoreZone["Vùng Điều phối Trung tâm (Core Boundary)"]
        GW["Core Gateway & Orchestrator<br/>Go (HTTP REST /api/v1/*)<br/>JWT/RBAC + ETag + Job Tracker"]
        PG[("PostgreSQL<br/>(SOLE Owner: Gateway)")]
    end

    subgraph AIZone["Vùng Dịch vụ AI Nội bộ"]
        AI["AI Pedagogical Service<br/>(Internal Only)<br/>429 Backoff + MOCK_AI"]
        GEM["Gemini API<br/>gemini-3.8-flash (Free Tier)"]
    end

    subgraph BrokerZone["Message Broker"]
        RS[("Redis Streams<br/>verify_jobs / verify_results<br/>judge_jobs / judge_results")]
    end

    subgraph SandboxZone["Vùng Thực thi Cô lập (Zero DB Credentials)"]
        VW["Verification Worker (Go)<br/>dmoj/judge-small + cptbox"]
        JW["Judging Workers xN (Go)<br/>dmoj/judge-small + cptbox"]
        VOL[("Shared Volume<br/>/data/problems")]
    end

    SPA -- "HTTPS + JWT Bearer<br/>Polling /jobs/{id} + ETag" --> GW
    GW -- "SQL (Read/Write)" --> PG
    GW -- "Internal HTTP<br/>Header: X-Internal-API-Key" --> AI
    AI -- "HTTPS JSON Schema" --> GEM
    GW -- "XADD verify_jobs / judge_jobs" --> RS
    RS -- "XREADGROUP verify_results / judge_results" --> GW
    RS -- "XREADGROUP verify_jobs" --> VW
    VW -- "XADD verify_results" --> RS
    RS -- "XREADGROUP judge_jobs" --> JW
    JW -- "XADD judge_results" --> RS
    VW -- "Mount :rw" --> VOL
    JW -- "Mount :ro" --> VOL
```

### Tóm tắt Ranh giới Tin cậy (Trust Boundaries)
1. **Public Edge (`SPA -> Gateway`):** Chỉ cho phép HTTPS + JWT Bearer (`TEACHER` / `STUDENT`). Mọi đầu vào đều được validate schema và phân quyền RBAC tại Gateway.
2. **Internal AI Boundary (`Gateway -> AI Service`):** AI Service không mở port ra ngoài Internet; bắt buộc kiểm tra header `X-Internal-API-Key` khớp secret nội bộ.
3. **Sandbox Isolation (`Redis Streams -> Judge Workers`):** Judge Workers chạy code không tin cậy bên trong `cptbox`, hoàn toàn **không có biến môi trường hay kết nối PostgreSQL**. Chỉ Verification Worker có quyền ghi `:rw` vào `/data/problems`; Judging Workers chỉ đọc `:ro`.

---

## 5. Sơ đồ Tuần tự Luồng Trọng tâm (Sequence Diagram)

Sơ đồ mô tả trọn vẹn 2 pha của luồng trọng tâm: **(A) Tự xác minh khi sinh đề bài** và **(B) Nộp bài chấm phân tầng + Phân tích Big-O On-Demand**:

```mermaid
sequenceDiagram
    autonumber
    actor Teacher as Giáo viên (SPA)
    actor Student as Học sinh (SPA)
    participant GW as Core Gateway (Go)
    participant DB as PostgreSQL
    participant AI as AI Service
    participant RS as Redis Streams
    participant JW as Judge Worker (cptbox)

    Note over Teacher,JW: PHA A: Sinh đề bài theo chủ đích & Tự xác minh 4 tầng Subtask
    Teacher->>GW: POST /api/v1/problems/generate (tags, difficulty, JWT TEACHER)
    GW->>DB: INSERT jobs (PROBLEM_GENERATE, PENDING)
    GW-->>Teacher: 202 Accepted { job_id }

    GW->>AI: POST /internal/ai/generate-problem (X-Internal-API-Key)
    AI-->>GW: { statement, generator.py, reference.cpp, subtask_tiers }
    GW->>DB: INSERT problems (status=VERIFYING), UPDATE jobs (RUNNING)
    GW->>RS: XADD verify_jobs { job_id, problem_id, generator_code, reference_solution_cpp }

    RS->>JW: XREADGROUP verify_jobs
    JW->>JW: Chạy generator.py tạo test 4 tầng (N=10^2..10^5) -> /data/problems/:rw
    JW->>JW: Biên dịch & chạy reference.cpp trong cptbox kiểm chứng AC toàn bộ
    JW->>RS: XADD verify_results { job_id, problem_id, verified: true, subtask_benchmarks }

    RS->>GW: XREADGROUP verify_results
    GW->>DB: UPDATE problems (status=PUBLISHED), UPDATE jobs (COMPLETED, resource_id)
    Teacher->>GW: GET /api/v1/jobs/{job_id}
    GW-->>Teacher: 200 OK { status: COMPLETED, resource_id: problem_id }

    Note over Student,JW: PHA B: Nộp bài O(N^2) -> TLE Subtask 3 -> Phân tích Big-O On-Demand
    Student->>GW: POST /api/v1/submissions (problem_id, cpp20, source_code)
    GW->>DB: INSERT submissions (PENDING, sha256) & jobs (SUBMISSION_JUDGE)
    GW-->>Student: 202 Accepted { job_id, submission_id }
    GW->>RS: XADD judge_jobs { job_id, submission_id, storage_path, source_code }

    RS->>JW: XREADGROUP judge_jobs
    JW->>JW: Chấm trên /data/problems/:ro đo thời gian từng subtask tier
    JW->>RS: XADD judge_results { status: TLE, score: 50, subtask_timings[] }
    RS->>GW: XREADGROUP judge_results
    GW->>DB: UPDATE submissions (TLE, subtask_timings), UPDATE jobs (COMPLETED)

    Student->>GW: GET /api/v1/submissions/{submission_id}
    GW-->>Student: 200 OK + ETag { status: TLE, subtask_timings[] }

    Student->>GW: POST /api/v1/submissions/{submission_id}/analyze (On-Demand)
    GW->>DB: SELECT * FROM ai_cache WHERE (problem_id, source_code_sha256)
    alt Cache Hit
        GW-->>Student: 200 OK { detected_complexity, socratic_hint, cached: true }
    else Cache Miss
        GW->>AI: POST /internal/ai/analyze-complexity (code + subtask_timings)
        AI-->>GW: { detected_complexity: O(N^2), socratic_hint, guiding_questions }
        GW->>DB: INSERT INTO ai_cache
        GW-->>Student: 200 OK { detected_complexity, socratic_hint, cached: false }
    end
```

---

## 6. Ngăn xếp Công nghệ & Chiến lược Kiểm thử

### 6.1 Tech Stack
- **Frontend:** React + TypeScript + `@monaco-editor/react` (thuần, không LSP), Fetch/Axios client.
- **Core Gateway:** Go (`net/http` / router chuẩn), PostgreSQL 16 (`pgx`), Redis 7 Streams (`go-redis`).
- **Judge Worker:** Go Redis Streams consumer bọc `dmoj/judge-small` (`dmoj-cli` + `cptbox`).
- **AI Service:** Python (FastAPI) hoặc Go (Long chốt dứt điểm trong Tuần 12) gọi `gemini-3.8-flash` với structured JSON output.
- **Contract & Mock Tooling:** OpenAPI 3.0.3, Swagger UI (`swaggerapi/swagger-ui`), Stoplight Prism 4 (`stoplight/prism:4`).

### 6.2 Chiến lược Kiểm thử (Testing Strategy)
1. **Tuần 12 (Contract-First Validation):**
   - Kiểm tra cú pháp OpenAPI 3.0.3 (zero broken `$ref`, đúng cấu trúc response/error).
   - Chạy `docker-compose.mock.yml` (Swagger UI + Prism Mock) để kiểm chứng luồng happy path và các mã lỗi `401`/`403`/`422`.
   - Chạy bộ Postman Collection (`tests/postman/algobloom-w12-mock.postman_collection.json`) trực tiếp trên Prism (`{{base_url}} = http://localhost:4010`).
2. **Tuần 13–14 (Unit, Integration & Sandbox Verification):**
   - **Go Gateway:** Unit/handler tests bằng `net/http/httptest` (JWT/RBAC, unified error format, `ETag` `304`, cache hit/miss `ai_cache`).
   - **Judge Worker:** Kiểm thử tích hợp với Redis Streams thật và mã nguồn C++ mẫu (`AC` $O(N \log N)$ vs `TLE` $O(N^2)$) chạy trong `cptbox`.
   - **AI Service:** Kiểm thử JSON Schema validation trên cả hai chế độ `MOCK_AI=true` và `gemini-3.8-flash` thật, mô phỏng retry `429`.
   - **End-to-End Contract:** Chạy lại chính bộ Postman/Newman collection của Tuần 12 nhưng trỏ `{{base_url}}` sang Go Gateway thật (`http://localhost:8000`) để bảo đảm không lệch hợp đồng.
