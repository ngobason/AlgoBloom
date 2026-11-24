# AlgoBloom Judge Worker (`services/judge-worker`)

Owner: **Nam** (Judge Infra & Redis Broker)

## Responsibilities
- Pull-based competing consumer reading jobs from Redis Streams (`XREADGROUP` / `XACK`) — **NO HTTP load balancer**.
- Executes untrusted code and test generators inside `dmoj/judge-small` (`dmoj-cli` + `cptbox`).
- **Zero Database Credentials:** Never connects to PostgreSQL. Communicates exclusively via Redis Streams defined in `contracts/redis-schemas.json`.

## Operating Modes & Volume Permissions
| `WORKER_MODE` | Consumes Stream | Produces Stream | `/data/problems` Mount |
| :--- | :--- | :--- | :--- |
| `verify` | `verify_jobs` (`cg_verify_workers`) | `verify_results` | `:rw` (writes generated 4-tier test suites + `init.yml`) |
| `judge` | `judge_jobs` (`cg_judge_workers`) | `judge_results` | `:ro` (read-only judging against verified test suites) |

## Week 13 Implementation Checklist
1. Verify `cptbox` execution inside `dmoj/judge-small` Docker container (`--cap-add=SYS_PTRACE --security-opt seccomp=unconfined`).
2. Implement Redis Streams consumer loop with PEL recovery and graceful shutdown.
3. Implement `verify_jobs` pipeline: run `generator.py` across $N \in \{10^2, 10^3, 10^4, 10^5\}$, generate `init.yml`, compile & verify `reference.cpp` gets `AC` on all 4 tiers.
4. Implement `judge_jobs` pipeline: invoke `dmoj-cli`, parse per-subtask execution times & memory into `subtask_timings[]`, publish `judge_results`.
