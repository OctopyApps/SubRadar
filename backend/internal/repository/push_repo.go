package repository

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/google/uuid"
)

type PushSubscriptionRepository struct {
	db *sql.DB
}

func NewPushSubscriptionRepository(db *sql.DB) *PushSubscriptionRepository {
	return &PushSubscriptionRepository{db: db}
}

// Upsert сохраняет Web Push подписку браузера/устройства. endpoint уникален
// глобально — если тот же браузер подписывается повторно (например, юзер
// перелогинился под другим аккаунтом на этом устройстве), перезаписываем
// user_id/ключи/lead_times на актуальные.
func (r *PushSubscriptionRepository) Upsert(userID int64, endpoint, p256dh, auth string, leadTimes []int) (*models.PushSubscription, error) {
	var leadTimesJSON any // nil → NULL в колонке (использовать дефолт юзера)
	if leadTimes != nil {
		raw, err := json.Marshal(leadTimes)
		if err != nil {
			return nil, err
		}
		leadTimesJSON = string(raw)
	}

	now := time.Now()
	_, err := r.db.Exec(
		`INSERT INTO push_subscriptions (id, user_id, endpoint, p256dh, auth, lead_times, created_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?)
		 ON CONFLICT(endpoint) DO UPDATE SET
		   user_id=excluded.user_id, p256dh=excluded.p256dh,
		   auth=excluded.auth, lead_times=excluded.lead_times`,
		uuid.NewString(), userID, endpoint, p256dh, auth, leadTimesJSON, now,
	)
	if err != nil {
		return nil, err
	}

	// При конфликте id остаётся от исходной строки (excluded его не
	// перезаписывает) — сгенерированный выше UUID мог не совпасть с
	// реальным id строки, поэтому забираем актуальный id отдельным SELECT.
	var id string
	if err := r.db.QueryRow(`SELECT id FROM push_subscriptions WHERE endpoint=?`, endpoint).Scan(&id); err != nil {
		return nil, err
	}

	return &models.PushSubscription{
		ID: id, UserID: userID, Endpoint: endpoint,
		P256dh: p256dh, Auth: auth, LeadTimes: leadTimes, CreatedAt: now,
	}, nil
}

// Delete удаляет подписку конкретного пользователя (проверяет владельца —
// один юзер не может отписать чужое устройство).
func (r *PushSubscriptionRepository) Delete(userID int64, endpoint string) error {
	result, err := r.db.Exec(
		`DELETE FROM push_subscriptions WHERE endpoint=? AND user_id=?`, endpoint, userID,
	)
	if err != nil {
		return err
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteByEndpoint удаляет подписку по endpoint без проверки владельца —
// используется фоновой джобой, когда push-сервис ответил 404/410 (подписка
// мёртвая: юзер убрал разрешение на уведомления или снёс PWA).
func (r *PushSubscriptionRepository) DeleteByEndpoint(endpoint string) error {
	_, err := r.db.Exec(`DELETE FROM push_subscriptions WHERE endpoint=?`, endpoint)
	return err
}

// PushCandidate — одна пара (подписка на списание × устройство юзера),
// потенциальный кандидат на напоминание. LeadTimes — уже разрешённый
// эффективный список (override устройства, если задан, иначе дефолт юзера).
type PushCandidate struct {
	BillingSubscriptionID   string
	BillingSubscriptionName string
	Price                   float64
	Currency                string
	NextBillingDate         time.Time
	PushSubscriptionID      string
	Endpoint                string
	P256dh                  string
	Auth                    string
	LeadTimes               []int
}

// ListCandidates возвращает все пары (подписка × push-устройство) по всем
// пользователям — источник для фоновой джобы напоминаний. Матчинг
// "наступил ли нужный день" и дедупликация через push_notifications_sent
// делаются на уровне джобы, не здесь: таблиц немного (self-hosted/малый
// shared-сервер), фильтровать в Go проще, чем городить JSON-матчинг в SQL.
func (r *PushSubscriptionRepository) ListCandidates() ([]PushCandidate, error) {
	rows, err := r.db.Query(
		`SELECT s.id, s.name, s.price, s.currency, s.next_billing_date,
		        ps.id, ps.endpoint, ps.p256dh, ps.auth, ps.lead_times, u.push_lead_times
		 FROM subscriptions s
		 JOIN push_subscriptions ps ON ps.user_id = s.user_id
		 JOIN users u ON u.id = s.user_id`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var candidates []PushCandidate
	for rows.Next() {
		var c PushCandidate
		var overrideRaw sql.NullString
		var defaultRaw string
		if err := rows.Scan(
			&c.BillingSubscriptionID, &c.BillingSubscriptionName, &c.Price, &c.Currency, &c.NextBillingDate,
			&c.PushSubscriptionID, &c.Endpoint, &c.P256dh, &c.Auth, &overrideRaw, &defaultRaw,
		); err != nil {
			return nil, err
		}

		raw := defaultRaw
		if overrideRaw.Valid {
			raw = overrideRaw.String
		}
		if err := json.Unmarshal([]byte(raw), &c.LeadTimes); err != nil {
			return nil, err
		}
		candidates = append(candidates, c)
	}
	return candidates, rows.Err()
}

// AlreadySent проверяет, отправляли ли уже это конкретное напоминание
// (тот же push_subscription + подписка + lead_time_day + billing_date) —
// чтобы фоновая джоба не продублировала пуш при повторном запуске.
func (r *PushSubscriptionRepository) AlreadySent(pushSubscriptionID, billingSubscriptionID string, leadTimeDay int, billingDate string) (bool, error) {
	var exists int
	err := r.db.QueryRow(
		`SELECT 1 FROM push_notifications_sent
		 WHERE push_subscription_id=? AND billing_subscription_id=? AND lead_time_day=? AND billing_date=?`,
		pushSubscriptionID, billingSubscriptionID, leadTimeDay, billingDate,
	).Scan(&exists)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// MarkSent записывает факт успешной отправки напоминания.
func (r *PushSubscriptionRepository) MarkSent(pushSubscriptionID, billingSubscriptionID string, leadTimeDay int, billingDate string) error {
	_, err := r.db.Exec(
		`INSERT OR IGNORE INTO push_notifications_sent
		 (push_subscription_id, billing_subscription_id, lead_time_day, billing_date, sent_at)
		 VALUES (?, ?, ?, ?, ?)`,
		pushSubscriptionID, billingSubscriptionID, leadTimeDay, billingDate, time.Now(),
	)
	return err
}
