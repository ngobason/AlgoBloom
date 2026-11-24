# Backlog, Lộ trình Triển khai & Quản trị Rủi ro (Tuần 12–15) — AlgoBloom

---

## 1. Lộ trình Tổng thể (Week 12–15 Roadmap)

| Tuần | Mốc đánh giá | Mục tiêu cốt lõi | Sản phẩm bàn giao (Deliverables) |
| :--- | :--- | :--- | :--- |
| **Tuần 12** | **Design Review** (Thứ Tư) | Chốt kiến trúc SOA, hợp đồng OpenAPI 3.0.3, ERD, Redis Schemas, Mock Server chạy được & toàn bộ 4 thành viên có PR merge trên Git | `docs/*`, `contracts/openapi.yaml`, `contracts/redis-schemas.json`, `docker-compose.mock.yml`, Postman starter collection, 7 slide + báo cáo tiến độ W12 |
| **Tuần 13** | **Implementation Review (Core)** | Dựng trục xương sống chạy được đầu-cuối (vertical slice) từng dịch vụ theo đúng hợp đồng đã chốt | Go Gateway (Auth, CRUD, DB migrations, Job dispatcher), Judge Worker (`dmoj/judge-small` + Redis Streams), AI Service (`MOCK_AI=true` + Gemini), React SPA (3 màn hình nối API) |
| **Tuần 14** | **Integration & Hardening** | Tích hợp hoàn chỉnh 4 dịch vụ qua Docker Compose, chạy thật luồng sinh đề tự xác minh + nộp bài TLE + phân tích Big-O, đo tải & tối ưu cache | `docker-compose.yml` full stack, tích hợp Newman/Postman trên Gateway thật, kiểm thử `429` backoff & `ETag`, sửa lỗi đồng bộ |
| **Tuần 15** | **Final Demo & Defense** | Đóng gói dữ liệu demo ổn định, hoàn thiện tài liệu tổng kết, kiểm thử hồi quy và trình bày bảo vệ cuối kỳ | Video/kịch bản dự phòng, bộ test hồi quy pass 100%, báo cáo cuối kỳ & slide bảo vệ |

---

## 2. Sổ đăng ký Rủi ro & Biện pháp Giảm thiểu (Risk Register)

| ID | Rủi ro | Mức độ | Ảnh hưởng | Biện pháp giảm thiểu (Mitigation) | Người phụ trách |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **R-01** | `cptbox` bên trong Docker container gặp lỗi quyền kernel (`SYS_PTRACE`, seccomp, cgroups v2) trên máy dev | Cao | Chặn toàn bộ tính năng chấm bài và tự xác minh đề | Thực hiện spike kỹ thuật ngay đầu Tuần 13 trong `services/judge-worker/Dockerfile`; ghi rõ flags `--cap-add=SYS_PTRACE --security-opt seccomp=unconfined` vào compose | **Nam** |
| **R-02** | `gemini-3.8-flash` Free Tier trả về `429 Too Many Requests` khi dev hoặc demo trực tiếp | Cao | Gián đoạn demo sinh đề hoặc phân tích Big-O | 1) On-demand trigger + hash cache PostgreSQL `(problem_id, sha256)`; 2) Exponential backoff + jitter; 3) Chế độ `MOCK_AI=true` dự phòng khẩn cấp | **Long** & **Khánh** |
| **R-03** | AI sinh `generator.py` hoặc `reference.cpp` sai cú pháp / không đạt `AC` khi tự xác minh | Trung bình | Job `PROBLEM_GENERATE` rơi vào `FAILED` | Ràng buộc JSON Schema nghiêm ngặt + prompt kèm mẫu `generator.py` chuẩn 4 tầng; cho phép tối đa 1 lần self-retry trước khi báo `FAILED` rõ ràng | **Long** & **Nam** |
| **R-04** | Lệch tên trường (field drift) giữa OpenAPI, PostgreSQL, Redis Streams và Frontend | Trung bình | Lỗi tích hợp phút chót ở Tuần 14 | Khóa chặt `contracts/openapi.yaml` và `contracts/redis-schemas.json` làm nguồn chân lý duy nhất; kiểm chứng bằng Postman Collection chạy trên cả Prism và Gateway thật | **Khánh** (tổng kiểm) |
| **R-05** | Phình phạm vi Frontend (sa đà vào LSP, WebSocket, giao diện phụ) | Trung bình | Trễ tiến độ 3 màn hình chính | Khóa cứng kiến trúc: Plain Monaco (no LSP), HTTP polling + `ETag`, chỉ tập trung 3 màn hình MVP | **Sơn** |

---

## 3. Ma trận Công việc theo Thành viên (Tuần 12 & Tuần 13)

| Thành viên | Nhiệm vụ Tuần 12 (Thứ Ba — Phải merge PR trước Thứ Tư) | Nhiệm vụ Tuần 13 (Core Implementation) | Nhánh Git đề xuất |
| :--- | :--- | :--- | :--- |
| **Nam** *(Judge Infra & Redis Broker)* | - Review & chuẩn hóa `contracts/redis-schemas.json`<br>- Kiểm tra & hoàn thiện sơ đồ Mermaid SOA + Sequence trong `docs/design.md`<br>- Chạy kiểm chứng `docker-compose.mock.yml` (Swagger UI + Prism) và đính kèm bằng chứng | - Dựng `services/judge-worker/Dockerfile` từ `dmoj/judge-small`, kiểm chứng `cptbox`<br>- Hiện thực Go Redis Streams worker xử lý `judge_jobs -> judge_results` và `verify_jobs -> verify_results`<br>- Đo và trả về `subtask_timings[]` chuẩn xác theo 4 tầng $N$ | `docs/w12-nam-redis-arch`<br>`feat/w13-nam-judge-worker` |
| **Khánh** *(Core Gateway, Auth & DB)* | - Review & bổ sung `contracts/openapi.yaml` khớp 100% với `001_init.sql`<br>- Rà soát bảng so sánh Resource Model vs. DB Schema trong `docs/design.md`<br>- Chạy Postman collection kiểm chứng happy path + `401`/`403`/`422` trên Prism | - Hiện thực Go Gateway: JWT + RBAC (`TEACHER`/`STUDENT`), DB migrations/seed<br>- Hiện thực CRUD Tags/Problems/Submissions + `ETag`<br>- Hiện thực `202` async job dispatcher, Redis result consumer, `ai_cache` & Postman integration tests | `docs/w12-khanh-openapi-erd`<br>`feat/w13-khanh-gateway-core` |
| **Long** *(AI Pedagogical Service)* | - Gọi thử `gemini-3.8-flash` thật để kiểm chứng & thay thế payload ví dụ trong `contracts/openapi.yaml` (đề bài `dp + binary-search` và phân tích `O(N^2)` TLE)<br>- Chốt ngôn ngữ triển khai (Python FastAPI vs. Go) trong `services/ai-service/README.md` | - Hiện thực `/internal/ai/generate-problem` và `/internal/ai/analyze-complexity`<br>- Bảo vệ `X-Internal-API-Key`, ép JSON Schema output<br>- Hiện thực exponential backoff `429` và chế độ `MOCK_AI=true` | `docs/w12-long-ai-samples`<br>`feat/w13-long-ai-service` |
| **Sơn** *(Client SPA & Presentation)* | - Hoàn thiện `docs/project-brief.md`<br>- Thiết kế 3 wireframe (Tag-Combiner Studio, Code Workspace, Big-O Hint Drawer) đưa vào `docs/wireframes/`<br>- Chốt 7 slide Design & Trade-offs (`docs/slides-outline-w12.md`) và kịch bản demo Mock | - Khởi tạo React SPA + plain `@monaco-editor/react` (no LSP)<br>- Hiện thực luồng Login/Register, Tag-Combiner Studio, Code Workspace + Job polling, Big-O Hint Drawer nối API Gateway/Prism | `docs/w12-son-brief-wireframes`<br>`feat/w13-son-frontend-spa` |
