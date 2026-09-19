package integration

import (
	"net/http"
	"testing"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/db"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/server"
	"github.com/stretchr/testify/require"
)

// newPushTestApp — как newTestApp, но с VAPID-ключами (push включён).
func newPushTestApp(t *testing.T) *testApp {
	t.Helper()

	database, err := db.Connect("sqlite", ":memory:")
	require.NoError(t, err)
	t.Cleanup(func() { database.Close() })

	cfg := testConfig()
	cfg.VAPIDPublicKey = "test-vapid-public-key"
	cfg.VAPIDPrivateKey = "test-vapid-private-key"
	cfg.VAPIDSubscriber = "mailto:test@example.com"

	return &testApp{router: server.NewRouter(database, cfg), db: database}
}

func TestPush_DisabledByDefault(t *testing.T) {
	app := newTestApp(t) // testConfig() без VAPID-ключей
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("GET", "/push/vapid-public-key", nil, "")
	require.Equal(t, http.StatusNotFound, rec.Code, "без VAPID-ключей /push/* не должен регистрироваться")

	subRec := app.do("POST", "/push/subscribe", map[string]any{
		"endpoint": "https://push.example.com/x",
		"keys":     map[string]string{"p256dh": "a", "auth": "b"},
	}, token)
	require.Equal(t, http.StatusNotFound, subRec.Code)
}

func TestPush_VAPIDPublicKey_Public(t *testing.T) {
	app := newPushTestApp(t)

	rec := app.do("GET", "/push/vapid-public-key", nil, "")
	require.Equal(t, http.StatusOK, rec.Code)

	var resp map[string]string
	decodeJSON(t, rec, &resp)
	require.Equal(t, "test-vapid-public-key", resp["public_key"])
}

func TestPush_Subscribe_NoToken(t *testing.T) {
	app := newPushTestApp(t)

	rec := app.do("POST", "/push/subscribe", map[string]any{
		"endpoint": "https://push.example.com/x",
		"keys":     map[string]string{"p256dh": "a", "auth": "b"},
	}, "")
	require.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestPush_Subscribe_MissingFields(t *testing.T) {
	app := newPushTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/push/subscribe", map[string]any{
		"endpoint": "",
	}, token)
	require.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestPush_Subscribe_Success_DoesNotLeakKeys(t *testing.T) {
	app := newPushTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/push/subscribe", map[string]any{
		"endpoint":   "https://push.example.com/x",
		"keys":       map[string]string{"p256dh": "p256dh-value", "auth": "auth-value"},
		"lead_times": []int{1, 3},
	}, token)
	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())

	var resp map[string]any
	decodeJSON(t, rec, &resp)
	require.NotEmpty(t, resp["id"])
	require.Equal(t, "https://push.example.com/x", resp["endpoint"])
	require.ElementsMatch(t, []any{float64(1), float64(3)}, resp["lead_times"])
	require.NotContains(t, resp, "p256dh", "p256dh не должен утекать в ответе")
	require.NotContains(t, resp, "auth", "auth не должен утекать в ответе")
}

func TestPush_Subscribe_ReplacesOnReSubscribe(t *testing.T) {
	app := newPushTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	body := map[string]any{
		"endpoint": "https://push.example.com/x",
		"keys":     map[string]string{"p256dh": "p256dh-1", "auth": "auth-1"},
	}
	rec1 := app.do("POST", "/push/subscribe", body, token)
	require.Equal(t, http.StatusCreated, rec1.Code)
	var sub1 map[string]any
	decodeJSON(t, rec1, &sub1)

	body["keys"] = map[string]string{"p256dh": "p256dh-2", "auth": "auth-2"}
	body["lead_times"] = []int{7}
	rec2 := app.do("POST", "/push/subscribe", body, token)
	require.Equal(t, http.StatusCreated, rec2.Code)
	var sub2 map[string]any
	decodeJSON(t, rec2, &sub2)

	require.Equal(t, sub1["id"], sub2["id"], "повторная подписка того же endpoint должна обновить, а не задублировать строку")
	require.ElementsMatch(t, []any{float64(7)}, sub2["lead_times"])
}

func TestPush_Unsubscribe_Success(t *testing.T) {
	app := newPushTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	app.do("POST", "/push/subscribe", map[string]any{
		"endpoint": "https://push.example.com/x",
		"keys":     map[string]string{"p256dh": "a", "auth": "b"},
	}, token)

	rec := app.do("DELETE", "/push/subscribe", map[string]any{"endpoint": "https://push.example.com/x"}, token)
	require.Equal(t, http.StatusOK, rec.Code)
}

func TestPush_Unsubscribe_NotFound(t *testing.T) {
	app := newPushTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("DELETE", "/push/subscribe", map[string]any{"endpoint": "https://does-not-exist"}, token)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

func TestPush_Unsubscribe_OtherUsersSubscription(t *testing.T) {
	app := newPushTestApp(t)
	tokenA := app.registerUser(t, "a@test.com", "password123")
	tokenB := app.registerUser(t, "b@test.com", "password123")

	app.do("POST", "/push/subscribe", map[string]any{
		"endpoint": "https://push.example.com/x",
		"keys":     map[string]string{"p256dh": "a", "auth": "b"},
	}, tokenA)

	rec := app.do("DELETE", "/push/subscribe", map[string]any{"endpoint": "https://push.example.com/x"}, tokenB)
	require.Equal(t, http.StatusNotFound, rec.Code, "B не должен уметь отписать устройство A")
}

func TestPush_UpdateMe_PushLeadTimes(t *testing.T) {
	app := newPushTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("PATCH", "/auth/me", map[string]any{
		"display_name":    "User",
		"push_lead_times": []int{2, 5},
	}, token)
	require.Equal(t, http.StatusOK, rec.Code, rec.Body.String())

	var resp map[string]any
	decodeJSON(t, rec, &resp)
	require.ElementsMatch(t, []any{float64(2), float64(5)}, resp["push_lead_times"])
}

func TestPush_UpdateMe_InvalidLeadTime(t *testing.T) {
	app := newPushTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("PATCH", "/auth/me", map[string]any{
		"display_name":    "User",
		"push_lead_times": []int{-1},
	}, token)
	require.Equal(t, http.StatusBadRequest, rec.Code)
}
