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

	// CookieSecure — ставить ли Secure на auth-cookie (см. auth.SetTokenCookie).
	// true возможен только за HTTPS (браузер не отправит Secure-cookie по
	// обычному http://) — дефолт false, чтобы не ломать self-hosted без TLS.
	CookieSecure bool

	// Web Push (напоминания о скором списании для веб-клиента). Пустые
	// VAPIDPublicKey/VAPIDPrivateKey означают, что push отключён — сервер
	// не публикует /push/*, фоновая джоба не запускается. Сгенерировать:
	// webpush.GenerateVAPIDKeys() (см. README.md).
	VAPIDPublicKey  string
	VAPIDPrivateKey string
	VAPIDSubscriber string // контакт для push-сервиса: "mailto:you@example.com"
	PushCheckHour   int    // час (0-23) по времени сервера, когда шлём напоминания раз в сутки

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
	viper.SetDefault("auth.cookie_secure", false)
	viper.SetDefault("push.check_hour", 10)

	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			log.Println("config.yaml не найден, используются env-переменные и дефолты")
		} else {
			log.Fatalf("Ошибка чтения config.yaml: %v", err)
		}
	} else {
		log.Printf("Конфиг загружен: %s", viper.ConfigFileUsed())
	}

	selfHosted := viper.GetBool("auth.self_hosted")

	// Self-hosted: разрешаем любой origin по умолчанию, если админ явно не
	// задал cors.allow_all в config.yaml/env. CORS не влияет на мобильные
	// клиенты (у них нет заголовка Origin) — только на веб-клиент, а риск
	// self-hosted-сервера, доступного публично из чужого браузера, низкий:
	// это единственный пользователь на своём сервере. В shared-режиме
	// дефолт остаётся false — там сервер публичный и с чужими пользователями.
	corsAllowAll := viper.GetBool("cors.allow_all")
	if selfHosted && !viper.IsSet("cors.allow_all") {
		corsAllowAll = true
		log.Println("self_hosted=true, cors.allow_all не задан — по умолчанию разрешаем любой origin (см. README.md)")
	}

	cfg := &Config{
		Port:           viper.GetInt("server.port"),
		DBDriver:       viper.GetString("storage.driver"),
		DBPath:         viper.GetString("storage.sqlite.path"),
		DSN:            viper.GetString("storage.postgres.dsn"),
		MigrationsPath: viper.GetString("storage.migrations_path"),

		JWTSecret:    viper.GetString("auth.jwt_secret"),
		SelfHosted:   selfHosted,
		ServerSecret: viper.GetString("auth.server_secret"),

		CORSAllowAll: corsAllowAll,
		CORSOrigins:  viper.GetStringSlice("cors.origins"),

		CookieSecure: viper.GetBool("auth.cookie_secure"),

		VAPIDPublicKey:  viper.GetString("push.vapid_public_key"),
		VAPIDPrivateKey: viper.GetString("push.vapid_private_key"),
		VAPIDSubscriber: viper.GetString("push.vapid_subscriber"),
		PushCheckHour:   viper.GetInt("push.check_hour"),

		GoogleClientID:  viper.GetString("GOOGLE_CLIENT_ID"),
		AppleTeamID:     viper.GetString("APPLE_TEAM_ID"),
		AppleClientID:   viper.GetString("APPLE_CLIENT_ID"),
		AppleKeyID:      viper.GetString("APPLE_KEY_ID"),
		ApplePrivateKey: viper.GetString("APPLE_PRIVATE_KEY"),
	}

	cfg.validateSecrets()

	return cfg
}

// PushEnabled сообщает, настроен ли Web Push (заданы VAPID-ключи).
// Если false — /push/* не регистрируются и фоновая джоба не запускается.
func (c *Config) PushEnabled() bool {
	return c.VAPIDPublicKey != "" && c.VAPIDPrivateKey != ""
}

// minSecretLength — минимальная допустимая длина jwt_secret/server_secret.
// См. README.md, раздел "Конфигурация".
const minSecretLength = 32

// defaultJWTSecret — значение-заглушка из SetDefault выше; запуск с ним
// в проде означает, что admin забыл положить свой config.yaml.
const defaultJWTSecret = "change-me-in-production"

// validateSecrets останавливает запуск сервера (log.Fatal), если
// jwt_secret оставлен дефолтным/слишком коротким, либо если self_hosted
// включён, а server_secret отсутствует/слишком короткий. Тихий запуск
// с такими значениями означает, что JWT или self-hosted вход можно
// подделать/подобрать.
func (c *Config) validateSecrets() {
	if c.JWTSecret == defaultJWTSecret || len(c.JWTSecret) < minSecretLength {
		log.Fatalf("auth.jwt_secret не задан или короче %d символов — задайте его в config.yaml (см. config.example.yaml) или через SUBRADAR_AUTH_JWT_SECRET", minSecretLength)
	}

	if c.SelfHosted && len(c.ServerSecret) < minSecretLength {
		log.Fatalf("auth.self_hosted=true, но auth.server_secret не задан или короче %d символов — задайте его в config.yaml (см. config.example.yaml) или через SUBRADAR_AUTH_SERVER_SECRET", minSecretLength)
	}
}
