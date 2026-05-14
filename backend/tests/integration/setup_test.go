package integration

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/db"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/server"
	"github.com/stretchr/testify/require"
)

// testApp — собранное приложение для одного теста.
type testApp struct {
	router http.Handler
	db     *sql.DB
}

// newTestApp поднимает SQLite в памяти, применяет миграции и возвращает роутер.
// Каждый вызов даёт чистую изолированную БД — тесты не влияют друг на друга.
func newTestApp(t *testing.T) *testApp {
	t.Helper()

	database, err := db.Connect("sqlite", ":memory:")
	require.NoError(t, err, "не удалось создать тестовую БД")

	t.Cleanup(func() { database.Close() })

	cfg := testConfig()
	router := server.NewRouter(database, cfg)

	return &testApp{router: router, db: database}
}

// testConfig возвращает конфиг для тестового окружения.
func testConfig() *config.Config {
	return &config.Config{
		Port:         8080,
		DBDriver:     "sqlite",
		DBPath:       ":memory:",
		JWTSecret:    "test-jwt-secret",
		SelfHosted:   true,
		ServerSecret: "test-server-secret",
		CORSAllowAll: true,
	}
}

// ── HTTP хелперы ──────────────────────────────────────────────────────────────

// do выполняет HTTP запрос к роутеру и возвращает recorder.
func (a *testApp) do(method, path string, body any, token string) *httptest.ResponseRecorder {
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}

	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	rec := httptest.NewRecorder()
	a.router.ServeHTTP(rec, req)
	return rec
}

// decodeJSON декодирует тело ответа в переданную структуру.
func decodeJSON(t *testing.T, rec *httptest.ResponseRecorder, dst any) {
	t.Helper()
	err := json.NewDecoder(rec.Body).Decode(dst)
	require.NoError(t, err, "не удалось декодировать JSON ответ: %s", rec.Body.String())
}

// ── Auth хелперы ──────────────────────────────────────────────────────────────

type authResponse struct {
	Token string `json:"token"`
}

// registerUser регистрирует пользователя и возвращает JWT токен.
func (a *testApp) registerUser(t *testing.T, email, password string) string {
	t.Helper()
	rec := a.do("POST", "/auth/register", map[string]string{
		"email":    email,
		"password": password,
	}, "")
	require.Equal(t, http.StatusCreated, rec.Code, "register failed: %s", rec.Body.String())

	var resp authResponse
	decodeJSON(t, rec, &resp)
	require.NotEmpty(t, resp.Token, "токен не вернулся при регистрации")
	return resp.Token
}

// loginUser выполняет вход и возвращает JWT токен.
func (a *testApp) loginUser(t *testing.T, email, password string) string {
	t.Helper()
	rec := a.do("POST", "/auth/login", map[string]string{
		"email":    email,
		"password": password,
	}, "")
	require.Equal(t, http.StatusOK, rec.Code, "login failed: %s", rec.Body.String())

	var resp authResponse
	decodeJSON(t, rec, &resp)
	require.NotEmpty(t, resp.Token)
	return resp.Token
}

// selfHostedLogin выполняет self-hosted вход и возвращает токен.
func (a *testApp) selfHostedLogin(t *testing.T) string {
	t.Helper()
	rec := a.do("POST", "/auth/self-hosted", map[string]string{
		"secret": testConfig().ServerSecret,
	}, "")
	require.Equal(t, http.StatusOK, rec.Code, "self-hosted login failed: %s", rec.Body.String())

	var resp authResponse
	decodeJSON(t, rec, &resp)
	require.NotEmpty(t, resp.Token)
	return resp.Token
}

// setupAdminAndUser создаёт двух пользователей: первый admin, второй user.
// Возвращает токены обоих — удобно для тестов разграничения прав.
func (a *testApp) setupAdminAndUser(t *testing.T) (adminToken, userToken string) {
	t.Helper()
	adminToken = a.registerUser(t, "admin@test.com", "password123")
	userToken = a.registerUser(t, "user@test.com", "password123")
	return adminToken, userToken
}
