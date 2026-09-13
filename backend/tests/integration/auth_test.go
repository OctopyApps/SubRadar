package integration

import (
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestHealth(t *testing.T) {
	a := newTestApp(t)
	rec := a.do("GET", "/health", nil, "")
	assert.Equal(t, http.StatusOK, rec.Code)
}

// ── Register ──────────────────────────────────────────────────────────────────

func TestRegister_FirstUserBecomesAdmin(t *testing.T) {
	a := newTestApp(t)

	rec := a.do("POST", "/auth/register", map[string]string{
		"email":    "first@test.com",
		"password": "password123",
	}, "")
	require.Equal(t, http.StatusCreated, rec.Code)

	var resp map[string]any
	decodeJSON(t, rec, &resp)
	require.NotEmpty(t, resp["token"])

	// Проверяем что роль действительно admin
	token := resp["token"].(string)
	meRec := a.do("GET", "/auth/me", nil, token)
	require.Equal(t, http.StatusOK, meRec.Code)

	var me map[string]any
	decodeJSON(t, meRec, &me)
	assert.Equal(t, "admin", me["role"], "первый пользователь должен быть admin")
}

func TestRegister_SecondUserIsRegularUser(t *testing.T) {
	a := newTestApp(t)
	_ = a.registerUser(t, "first@test.com", "password123")

	rec := a.do("POST", "/auth/register", map[string]string{
		"email":    "second@test.com",
		"password": "password123",
	}, "")
	require.Equal(t, http.StatusCreated, rec.Code)

	var resp map[string]any
	decodeJSON(t, rec, &resp)
	token := resp["token"].(string)

	meRec := a.do("GET", "/auth/me", nil, token)
	var me map[string]any
	decodeJSON(t, meRec, &me)
	assert.Equal(t, "user", me["role"], "второй пользователь должен быть user")
}

func TestRegister_DuplicateEmail(t *testing.T) {
	a := newTestApp(t)
	_ = a.registerUser(t, "dup@test.com", "password123")

	rec := a.do("POST", "/auth/register", map[string]string{
		"email":    "dup@test.com",
		"password": "password123",
	}, "")
	assert.Equal(t, http.StatusConflict, rec.Code)

	var resp map[string]any
	decodeJSON(t, rec, &resp)
	assert.Contains(t, resp, "error")
}

func TestRegister_WeakPassword(t *testing.T) {
	a := newTestApp(t)

	rec := a.do("POST", "/auth/register", map[string]string{
		"email":    "weak@test.com",
		"password": "123",
	}, "")
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestRegister_InvalidJSON(t *testing.T) {
	a := newTestApp(t)
	rec := a.do("POST", "/auth/register", "не JSON", "")
	assert.Equal(t, http.StatusBadRequest, rec.Code)
}

// ── Login ─────────────────────────────────────────────────────────────────────

func TestLogin_Success(t *testing.T) {
	a := newTestApp(t)
	_ = a.registerUser(t, "login@test.com", "password123")

	rec := a.do("POST", "/auth/login", map[string]string{
		"email":    "login@test.com",
		"password": "password123",
	}, "")
	require.Equal(t, http.StatusOK, rec.Code)

	var resp map[string]any
	decodeJSON(t, rec, &resp)
	assert.NotEmpty(t, resp["token"])
}

func TestLogin_WrongPassword(t *testing.T) {
	a := newTestApp(t)
	_ = a.registerUser(t, "login@test.com", "password123")

	rec := a.do("POST", "/auth/login", map[string]string{
		"email":    "login@test.com",
		"password": "wrongpassword",
	}, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestLogin_UnknownEmail(t *testing.T) {
	a := newTestApp(t)

	rec := a.do("POST", "/auth/login", map[string]string{
		"email":    "ghost@test.com",
		"password": "password123",
	}, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

// ── Self-hosted ───────────────────────────────────────────────────────────────

func TestSelfHosted_CorrectSecret(t *testing.T) {
	a := newTestApp(t)
	token := a.selfHostedLogin(t)
	assert.NotEmpty(t, token)
}

func TestSelfHosted_AlwaysAdmin(t *testing.T) {
	a := newTestApp(t)
	// Сначала регистрируем обычного пользователя — self-hosted всё равно должен быть admin
	_ = a.registerUser(t, "regular@test.com", "password123")

	token := a.selfHostedLogin(t)

	meRec := a.do("GET", "/auth/me", nil, token)
	var me map[string]any
	decodeJSON(t, meRec, &me)
	assert.Equal(t, "admin", me["role"], "self-hosted пользователь всегда должен быть admin")
}

func TestSelfHosted_WrongSecret(t *testing.T) {
	a := newTestApp(t)

	rec := a.do("POST", "/auth/self-hosted", map[string]string{
		"secret": "wrong_secret",
	}, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestSelfHosted_SecondLoginReturnsSameUser(t *testing.T) {
	a := newTestApp(t)

	token1 := a.selfHostedLogin(t)
	token2 := a.selfHostedLogin(t)

	// Оба токена должны давать одного и того же пользователя
	me1Rec := a.do("GET", "/auth/me", nil, token1)
	me2Rec := a.do("GET", "/auth/me", nil, token2)

	var me1, me2 map[string]any
	decodeJSON(t, me1Rec, &me1)
	decodeJSON(t, me2Rec, &me2)

	assert.Equal(t, me1["id"], me2["id"], "повторный self-hosted вход должен давать того же пользователя")
}

// ── Auth middleware ───────────────────────────────────────────────────────────

func TestProtectedRoute_NoToken(t *testing.T) {
	a := newTestApp(t)
	rec := a.do("GET", "/auth/me", nil, "")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestProtectedRoute_InvalidToken(t *testing.T) {
	a := newTestApp(t)
	rec := a.do("GET", "/auth/me", nil, "not.a.valid.token")
	assert.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestProtectedRoute_BlockedUser(t *testing.T) {
	a := newTestApp(t)
	adminToken, userToken := a.setupAdminAndUser(t)

	// Получаем ID второго пользователя
	meRec := a.do("GET", "/auth/me", nil, userToken)
	var me map[string]any
	decodeJSON(t, meRec, &me)
	userID := int(me["id"].(float64))

	// Блокируем
	blockRec := a.do("PATCH", "/admin/users/"+itoa(userID), map[string]any{
		"is_blocked":     true,
		"blocked_reason": "тест",
	}, adminToken)
	require.Equal(t, http.StatusOK, blockRec.Code)

	// Заблокированный не может обратиться к API
	rec := a.do("GET", "/auth/me", nil, userToken)
	assert.Equal(t, http.StatusForbidden, rec.Code)
}
