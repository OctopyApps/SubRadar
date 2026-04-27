package handlers

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

type SubscriptionHandler struct {
	subs *repository.SubscriptionRepository
}

func NewSubscriptionHandler(subs *repository.SubscriptionRepository) *SubscriptionHandler {
	return &SubscriptionHandler{subs: subs}
}

// List godoc
// GET /subscriptions
func (h *SubscriptionHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	subs, err := h.subs.FindAllByUser(userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения подписок")
		return
	}
	if subs == nil {
		subs = []models.Subscription{} // возвращаем [] а не null
	}
	respondJSON(w, http.StatusOK, subs)
}

// Create godoc
// POST /subscriptions
func (h *SubscriptionHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())

	var s models.Subscription
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}
	s.UserID = userID
	s.ID = uuid.NewString() // генерируем на сервере, игнорируем что пришло от клиента

	if s.Name == "" {
		respondError(w, http.StatusBadRequest, "поле name обязательно")
		return
	}

	if err := h.subs.Create(&s); err != nil {
		log.Printf("Create subscription error: %v", err)
		respondError(w, http.StatusInternalServerError, "ошибка создания подписки")
		return
	}
	respondJSON(w, http.StatusCreated, s) // возвращаем объект с присвоенным ID
}

// Update godoc
// PUT /subscriptions/{id}
func (h *SubscriptionHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	id := chi.URLParam(r, "id")

	var s models.Subscription
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}
	s.ID = id
	s.UserID = userID

	if err := h.subs.Update(&s); err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка обновления подписки")
		return
	}
	respondJSON(w, http.StatusOK, s)
}

// Delete godoc
// DELETE /subscriptions/{id}
func (h *SubscriptionHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	id := chi.URLParam(r, "id")

	if err := h.subs.Delete(id, userID); err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка удаления подписки")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
