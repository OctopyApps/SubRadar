package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
	"github.com/go-chi/chi/v5"
)

type AdminHandler struct {
	admin *repository.AdminRepository
	users *repository.UserRepository
}

func NewAdminHandler(admin *repository.AdminRepository, users *repository.UserRepository) *AdminHandler {
	return &AdminHandler{admin: admin, users: users}
}

// ============================================================
// Статистика
// ============================================================

// Stats godoc
// GET /admin/stats
func (h *AdminHandler) Stats(w http.ResponseWriter, r *http.Request) {
	stats, err := h.admin.GetStats()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения статистики")
		return
	}
	respondJSON(w, http.StatusOK, stats)
}

// ============================================================
// Пользователи
// ============================================================

// ListUsers godoc
// GET /admin/users?limit=20&offset=0&role=admin&search=john
func (h *AdminHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	limit, offset := parsePagination(r)
	role := r.URL.Query().Get("role")
	search := strings.TrimSpace(r.URL.Query().Get("search"))

	page, err := h.admin.ListUsers(limit, offset, role, search)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения пользователей")
		return
	}
	respondJSON(w, http.StatusOK, page)
}

// GetUser godoc
// GET /admin/users/{id}
func (h *AdminHandler) GetUser(w http.ResponseWriter, r *http.Request) {
	id, ok := parseUserID(w, r)
	if !ok {
		return
	}

	user, err := h.admin.GetUser(id)
	if errors.Is(err, repository.ErrNotFound) {
		respondError(w, http.StatusNotFound, "пользователь не найден")
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения пользователя")
		return
	}
	respondJSON(w, http.StatusOK, user)
}

// UpdateUser godoc
// PATCH /admin/users/{id}
// Поддерживает: role, is_blocked, blocked_reason, display_name.
// Каждое поле опциональное — меняем только то что пришло.
type updateUserRequest struct {
	Role          *string `json:"role"`
	IsBlocked     *bool   `json:"is_blocked"`
	BlockedReason *string `json:"blocked_reason"`
	DisplayName   *string `json:"display_name"`
}

func (h *AdminHandler) UpdateUser(w http.ResponseWriter, r *http.Request) {
	id, ok := parseUserID(w, r)
	if !ok {
		return
	}

	var req updateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	// Применяем только те поля которые пришли в запросе
	if req.Role != nil {
		role := models.UserRole(*req.Role)
		if role != models.UserRoleUser && role != models.UserRoleAdmin {
			respondError(w, http.StatusBadRequest, "допустимые роли: user, admin")
			return
		}
		if err := h.users.SetRole(id, role); err != nil {
			respondError(w, http.StatusInternalServerError, "ошибка обновления роли")
			return
		}
	}

	if req.IsBlocked != nil {
		reason := ""
		if req.BlockedReason != nil {
			reason = strings.TrimSpace(*req.BlockedReason)
		}
		if err := h.users.SetBlocked(id, *req.IsBlocked, reason); err != nil {
			respondError(w, http.StatusInternalServerError, "ошибка обновления статуса блокировки")
			return
		}
	}

	if req.DisplayName != nil {
		name := strings.TrimSpace(*req.DisplayName)
		if name == "" {
			respondError(w, http.StatusBadRequest, "display_name не может быть пустым")
			return
		}
		if err := h.users.UpdateDisplayName(id, name); err != nil {
			respondError(w, http.StatusInternalServerError, "ошибка обновления имени")
			return
		}
	}

	// Возвращаем актуальное состояние пользователя
	user, err := h.admin.GetUser(id)
	if errors.Is(err, repository.ErrNotFound) {
		respondError(w, http.StatusNotFound, "пользователь не найден")
		return
	}
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения пользователя")
		return
	}
	respondJSON(w, http.StatusOK, user)
}

// DeleteUser godoc
// DELETE /admin/users/{id}
func (h *AdminHandler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	id, ok := parseUserID(w, r)
	if !ok {
		return
	}

	if err := h.users.Delete(id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			respondError(w, http.StatusNotFound, "пользователь не найден")
			return
		}
		respondError(w, http.StatusInternalServerError, "ошибка удаления пользователя")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ============================================================
// Системные категории
// ============================================================

// ListSystemCategories godoc
// GET /admin/categories
func (h *AdminHandler) ListSystemCategories(w http.ResponseWriter, r *http.Request) {
	cats, err := h.admin.ListSystemCategories()
	if err != nil {
		respondError(w, http.StatusInternalServerError, "ошибка получения категорий")
		return
	}
	respondJSON(w, http.StatusOK, cats)
}

// CreateSystemCategory godoc
// POST /admin/categories
type createCategoryRequest struct {
	Name string `json:"name"`
	Icon string `json:"icon"`
}

func (h *AdminHandler) CreateSystemCategory(w http.ResponseWriter, r *http.Request) {
	var req createCategoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "невалидный JSON")
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	req.Icon = strings.TrimSpace(req.Icon)

	if req.Name == "" {
		respondError(w, http.StatusBadRequest, "name обязателен")
		return
	}
	if req.Icon == "" {
		req.Icon = "ellipsis.circle" // дефолтная иконка
	}

	cat, err := h.admin.CreateSystemCategory(req.Name, req.Icon)
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			respondError(w, http.StatusConflict, "категория с таким именем уже существует")
			return
		}
		respondError(w, http.StatusInternalServerError, "ошибка создания категории")
		return
	}

	respondJSON(w, http.StatusCreated, cat)
}

// DeleteSystemCategory godoc
// DELETE /admin/categories/{id}
func (h *AdminHandler) DeleteSystemCategory(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if id == "" {
		respondError(w, http.StatusBadRequest, "id обязателен")
		return
	}

	if err := h.admin.DeleteSystemCategory(id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			respondError(w, http.StatusNotFound, "категория не найдена")
			return
		}
		respondError(w, http.StatusInternalServerError, "ошибка удаления категории")
		return
	}

	respondJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ============================================================
// Вспомогательные функции
// ============================================================

// parsePagination читает limit/offset из query параметров.
// Дефолты: limit=20, offset=0. Максимум limit=100.
func parsePagination(r *http.Request) (limit, offset int) {
	limit = 20
	offset = 0

	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}
	if limit > 100 {
		limit = 100
	}

	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = n
		}
	}

	return limit, offset
}

// parseUserID читает и валидирует {id} из URL.
func parseUserID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	raw := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		respondError(w, http.StatusBadRequest, "некорректный id пользователя")
		return 0, false
	}
	return id, true
}
