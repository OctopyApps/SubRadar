package repository

import (
	"database/sql"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
)

type SubscriptionRepository struct {
	db *sql.DB
}

func NewSubscriptionRepository(db *sql.DB) *SubscriptionRepository {
	return &SubscriptionRepository{db: db}
}

// FindAllByUser возвращает все подписки пользователя.
func (r *SubscriptionRepository) FindAllByUser(userID int64) ([]models.Subscription, error) {
	rows, err := r.db.Query(
		`SELECT id, user_id, name, category, price, currency, billing_period,
		        color, icon_name, start_date, next_billing_date, tag, url, image_data, created_at, updated_at
		 FROM subscriptions WHERE user_id = ? ORDER BY created_at DESC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var subs []models.Subscription
	for rows.Next() {
		s, err := scanSubscription(rows)
		if err != nil {
			return nil, err
		}
		subs = append(subs, s)
	}
	return subs, rows.Err()
}

// Create сохраняет новую подписку.
func (r *SubscriptionRepository) Create(s *models.Subscription) error {
	now := time.Now()
	_, err := r.db.Exec(
		`INSERT INTO subscriptions
		 (id, user_id, name, category, price, currency, billing_period,
		  color, icon_name, start_date, next_billing_date, tag, url, image_data, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		s.ID, s.UserID, s.Name, s.Category, s.Price, s.Currency, s.BillingPeriod,
		s.Color, s.IconName, s.StartDate, s.NextBillingDate, s.Tag, s.URL, s.ImageData, now, now,
	)
	return err
}

// Update обновляет существующую подписку (только свою — проверяем user_id).
func (r *SubscriptionRepository) Update(s *models.Subscription) error {
	_, err := r.db.Exec(
		`UPDATE subscriptions SET
		 name=?, category=?, price=?, currency=?, billing_period=?,
		 color=?, icon_name=?, start_date=?, next_billing_date=?, tag=?, url=?, image_data=?, updated_at=?
		 WHERE id=? AND user_id=?`,
		s.Name, s.Category, s.Price, s.Currency, s.BillingPeriod,
		s.Color, s.IconName, s.StartDate, s.NextBillingDate, s.Tag, s.URL, s.ImageData, time.Now(),
		s.ID, s.UserID,
	)
	return err
}

// Delete удаляет подписку пользователя.
func (r *SubscriptionRepository) Delete(id string, userID int64) error {
	_, err := r.db.Exec(`DELETE FROM subscriptions WHERE id=? AND user_id=?`, id, userID)
	return err
}

func scanSubscription(rows *sql.Rows) (models.Subscription, error) {
	var s models.Subscription
	err := rows.Scan(
		&s.ID, &s.UserID, &s.Name, &s.Category, &s.Price, &s.Currency, &s.BillingPeriod,
		&s.Color, &s.IconName, &s.StartDate, &s.NextBillingDate, &s.Tag, &s.URL, &s.ImageData,
		&s.CreatedAt, &s.UpdatedAt,
	)
	return s, err
}
