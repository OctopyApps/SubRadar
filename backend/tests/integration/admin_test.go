package integration

import (
	"fmt"
	"net/http"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// itoa конвертирует int в строку — нужен для формирования URL с ID.
func itoa(n int) string {
	return strconv.Itoa(n)
}

// getUserID достаёт ID текущего пользователя через /auth/me.
func (a *testApp) getUserID(t *testing.T, token string) int {
	t.Helper()
	rec := a.do("GET", "/auth/me", nil, token)
	require.Equal(t, http.StatusOK, rec.Code)
	var me map[string]any
	decodeJSON(t, rec, &me)
	return int(me["id"].(float64))
}

// ── Stats ─────────────────────────────────────────────────────────────────────

func TestAdminStats_AdminAccess(t *testing.T) {
	a := newTestApp(t)
	adminToken, _ := a.setupAdminAndUser(t)

	rec := a.do("GET", "/admin/stats", nil, adminToken)
	require.Equal(t, http.StatusOK, rec.Code)

	var stats map[string]any
	decodeJSON(t, rec, &stats)

	fields := []string{
		"total_users", "total_admins", "total_blocked",
		"total_subscriptions", "total_categories", "total_tags",
		"new_users_last_30_days",
	}
	for _, f := range fields {
		assert.Contains(t, stats, f, "поле %s отсутствует в статистике", f)
	}
	assert.Equal(t, float64(2), stats["total_users"])
	assert.Equal(t, float64(1), stats["total_admins"])
}

func TestAdminStats_UserForbidden(t *testing.T) {
	a := newTestApp(t)
	_, userToken := a.setupAdminAndUser(t)

	rec := a.do("GET", "/admin/stats", nil, userToken)
	assert.Equal(t, http.StatusForbidden, rec.Code)
}

func TestAdminStats_NoToken(t *testing.T) {
	a := newTestApp(t)
	rec := a.do("GET", "/admin/stats", nil, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

// ── List Users ────────────────────────────────────────────────────────────────

func TestAdminListUsers_ReturnsAllUsers(t *testing.T) {
	a := newTestApp(t)
	adminToken, _ := a.setupAdminAndUser(t)

	rec := a.do("GET", "/admin/users", nil, adminToken)
	require.Equal(t, http.StatusOK, rec.Code)

	var page map[string]any
	decodeJSON(t, rec, &page)

	assert.Equal(t, float64(2), page["total"])
	users := page["users"].([]any)
	assert.Len(t, users, 2)

	// Проверяем поля первого пользователя
	u := users[0].(map[string]any)
	for _, f := range []string{"id", "email", "display_name", "provider", "role", "is_blocked", "created_at"} {
		assert.Contains(t, u, f, "поле %s отсутствует", f)
	}
}

func TestAdminListUsers_FilterByRole(t *testing.T) {
	a := newTestApp(t)
	adminToken, _ := a.setupAdminAndUser(t)

	rec := a.do("GET", "/admin/users?role=admin", nil, adminToken)
	require.Equal(t, http.StatusOK, rec.Code)

	var page map[string]any
	decodeJSON(t, rec, &page)
	assert.Equal(t, float64(1), page["total"])
}

func TestAdminListUsers_Search(t *testing.T) {
	a := newTestApp(t)
	adminToken, _ := a.setupAdminAndUser(t)

	rec := a.do("GET", "/admin/users?search=admin", nil, adminToken)
	require.Equal(t, http.StatusOK, rec.Code)

	var page map[string]any
	decodeJSON(t, rec, &page)
	users := page["users"].([]any)
	for _, u := range users {
		email := u.(map[string]any)["email"].(string)
		assert.Contains(t, email, "admin")
	}
}

func TestAdminListUsers_Pagination(t *testing.T) {
	a := newTestApp(t)
	adminToken, _ := a.setupAdminAndUser(t)

	rec := a.do("GET", "/admin/users?limit=1&offset=0", nil, adminToken)
	require.Equal(t, http.StatusOK, rec.Code)

	var page map[string]any
	decodeJSON(t, rec, &page)
	assert.Equal(t, float64(2), page["total"]) // всего 2
	assert.Equal(t, float64(1), page["limit"])
	users := page["users"].([]any)
	assert.Len(t, users, 1) // но вернули 1
}

// ── Get User ──────────────────────────────────────────────────────────────────

func TestAdminGetUser_Found(t *testing.T) {
	a := newTestApp(t)
	adminToken, _ := a.setupAdminAndUser(t)
	adminID := a.getUserID(t, adminToken)

	rec := a.do("GET", fmt.Sprintf("/admin/users/%d", adminID), nil, adminToken)
	require.Equal(t, http.StatusOK, rec.Code)

	var u map[string]any
	decodeJSON(t, rec, &u)
	assert.Equal(t, float64(adminID), u["id"])
	assert.Equal(t, "admin", u["role"])
}

func TestAdminGetUser_NotFound(t *testing.T) {
	a := newTestApp(t)
	adminToken, _ := a.setupAdminAndUser(t)

	rec := a.do("GET", "/admin/users/99999", nil, adminToken)
	assert.Equal(t, http.StatusNotFound, rec.Code)
}

// ── Update User ───────────────────────────────────────────────────────────────

func TestAdminUpdateUser_BlockAndUnblock(t *testing.T) {
	a := newTestApp(t)
	adminToken, userToken := a.setupAdminAndUser(t)
	userID := a.getUserID(t, userToken)

	// Блокируем
	blockRec := a.do("PATCH", fmt.Sprintf("/admin/users/%d", userID), map[string]any{
		"is_blocked":     true,
		"blocked_reason": "тест блокировки",
	}, adminToken)
	require.Equal(t, http.StatusOK, blockRec.Code)

	var blocked map[string]any
	decodeJSON(t, blockRec, &blocked)
	assert.True(t, blocked["is_blocked"].(bool))
	assert.NotNil(t, blocked["blocked_at"])

	// Убеждаемся что заблокированный не может войти
	accessRec := a.do("GET", "/auth/me", nil, userToken)
	assert.Equal(t, http.StatusForbidden, accessRec.Code)

	// Разблокируем
	unblockRec := a.do("PATCH", fmt.Sprintf("/admin/users/%d", userID), map[string]any{
		"is_blocked": false,
	}, adminToken)
	require.Equal(t, http.StatusOK, unblockRec.Code)

	var unblocked map[string]any
	decodeJSON(t, unblockRec, &unblocked)
	assert.False(t, unblocked["is_blocked"].(bool))

	// После разблокировки токен снова работает
	accessRec2 := a.do("GET", "/auth/me", nil, userToken)
	assert.Equal(t, http.StatusOK, accessRec2.Code)
}

func TestAdminUpdateUser_ChangeRole(t *testing.T) {
	a := newTestApp(t)
	adminToken, userToken := a.setupAdminAndUser(t)
	userID := a.getUserID(t, userToken)

	rec := a.do("PATCH", fmt.Sprintf("/admin/users/%d", userID), map[string]any{
		"role": "admin",
	}, adminToken)
	require.Equal(t, http.StatusOK, rec.Code)

	var u map[string]any
	decodeJSON(t, rec, &u)
	assert.Equal(t, "admin", u["role"])

	// Теперь этот пользователь тоже может ходить в admin endpoints
	statsRec := a.do("GET", "/admin/stats", nil, userToken)
	assert.Equal(t, http.StatusOK, statsRec.Code)
}

func TestAdminUpdateUser_InvalidRole(t *testing.T) {
	a := newTestApp(t)
	adminToken, userToken := a.setupAdminAndUser(t)
	userID := a.getUserID(t, userToken)

	rec := a.do("PATCH", fmt.Sprintf("/admin/users/%d", userID), map[string]any{
		"role": "superuser",
	}, adminToken)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestAdminUpdateUser_UserCannotUpdate(t *testing.T) {
	a := newTestApp(t)
	adminToken, userToken := a.setupAdminAndUser(t)
	adminID := a.getUserID(t, adminToken)

	rec := a.do("PATCH", fmt.Sprintf("/admin/users/%d", adminID), map[string]any{
		"role": "user",
	}, userToken)
	assert.Equal(t, http.StatusForbidden, rec.Code)
}

// ── Delete User ───────────────────────────────────────────────────────────────

func TestAdminDeleteUser(t *testing.T) {
	a := newTestApp(t)
	adminToken, userToken := a.setupAdminAndUser(t)
	userID := a.getUserID(t, userToken)

	rec := a.do("DELETE", fmt.Sprintf("/admin/users/%d", userID), nil, adminToken)
	assert.Equal(t, http.StatusOK, rec.Code)

	// Удалённый пользователь больше не находится
	getRec := a.do("GET", fmt.Sprintf("/admin/users/%d", userID), nil, adminToken)
	assert.Equal(t, http.StatusNotFound, getRec.Code)

	// Статистика обновилась
	statsRec := a.do("GET", "/admin/stats", nil, adminToken)
	var stats map[string]any
	decodeJSON(t, statsRec, &stats)
	assert.Equal(t, float64(1), stats["total_users"])
}

// ── System Categories ─────────────────────────────────────────────────────────

func TestAdminSystemCategories_CreateAndList(t *testing.T) {
	a := newTestApp(t)
	adminToken, userToken := a.setupAdminAndUser(t)

	// Создаём системную категорию
	createRec := a.do("POST", "/admin/categories", map[string]string{
		"name": "Стриминг",
		"icon": "play.circle",
	}, adminToken)
	require.Equal(t, http.StatusCreated, createRec.Code)

	var cat map[string]any
	decodeJSON(t, createRec, &cat)
	assert.Equal(t, "Стриминг", cat["name"])
	assert.True(t, cat["is_system"].(bool))
	assert.Nil(t, cat["user_id"])

	catID := cat["id"].(string)

	// Список системных категорий
	listRec := a.do("GET", "/admin/categories", nil, adminToken)
	require.Equal(t, http.StatusOK, listRec.Code)

	var cats []any
	decodeJSON(t, listRec, &cats)
	assert.Len(t, cats, 1)

	// Системная категория видна обычному пользователю
	userCatsRec := a.do("GET", "/categories", nil, userToken)
	require.Equal(t, http.StatusOK, userCatsRec.Code)

	var userCats []any
	decodeJSON(t, userCatsRec, &userCats)
	found := false
	for _, c := range userCats {
		if c.(map[string]any)["id"] == catID {
			found = true
			break
		}
	}
	assert.True(t, found, "системная категория должна быть видна обычному пользователю")

	// Удаляем
	deleteRec := a.do("DELETE", "/admin/categories/"+catID, nil, adminToken)
	assert.Equal(t, http.StatusOK, deleteRec.Code)

	// Список теперь пуст
	listRec2 := a.do("GET", "/admin/categories", nil, adminToken)
	var cats2 []any
	decodeJSON(t, listRec2, &cats2)
	assert.Empty(t, cats2)
}

func TestAdminSystemCategories_UserCannotCreate(t *testing.T) {
	a := newTestApp(t)
	_, userToken := a.setupAdminAndUser(t)

	rec := a.do("POST", "/admin/categories", map[string]string{
		"name": "Хакерская категория",
		"icon": "exclamationmark.triangle",
	}, userToken)
	assert.Equal(t, http.StatusForbidden, rec.Code)
}
