package db

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/golang-migrate/migrate/v4"
	migratepostgres "github.com/golang-migrate/migrate/v4/database/postgres"
	migratesqlite "github.com/golang-migrate/migrate/v4/database/sqlite3"
	_ "github.com/golang-migrate/migrate/v4/source/file"
	_ "github.com/lib/pq"
	_ "github.com/mattn/go-sqlite3"
)

// Connect открывает соединение с базой данных и запускает миграции.
// driver: "sqlite" | "postgres"
func Connect(driver, source string) (*sql.DB, error) {
	switch driver {
	case "postgres":
		return connectPostgres(source)
	default:
		return connectSQLite(source)
	}
}

func connectSQLite(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite3", path+"?_foreign_keys=on&_journal_mode=WAL")
	if err != nil {
		return nil, fmt.Errorf("открытие SQLite: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("соединение с SQLite: %w", err)
	}
	db.SetMaxOpenConns(1)

	if err := runMigrationsSQLite(db); err != nil {
		return nil, fmt.Errorf("миграции SQLite: %w", err)
	}
	log.Println("SQLite готова:", path)
	return db, nil
}

func connectPostgres(dsn string) (*sql.DB, error) {
	if dsn == "" {
		return nil, fmt.Errorf("storage.postgres.dsn не задан в config.yaml или SUBRADAR_STORAGE_POSTGRES_DSN")
	}
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("открытие Postgres: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("соединение с Postgres: %w", err)
	}

	if err := runMigrationsPostgres(db); err != nil {
		return nil, fmt.Errorf("миграции Postgres: %w", err)
	}
	log.Println("Postgres готов")
	return db, nil
}

func migrationsPath() string {
	wd, _ := os.Getwd()
	return filepath.Join(wd, "internal", "db", "migrations")
}

func runMigrationsSQLite(db *sql.DB) error {
	driver, err := migratesqlite.WithInstance(db, &migratesqlite.Config{})
	if err != nil {
		return err
	}
	path := "file://" + migrationsPath()
	m, err := migrate.NewWithDatabaseInstance(path, "sqlite3", driver)
	if err != nil {
		return err
	}
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return err
	}
	return nil
}

func runMigrationsPostgres(db *sql.DB) error {
	driver, err := migratepostgres.WithInstance(db, &migratepostgres.Config{})
	if err != nil {
		return err
	}
	path := "file://" + migrationsPath()
	m, err := migrate.NewWithDatabaseInstance(path, "postgres", driver)
	if err != nil {
		return err
	}
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return err
	}
	return nil
}
