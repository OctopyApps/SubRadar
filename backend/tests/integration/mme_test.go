package integration

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestMe_ReturnsProfile(t *testing.T) {
	a := newTestApp(t)
	token := a.registerUser(t, "me@test.com", "password123")

	rec := a.do("GET", "/auth/me", nil, token)
	require.Equal(t, http.StatusOK, rec.Code)

	var me map[string]any
	decodeJSON(t, rec, &me)

	assert.Equal(t, "me@test.com", me["email"])
	assert.Equal(t, "admin", me["role"]) // первый пользователь
	assert.Equal(t, "local", me["provider"])
	assert.NotContains(t, me, "password_hash", "хэш пароля не должен утекать")
	assert.NotContains(t, me, "provider_id")

	for _, f := range []string{"id", "email", "display_name", "provider", "role", "created_at"} {
		assert.Contains(t, me, f)
	}
}

func TestMe_NoToken(t *testing.T) {
	a := newTestApp(t)
	rec := a.do("GET", "/auth/me", nil, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

// ── PATCH /auth/me ────────────────────────────────────────────────────────────

func TestUpdateMe_DisplayName(t *testing.T) {
	a := newTestApp(t)
	token := a.registerUser(t, "update@test.com", "password123")

	rec := a.do("PATCH", "/auth/me", map[string]string{
		"display_name": "Алексей",
	}, token)
	require.Equal(t, http.StatusOK, rec.Code)

	var me map[string]any
	decodeJSON(t, rec, &me)
	assert.Equal(t, "Алексей", me["display_name"])

	// Проверяем что изменение персистентно
	meRec := a.do("GET", "/auth/me", nil, token)
	var me2 map[string]any
	decodeJSON(t, meRec, &me2)
	assert.Equal(t, "Алексей", me2["display_name"])
}

func TestUpdateMe_EmptyDisplayName(t *testing.T) {
	a := newTestApp(t)
	token := a.registerUser(t, "update@test.com", "password123")

	rec := a.do("PATCH", "/auth/me", map[string]string{
		"display_name": "",
	}, token)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestUpdateMe_WhitespaceDisplayName(t *testing.T) {
	a := newTestApp(t)
	token := a.registerUser(t, "update@test.com", "password123")

	rec := a.do("PATCH", "/auth/me", map[string]string{
		"display_name": "   ",
	}, token)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ── POST /auth/me/change-password ─────────────────────────────────────────────

func TestChangePassword_Success(t *testing.T) {
	a := newTestApp(t)
	token := a.registerUser(t, "pw@test.com", "oldpassword")

	rec := a.do("POST", "/auth/me/change-password", map[string]string{
		"old_password": "oldpassword",
		"new_password": "newpassword123",
	}, token)
	require.Equal(t, http.StatusOK, rec.Code)

	// Старый пароль больше не работает
	loginOldRec := a.do("POST", "/auth/login", map[string]string{
		"email":    "pw@test.com",
		"password": "oldpassword",
	}, "")
	assert.Equal(t, http.StatusUnauthorized, loginOldRec.Code)

	// Новый пароль работает
	loginNewRec := a.do("POST", "/auth/login", map[string]string{
		"email":    "pw@test.com",
		"password": "newpassword123",
	}, "")
	assert.Equal(t, http.StatusOK, loginNewRec.Code)
}

func TestChangePassword_WrongOldPassword(t *testing.T) {
	a := newTestApp(t)
	token := a.registerUser(t, "pw@test.com", "correctpassword")

	rec := a.do("POST", "/auth/me/change-password", map[string]string{
		"old_password": "wrongpassword",
		"new_password": "newpassword123",
	}, token)
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestChangePassword_SelfHostedAccount(t *testing.T) {
	a := newTestApp(t)
	token := a.selfHostedLogin(t)

	// Self-hosted аккаунт не имеет пароля — должна быть понятная ошибка
	rec := a.do("POST", "/auth/me/change-password", map[string]string{
		"old_password": "anything",
		"new_password": "newpassword123",
	}, token)
	assert.Equal(t, http.StatusBadRequest, rec.Code)

	var resp map[string]any
	decodeJSON(t, rec, &resp)
	assert.Contains(t, resp, "error")
}
