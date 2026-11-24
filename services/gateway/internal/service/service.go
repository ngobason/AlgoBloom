package service

// Orchestrator coordinates PostgreSQL state, internal AI Service calls (X-Internal-API-Key),
// and Redis Streams job dispatch (`verify_jobs`, `judge_jobs`).
// TODO(W13 - Khanh): Implement ProblemGeneration, SubmissionJudge, WeaknessProfiler, and BigOAnalysis (with ai_cache lookup).
type Orchestrator struct{}

// NewOrchestrator creates a skeleton Orchestrator.
func NewOrchestrator() *Orchestrator {
	return &Orchestrator{}
}
