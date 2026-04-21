package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/sqlite3"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "github.com/mattn/go-sqlite3"
)

// Connect открывает соединение с SQLite и запускает миграции.
func Connect(dbPath string) (*sql.DB, error) {
	db, err := sql.Open("sqlite3", dbPath+"?_foreign_keys=on&_journal_mode=WAL")
	if err != nil {
		return nil, fmt.Errorf("открытие базы данных: %w", err)
	}

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("соединение с базой данных: %w", err)
	}

	// SQLite не поддерживает параллельную запись
	db.SetMaxOpenConns(1)

	if err := runMigrations(db); err != nil {
		return nil, fmt.Errorf("миграции: %w", err)
	}

	log.Println("База данных готова:", dbPath)
	return db, nil
}

func runMigrations(db *sql.DB) error {
	driver, err := sqlite3.WithInstance(db, &sqlite3.Config{})
	if err != nil {
		return err
	}

	// Абсолютный путь к миграциям относительно рабочей директории
	wd, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("не удалось получить рабочую директорию: %w", err)
	}
	migrationsPath := filepath.Join(wd, "internal", "db", "migrations")
	log.Println("Путь к миграциям:", "file://"+migrationsPath) // ← добавить

	m, err := migrate.NewWithDatabaseInstance(
		"file://"+migrationsPath,
		"sqlite3",
		driver,
	)
	if err != nil {
		return err
	}
	log.Println("Миграции применены успешно") // ← добавить

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return err
	}

	return nil
}
