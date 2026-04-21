package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/auth"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
	"github.com/go-chi/chi/v5"
)

type TagHandler struct {
	tags *repository.TagRepository
}

func NewTagHandler(tags *repository.TagRepository) *TagHandler {
	return &TagHandler{tags: tags}
}

// List godoc
// GET /tags
func (h *TagHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	tags, err := h.tags.FindAllByUser(userID)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения тегов")
		return
	}
	if tags == nil {
		tags = []models.Tag{}
	}
	respondJSON(w, http.StatusOK, tags)
}

// Create godoc
// POST /tags
func (h *TagHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())

	var body struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Name == "" {
		respondError(w, http.StatusBadRequest, "поле name обязательно")
		return
	}

	tag, err := h.tags.FindOrCreate(userID, body.Name)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка создания тега")
		return
	}
	respondJSON(w, http.StatusCreated, tag)
}

// Delete godoc
// DELETE /tags/{id}
func (h *TagHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.UserIDFromContext(r.Context())
	id := chi.URLParam(r, "id")

	if err := h.tags.Delete(id, userID); err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка удаления тега")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
