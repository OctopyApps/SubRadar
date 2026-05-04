package models

import (
	"strings"
	"time"
)

// RFC3339Seconds — time.Time с сериализацией без дробных секунд.
// Go по умолчанию пишет наносекунды (RFC3339Nano), iOS .iso8601 их не принимает.
type RFC3339Seconds time.Time

func (t RFC3339Seconds) MarshalJSON() ([]byte, error) {
	s := time.Time(t).UTC().Format(time.RFC3339)
	return []byte(`"` + s + `"`), nil
}

func (t *RFC3339Seconds) UnmarshalJSON(data []byte) error {
	s := strings.Trim(string(data), `"`)
	parsed, err := time.Parse(time.RFC3339, s)
	if err != nil {
		// Fallback: наносекунды (на случай старых записей)
		parsed, err = time.Parse(time.RFC3339Nano, s)
		if err != nil {
			return err
		}
	}
	*t = RFC3339Seconds(parsed)
	return nil
}

func (t RFC3339Seconds) Time() time.Time {
	return time.Time(t)
}

// Subscription — подписка пользователя
type Subscription struct {
	ID              string         `json:"id"` // UUID
	UserID          int64          `json:"user_id"`
	Name            string         `json:"name"`
	Category        string         `json:"category"`
	Price           float64        `json:"price"`
	Currency        string         `json:"currency"`
	BillingPeriod   string         `json:"billing_period"`
	Color           string         `json:"color"`
	IconName        string         `json:"icon_name"`
	StartDate       RFC3339Seconds `json:"start_date"`
	NextBillingDate RFC3339Seconds `json:"next_billing_date"`
	Tag             *string        `json:"tag,omitempty"`
	URL             *string        `json:"url,omitempty"`
	ImageData       []byte         `json:"image_data,omitempty"`
	CreatedAt       RFC3339Seconds `json:"created_at"`
	UpdatedAt       RFC3339Seconds `json:"updated_at"`
}

// Tag — пользовательский тег
type Tag struct {
	ID        string         `json:"id"` // UUID
	UserID    int64          `json:"user_id"`
	Name      string         `json:"name"`
	CreatedAt RFC3339Seconds `json:"created_at"`
}
