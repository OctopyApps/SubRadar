package repository

import (
	"database/sql"
	"errors"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/google/uuid"
)

type TagRepository struct {
	db *sql.DB
}

func NewTagRepository(db *sql.DB) *TagRepository {
	return &TagRepository{db: db}
}

// FindAllByUser возвращает все теги пользователя.
func (r *TagRepository) FindAllByUser(userID int64) ([]models.Tag, error) {
	rows, err := r.db.Query(
		`SELECT id, user_id, name, created_at FROM tags WHERE user_id=? ORDER BY name`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tags []models.Tag
	for rows.Next() {
		var t models.Tag
		var createdAt time.Time
		if err := rows.Scan(&t.ID, &t.UserID, &t.Name, &createdAt); err != nil {
			return nil, err
		}
		t.CreatedAt = models.RFC3339Seconds(createdAt)
		tags = append(tags, t)
	}
	return tags, rows.Err()
}

// FindOrCreate возвращает тег по имени или создаёт новый (идемпотентно).
func (r *TagRepository) FindOrCreate(userID int64, name string) (models.Tag, error) {
	var t models.Tag
	var createdAt time.Time
	err := r.db.QueryRow(
		`SELECT id, user_id, name, created_at FROM tags WHERE user_id=? AND name=?`, userID, name,
	).Scan(&t.ID, &t.UserID, &t.Name, &createdAt)

	if err == nil {
		t.CreatedAt = models.RFC3339Seconds(createdAt)
		return t, nil // нашли
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return t, err
	}

	// Создаём новый
	now := time.Now()
	t.ID = uuid.NewString()
	t.UserID = userID
	t.Name = name
	t.CreatedAt = models.RFC3339Seconds(now)
	_, err = r.db.Exec(
		`INSERT INTO tags (id, user_id, name, created_at) VALUES (?, ?, ?, ?)`,
		t.ID, t.UserID, t.Name, now,
	)
	return t, err
}

// Delete удаляет тег пользователя.
func (r *TagRepository) Delete(id string, userID int64) error {
	_, err := r.db.Exec(`DELETE FROM tags WHERE id=? AND user_id=?`, id, userID)
	return err
}
