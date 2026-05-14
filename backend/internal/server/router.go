package server

import (
	"database/sql"
	"net/http"
	"strings"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/handlers"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func NewRouter(db *sql.DB, cfg *config.Config) http.Handler {
	r := chi.NewRouter()

	// --- Глобальные middleware ---
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(corsMiddleware(cfg))
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			next.ServeHTTP(w, r)
		})
	})

	// --- Репозитории ---
	userRepo := repository.NewUserRepository(db)
	subRepo := repository.NewSubscriptionRepository(db)
	tagRepo := repository.NewTagRepository(db)
	categoryRepo := repository.NewCategoryRepository(db)
	currencyRepo := repository.NewCurrencyRepository(db)
	adminRepo := repository.NewAdminRepository(db)

	// --- Хендлеры ---
	authHandler := handlers.NewAuthHandler(userRepo, cfg)
	meHandler := handlers.NewMeHandler(userRepo, cfg)
	subHandler := handlers.NewSubscriptionHandler(subRepo)
	tagHandler := handlers.NewTagHandler(tagRepo)
	categoryHandler := handlers.NewCategoryHandler(categoryRepo)
	currencyHandler := handlers.NewCurrencyHandler(currencyRepo)
	adminHandler := handlers.NewAdminHandler(adminRepo, userRepo)

	// --- Health check (публичный) ---
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})

	// --- Публичные маршруты (без токена) ---
	r.Post("/auth/register", authHandler.Register)
	r.Post("/auth/login", authHandler.Login)
	r.Post("/auth/self-hosted", authHandler.SelfHosted)
	r.Post("/auth/google", authHandler.Google)
	r.Post("/auth/apple", authHandler.Apple)

	// --- Защищённые маршруты (нужен JWT) ---
	r.Group(func(r chi.Router) {
		r.Use(auth.Middleware(cfg.JWTSecret, userRepo))

		// Профиль текущего пользователя
		r.Get("/auth/me", meHandler.Me)
		r.Patch("/auth/me", meHandler.UpdateMe)
		r.Post("/auth/me/change-password", meHandler.ChangePassword)

		// Подписки
		r.Get("/subscriptions", subHandler.List)
		r.Post("/subscriptions", subHandler.Create)
		r.Put("/subscriptions/{id}", subHandler.Update)
		r.Delete("/subscriptions/{id}", subHandler.Delete)

		// Теги
		r.Get("/tags", tagHandler.List)
		r.Post("/tags", tagHandler.Create)
		r.Delete("/tags/{id}", tagHandler.Delete)

		// Категории — возвращает системные + пользовательские
		r.Get("/categories", categoryHandler.List)
		r.Post("/categories", categoryHandler.Create)
		r.Delete("/categories/{id}", categoryHandler.Delete)

		// Валюты
		r.Get("/currencies", currencyHandler.List)
		r.Post("/currencies", currencyHandler.Create)
		r.Delete("/currencies/{id}", currencyHandler.Delete)

		// --- Admin-only маршруты ---
		r.Group(func(r chi.Router) {
			r.Use(auth.RequireAdmin)

			r.Get("/admin/stats", adminHandler.Stats)

			r.Get("/admin/users", adminHandler.ListUsers)
			r.Get("/admin/users/{id}", adminHandler.GetUser)
			r.Patch("/admin/users/{id}", adminHandler.UpdateUser)
			r.Delete("/admin/users/{id}", adminHandler.DeleteUser)

			r.Get("/admin/categories", adminHandler.ListSystemCategories)
			r.Post("/admin/categories", adminHandler.CreateSystemCategory)
			r.Delete("/admin/categories/{id}", adminHandler.DeleteSystemCategory)
		})
	})

	return r
}

// corsMiddleware разрешает запросы из веб-клиентов.
// В продакшене AllowedOrigins берётся из конфига, в dev разрешаем всё.
func corsMiddleware(cfg *config.Config) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			origin := r.Header.Get("Origin")

			if origin != "" {
				if cfg.CORSAllowAll || isAllowedOrigin(origin, cfg.CORSOrigins) {
					w.Header().Set("Access-Control-Allow-Origin", origin)
					w.Header().Set("Access-Control-Allow-Credentials", "true")
					w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
					w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept")
					w.Header().Set("Access-Control-Max-Age", "86400")
					w.Header().Set("Vary", "Origin")
				}
			}

			// Preflight OPTIONS — отвечаем сразу без передачи дальше
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}

// isAllowedOrigin проверяет входит ли origin в список разрешённых.
func isAllowedOrigin(origin string, allowed []string) bool {
	for _, a := range allowed {
		if strings.EqualFold(a, origin) {
			return true
		}
	}
	return false
}
