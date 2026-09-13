package auth

import (
	"context"
	"net/http"
	"strings"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
)

type contextKey string

const (
	UserIDKey   contextKey = "user_id"
	UserRoleKey contextKey = "user_role"
)

// Middleware проверяет JWT, убеждается что пользователь не заблокирован,
// и кладёт user_id + role в контекст запроса.
func Middleware(secret string, users *repository.UserRepository) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			if !strings.HasPrefix(header, "Bearer ") {
				http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
				return
			}

			tokenStr := strings.TrimPrefix(header, "Bearer ")
			claims, err := ParseToken(tokenStr, secret)
			if err != nil {
				http.Error(w, `{"error":"invalid token"}`, http.StatusUnauthorized)
				return
			}

			// Проверяем пользователя в БД — актуальный статус блокировки и роль
			user, err := users.FindByID(claims.UserID)
			if err != nil {
				http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
				return
			}

			if user.IsBlocked {
				http.Error(w, `{"error":"account blocked"}`, http.StatusForbidden)
				return
			}

			// Обновляем last_seen_at асинхронно — не блокируем запрос
			go users.UpdateLastSeen(user.ID) //nolint:errcheck

			ctx := context.WithValue(r.Context(), UserIDKey, user.ID)
			ctx = context.WithValue(ctx, UserRoleKey, user.Role)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// UserIDFromContext извлекает user_id из контекста запроса.
func UserIDFromContext(ctx context.Context) (int64, bool) {
	id, ok := ctx.Value(UserIDKey).(int64)
	return id, ok
}

// UserRoleFromContext извлекает роль пользователя из контекста запроса.
func UserRoleFromContext(ctx context.Context) (models.UserRole, bool) {
	role, ok := ctx.Value(UserRoleKey).(models.UserRole)
	return role, ok
}
