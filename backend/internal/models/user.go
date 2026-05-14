package models

import "time"

// AuthProvider — способ входа пользователя
type AuthProvider string

const (
	AuthProviderLocal  AuthProvider = "local"
	AuthProviderGoogle AuthProvider = "google"
	AuthProviderApple  AuthProvider = "apple"
)

// UserRole — роль пользователя в системе
type UserRole string

const (
	UserRoleUser  UserRole = "user"
	UserRoleAdmin UserRole = "admin"
)

// User — пользователь системы
type User struct {
	ID            int64        `json:"id"`
	Email         string       `json:"email"`
	PasswordHash  string       `json:"-"` // никогда не отдаём клиенту
	Provider      AuthProvider `json:"provider"`
	ProviderID    string       `json:"-"` // ID пользователя у провайдера (Google sub, Apple sub)
	Role          UserRole     `json:"role"`
	IsBlocked     bool         `json:"is_blocked"`
	BlockedAt     *time.Time   `json:"blocked_at,omitempty"`
	BlockedReason *string      `json:"blocked_reason,omitempty"`
	DisplayName   string       `json:"display_name"`
	LastSeenAt    *time.Time   `json:"last_seen_at,omitempty"`
	CreatedAt     time.Time    `json:"created_at"`
}

// IsAdmin возвращает true если пользователь — администратор.
func (u *User) IsAdmin() bool {
	return u.Role == UserRoleAdmin
}

// UserPublic — безопасное представление пользователя для API-ответов.
// Используется в /auth/me и в списках пользователей для не-админов.
type UserPublic struct {
	ID          int64        `json:"id"`
	Email       string       `json:"email"`
	DisplayName string       `json:"display_name"`
	Provider    AuthProvider `json:"provider"`
	Role        UserRole     `json:"role"`
	CreatedAt   time.Time    `json:"created_at"`
}

// UserAdmin — расширенное представление для /admin/users/*.
// Включает поля блокировки и активности.
type UserAdmin struct {
	ID            int64        `json:"id"`
	Email         string       `json:"email"`
	DisplayName   string       `json:"display_name"`
	Provider      AuthProvider `json:"provider"`
	Role          UserRole     `json:"role"`
	IsBlocked     bool         `json:"is_blocked"`
	BlockedAt     *time.Time   `json:"blocked_at,omitempty"`
	BlockedReason *string      `json:"blocked_reason,omitempty"`
	LastSeenAt    *time.Time   `json:"last_seen_at,omitempty"`
	CreatedAt     time.Time    `json:"created_at"`
}

// ToPublic конвертирует User в UserPublic.
func (u *User) ToPublic() UserPublic {
	return UserPublic{
		ID:          u.ID,
		Email:       u.Email,
		DisplayName: u.DisplayName,
		Provider:    u.Provider,
		Role:        u.Role,
		CreatedAt:   u.CreatedAt,
	}
}

// ToAdmin конвертирует User в UserAdmin.
func (u *User) ToAdmin() UserAdmin {
	return UserAdmin{
		ID:            u.ID,
		Email:         u.Email,
		DisplayName:   u.DisplayName,
		Provider:      u.Provider,
		Role:          u.Role,
		IsBlocked:     u.IsBlocked,
		BlockedAt:     u.BlockedAt,
		BlockedReason: u.BlockedReason,
		LastSeenAt:    u.LastSeenAt,
		CreatedAt:     u.CreatedAt,
	}
}
