package models

import "time"

// Subscription — подписка пользователя
type Subscription struct {
	ID              string    `json:"id"` // UUID
	UserID          int64     `json:"user_id"`
	Name            string    `json:"name"`
	Category        string    `json:"category"`
	Price           float64   `json:"price"`
	Currency        string    `json:"currency"`
	BillingPeriod   string    `json:"billing_period"`
	Color           string    `json:"color"`
	IconName        string    `json:"icon_name"`
	StartDate       time.Time `json:"start_date"`
	NextBillingDate time.Time `json:"next_billing_date"`
	Tag             *string   `json:"tag,omitempty"`
	URL             *string   `json:"url,omitempty"`
	ImageData       []byte    `json:"image_data,omitempty"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

// Tag — пользовательский тег
type Tag struct {
	ID        string    `json:"id"` // UUID
	UserID    int64     `json:"user_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}
