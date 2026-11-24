# Tóm tắt Quyết định Kiến trúc & Đánh đổi (ADR Summary) — AlgoBloom

Tài liệu này ghi nhận các quyết định kiến trúc cốt lõi (Architecture Decision Records) đã được chốt trong giai đoạn Thiết kế (Tuần 12) cho hệ thống **AlgoBloom** (AI-Augmented Online Judge). Mọi thành viên trong nhóm tuân thủ các ranh giới và đánh đổi dưới đây xuyên suốt quá trình triển khai Tuần 13–15.

---

## ADR-01: Tách rời `dmoj/judge-small` (Headless) thay vì triển khai nguyên khối DMOJ Monolith

- **Bối cảnh:** AlgoBloom cần sandbox chấm bài C++/Python an toàn (cách ly syscall, giới hạn CPU/RAM chính xác) để đo thời gian chạy theo từng subtask phân tầng ($N = 10^2, 10^3, 10^4, 10^5$).
- **Quyết định:** Chỉ sử dụng container tối giản `dmoj/judge-small` kèm `dmoj-cli` và `cptbox` ở chế độ headless, được bọc bởi một Go Redis Streams Worker (`services/judge-worker/`). Không triển khai DMOJ Django site, Celery, hay Bridge server gốc.
- **Lý do & Đánh đổi:**
  - *Ưu điểm:* Giảm mạnh footprint tài nguyên (phù hợp môi trường laptop/VM phát triển), loại bỏ hoàn toàn sự phụ thuộc vào schema Django/MySQL của DMOJ, kiểm soát trực tiếp định dạng `subtask_timings[]` trả về cho AI Coach.
  - *Nhược điểm:* Nhóm tự chịu trách nhiệm viết lớp wrapper gọi `dmoj-cli`, đóng gói thư mục test case theo cấu trúc `init.yml` và xử lý parse kết quả đầu ra.
  - *Kiểm soát rủi ro:* Nam thực hiện spike kiểm chứng `cptbox` bên trong Docker container ngay đầu Tuần 13 (`SYS_PTRACE` / seccomp profile).

---

## ADR-02: Hàng đợi kéo (Pull-based Competing Consumers) qua Redis Streams thay vì HTTP Load Balancer

- **Bối cảnh:** Tác vụ sinh test + xác minh đề bài (`verify_jobs`) và chấm bài (`judge_jobs`) tốn nhiều CPU và có thời gian thực thi biến động (vài trăm ms đến vài chục giây).
- **Quyết định:** Giao tiếp bất đồng bộ giữa Core Gateway và Judge Workers thông qua 4 Redis Streams (`verify_jobs`, `verify_results`, `judge_jobs`, `judge_results`) sử dụng `XADD` / `XREADGROUP` / `XACK`. Không đặt HTTP Load Balancer trước các Judge Worker.
- **Lý do & Đánh đổi:**
  - *Ưu điểm:* Tự nhiên hỗ trợ backpressure (worker rảnh mới kéo job, không bị đẩy ngập request), hỗ trợ scale ngang bằng cách thêm container worker cùng consumer group, chống mất job khi worker crash (qua Pending Entries List - PEL).
  - *Nhược điểm:* Cần thiết kế cơ chế theo dõi trạng thái job (`GET /api/v1/jobs/{jobId}`) và xử lý idempotency khi retry message trong PEL.

---

## ADR-03: Kiến trúc SOA — Gateway Orchestration (Option A) thay vì Choreography phân tán

- **Bối cảnh:** Luồng nghiệp vụ chính (Giáo viên tạo đề -> AI sinh đề & test -> Judge xác minh -> Lưu DB -> Xuất bản; Học sinh nộp bài -> Chấm -> Phân tích Big-O) liên quan đến 3 thành phần: Gateway, AI Service và Judge Worker.
- **Quyết định:** Áp dụng **Gateway Orchestration** (`services/gateway/` bằng Go). Gateway là thành phần **duy nhất** sở hữu và kết nối PostgreSQL, đóng vai trò điều phối trung tâm:
  - Client SPA chỉ giao tiếp với Gateway qua `/api/v1/*`.
  - Gateway gọi đồng bộ/nền tới AI Service qua mạng nội bộ có bảo vệ `X-Internal-API-Key`.
  - Gateway đẩy job sang Redis Streams và lắng nghe stream kết quả để cập nhật trạng thái vào PostgreSQL.
  - Judge Worker hoàn toàn stateless và có **ZERO database credentials**.
- **Lý do & Đánh đổi:**
  - *Ưu điểm:* Ranh giới bảo mật rõ ràng (sandbox thực thi code người dùng không thể chạm tới DB ngay cả khi bị vượt rào), quản lý giao dịch và trạng thái `jobs` tập trung tại một điểm duy nhất, dễ debug và kiểm thử hợp đồng.
  - *Nhược điểm:* Gateway tập trung nhiều logic điều phối hơn; nếu không tách rõ `handler` / `service` / `repo` sẽ dễ phình to.
  - *Phân quyền mount ổ đĩa:* Verification worker mount `/data/problems` ở chế độ `:rw` để ghi bộ test đã sinh; Judging workers chỉ mount `:ro`.

---

## ADR-04: Chẩn đoán Big-O bằng Subtask phân tầng thực nghiệm kết hợp LLM thay vì chỉ dùng LLM đọc code

- **Bối cảnh:** Nếu chỉ gửi mã nguồn cho LLM đoán độ phức tạp Big-O, mô hình dễ bị ảo giác (hallucination) với các cấu trúc vòng lặp lồng có điều kiện thoát sớm hoặc hằng số ẩn.
- **Quyết định:** Mỗi bài toán được sinh kèm bộ test phân tầng theo kích thước đầu vào ($N = 10^2, 10^3, 10^4, 10^5$). Khi học sinh nộp bài, Judge Worker thu thập `subtask_timings[]` thực tế (thời gian chạy, bộ nhớ, vị trí "vách đá TLE"). AI Service kết hợp **mã nguồn + bảng thời gian thực nghiệm** để đối chiếu độ phức tạp thực tế với `target_complexity` và sinh gợi ý Socratic (không lộ full code).
- **Lý do & Đánh đổi:**
  - *Ưu điểm:* Bằng chứng thực nghiệm (ví dụ: $N=10^2 \to 4\text{ms}, N=10^3 \to 42\text{ms}, N=10^4 \to \text{TLE}$) giúp LLM neo lập luận chính xác và đưa ra giải thích thuyết phục cho học sinh.
  - *Nhược điểm:* Yêu cầu `generator.py` do AI sinh ra phải tuân thủ chặt chẽ cấu trúc tham số kích thước $N$ theo từng subtask tier.

---

## ADR-05: Kích hoạt AI Coach theo yêu cầu (On-demand) + Cache băm PostgreSQL thay vì tự động chạy sau mỗi lần nộp

- **Bối cảnh:** Hệ thống sử dụng `gemini-3.8-flash` (Free Tier) có giới hạn RPM/TPM chặt (dễ gặp lỗi `429 Too Many Requests`).
- **Quyết định:**
  1. Không bao giờ tự động gọi AI sau khi chấm bài. Học sinh phải bấm nút rõ ràng gọi `POST /api/v1/submissions/{submissionId}/analyze`.
  2. Gateway lưu cache kết quả phân tích trong bảng `ai_cache` với khóa duy nhất `(problem_id, source_code_sha256)`. Nếu hit cache, trả về ngay với cờ `cached: true` mà không gọi AI Service.
  3. AI Service cài đặt exponential backoff khi gặp `429` và chế độ `MOCK_AI=true` cho môi trường dev/CI.
- **Lý do & Đánh đổi:**
  - *Ưu điểm:* Tiết kiệm tối đa quota API miễn phí, giảm độ trễ xuống vài ms cho các bài nộp trùng mã nguồn, tránh spam LLM khi học sinh sửa lỗi nhỏ và nộp liên tục.
  - *Nhược điểm:* Học sinh cần thao tác thêm 1 lần bấm nút để nhận gợi ý (nhưng điều này đồng thời phù hợp triết lý sư phạm: khuyến khích tự suy nghĩ trước khi xin gợi ý).

---

## ADR-06: Plain `@monaco-editor/react` (Không tích hợp LSP) và Caching trình duyệt bằng HTTP `ETag`

- **Bối cảnh:** Frontend cần trình soạn thảo code mượt mà cho C++/Python trong phạm vi đồ án 4 tuần.
- **Quyết định:**
  - Dùng `@monaco-editor/react` thuần (syntax highlighting cơ bản), **không** triển khai Language Server Protocol (`clangd`/`pyright` qua WebSocket).
  - Các endpoint đọc đề bài (`GET /api/v1/problems/{problemId}`) và chi tiết bài nộp (`GET /api/v1/submissions/{submissionId}`) trả về header `ETag` (hỗ trợ `If-None-Match` -> `304 Not Modified`) để giảm tải băng thông khi polling hoặc chuyển trang.
- **Lý do & Đánh đổi:**
  - *Ưu điểm:* Loại bỏ hoàn toàn gánh nặng vận hành container LSP tốn RAM và phức tạp hóa WebSocket proxy; tập trung nguồn lực Frontend vào 3 màn hình cốt lõi (Tag-Combiner Studio, Code Workspace, Big-O Hint Drawer).
  - *Nhược điểm:* Không có auto-complete ngữ nghĩa sâu hay gạch chân lỗi biên dịch thời gian thực như IDE cục bộ (chấp nhận được với trải nghiệm Online Judge tiêu chuẩn).

---

## Bảng tổng hợp Đánh đổi Kiến trúc

| Chủ đề | Lựa chọn chốt (AlgoBloom) | Phương án loại bỏ | Đánh đổi chính |
| :--- | :--- | :--- | :--- |
| Sandbox chấm bài | `dmoj/judge-small` + Go Worker | DMOJ Monolith | Tự viết wrapper đổi lấy nhẹ và tách DB hoàn toàn |
| Giao tiếp Worker | Redis Streams (`XREADGROUP`) | HTTP Load Balancer | Thêm endpoint polling `jobs` đổi lấy backpressure & resilience |
| Điều phối SOA | Gateway Orchestration (Option A) | Event Choreography | Gateway nhiều logic hơn đổi lấy bảo mật 1 nguồn chân lý DB |
| Phân tích Big-O | Subtask thực nghiệm + LLM | Chỉ LLM đọc code | `generator.py` phức tạp hơn đổi lấy chẩn đoán có căn cứ |
| Gọi AI Coach | On-demand + Hash Cache Postgres | Auto-trigger mỗi submit | Thêm 1 click đổi lấy sống sót trên Free Tier API |
| Code Editor | Plain Monaco (No LSP) | Monaco + `clangd` LSP | Không có semantic autocomplete đổi lấy triển khai nhanh, nhẹ |
