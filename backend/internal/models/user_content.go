package models

// Category — пользовательская категория подписки
type Category struct {
	ID        string         `json:"id"` // UUID
	UserID    int64          `json:"user_id"`
	Name      string         `json:"name"`
	Icon      string         `json:"icon"` // SF Symbol name
	CreatedAt RFC3339Seconds `json:"created_at"`
}

// Currency — пользовательская валюта
type Currency struct {
	ID          string         `json:"id"` // UUID
	UserID      int64          `json:"user_id"`
	Code        string         `json:"code"`   // "RUB", "USD"
	Symbol      string         `json:"symbol"` // "₽", "$"
	DisplayName string         `json:"display_name"`
	CreatedAt   RFC3339Seconds `json:"created_at"`
}
