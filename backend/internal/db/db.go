package db

import (
	"database/sql"
	"embed"
	"fmt"
	"log"

	"github.com/golang-migrate/migrate/v4"
	migratepostgres "github.com/golang-migrate/migrate/v4/database/postgres"
	migratesqlite "github.com/golang-migrate/migrate/v4/database/sqlite"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	_ "github.com/lib/pq"
	_ "modernc.org/sqlite"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

func Connect(driver, source string) (*sql.DB, error) {
	switch driver {
	case "postgres":
		return connectPostgres(source)
	default:
		return connectSQLite(source)
	}
}

func connectSQLite(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path+"?_foreign_keys=on&_journal_mode=WAL")
	if err != nil {
		return nil, fmt.Errorf("открытие SQLite: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("соединение с SQLite: %w", err)
	}
	db.SetMaxOpenConns(1)

	if err := runMigrations(db, "sqlite"); err != nil {
		return nil, fmt.Errorf("миграции SQLite: %w", err)
	}
	log.Println("SQLite готова:", path)
	return db, nil
}

func connectPostgres(dsn string) (*sql.DB, error) {
	if dsn == "" {
		return nil, fmt.Errorf("storage.postgres.dsn не задан")
	}
	db, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("открытие Postgres: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("соединение с Postgres: %w", err)
	}

	if err := runMigrations(db, "postgres"); err != nil {
		return nil, fmt.Errorf("миграции Postgres: %w", err)
	}
	log.Println("Postgres готов")
	return db, nil
}

func runMigrations(db *sql.DB, driver string) error {
	srcDriver, err := iofs.New(migrationsFS, "migrations")
	if err != nil {
		return err
	}

	var m *migrate.Migrate
	switch driver {
	case "postgres":
		dbDriver, err := migratepostgres.WithInstance(db, &migratepostgres.Config{})
		if err != nil {
			return err
		}
		m, err = migrate.NewWithInstance("iofs", srcDriver, "postgres", dbDriver)
		if err != nil {
			return err
		}
	default:
		dbDriver, err := migratesqlite.WithInstance(db, &migratesqlite.Config{})
		if err != nil {
			return err
		}
		m, err = migrate.NewWithInstance("iofs", srcDriver, "sqlite", dbDriver)
		if err != nil {
			return err
		}
	}

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return err
	}
	return nil
}
