package auth

import (
	"net/http"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
)

// RequireAdmin запрещает доступ всем кроме пользователей с ролью admin.
// Должен использоваться после Middleware — роль уже лежит в контексте.
func RequireAdmin(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		role, ok := UserRoleFromContext(r.Context())
		if !ok || role != models.UserRoleAdmin {
			http.Error(w, `{"error":"forbidden"}`, http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}
