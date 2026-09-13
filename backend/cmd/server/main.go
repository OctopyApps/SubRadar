package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/db"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/server"
	"github.com/spf13/viper"
)

var version = "dev"

func main() {
	configPath := flag.String("config", "", "путь к config.yaml")
	showVersion := flag.Bool("version", false, "версия приложения")
	flag.Parse()

	if *showVersion {
		fmt.Printf("SubRadar v%s\n", version)
		return
	}
	if *configPath != "" {
		viper.SetConfigFile(*configPath)
	}

	// Конфиг из переменных окружения
	cfg := config.Load()

	// База данных + миграции
	source := cfg.DBPath
	if cfg.DBDriver == "postgres" {
		source = cfg.DSN
	}

	database, err := db.Connect(cfg.DBDriver, source)

	if err != nil {
		log.Fatalf("Не удалось подключиться к базе данных: %v", err)
	}
	defer database.Close()

	// Роутер
	router := server.NewRouter(database, cfg)

	addr := fmt.Sprintf(":%d", cfg.Port)
	log.Printf("SubRadar backend запущен на %s", addr)

	srv := &http.Server{
		Addr:              addr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	if err := srv.ListenAndServe(); err != nil {
		log.Fatalf("Ошибка сервера: %v", err)
	}
}
