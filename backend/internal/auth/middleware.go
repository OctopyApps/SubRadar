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
			tokenStr, ok := tokenFromRequest(r)
			if !ok {
				http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
				return
			}

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

// tokenFromRequest достаёт JWT из заголовка Authorization: Bearer (основной
// путь — iOS-клиент и большинство веб-запросов), а если его нет — из
// httpOnly cookie TokenCookieName (веб-клиент, который выбрал cookie вместо
// ручного хранения токена).
func tokenFromRequest(r *http.Request) (string, bool) {
	if header := r.Header.Get("Authorization"); strings.HasPrefix(header, "Bearer ") {
		return strings.TrimPrefix(header, "Bearer "), true
	}
	if cookie, err := r.Cookie(TokenCookieName); err == nil && cookie.Value != "" {
		return cookie.Value, true
	}
	return "", false
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
