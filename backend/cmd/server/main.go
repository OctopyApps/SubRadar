package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/db"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/pushjob"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
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

	// Роутер
	router := server.NewRouter(database, cfg)

	// Фоновая джоба Web Push — раз в сутки, только если заданы VAPID-ключи.
	pushCtx, cancelPush := context.WithCancel(context.Background())
	defer cancelPush()
	if cfg.PushEnabled() {
		pushRepo := repository.NewPushSubscriptionRepository(database)
		go pushjob.New(cfg, pushRepo).Start(pushCtx)
	}

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

	// Запускаем сервер в отдельной горутине, чтобы не блокировать
	// ожидание сигнала на graceful shutdown.
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Ошибка сервера: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	log.Println("Получен сигнал остановки, завершаем работу...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("Ошибка при остановке сервера: %v", err)
	}

	if err := database.Close(); err != nil {
		log.Printf("Ошибка при закрытии базы данных: %v", err)
	}

	log.Println("Сервер остановлен")
}
