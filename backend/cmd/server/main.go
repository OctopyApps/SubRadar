package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/db"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/server"
	"github.com/spf13/viper"
)

var version = "dev"

func main() {
	configPath := flag.String("config", "", "путь к config.yaml")

	flag.Parse()

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

	if err := http.ListenAndServe(addr, router); err != nil {
		log.Fatalf("Ошибка сервера: %v", err)
	}
}
