package models

import "time"

// PushSubscription — Web Push подписка одного браузера/устройства.
// LeadTimes == nil означает "использовать User.PushLeadTimes" (дефолт
// пользователя) — override хранится только если юзер явно его задал для
// конкретного устройства.
type PushSubscription struct {
	ID        string    `json:"id"`
	UserID    int64     `json:"user_id"`
	Endpoint  string    `json:"endpoint"`
	P256dh    string    `json:"-"`
	Auth      string    `json:"-"`
	LeadTimes []int     `json:"lead_times,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}
