package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
)

type MeHandler struct {
	users  *repository.UserRepository
	config *config.Config
}

func NewMeHandler(users *repository.UserRepository, cfg *config.Config) *MeHandler {
	return &MeHandler{users: users, config: cfg}
}

// Me godoc
// GET /auth/me
// Возвращает публичный профиль текущего пользователя.
func (h *MeHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	user, err := h.users.FindByID(userID)
	if errors.Is(err, repository.ErrNotFound) {
		respondError(w, http.StatusNotFound, "пользователь не найден")
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения профиля")
		return
	}

	respondJSON(w, http.StatusOK, user.ToPublic())
}

// UpdateMe godoc
// PATCH /auth/me
// Обновляет display_name текущего пользователя и, опционально,
// дефолтный push_lead_times (за сколько дней до списания слать Web Push
// на устройства без своего override).
type updateMeRequest struct {
	DisplayName string `json:"display_name"`
	// Указатель — чтобы отличить "поле не передано" (nil, не трогаем) от
	// "передан пустой список" ([]int{}, означает "отключить дефолтные
	// напоминания").
	PushLeadTimes *[]int `json:"push_lead_times,omitempty"`
}

// maxPushLeadTimeDays — верхняя граница на sanity: напоминание "за 400 дней"
// смысла не имеет и не с чем сравнивать next_billing_date разумно далеко.
const maxPushLeadTimeDays = 90

func (h *MeHandler) UpdateMe(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req updateMeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if req.DisplayName == "" {
		respondError(w, http.StatusBadRequest, "display_name не может быть пустым")
		return
	}

	if req.PushLeadTimes != nil {
		for _, d := range *req.PushLeadTimes {
			if d < 0 || d > maxPushLeadTimeDays {
				respondError(w, http.StatusBadRequest, "push_lead_times: день должен быть от 0 до 90")
				return
			}
		}
	}

	if err := h.users.UpdateDisplayName(userID, req.DisplayName); err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка обновления профиля")
		return
	}

	if req.PushLeadTimes != nil {
		if err := h.users.SetPushLeadTimes(userID, *req.PushLeadTimes); err != nil {
			respondError(w, http.StatusInternalServerError, "ошибка обновления push_lead_times")
			return
		}
	}

	user, err := h.users.FindByID(userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения профиля")
		return
	}

	respondJSON(w, http.StatusOK, user.ToPublic())
}

// ChangePassword godoc
// POST /auth/me/change-password
// Меняет пароль текущего пользователя. Требует старый пароль для подтверждения.
type changePasswordRequest struct {
	OldPassword string `json:"old_password"`
	NewPassword string `json:"new_password"`
}

func (h *MeHandler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req changePasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	user, err := h.users.FindByID(userID)
	if errors.Is(err, repository.ErrNotFound) {
		respondError(w, http.StatusNotFound, "пользователь не найден")
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения профиля")
		return
	}

	// Self-hosted пользователь входит по server_secret, у него нет пароля
	if user.PasswordHash == "" {
		respondError(w, http.StatusBadRequest, "смена пароля недоступна для self-hosted аккаунта")
		return
	}

	if !auth.CheckPassword(req.OldPassword, user.PasswordHash) {
		respondError(w, http.StatusUnauthorized, "неверный текущий пароль")
		return
	}

	newHash, err := auth.HashPassword(req.NewPassword)
	if errors.Is(err, auth.ErrWeakPassword) {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка хэширования пароля")
		return
	}

	if err := h.users.UpdatePassword(userID, newHash); err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка смены пароля")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
