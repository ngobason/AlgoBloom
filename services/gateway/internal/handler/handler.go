package handler

import "net/http"

// APIHandler holds HTTP handlers for `/api/v1/*` routes.
// TODO(W13 - Khanh): Inject service layer, unified ErrorResponse encoder, and ETag middleware.
type APIHandler struct{}

// NewAPIHandler creates a skeleton APIHandler.
func NewAPIHandler() *APIHandler {
	return &APIHandler{}
}

// RegisterRoutes mounts `/api/v1/*` routes onto the given ServeMux.
func (h *APIHandler) RegisterRoutes(_ *http.ServeMux) {
	// TODO(W13 - Khanh): Mount auth, tags, students, problems, submissions, and jobs routes.
}
