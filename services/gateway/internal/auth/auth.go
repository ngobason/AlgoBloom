package auth

import "net/http"

// Role represents RBAC roles enforced by the Core Gateway.
type Role string

const (
	RoleTeacher Role = "TEACHER"
	RoleStudent Role = "STUDENT"
)

// Claims represents the decoded JWT subject and role.
type Claims struct {
	UserID string
	Role   Role
}

// RequireAuth is a Week 13 stub for JWT verification and RBAC middleware.
// TODO(W13 - Khanh): Verify Bearer JWT signature/expiry and attach Claims to request context.
func RequireAuth(next http.Handler) http.Handler {
	return next
}
