package repository

import (
	"database/sql"
	"errors"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
)

var ErrNotFound = errors.New("запись не найдена")

type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

// Create создаёт нового пользователя и возвращает его ID.
// Если в таблице ещё нет ни одного пользователя — назначает роль admin.
func (r *UserRepository) Create(email, passwordHash string, provider models.AuthProvider, providerID string) (int64, error) {
	role := models.UserRoleUser
	count, err := r.CountAll()
	if err != nil {
		return 0, err
	}
	if count == 0 {
		role = models.UserRoleAdmin
	}

	res, err := r.db.Exec(
		`INSERT INTO users (email, password_hash, provider, provider_id, role, created_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		email, passwordHash, provider, providerID, role, time.Now(),
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// CountAll возвращает общее количество пользователей в системе.
func (r *UserRepository) CountAll() (int64, error) {
	var count int64
	err := r.db.QueryRow(`SELECT COUNT(*) FROM users`).Scan(&count)
	return count, err
}

// FindByEmail ищет пользователя по email.
func (r *UserRepository) FindByEmail(email string) (*models.User, error) {
	row := r.db.QueryRow(
		`SELECT id, email, password_hash, provider, provider_id,
		        role, is_blocked, blocked_at, blocked_reason,
		        display_name, last_seen_at, created_at
		 FROM users WHERE email = ?`, email,
	)
	return scanUser(row)
}

// FindByProviderID ищет пользователя по провайдеру и его ID (для OAuth).
func (r *UserRepository) FindByProviderID(provider models.AuthProvider, providerID string) (*models.User, error) {
	row := r.db.QueryRow(
		`SELECT id, email, password_hash, provider, provider_id,
		        role, is_blocked, blocked_at, blocked_reason,
		        display_name, last_seen_at, created_at
		 FROM users WHERE provider = ? AND provider_id = ?`, provider, providerID,
	)
	return scanUser(row)
}

// FindByID ищет пользователя по ID.
func (r *UserRepository) FindByID(id int64) (*models.User, error) {
	row := r.db.QueryRow(
		`SELECT id, email, password_hash, provider, provider_id,
		        role, is_blocked, blocked_at, blocked_reason,
		        display_name, last_seen_at, created_at
		 FROM users WHERE id = ?`, id,
	)
	return scanUser(row)
}

// UpdateLastSeen обновляет время последней активности пользователя.
func (r *UserRepository) UpdateLastSeen(id int64) error {
	_, err := r.db.Exec(
		`UPDATE users SET last_seen_at = ? WHERE id = ?`,
		time.Now(), id,
	)
	return err
}

// UpdateDisplayName обновляет отображаемое имя пользователя.
func (r *UserRepository) UpdateDisplayName(id int64, displayName string) error {
	_, err := r.db.Exec(
		`UPDATE users SET display_name = ? WHERE id = ?`,
		displayName, id,
	)
	return err
}

// UpdatePassword обновляет хэш пароля пользователя.
func (r *UserRepository) UpdatePassword(id int64, passwordHash string) error {
	_, err := r.db.Exec(
		`UPDATE users SET password_hash = ? WHERE id = ?`,
		passwordHash, id,
	)
	return err
}

// SetRole назначает роль пользователю.
func (r *UserRepository) SetRole(id int64, role models.UserRole) error {
	_, err := r.db.Exec(
		`UPDATE users SET role = ? WHERE id = ?`,
		role, id,
	)
	return err
}

// SetBlocked блокирует или разблокирует пользователя.
func (r *UserRepository) SetBlocked(id int64, blocked bool, reason string) error {
	if blocked {
		now := time.Now()
		_, err := r.db.Exec(
			`UPDATE users SET is_blocked = 1, blocked_at = ?, blocked_reason = ? WHERE id = ?`,
			now, reason, id,
		)
		return err
	}
	_, err := r.db.Exec(
		`UPDATE users SET is_blocked = 0, blocked_at = NULL, blocked_reason = NULL WHERE id = ?`,
		id,
	)
	return err
}

// Delete удаляет пользователя и все его данные (CASCADE в БД).
func (r *UserRepository) Delete(id int64) error {
	result, err := r.db.Exec(`DELETE FROM users WHERE id = ?`, id)
	if err != nil {
		return err
	}
	if rows, _ := result.RowsAffected(); rows == 0 {
		return ErrNotFound
	}
	return nil
}

// scanUser сканирует строку БД в модель User.
// Используется во всех Find* методах — единая точка маппинга.
func scanUser(row *sql.Row) (*models.User, error) {
	u := &models.User{}
	var isBlocked int // SQLite хранит bool как INTEGER
	err := row.Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Provider, &u.ProviderID,
		&u.Role, &isBlocked, &u.BlockedAt, &u.BlockedReason,
		&u.DisplayName, &u.LastSeenAt, &u.CreatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	u.IsBlocked = isBlocked == 1
	return u, nil
}
