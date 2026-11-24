-- AlgoBloom PostgreSQL Schema (Migration 001)
-- SOLE Owner: services/gateway (Core Gateway & Orchestrator)
-- Aligned 100% with docs/design.md ERD and contracts/openapi.yaml

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Users (RBAC: TEACHER | STUDENT)
CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name     TEXT NOT NULL,
    role          TEXT NOT NULL CHECK (role IN ('TEACHER', 'STUDENT')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Structured Codeforces-style Algorithmic Tags
CREATE TABLE IF NOT EXISTS tags (
    id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug     TEXT NOT NULL UNIQUE,
    name     TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('ALGORITHM', 'DATA_STRUCTURE', 'TECHNIQUE'))
);

-- 3. Problems (internal generator_code, reference_solution_cpp, storage_path are NEVER exposed to students)
CREATE TABLE IF NOT EXISTS problems (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug                   TEXT NOT NULL UNIQUE,
    title                  TEXT NOT NULL,
    statement_md           TEXT NOT NULL,
    input_format_md        TEXT NOT NULL,
    output_format_md       TEXT NOT NULL,
    constraints_md         TEXT NOT NULL,
    difficulty             INT NOT NULL CHECK (difficulty BETWEEN 800 AND 3500),
    time_limit_ms          INT NOT NULL DEFAULT 2000 CHECK (time_limit_ms BETWEEN 500 AND 10000),
    memory_limit_mb        INT NOT NULL DEFAULT 256 CHECK (memory_limit_mb BETWEEN 64 AND 1024),
    target_complexity      TEXT NOT NULL,
    sample_cases           JSONB NOT NULL DEFAULT '[]'::jsonb,
    subtask_tiers          JSONB NOT NULL DEFAULT '[]'::jsonb,
    generator_code         TEXT NOT NULL,
    reference_solution_cpp TEXT NOT NULL,
    storage_path           TEXT NOT NULL,
    status                 TEXT NOT NULL DEFAULT 'DRAFT'
                           CHECK (status IN ('DRAFT', 'VERIFYING', 'PUBLISHED', 'FAILED')),
    created_by             UUID NOT NULL REFERENCES users(id),
    version                INT NOT NULL DEFAULT 1,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_problems_status_difficulty ON problems (status, difficulty);
CREATE INDEX IF NOT EXISTS idx_problems_created_at ON problems (created_at DESC);

-- 4. Problem <-> Tag Join Table (3NF; embedded as tags[] in Public API)
CREATE TABLE IF NOT EXISTS problem_tags (
    problem_id UUID NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
    tag_id     UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (problem_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_problem_tags_tag_id ON problem_tags (tag_id);

-- 5. Submissions (stores tiered empirical subtask_timings[] and source_code_sha256 for ai_cache lookup)
CREATE TABLE IF NOT EXISTS submissions (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    problem_id         UUID NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
    student_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    language           TEXT NOT NULL CHECK (language IN ('cpp17', 'cpp20', 'python3')),
    source_code        TEXT NOT NULL,
    source_code_sha256 CHAR(64) NOT NULL,
    status             TEXT NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING', 'RUNNING', 'AC', 'WA', 'TLE', 'MLE', 'RE', 'CE', 'IE')),
    score              INT NOT NULL DEFAULT 0 CHECK (score BETWEEN 0 AND 100),
    max_time_ms        INT,
    max_memory_kb      INT,
    subtask_timings    JSONB NOT NULL DEFAULT '[]'::jsonb,
    compiler_output    TEXT,
    version            INT NOT NULL DEFAULT 1,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    judged_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_submissions_student_created ON submissions (student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_submissions_problem_status ON submissions (problem_id, status);
CREATE INDEX IF NOT EXISTS idx_submissions_cache_key ON submissions (problem_id, source_code_sha256);

-- 6. Async Jobs (tracks 202 Accepted PROBLEM_GENERATE and SUBMISSION_JUDGE workflows)
CREATE TABLE IF NOT EXISTS jobs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type          TEXT NOT NULL CHECK (type IN ('PROBLEM_GENERATE', 'SUBMISSION_JUDGE')),
    status        TEXT NOT NULL DEFAULT 'PENDING'
                  CHECK (status IN ('PENDING', 'RUNNING', 'COMPLETED', 'FAILED')),
    requested_by  UUID NOT NULL REFERENCES users(id),
    resource_type TEXT CHECK (resource_type IN ('PROBLEM', 'SUBMISSION')),
    resource_id   UUID,
    payload       JSONB NOT NULL DEFAULT '{}'::jsonb,
    result        JSONB,
    error_code    TEXT,
    error_message TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at  TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_jobs_requested_by_created ON jobs (requested_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs (status);

-- 7. AI Analysis Hash Cache (hidden from public API; exposed only as `cached: boolean`)
CREATE TABLE IF NOT EXISTS ai_cache (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    problem_id          UUID NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
    source_code_sha256  CHAR(64) NOT NULL,
    language            TEXT NOT NULL CHECK (language IN ('cpp17', 'cpp20', 'python3')),
    detected_complexity TEXT NOT NULL,
    target_complexity   TEXT NOT NULL,
    bottleneck_summary  TEXT NOT NULL,
    socratic_hint       TEXT NOT NULL,
    guiding_questions   JSONB NOT NULL DEFAULT '[]'::jsonb,
    model_version       TEXT NOT NULL DEFAULT 'gemini-3.8-flash',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_ai_cache_problem_hash UNIQUE (problem_id, source_code_sha256)
);
