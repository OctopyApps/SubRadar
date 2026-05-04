package repository

import (
	"database/sql"
	"errors"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/google/uuid"
)

type CategoryRepository struct {
	db *sql.DB
}

func NewCategoryRepository(db *sql.DB) *CategoryRepository {
	return &CategoryRepository{db: db}
}

// FindAllByUser возвращает все пользовательские категории.
func (r *CategoryRepository) FindAllByUser(userID int64) ([]models.Category, error) {
	rows, err := r.db.Query(
		`SELECT id, user_id, name, icon, created_at
		 FROM categories WHERE user_id = ? ORDER BY name`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cats []models.Category
	for rows.Next() {
		var c models.Category
		var createdAt time.Time
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.Icon, &createdAt); err != nil {
			return nil, err
		}
		c.CreatedAt = models.RFC3339Seconds(createdAt)
		cats = append(cats, c)
	}
	return cats, rows.Err()
}

// FindOrCreate возвращает категорию по имени или создаёт новую (идемпотентно).
func (r *CategoryRepository) FindOrCreate(userID int64, name, icon string) (models.Category, error) {
	var c models.Category
	var createdAt time.Time
	err := r.db.QueryRow(
		`SELECT id, user_id, name, icon, created_at FROM categories WHERE user_id = ? AND name = ?`,
		userID, name,
	).Scan(&c.ID, &c.UserID, &c.Name, &c.Icon, &createdAt)

	if err == nil {
		c.CreatedAt = models.RFC3339Seconds(createdAt)
		return c, nil // нашли
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return c, err
	}

	// Создаём новую
	now := time.Now()
	c = models.Category{
		ID:        uuid.NewString(),
		UserID:    userID,
		Name:      name,
		Icon:      icon,
		CreatedAt: models.RFC3339Seconds(now),
	}
	_, err = r.db.Exec(
		`INSERT INTO categories (id, user_id, name, icon, created_at) VALUES (?, ?, ?, ?, ?)`,
		c.ID, c.UserID, c.Name, c.Icon, now,
	)
	return c, err
}

// Delete удаляет категорию пользователя.
func (r *CategoryRepository) Delete(id string, userID int64) error {
	_, err := r.db.Exec(`DELETE FROM categories WHERE id = ? AND user_id = ?`, id, userID)
	return err
}
