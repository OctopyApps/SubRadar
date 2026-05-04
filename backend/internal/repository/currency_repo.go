package repository

import (
	"database/sql"
	"errors"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/google/uuid"
)

type CurrencyRepository struct {
	db *sql.DB
}

func NewCurrencyRepository(db *sql.DB) *CurrencyRepository {
	return &CurrencyRepository{db: db}
}

// FindAllByUser возвращает все пользовательские валюты.
func (r *CurrencyRepository) FindAllByUser(userID int64) ([]models.Currency, error) {
	rows, err := r.db.Query(
		`SELECT id, user_id, code, symbol, display_name, created_at
		 FROM currencies WHERE user_id = ? ORDER BY code`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var currencies []models.Currency
	for rows.Next() {
		var c models.Currency
		var createdAt time.Time
		if err := rows.Scan(&c.ID, &c.UserID, &c.Code, &c.Symbol, &c.DisplayName, &createdAt); err != nil {
			return nil, err
		}
		c.CreatedAt = models.RFC3339Seconds(createdAt)
		currencies = append(currencies, c)
	}
	return currencies, rows.Err()
}

// FindOrCreate возвращает валюту по коду или создаёт новую (идемпотентно).
func (r *CurrencyRepository) FindOrCreate(userID int64, code, symbol, displayName string) (models.Currency, error) {
	var c models.Currency
	var createdAt time.Time
	err := r.db.QueryRow(
		`SELECT id, user_id, code, symbol, display_name, created_at
		 FROM currencies WHERE user_id = ? AND code = ?`,
		userID, code,
	).Scan(&c.ID, &c.UserID, &c.Code, &c.Symbol, &c.DisplayName, &createdAt)

	if err == nil {
		c.CreatedAt = models.RFC3339Seconds(createdAt)
		return c, nil // нашли
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return c, err
	}

	// Создаём новую
	now := time.Now()
	c = models.Currency{
		ID:          uuid.NewString(),
		UserID:      userID,
		Code:        code,
		Symbol:      symbol,
		DisplayName: displayName,
		CreatedAt:   models.RFC3339Seconds(now),
	}
	_, err = r.db.Exec(
		`INSERT INTO currencies (id, user_id, code, symbol, display_name, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
		c.ID, c.UserID, c.Code, c.Symbol, c.DisplayName, now,
	)
	return c, err
}

// Delete удаляет валюту пользователя.
func (r *CurrencyRepository) Delete(id string, userID int64) error {
	_, err := r.db.Exec(`DELETE FROM currencies WHERE id = ? AND user_id = ?`, id, userID)
	return err
}
