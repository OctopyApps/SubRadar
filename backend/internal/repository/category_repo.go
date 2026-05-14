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

// FindAllByUser возвращает системные категории + личные категории пользователя.
// Системные идут первыми, затем пользовательские по алфавиту.
func (r *CategoryRepository) FindAllByUser(userID int64) ([]models.Category, error) {
	rows, err := r.db.Query(
		`SELECT id, user_id, name, icon, is_system, created_at
		 FROM categories
		 WHERE is_system = 1 OR user_id = ?
		 ORDER BY is_system DESC, name ASC`, userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cats := []models.Category{}
	for rows.Next() {
		c, err := scanCategoryRow(rows)
		if err != nil {
			return nil, err
		}
		cats = append(cats, c)
	}
	return cats, rows.Err()
}

// FindOrCreate возвращает пользовательскую категорию по имени или создаёт новую (идемпотентно).
// Системные категории через этот метод не создаются — для них AdminRepository.
func (r *CategoryRepository) FindOrCreate(userID int64, name, icon string) (models.Category, error) {
	var c models.Category
	var createdAt time.Time
	var isSystem int

	err := r.db.QueryRow(
		`SELECT id, user_id, name, icon, is_system, created_at
		 FROM categories WHERE user_id = ? AND name = ?`,
		userID, name,
	).Scan(&c.ID, &c.UserID, &c.Name, &c.Icon, &isSystem, &createdAt)

	if err == nil {
		c.IsSystem = isSystem == 1
		c.CreatedAt = models.RFC3339Seconds(createdAt)
		return c, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return c, err
	}

	// Не нашли — создаём
	now := time.Now()
	userIDVal := int64(userID)
	c = models.Category{
		ID:        uuid.NewString(),
		UserID:    &userIDVal,
		Name:      name,
		Icon:      icon,
		IsSystem:  false,
		CreatedAt: models.RFC3339Seconds(now),
	}
	_, err = r.db.Exec(
		`INSERT INTO categories (id, user_id, name, icon, is_system, created_at)
		 VALUES (?, ?, ?, ?, 0, ?)`,
		c.ID, userID, c.Name, c.Icon, now,
	)
	return c, err
}

// Delete удаляет пользовательскую категорию.
// Системные категории через этот метод удалить нельзя (is_system = 0).
func (r *CategoryRepository) Delete(id string, userID int64) error {
	result, err := r.db.Exec(
		`DELETE FROM categories WHERE id = ? AND user_id = ? AND is_system = 0`,
		id, userID,
	)
	if err != nil {
		return err
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		return ErrNotFound
	}
	return nil
}

// scanCategoryRow сканирует строку из *sql.Rows в models.Category.
func scanCategoryRow(rows *sql.Rows) (models.Category, error) {
	var c models.Category
	var createdAt time.Time
	var isSystem int
	err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.Icon, &isSystem, &createdAt)
	if err != nil {
		return c, err
	}
	c.IsSystem = isSystem == 1
	c.CreatedAt = models.RFC3339Seconds(createdAt)
	return c, nil
}
