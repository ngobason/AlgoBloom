package repo

// Store encapsulates all PostgreSQL queries.
// Core Gateway is the SOLE owner of PostgreSQL in AlgoBloom's SOA topology.
// TODO(W13 - Khanh): Implement pgx-backed repositories for users, tags, problems, submissions, jobs, and ai_cache.
type Store struct{}

// NewStore creates a skeleton Store.
func NewStore() *Store {
	return &Store{}
}
