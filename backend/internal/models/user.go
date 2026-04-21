package models

import "time"

// AuthProvider — способ входа пользователя
type AuthProvider string

const (
	AuthProviderLocal  AuthProvider = "local"
	AuthProviderGoogle AuthProvider = "google"
	AuthProviderApple  AuthProvider = "apple"
)

// User — пользователь системы
type User struct {
	ID           int64        `json:"id"`
	Email        string       `json:"email"`
	PasswordHash string       `json:"-"` // никогда не отдаём клиенту
	Provider     AuthProvider `json:"provider"`
	ProviderID   string       `json:"-"` // ID пользователя у провайдера (Google sub, Apple sub)
	CreatedAt    time.Time    `json:"created_at"`
}
