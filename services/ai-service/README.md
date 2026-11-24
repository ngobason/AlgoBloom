# AlgoBloom AI Pedagogical Service (`services/ai-service`)

Owner: **Long** (AI Pedagogical Service)

## Architectural Role
- **Internal-Only Service:** Not exposed to the public internet or Frontend SPA. Only `services/gateway` calls this service over the internal Docker network.
- **Authentication:** Every request MUST include `X-Internal-API-Key: <INTERNAL_API_KEY>`. Missing or invalid keys MUST return `401 Unauthorized`.
- **Model:** `gemini-3.8-flash` (Free Tier) configured with strict JSON Schema output matching `schemas/*.schema.json`.
- **Resilience:**
  - Exponential backoff with jitter on upstream `429 Too Many Requests` / `503`.
  - Deterministic `MOCK_AI=true` mode returning valid, realistic fixtures for local development and CI without consuming Gemini quota.
- **Stack Flexibility (Lock in Week 12 PR):** Long may implement this service in **Python (FastAPI + Pydantic + `google-genai`)** or **Go** without altering the HTTP contract below.

## Internal HTTP Contract

### 1. `POST /internal/ai/generate-problem`
- **Headers:** `Content-Type: application/json`, `X-Internal-API-Key: <secret>`
- **Request Schema:** `schemas/generate-problem.request.schema.json`
- **Response Schema (`200 OK`):** `schemas/generate-problem.response.schema.json`
  - Returns structured problem statement, `sample_cases`, 4-tier `subtask_tiers` ($N = 10^2, 10^3, 10^4, 10^5$), Python `generator_code`, and optimal C++ `reference_solution_cpp`.

### 2. `POST /internal/ai/analyze-complexity`
- **Headers:** `Content-Type: application/json`, `X-Internal-API-Key: <secret>`
- **Request Schema:** `schemas/analyze-complexity.request.schema.json`
- **Response Schema (`200 OK`):** `schemas/analyze-complexity.response.schema.json`
  - Combines student `source_code` + empirical `subtask_timings[]` + `target_complexity` to diagnose `detected_complexity`, explain the TLE cliff (`bottleneck_summary`), and provide a non-spoiler `socratic_hint` + `guiding_questions[]`.

### 3. `GET /health`
- Returns `200 OK` `{ "status": "ok", "service": "algobloom-ai-service", "mock_ai": true|false }`.

## Caching Boundary Note
PostgreSQL hash caching (`ai_cache` keyed on `(problem_id, source_code_sha256)`) is owned and checked by **Core Gateway** (`services/gateway`) *before* calling `/internal/ai/analyze-complexity`. This keeps `services/ai-service` stateless with zero database dependencies.
