package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
	"github.com/go-chi/chi/v5"
)

// MARK: - CategoryHandler

type CategoryHandler struct {
	cats *repository.CategoryRepository
}

func NewCategoryHandler(cats *repository.CategoryRepository) *CategoryHandler {
	return &CategoryHandler{cats: cats}
}

// List godoc
// GET /categories
func (h *CategoryHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	cats, err := h.cats.FindAllByUser(userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения категорий")
		return
	}
	if cats == nil {
		cats = []models.Category{}
	}
	respondJSON(w, http.StatusOK, cats)
}

// Create godoc
// POST /categories
func (h *CategoryHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())

	var body struct {
		Name string `json:"name"`
		Icon string `json:"icon"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Name == "" {
		respondError(w, http.StatusBadRequest, "поле name обязательно")
		return
	}
	if body.Icon == "" {
		body.Icon = "ellipsis.circle"
	}

	cat, err := h.cats.FindOrCreate(userID, body.Name, body.Icon)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка создания категории")
		return
	}
	respondJSON(w, http.StatusCreated, cat)
}

// Delete godoc
// DELETE /categories/{id}
func (h *CategoryHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	id := chi.URLParam(r, "id")

	if err := h.cats.Delete(id, userID); err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка удаления категории")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// MARK: - CurrencyHandler

type CurrencyHandler struct {
	currencies *repository.CurrencyRepository
}

func NewCurrencyHandler(currencies *repository.CurrencyRepository) *CurrencyHandler {
	return &CurrencyHandler{currencies: currencies}
}

// List godoc
// GET /currencies
func (h *CurrencyHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	currencies, err := h.currencies.FindAllByUser(userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения валют")
		return
	}
	if currencies == nil {
		currencies = []models.Currency{}
	}
	respondJSON(w, http.StatusOK, currencies)
}

// Create godoc
// POST /currencies
func (h *CurrencyHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())

	var body struct {
		Code        string `json:"code"`
		Symbol      string `json:"symbol"`
		DisplayName string `json:"display_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Code == "" || body.Symbol == "" {
		respondError(w, http.StatusBadRequest, "поля code и symbol обязательны")
		return
	}
	if body.DisplayName == "" {
		body.DisplayName = body.Code
	}

	currency, err := h.currencies.FindOrCreate(userID, body.Code, body.Symbol, body.DisplayName)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка создания валюты")
		return
	}
	respondJSON(w, http.StatusCreated, currency)
}

// Delete godoc
// DELETE /currencies/{id}
func (h *CurrencyHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	id := chi.URLParam(r, "id")

	if err := h.currencies.Delete(id, userID); err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка удаления валюты")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
