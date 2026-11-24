package redis

// Stream names locked in contracts/redis-schemas.json.
const (
	StreamVerifyJobs    = "verify_jobs"
	StreamVerifyResults = "verify_results"
	StreamJudgeJobs     = "judge_jobs"
	StreamJudgeResults  = "judge_results"
)

// StreamBroker wraps Redis Streams XADD / XREADGROUP / XACK operations for Core Gateway.
// TODO(W13 - Khanh): Implement producer for verify_jobs/judge_jobs and background consumer for verify_results/judge_results.
type StreamBroker struct{}

// NewStreamBroker creates a skeleton StreamBroker.
func NewStreamBroker() *StreamBroker {
	return &StreamBroker{}
}
