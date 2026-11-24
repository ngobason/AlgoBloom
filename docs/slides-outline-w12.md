# Dàn ý Slide Báo cáo Thiết kế Tuần 12 (Design & Trade-offs Review)

- **Tổng thời lượng trình bày:** 10–12 phút (7 slide + 3 phút live demo Swagger UI & Prism Mock).
- **Trọng tâm đánh giá:** Không chỉ trình bày ý tưởng sản phẩm mà phải làm rõ **quyết định kiến trúc, ranh giới dịch vụ, sự khác biệt Resource Model vs. DB Schema, hợp đồng OpenAPI và đánh đổi kỹ thuật**.

---

## Cấu trúc 7 Slide & Phân công Trình bày

### Slide 1: Bài toán & Định vị AlgoBloom (1 phút — Sơn)
- **Nội dung:**
  - Hai khoảng trống của OJ truyền thống (Codeforces/LeetCode/DMOJ): (1) Giáo viên tốn công viết đề & test phân tầng, còn LLM free-text dễ sinh đề sai; (2) Verdict `TLE` khô khan, không chỉ ra Big-O thực tế hay hướng tối ưu sư phạm.
  - Hai tính năng trọng tâm: **Teacher Intent-Driven Problem Studio** (tự xác minh 4 tầng $N=10^2..10^5$) và **Student Empirical Big-O & Socratic Coach** (on-demand).
  - Ranh giới MVP vs. Out-of-Scope (không LSP, không WebSocket, không free-chat).

### Slide 2: Kiến trúc SOA — Gateway Orchestration & Ranh giới Tin cậy (2 phút — Nam)
- **Nội dung:**
  - Chèn sơ đồ kiến trúc SOA từ `docs/design.md` (Client SPA -> Core Go Gateway -> PostgreSQL / AI Service / Redis Streams -> Judge Workers).
  - Nhấn mạnh 3 ranh giới bảo mật:
    1. Gateway là **chủ sở hữu duy nhất** của PostgreSQL; Judge Workers có **ZERO DB credentials**.
    2. AI Service chỉ mở nội bộ qua `X-Internal-API-Key`.
    3. Phân quyền volume `/data/problems`: Verification worker `:rw`, Judging workers `:ro`.

### Slide 3: Resource Model vs. PostgreSQL ERD (2 phút — Khánh)
- **Nội dung:**
  - So sánh trực quan sơ đồ Resource Model và 7 bảng PostgreSQL (`users`, `tags`, `problems`, `problem_tags`, `submissions`, `jobs`, `ai_cache`).
  - Trình bày 4 lý do cốt lõi khiến API Resource khác DB Schema:
    1. `problem_tags` (3NF) -> nhúng `tags[]` trong `Problem`.
    2. `StudentWeakness` là computed projection (không có bảng riêng).
    3. `ai_cache` ẩn hoàn toàn khỏi public API (chỉ lộ cờ `cached: boolean`).
    4. Che giấu `password_hash`, `generator_code`, `reference_solution_cpp`, `storage_path`; chuyển `version` thành HTTP `ETag`.

### Slide 4: Thiết kế Hợp đồng REST API & Xử lý Bất đồng bộ (1.5 phút — Khánh)
- **Nội dung:**
  - Chuẩn `/api/v1/*`: phân trang (`page`/`limit`), lọc (`tags`/`difficulty`/`status`), sắp xếp (`sort`).
  - Mẫu `202 Accepted` + `GET /api/v1/jobs/{jobId}` cho sinh đề & chấm bài.
  - HTTP `ETag` / `If-None-Match` (`304 Not Modified`) giảm tải polling.
  - Định dạng lỗi thống nhất `{ error: { code, message, details, request_id } }` cho `400`, `401`, `403`, `404`, `422`, `429`, `500`.

### Slide 5: Luồng Tự xác minh & Chẩn đoán Big-O Thực nghiệm (1.5 phút — Nam & Long)
- **Nội dung:**
  - Chèn Sequence Diagram (Pha A: `verify_jobs` -> `cptbox` -> `verify_results`; Pha B: `judge_jobs` -> `subtask_timings[]` -> `POST /analyze`).
  - Giải thích cơ chế Redis Streams competing consumers (`XADD`/`XREADGROUP`/`XACK`) thay cho HTTP Load Balancer.
  - Giải thích vì sao kết hợp `subtask_timings[]` + `gemini-3.8-flash` (JSON Schema strict) giảm ảo giác Big-O.

### Slide 6: Quyết định Đánh đổi Kỹ thuật (Key Trade-offs / ADRs) (1.5 phút — Long)
- **Nội dung:** Bảng 6 đánh đổi chính từ `docs/adr-summary.md`:
  1. `dmoj/judge-small` headless vs. DMOJ Monolith.
  2. Redis Streams pull-based vs. HTTP Load Balancer.
  3. Gateway Orchestration vs. Choreography.
  4. On-demand + Postgres hash cache `(problem_id, sha256)` + `429` backoff + `MOCK_AI=true` để sống sót trên Free Tier.
  5. Plain Monaco vs. LSP.

### Slide 7: Trải nghiệm 3 Màn hình MVP & Kế hoạch Tuần 13–15 (1 phút — Sơn)
- **Nội dung:**
  - Wireframe 3 màn hình: (1) Tag-Combiner Studio (Giáo viên), (2) Code Workspace + Bảng Subtask Timings (Học sinh), (3) Big-O & Socratic Hint Drawer.
  - Tóm tắt phân công Tuần 13 (4 nhánh song song) và 2 rủi ro lớn nhất (`cptbox` trong Docker, `429` Gemini Free Tier) kèm phương án xử lý.

---

## Kịch bản Live Demo Thứ Tư (Swagger UI + Prism Mock — 3 phút)

**Người điều khiển:** Sơn (hoặc Khánh hỗ trợ).
**Chuẩn bị trước buổi báo cáo:**
```bash
docker compose -f docker-compose.mock.yml up -d
```
Mở sẵn trình duyệt tại `http://localhost:8080` (Swagger UI đã cấu hình server mặc định là `http://localhost:4010` — Prism Mock Server).

### Các bước Demo Chuỗi 4 Thao tác (3 Happy Path nối tiếp + 1 Error/Unauthorized Case)

1. **Bước 0 — Kiểm tra trường hợp lỗi xác thực (Error / Unauthorized Case):**
   - Mở `POST /api/v1/problems/generate` -> bấm **Try it out** **KHÔNG** nhập Bearer token -> Execute.
   - **Kết quả kỳ vọng:** Prism trả về `401 Unauthorized` với cấu trúc lỗi chuẩn `{ "error": { "code": "UNAUTHORIZED", "message": "...", "request_id": "..." } }`.
   - Sau đó bấm nút **Authorize** ở góc trên Swagger UI, nhập token mẫu `mock-teacher-jwt` để tiếp tục luồng chính.

2. **Bước 1 — Giáo viên kích hoạt sinh đề bài theo tổ hợp Tag (`POST /api/v1/problems/generate`):**
   - Dùng payload mặc định (`tags: ["dp", "binary-search"]`, `difficulty: 1600`).
   - **Kết quả kỳ vọng:** `202 Accepted` trả về `job_id` và trạng thái `PENDING`.
   - Gọi tiếp `GET /api/v1/jobs/{jobId}` -> thấy trạng thái `COMPLETED` kèm `resource_id` của bài toán đã xác minh (`PUBLISHED`).

3. **Bước 2 — Học sinh xem đề & xem kết quả nộp bài có Vách đá TLE (`GET /api/v1/problems/{problemId}` & `GET /api/v1/submissions/{submissionId}`):**
   - Gọi `GET /api/v1/problems/{problemId}` -> chỉ rõ response có header `ETag` và mảng `subtask_tiers` ($N = 10^2..10^5$), không hề rò rỉ `reference_solution_cpp` hay `generator_code`.
   - Gọi `GET /api/v1/submissions/{submissionId}` -> chỉ rõ verdict `TLE` (50/100 điểm) và mảng `subtask_timings[]` (Subtask 1: `4ms`, Subtask 2: `48ms`, Subtask 3: `TLE > 2000ms`).

4. **Bước 3 — Phân tích Big-O Thực nghiệm & Gợi ý Socratic On-Demand (`POST /api/v1/submissions/{submissionId}/analyze`):**
   - Thực thi endpoint phân tích cho bài nộp vừa xem.
   - **Kết quả kỳ vọng:** `200 OK` trả về `detected_complexity: "O(N^2)"`, `target_complexity: "O(N log N)"`, `bottleneck_summary`, `socratic_hint` (không lộ full code), `guiding_questions[]` và trường `cached: false`.
   - *(Tùy chọn mở rộng)* Chạy nhanh Postman Collection (`tests/postman/algobloom-w12-mock.postman_collection.json`) để chứng minh kiểm thử tự động pass cho cả happy path và negative cases (`401`/`403`/`422`).
