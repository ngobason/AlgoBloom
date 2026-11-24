package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

// WorkerMode defines whether this container mounts /data/problems as :rw (verify) or :ro (judge).
// SECURITY INVARIANT: Judge workers MUST NEVER receive PostgreSQL credentials or network access to DB.
func main() {
	mode := os.Getenv("WORKER_MODE")
	if mode == "" {
		mode = "judge"
	}
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	problemsDir := os.Getenv("PROBLEMS_DIR")
	if problemsDir == "" {
		problemsDir = "/data/problems"
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	log.Printf("[judge-worker] starting skeleton in mode=%s redis=%s problems_dir=%s", mode, redisAddr, problemsDir)

	// TODO(W13 - Nam): Connect go-redis client and create consumer groups:
	// - mode=verify: XREADGROUP on `verify_jobs` (cg_verify_workers), write testdata to /data/problems/:rw,
	//   invoke `dmoj-cli` inside `cptbox` to verify reference.cpp across 4 tiers, XADD `verify_results`, XACK.
	// - mode=judge:  XREADGROUP on `judge_jobs` (cg_judge_workers), read testdata from /data/problems/:ro,
	//   invoke `dmoj-cli` inside `cptbox`, collect tiered subtask_timings[], XADD `judge_results`, XACK.

	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Printf("[judge-worker] shutting down cleanly")
			return
		case <-ticker.C:
			log.Printf("[judge-worker] idle heartbeat (skeleton mode=%s)", mode)
		}
	}
}
