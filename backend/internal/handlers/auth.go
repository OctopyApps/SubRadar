package handlers

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
)

type AuthHandler struct {
	users  *repository.UserRepository
	config *config.Config
}

func NewAuthHandler(users *repository.UserRepository, cfg *config.Config) *AuthHandler {
	return &AuthHandler{users: users, config: cfg}
}

// --- Регистрация ---

type registerRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// Register godoc
// POST /auth/register
func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	if req.Email == "" || !strings.Contains(req.Email, "@") {
		respondError(w, http.StatusBadRequest, "некорректный email")
		return
	}

	hash, err := auth.HashPassword(req.Password)
	if errors.Is(err, auth.ErrWeakPassword) {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка хэширования пароля")
		return
	}

	userID, err := h.users.Create(req.Email, hash, models.AuthProviderLocal, "")
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			respondError(w, http.StatusConflict, "пользователь с таким email уже существует")
			return
		}
		log.Println("ошибка создания пользователя:", err)

		respondError(w, http.StatusInternalServerError, "ошибка создания пользователя")
		return
	}

	token, err := auth.GenerateToken(userID, h.config.JWTSecret)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка генерации токена")
		return
	}

	respondJSON(w, http.StatusCreated, map[string]string{"token": token})
}

// --- Вход ---

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// Login godoc
// POST /auth/login
func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	req.Email = strings.TrimSpace(strings.ToLower(req.Email))
	user, err := h.users.FindByEmail(req.Email)
	if errors.Is(err, repository.ErrNotFound) {
		respondError(w, http.StatusUnauthorized, "неверный email или пароль")
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка поиска пользователя")
		return
	}

	if !auth.CheckPassword(req.Password, user.PasswordHash) {
		respondError(w, http.StatusUnauthorized, "неверный email или пароль")
		return
	}

	token, err := auth.GenerateToken(user.ID, h.config.JWTSecret)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка генерации токена")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"token": token})
}

// --- Self-hosted: вход по секретному ключу ---

type selfHostedRequest struct {
	Secret string `json:"secret"`
}

// SelfHosted godoc
// POST /auth/self-hosted
func (h *AuthHandler) SelfHosted(w http.ResponseWriter, r *http.Request) {
	if !h.config.SelfHosted {
		respondError(w, http.StatusForbidden, "self-hosted режим не включён")
		return
	}

	var req selfHostedRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	if req.Secret != h.config.ServerSecret {
		respondError(w, http.StatusUnauthorized, "неверный секретный ключ")
		return
	}

	// В self-hosted режиме — один пользователь с фиксированным email
	const selfHostedEmail = "admin@self-hosted.local"
	user, err := h.users.FindByEmail(selfHostedEmail)
	if errors.Is(err, repository.ErrNotFound) {
		// Первый вход — создаём пользователя
		id, err := h.users.Create(selfHostedEmail, "", models.AuthProviderLocal, "self-hosted")
		if err != nil {
			respondError(w, http.StatusInternalServerError, "ошибка создания пользователя")
			return
		}
		token, err := auth.GenerateToken(id, h.config.JWTSecret)
		if err != nil {
			respondError(w, http.StatusInternalServerError, "ошибка генерации токена")
			return
		}
		respondJSON(w, http.StatusOK, map[string]string{"token": token})
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка поиска пользователя")
		return
	}

	token, err := auth.GenerateToken(user.ID, h.config.JWTSecret)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка генерации токена")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"token": token})
}

// --- OAuth заглушки (будут реализованы позже) ---

// Google godoc
// POST /auth/google
func (h *AuthHandler) Google(w http.ResponseWriter, r *http.Request) {
	respondError(w, http.StatusNotImplemented, "Google OAuth в разработке")
}

// Apple godoc
// POST /auth/apple
func (h *AuthHandler) Apple(w http.ResponseWriter, r *http.Request) {
	respondError(w, http.StatusNotImplemented, "Apple OAuth в разработке")
}
