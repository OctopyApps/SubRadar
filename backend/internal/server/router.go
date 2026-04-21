package server

import (
	"net/http"

	"database/sql"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/handlers"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func NewRouter(db *sql.DB, cfg *config.Config) http.Handler {
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.RealIP)
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			next.ServeHTTP(w, r)
		})
	})

	// Репозитории
	userRepo := repository.NewUserRepository(db)
	subRepo := repository.NewSubscriptionRepository(db)
	tagRepo := repository.NewTagRepository(db)

	// Хэндлеры
	authHandler := handlers.NewAuthHandler(userRepo, cfg)
	subHandler := handlers.NewSubscriptionHandler(subRepo)
	tagHandler := handlers.NewTagHandler(tagRepo)

	// Публичные маршруты (без токена)
	r.Post("/auth/register", authHandler.Register)
	r.Post("/auth/login", authHandler.Login)
	r.Post("/auth/self-hosted", authHandler.SelfHosted)
	r.Post("/auth/google", authHandler.Google)
	r.Post("/auth/apple", authHandler.Apple)

	// Защищённые маршруты (нужен JWT)
	r.Group(func(r chi.Router) {
		r.Use(auth.Middleware(cfg.JWTSecret))

		r.Get("/subscriptions", subHandler.List)
		r.Post("/subscriptions", subHandler.Create)
		r.Put("/subscriptions/{id}", subHandler.Update)
		r.Delete("/subscriptions/{id}", subHandler.Delete)

		r.Get("/tags", tagHandler.List)
		r.Post("/tags", tagHandler.Create)
		r.Delete("/tags/{id}", tagHandler.Delete)
	})

	// Health check
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})

	return r
}
