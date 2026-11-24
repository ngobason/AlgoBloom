# AlgoBloom Client SPA (`frontend`)

Owner: **Sơn** (Client SPA & Presentation)

## Architectural Constraints (Locked)
- **API Boundary:** Communicates **ONLY** with Core Gateway (`/api/v1/*`). Never calls AI Service or Redis directly.
- **Code Editor:** Plain `@monaco-editor/react` (syntax highlighting for C++/Python). **NO LSP** (`clangd`/`pyright`) integration.
- **Async Updates & Caching:**
  - Use HTTP polling on `GET /api/v1/jobs/{jobId}` (e.g., every 1.5s until `COMPLETED` or `FAILED`).
  - Leverage browser HTTP `ETag` caching on `GET /api/v1/problems/{problemId}` and `GET /api/v1/submissions/{submissionId}`.
- **On-Demand AI Hint:** Never auto-call `POST /api/v1/submissions/{submissionId}/analyze` after judging finishes. Require an explicit user button click ("Analyze Big-O & Hint").

## API Base URL Configuration
- **Week 12 (Prism Mock Server):** `VITE_API_BASE_URL=http://localhost:4010`
- **Week 13+ (Local Go Core Gateway):** `VITE_API_BASE_URL=http://localhost:8000`
- All endpoints are prefixed with `/api/v1` (e.g., `${VITE_API_BASE_URL}/api/v1/problems`).

## 3 MVP Screens
1. **Tag-Combiner Studio (`TEACHER`):**
   - Loads tags from `GET /api/v1/tags` and optional student weakness profile from `GET /api/v1/students/{studentId}/weaknesses`.
   - Submits structured intent (`tags[]`, `difficulty`) to `POST /api/v1/problems/generate` -> polls `GET /api/v1/jobs/{jobId}` -> links to verified `PUBLISHED` problem.
2. **Code Workspace (`STUDENT`):**
   - Split pane: Problem statement + 4 subtask tiers (`GET /api/v1/problems/{problemId}`) on the left; plain `@monaco-editor/react` + language selector (`cpp17`, `cpp20`, `python3`) on the right.
   - Submits via `POST /api/v1/submissions`, polls `GET /api/v1/jobs/{jobId}`, and renders tiered `subtask_timings[]` table showing runtime / TLE cliff.
3. **Big-O & Socratic Hint Drawer (`STUDENT`):**
   - Slide-over drawer triggered strictly by explicit button click calling `POST /api/v1/submissions/{submissionId}/analyze`.
   - Displays `detected_complexity` vs `target_complexity`, `bottleneck_summary`, `socratic_hint`, `guiding_questions[]`, and a subtle `Cached` badge when `cached: true`.

## Week 13 Initialization Guide
Initialize using Vite + React + TypeScript locally (no global npm packages):
```bash
npx --yes create-vite@latest . --template react-ts
npm install @monaco-editor/react
```
