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
func (r *UserRepository) Create(email, passwordHash string, provider models.AuthProvider, providerID string) (int64, error) {
	res, err := r.db.Exec(
		`INSERT INTO users (email, password_hash, provider, provider_id, created_at)
		 VALUES (?, ?, ?, ?, ?)`,
		email, passwordHash, provider, providerID, time.Now(),
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// FindByEmail ищет пользователя по email.
func (r *UserRepository) FindByEmail(email string) (*models.User, error) {
	row := r.db.QueryRow(
		`SELECT id, email, password_hash, provider, provider_id, created_at
		 FROM users WHERE email = ?`, email,
	)
	return scanUser(row)
}

// FindByProviderID ищет пользователя по провайдеру и его ID (для OAuth).
func (r *UserRepository) FindByProviderID(provider models.AuthProvider, providerID string) (*models.User, error) {
	row := r.db.QueryRow(
		`SELECT id, email, password_hash, provider, provider_id, created_at
		 FROM users WHERE provider = ? AND provider_id = ?`, provider, providerID,
	)
	return scanUser(row)
}

// FindByID ищет пользователя по ID.
func (r *UserRepository) FindByID(id int64) (*models.User, error) {
	row := r.db.QueryRow(
		`SELECT id, email, password_hash, provider, provider_id, created_at
		 FROM users WHERE id = ?`, id,
	)
	return scanUser(row)
}

func scanUser(row *sql.Row) (*models.User, error) {
	u := &models.User{}
	err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &u.Provider, &u.ProviderID, &u.CreatedAt)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return u, nil
}
