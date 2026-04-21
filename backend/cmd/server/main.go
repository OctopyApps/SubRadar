package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/db"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/server"
)

func main() {
	// Конфиг из переменных окружения
	cfg := config.Load()

	// База данных + миграции
	database, err := db.Connect(cfg.DBPath)
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
