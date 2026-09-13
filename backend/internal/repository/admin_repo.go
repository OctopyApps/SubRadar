package repository

import (
	"database/sql"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/google/uuid"
)

type AdminRepository struct {
	db *sql.DB
}

func NewAdminRepository(db *sql.DB) *AdminRepository {
	return &AdminRepository{db: db}
}

// ============================================================
// Пользователи
// ============================================================

// UsersPage — результат постраничного запроса пользователей.
type UsersPage struct {
	Users  []models.UserAdmin `json:"users"`
	Total  int64              `json:"total"`
	Limit  int                `json:"limit"`
	Offset int                `json:"offset"`
}

// ListUsers возвращает постраничный список всех пользователей.
// Поддерживает фильтрацию по роли и статусу блокировки.
func (r *AdminRepository) ListUsers(limit, offset int, role, search string) (UsersPage, error) {
	// Собираем WHERE условия динамически
	where := "WHERE 1=1"
	args := []any{}

	if role != "" {
		where += " AND role = ?"
		args = append(args, role)
	}
	if search != "" {
		where += " AND (email LIKE ? OR display_name LIKE ?)"
		pattern := "%" + search + "%"
		args = append(args, pattern, pattern)
	}

	// Общее количество для пагинации
	var total int64
	countArgs := make([]any, len(args))
	copy(countArgs, args)
	if err := r.db.QueryRow("SELECT COUNT(*) FROM users "+where, countArgs...).Scan(&total); err != nil {
		return UsersPage{}, err
	}

	// Сам список
	args = append(args, limit, offset)
	rows, err := r.db.Query(
		`SELECT id, email, display_name, provider, role,
		        is_blocked, blocked_at, blocked_reason,
		        last_seen_at, created_at
		 FROM users `+where+`
		 ORDER BY created_at DESC
		 LIMIT ? OFFSET ?`,
		args...,
	)
	if err != nil {
		return UsersPage{}, err
	}
	defer rows.Close()

	users := []models.UserAdmin{}
	for rows.Next() {
		u, err := scanUserAdmin(rows)
		if err != nil {
			return UsersPage{}, err
		}
		users = append(users, u)
	}
	if err := rows.Err(); err != nil {
		return UsersPage{}, err
	}

	return UsersPage{
		Users:  users,
		Total:  total,
		Limit:  limit,
		Offset: offset,
	}, nil
}

// GetUser возвращает одного пользователя для админки.
func (r *AdminRepository) GetUser(id int64) (models.UserAdmin, error) {
	row := r.db.QueryRow(
		`SELECT id, email, display_name, provider, role,
		        is_blocked, blocked_at, blocked_reason,
		        last_seen_at, created_at
		 FROM users WHERE id = ?`, id,
	)
	var u models.UserAdmin
	var isBlocked int
	err := row.Scan(
		&u.ID, &u.Email, &u.DisplayName, &u.Provider, &u.Role,
		&isBlocked, &u.BlockedAt, &u.BlockedReason,
		&u.LastSeenAt, &u.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return u, ErrNotFound
	}
	if err != nil {
		return u, err
	}
	u.IsBlocked = isBlocked == 1
	return u, nil
}

// ============================================================
// Статистика
// ============================================================

// Stats — общая статистика системы для дашборда админки.
type Stats struct {
	TotalUsers         int64 `json:"total_users"`
	TotalAdmins        int64 `json:"total_admins"`
	TotalBlocked       int64 `json:"total_blocked"`
	TotalSubscriptions int64 `json:"total_subscriptions"`
	TotalCategories    int64 `json:"total_categories"`
	TotalTags          int64 `json:"total_tags"`
	NewUsersLast30Days int64 `json:"new_users_last_30_days"`
}

// GetStats возвращает агрегированную статистику по всей системе.
func (r *AdminRepository) GetStats() (Stats, error) {
	var s Stats

	queries := []struct {
		dest  *int64
		query string
		args  []any
	}{
		{&s.TotalUsers, `SELECT COUNT(*) FROM users`, nil},
		{&s.TotalAdmins, `SELECT COUNT(*) FROM users WHERE role = 'admin'`, nil},
		{&s.TotalBlocked, `SELECT COUNT(*) FROM users WHERE is_blocked = 1`, nil},
		{&s.TotalSubscriptions, `SELECT COUNT(*) FROM subscriptions`, nil},
		{&s.TotalCategories, `SELECT COUNT(*) FROM categories WHERE is_system = 0`, nil},
		{&s.TotalTags, `SELECT COUNT(*) FROM tags`, nil},
		{&s.NewUsersLast30Days, `SELECT COUNT(*) FROM users WHERE created_at >= ?`,
			[]any{time.Now().AddDate(0, 0, -30)}},
	}

	for _, q := range queries {
		if err := r.db.QueryRow(q.query, q.args...).Scan(q.dest); err != nil {
			return s, err
		}
	}

	return s, nil
}

// ============================================================
// Системные категории
// ============================================================

// ListSystemCategories возвращает все системные категории.
func (r *AdminRepository) ListSystemCategories() ([]models.Category, error) {
	rows, err := r.db.Query(
		`SELECT id, user_id, name, icon, is_system, created_at
		 FROM categories WHERE is_system = 1 ORDER BY name`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cats := []models.Category{}
	for rows.Next() {
		c, err := scanCategory(rows)
		if err != nil {
			return nil, err
		}
		cats = append(cats, c)
	}
	return cats, rows.Err()
}

// CreateSystemCategory создаёт глобальную категорию видимую всем пользователям.
func (r *AdminRepository) CreateSystemCategory(name, icon string) (models.Category, error) {
	now := time.Now()
	c := models.Category{
		ID:        uuid.NewString(),
		UserID:    nil, // системная — не принадлежит никому
		Name:      name,
		Icon:      icon,
		IsSystem:  true,
		CreatedAt: models.RFC3339Seconds(now),
	}
	_, err := r.db.Exec(
		`INSERT INTO categories (id, user_id, name, icon, is_system, created_at)
		 VALUES (?, NULL, ?, ?, 1, ?)`,
		c.ID, c.Name, c.Icon, now,
	)
	return c, err
}

// DeleteSystemCategory удаляет системную категорию.
// Обычные пользовательские категории через этот метод удалить нельзя.
func (r *AdminRepository) DeleteSystemCategory(id string) error {
	result, err := r.db.Exec(
		`DELETE FROM categories WHERE id = ? AND is_system = 1`, id,
	)
	if err != nil {
		return err
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		return ErrNotFound
	}
	return nil
}

// ============================================================
// Вспомогательные функции сканирования
// ============================================================

func scanUserAdmin(rows *sql.Rows) (models.UserAdmin, error) {
	var u models.UserAdmin
	var isBlocked int
	err := rows.Scan(
		&u.ID, &u.Email, &u.DisplayName, &u.Provider, &u.Role,
		&isBlocked, &u.BlockedAt, &u.BlockedReason,
		&u.LastSeenAt, &u.CreatedAt,
	)
	if err != nil {
		return u, err
	}
	u.IsBlocked = isBlocked == 1
	return u, nil
}

func scanCategory(rows *sql.Rows) (models.Category, error) {
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
