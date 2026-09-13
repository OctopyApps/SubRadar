package config

import (
	"log"
	"strings"

	"github.com/spf13/viper"
)

type Config struct {
	Port     int
	DBDriver string // "sqlite" | "postgres"
	DBPath   string // для sqlite
	DSN      string // для postgres

	MigrationsPath string
	JWTSecret      string
	SelfHosted     bool
	ServerSecret   string

	// CORS
	CORSAllowAll bool     // true — разрешаем любой origin (только для dev)
	CORSOrigins  []string // список разрешённых origins для продакшена

	// OAuth (читаются только из env — содержат секреты)
	GoogleClientID  string
	AppleTeamID     string
	AppleClientID   string
	AppleKeyID      string
	ApplePrivateKey string
}

func Load() *Config {
	// Ищем config.yaml рядом с бинарником, в ~/.subradar и /etc/subradar
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("$HOME/.subradar")
	viper.AddConfigPath("/etc/subradar")

	// Env-переменные с префиксом SUBRADAR_ перезаписывают config.yaml
	// Пример: SUBRADAR_SERVER_PORT=9090
	viper.SetEnvPrefix("SUBRADAR")
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	// Дефолты
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("storage.driver", "sqlite")
	viper.SetDefault("storage.sqlite.path", "./subradar.db")
	viper.SetDefault("auth.jwt_secret", "change-me-in-production")
	viper.SetDefault("auth.self_hosted", false)
	viper.SetDefault("cors.allow_all", false) // в продакшене false, в dev можно true

	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			log.Println("config.yaml не найден, используются env-переменные и дефолты")
		} else {
			log.Fatalf("Ошибка чтения config.yaml: %v", err)
		}
	} else {
		log.Printf("Конфиг загружен: %s", viper.ConfigFileUsed())
	}

	return &Config{
		Port:           viper.GetInt("server.port"),
		DBDriver:       viper.GetString("storage.driver"),
		DBPath:         viper.GetString("storage.sqlite.path"),
		DSN:            viper.GetString("storage.postgres.dsn"),
		MigrationsPath: viper.GetString("storage.migrations_path"),

		JWTSecret:    viper.GetString("auth.jwt_secret"),
		SelfHosted:   viper.GetBool("auth.self_hosted"),
		ServerSecret: viper.GetString("auth.server_secret"),

		CORSAllowAll: viper.GetBool("cors.allow_all"),
		CORSOrigins:  viper.GetStringSlice("cors.origins"),

		GoogleClientID:  viper.GetString("GOOGLE_CLIENT_ID"),
		AppleTeamID:     viper.GetString("APPLE_TEAM_ID"),
		AppleClientID:   viper.GetString("APPLE_CLIENT_ID"),
		AppleKeyID:      viper.GetString("APPLE_KEY_ID"),
		ApplePrivateKey: viper.GetString("APPLE_PRIVATE_KEY"),
	}
}
