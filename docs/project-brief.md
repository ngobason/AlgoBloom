# Bản Tóm tắt Dự án (Project Brief) — AlgoBloom

## 1. Đặt vấn đề (Problem Statement)

Các hệ thống Online Judge (OJ) truyền thống như Codeforces, LeetCode hay DMOJ làm rất tốt việc chấm bài tự động theo bộ test tĩnh, nhưng vẫn tồn tại hai khoảng trống nghiêm trọng trong bối cảnh giảng dạy thuật toán đại học và luyện thi:

1. **Chi phí tạo bài tập chất lượng cao cho giáo viên rất lớn:** Để thiết kế một bài toán bám sát đúng tổ hợp kỹ năng (ví dụ: Quy hoạch động kết hợp Tìm kiếm nhị phân) và đúng điểm yếu của lớp, giáo viên phải tự viết đề, viết script sinh test phân tầng và lời giải chuẩn C++, rồi tự kiểm chứng không lỗi tràn số hay TLE sai. Nếu dùng LLM bằng prompt tự do (free-text), đề bài thường mơ hồ, test case sai ràng buộc hoặc lời giải mẫu không vượt qua chính bộ test đó.
2. **Phản hồi khi bài nộp TLE/WA quá nghèo nàn về mặt sư phạm:** Khi học sinh nộp bài bị `TLE` (Time Limit Exceeded), hệ thống chỉ báo một nhãn verdict khô khan. Học sinh không biết thuật toán của mình đang chạy ở độ phức tạp thực tế nào ($O(N^2)$ hay $O(N \log^2 N)$), bị nghẽn ở tầng dữ liệu nào, và cần thay đổi tư duy theo hướng nào để đạt độ phức tạp mục tiêu mà không cần đọc ngay lời giải mẫu.

**AlgoBloom** giải quyết trực tiếp hai khoảng trống này thông qua hai năng lực cốt lõi:
- **Teacher Intent-Driven Problem Studio:** Giáo viên chọn thẻ thuật toán có cấu trúc + độ khó mục tiêu (+ điểm yếu học sinh tùy chọn). Hệ thống tự sinh đề, `generator.py`, `reference.cpp` và **xác minh tự động trong sandbox cô lập** trên 4 tầng kích thước ($N = 10^2, 10^3, 10^4, 10^5$) trước khi xuất bản.
- **Student Empirical Big-O & Socratic Hint Coach:** Chấm bài theo subtask phân tầng để đo đường cong thời gian thực tế, kết hợp LLM theo yêu cầu (on-demand) để chẩn đoán Big-O thực nghiệm và đưa ra gợi ý Socratic (không làm lộ full code).

---

## 2. Đối tượng sử dụng API (API Consumers)

| Nhóm Consumer | Vai trò / Thành phần | Mục đích tiêu thụ API | Cơ chế xác thực |
| :--- | :--- | :--- | :--- |
| **Client SPA (Web App)** | Giáo viên (`TEACHER`) | Chọn thẻ thuật toán, xem điểm yếu học sinh, kích hoạt sinh đề bài tự xác minh, theo dõi tiến trình job, quản lý danh sách đề | JWT Bearer (`Authorization: Bearer <token>`) |
| **Client SPA (Web App)** | Học sinh (`STUDENT`) | Duyệt/lọc đề bài, đọc đề, viết code C++/Python trên Monaco Editor, nộp bài, xem bảng thời gian từng subtask, bấm nút xin phân tích Big-O & gợi ý Socratic | JWT Bearer (`Authorization: Bearer <token>`) |
| **Internal Service Consumer** | Core Gateway -> AI Service | Gọi nội bộ để sinh đề/test (`POST /internal/ai/generate-problem`) và phân tích Big-O (`POST /internal/ai/analyze-complexity`) | Header `X-Internal-API-Key` (mạng nội bộ) |
| **Async Worker Consumer** | Judge Worker <-> Redis Streams | Tiêu thụ `verify_jobs` / `judge_jobs` và trả kết quả về `verify_results` / `judge_results` (không gọi trực tiếp DB) | Redis ACL / Internal Network |

---

## 3. Các Ca sử dụng Cốt lõi (Core Use Cases)

1. **UC-01 — Đăng ký, Đăng nhập & Phân quyền (Auth & RBAC):** Người dùng đăng ký/đăng nhập nhận JWT access/refresh token với vai trò `TEACHER` hoặc `STUDENT`. Các thao tác nhạy cảm như sinh đề bài bị chặn `403 Forbidden` đối với `STUDENT`.
2. **UC-02 — Tra cứu Danh mục Thẻ & Điểm yếu Học sinh:** Giáo viên truy vấn danh mục thẻ chuẩn Codeforces (`GET /api/v1/tags`) và hồ sơ điểm yếu của một học sinh (`GET /api/v1/students/{studentId}/weaknesses`) tổng hợp từ lịch sử nộp bài (`WA`/`TLE` theo từng tag).
3. **UC-03 — Sinh và Tự xác minh Đề bài theo Chủ đích (Intent-Driven Problem Generation):** Giáo viên gửi danh sách tag + độ khó (`POST /api/v1/problems/generate`), nhận `202 Accepted` kèm `job_id`. Gateway gọi AI Service sinh đề + `generator.py` + `reference.cpp`, sau đó đẩy sang `verify_jobs` để Judge Worker sinh test 4 tầng và chạy `reference.cpp` kiểm chứng `AC` toàn bộ trước khi chuyển trạng thái đề sang `PUBLISHED`.
4. **UC-04 — Nộp bài & Chấm Subtask Phân tầng:** Học sinh nộp mã nguồn C++/Python (`POST /api/v1/submissions`), nhận `202 Accepted` + `job_id`, polling `GET /api/v1/jobs/{jobId}` tới khi `COMPLETED`, sau đó xem kết quả chi tiết kèm mảng `subtask_timings[]` (`GET /api/v1/submissions/{submissionId}`).
5. **UC-05 — Phân tích Big-O Thực nghiệm & Gợi ý Socratic (On-Demand):** Khi bài nộp bị `TLE` hoặc chưa tối ưu, học sinh chủ động bấm nút gọi `POST /api/v1/submissions/{submissionId}/analyze`. Gateway kiểm tra cache băm `(problem_id, sha256(source_code))` trong PostgreSQL; nếu miss mới gọi AI Service và trả về độ phức tạp chẩn đoán, điểm nghẽn và câu hỏi gợi mở Socratic.

---

## 4. Luồng Demo Trọng tâm End-to-End (Focal Demo Flow)

1. **Bước 1 (Giáo viên tạo đề đã xác minh):** Giáo viên chọn tổ hợp thẻ `["dp", "binary-search"]`, độ khó `1600`, gọi `POST /api/v1/problems/generate` -> nhận `202 Accepted` (`job_id`). Sau khi AI sinh đề và Judge Worker xác minh thành công `reference.cpp` trên 4 tầng $N \in \{10^2, 10^3, 10^4, 10^5\}$, polling `GET /api/v1/jobs/{jobId}` trả về `COMPLETED` cùng `problem_id` ở trạng thái `PUBLISHED`.
2. **Bước 2 (Học sinh nộp lời giải chưa tối ưu $O(N^2)$):** Học sinh mở đề (`GET /api/v1/problems/{problemId}`), viết lời giải quy hoạch động hai vòng lặp $O(N^2)$ và nộp qua `POST /api/v1/submissions`.
3. **Bước 3 (Quan sát "Vách đá TLE" ở Subtask 3):** Sau khi job chấm bài hoàn tất, `GET /api/v1/submissions/{submissionId}` trả về verdict `TLE` (50/100 điểm) với số liệu thực nghiệm:
   - Subtask 1 ($N \le 10^2$): `AC` — `4 ms`
   - Subtask 2 ($N \le 10^3$): `AC` — `48 ms`
   - Subtask 3 ($N \le 10^4$): `TLE` — `> 2000 ms`
   - Subtask 4 ($N \le 10^5$): `TLE` — `> 2000 ms`
4. **Bước 4 (Phân tích Big-O & Gợi ý Socratic On-Demand):** Học sinh bấm nút "Phân tích Big-O" -> `POST /api/v1/submissions/{submissionId}/analyze`. Hệ thống trả về `detected_complexity: "O(N^2)"`, `target_complexity: "O(N log N)"`, chỉ ra vòng lặp chuyển trạng thái tuyến tính gây vách đá tại $N = 10^4$, và đặt câu hỏi Socratic gợi ý duy trì mảng đơn điệu kết hợp `lower_bound` (không lộ code hoàn chỉnh). Lần bấm thứ hai với cùng mã nguồn trả về `cached: true` ngay lập tức.

---

## 5. Phạm vi MVP vs. Ngoài phạm vi (Out-of-Scope)

| Hạng mục | Trong phạm vi MVP (Tuần 12–15) | Ngoài phạm vi (Out-of-Scope) |
| :--- | :--- | :--- |
| **Quản lý người dùng** | Đăng ký, đăng nhập JWT, 2 vai trò `TEACHER` / `STUDENT` | OAuth2/SSO bên thứ ba, quản trị đa tổ chức (multi-tenant) |
| **Sinh đề bài** | Chọn tag + độ khó (+ điểm yếu học sinh), tự xác minh 4 tầng subtask | Prompt tự do không kiểm soát, đề bài tương tác (interactive) hoặc chấm đa đáp án tùy biến phức tạp (custom special judge) |
| **Ngôn ngữ lập trình** | `cpp17`, `cpp20`, `python3` | Java, Rust, Go, C# |
| **Trình soạn thảo Code** | Plain `@monaco-editor/react` (syntax highlighting) | Tích hợp LSP (`clangd`/`pyright`), cộng tác thời gian thực |
| **Trợ lý AI** | Phân tích Big-O thực nghiệm + gợi ý Socratic theo yêu cầu, cache băm Postgres | Chatbot hội thoại nhiều lượt tự do, tự động sửa code thay học sinh |
| **Cuộc thi & Xếp hạng** | Danh sách đề bài, nộp bài cá nhân, hồ sơ điểm yếu học sinh | Tổ chức kỳ thi đồng thời quy mô lớn, bảng xếp hạng ICPC realtime, hệ thống chống đạo văn |
| **Cập nhật trạng thái** | HTTP Polling (`GET /api/v1/jobs/{jobId}`) + HTTP `ETag` | WebSocket / Server-Sent Events (SSE) push |
