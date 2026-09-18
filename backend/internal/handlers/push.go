package handlers

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
)

type PushHandler struct {
	push   *repository.PushSubscriptionRepository
	config *config.Config
}

func NewPushHandler(push *repository.PushSubscriptionRepository, cfg *config.Config) *PushHandler {
	return &PushHandler{push: push, config: cfg}
}

// VAPIDPublicKey godoc
// GET /push/vapid-public-key
// Публичный — клиенту нужен public key до аутентификации, чтобы вызвать
// pushManager.subscribe(). Регистрируется только если cfg.PushEnabled().
func (h *PushHandler) VAPIDPublicKey(w http.ResponseWriter, r *http.Request) {
	respondJSON(w, http.StatusOK, map[string]string{"public_key": h.config.VAPIDPublicKey})
}

// --- Подписка/отписка ---

type subscribeRequest struct {
	Endpoint string `json:"endpoint"`
	Keys     struct {
		P256dh string `json:"p256dh"`
		Auth   string `json:"auth"`
	} `json:"keys"`
	// LeadTimes — override дефолта юзера для этого конкретного устройства.
	// nil (поле не передано) — использовать push_lead_times пользователя.
	LeadTimes *[]int `json:"lead_times,omitempty"`
}

// Subscribe godoc
// POST /push/subscribe
// Сохраняет Web Push подписку браузера (объект PushSubscription из
// ServiceWorkerRegistration.pushManager.subscribe()).
func (h *PushHandler) Subscribe(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req subscribeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	if req.Endpoint == "" || req.Keys.P256dh == "" || req.Keys.Auth == "" {
		respondError(w, http.StatusBadRequest, "endpoint и keys.p256dh/keys.auth обязательны")
		return
	}

	var leadTimes []int
	if req.LeadTimes != nil {
		for _, d := range *req.LeadTimes {
			if d < 0 || d > maxPushLeadTimeDays {
				respondError(w, http.StatusBadRequest, "lead_times: день должен быть от 0 до 90")
				return
			}
		}
		leadTimes = *req.LeadTimes
	}

	sub, err := h.push.Upsert(userID, req.Endpoint, req.Keys.P256dh, req.Keys.Auth, leadTimes)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка сохранения push-подписки")
		return
	}

	respondJSON(w, http.StatusCreated, sub)
}

type unsubscribeRequest struct {
	Endpoint string `json:"endpoint"`
}

// Unsubscribe godoc
// DELETE /push/subscribe
func (h *PushHandler) Unsubscribe(w http.ResponseWriter, r *http.Request) {
	userID, ok := auth.UserIDFromContext(r.Context())
	if !ok {
		respondError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var req unsubscribeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	if err := h.push.Delete(userID, req.Endpoint); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			respondError(w, http.StatusNotFound, "подписка не найдена")
			return
		}
		respondError(w, http.StatusInternalServerError, "ошибка отписки")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
