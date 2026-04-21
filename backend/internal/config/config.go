package config

import (
	"os"
	"strconv"
)

// Config хранит все настройки сервера.
// Значения читаются из переменных окружения, при отсутствии — дефолты.
type Config struct {
	Port           int
	DBPath         string // путь к файлу SQLite
	JWTSecret      string // секрет для подписи JWT
	SelfHosted     bool   // режим self-hosted (вход по секретному ключу)
	ServerSecret   string // секретный ключ для self-hosted режима
	MigrationsPath string

	// OAuth
	GoogleClientID  string
	AppleTeamID     string
	AppleClientID   string
	AppleKeyID      string
	ApplePrivateKey string // содержимое .p8 файла
}

func Load() *Config {
	return &Config{
		Port:           getInt("PORT", 8080),
		DBPath:         getString("DB_PATH", "./subradar.db"),
		MigrationsPath: getString("MIGRATIONS_PATH", "internal/db/migrations"),

		JWTSecret:    getString("JWT_SECRET", "change-me-in-production"),
		SelfHosted:   getBool("SELF_HOSTED", false),
		ServerSecret: getString("SERVER_SECRET", ""),

		GoogleClientID:  getString("GOOGLE_CLIENT_ID", ""),
		AppleTeamID:     getString("APPLE_TEAM_ID", ""),
		AppleClientID:   getString("APPLE_CLIENT_ID", ""),
		AppleKeyID:      getString("APPLE_KEY_ID", ""),
		ApplePrivateKey: getString("APPLE_PRIVATE_KEY", ""),
	}
}

func getString(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func getBool(key string, fallback bool) bool {
	if v := os.Getenv(key); v != "" {
		b, err := strconv.ParseBool(v)
		if err == nil {
			return b
		}
	}
	return fallback
}
