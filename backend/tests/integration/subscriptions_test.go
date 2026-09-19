package integration

import (
	"net/http"
	"testing"
	"time"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/stretchr/testify/require"
)

func newSubscriptionPayload(name string) map[string]any {
	now := time.Now().UTC().Format(time.RFC3339)
	return map[string]any{
		"name":              name,
		"category":          "video",
		"price":             999.0,
		"currency":          "RUB",
		"billing_period":    "мес",
		"color":             "#6C5CE7",
		"icon_name":         "tv",
		"start_date":        now,
		"next_billing_date": now,
	}
}

func TestSubscriptions_List_EmptyByDefault(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("GET", "/subscriptions", nil, token)
	require.Equal(t, http.StatusOK, rec.Code)

	var subs []models.Subscription
	decodeJSON(t, rec, &subs)
	require.NotNil(t, subs, "должен вернуться [], а не null")
	require.Empty(t, subs)
}

func TestSubscriptions_List_NoToken(t *testing.T) {
	app := newTestApp(t)

	rec := app.do("GET", "/subscriptions", nil, "")
	require.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestSubscriptions_Create_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/subscriptions", newSubscriptionPayload("Netflix"), token)
	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())

	var sub models.Subscription
	decodeJSON(t, rec, &sub)
	require.NotEmpty(t, sub.ID, "сервер должен сгенерировать ID")
	require.Equal(t, "Netflix", sub.Name)
	require.Equal(t, 999.0, sub.Price)

	// Подписка реально появляется в списке.
	listRec := app.do("GET", "/subscriptions", nil, token)
	var subs []models.Subscription
	decodeJSON(t, listRec, &subs)
	require.Len(t, subs, 1)
	require.Equal(t, sub.ID, subs[0].ID)
}

func TestSubscriptions_Create_IgnoresClientSuppliedID(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	payload := newSubscriptionPayload("Netflix")
	payload["id"] = "client-supplied-id"

	rec := app.do("POST", "/subscriptions", payload, token)
	require.Equal(t, http.StatusCreated, rec.Code)

	var sub models.Subscription
	decodeJSON(t, rec, &sub)
	require.NotEqual(t, "client-supplied-id", sub.ID, "сервер должен игнорировать переданный ID")
}

func TestSubscriptions_Create_MissingName(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	payload := newSubscriptionPayload("")
	rec := app.do("POST", "/subscriptions", payload, token)
	require.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestSubscriptions_Create_NoToken(t *testing.T) {
	app := newTestApp(t)

	rec := app.do("POST", "/subscriptions", newSubscriptionPayload("Netflix"), "")
	require.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestSubscriptions_List_IsolatedPerUser(t *testing.T) {
	app := newTestApp(t)
	tokenA := app.registerUser(t, "a@test.com", "password123")
	tokenB := app.registerUser(t, "b@test.com", "password123")

	rec := app.do("POST", "/subscriptions", newSubscriptionPayload("Netflix"), tokenA)
	require.Equal(t, http.StatusCreated, rec.Code)

	// У пользователя B своих подписок нет — чужие не видны.
	listRec := app.do("GET", "/subscriptions", nil, tokenB)
	var subsB []models.Subscription
	decodeJSON(t, listRec, &subsB)
	require.Empty(t, subsB)
}

func TestSubscriptions_Update_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	createRec := app.do("POST", "/subscriptions", newSubscriptionPayload("Netflix"), token)
	var created models.Subscription
	decodeJSON(t, createRec, &created)

	updatePayload := newSubscriptionPayload("Netflix Premium")
	updatePayload["price"] = 1299.0

	updateRec := app.do("PUT", "/subscriptions/"+created.ID, updatePayload, token)
	require.Equal(t, http.StatusOK, updateRec.Code, updateRec.Body.String())

	var updated models.Subscription
	decodeJSON(t, updateRec, &updated)
	require.Equal(t, created.ID, updated.ID)
	require.Equal(t, "Netflix Premium", updated.Name)
	require.Equal(t, 1299.0, updated.Price)
}

func TestSubscriptions_Update_NotFound(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("PUT", "/subscriptions/does-not-exist", newSubscriptionPayload("Netflix"), token)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

func TestSubscriptions_Update_OtherUsersSubscription(t *testing.T) {
	app := newTestApp(t)
	tokenA := app.registerUser(t, "a@test.com", "password123")
	tokenB := app.registerUser(t, "b@test.com", "password123")

	createRec := app.do("POST", "/subscriptions", newSubscriptionPayload("Netflix"), tokenA)
	var created models.Subscription
	decodeJSON(t, createRec, &created)

	// B пытается обновить подписку A — WHERE id=? AND user_id=? не находит
	// строку, должно быть 404, а не 500 и не успешное чужое обновление.
	updateRec := app.do("PUT", "/subscriptions/"+created.ID, newSubscriptionPayload("Hacked"), tokenB)
	require.Equal(t, http.StatusNotFound, updateRec.Code)

	// Подписка A осталась нетронутой.
	listRec := app.do("GET", "/subscriptions", nil, tokenA)
	var subsA []models.Subscription
	decodeJSON(t, listRec, &subsA)
	require.Len(t, subsA, 1)
	require.Equal(t, "Netflix", subsA[0].Name)
}

func TestSubscriptions_Update_NoToken(t *testing.T) {
	app := newTestApp(t)

	rec := app.do("PUT", "/subscriptions/some-id", newSubscriptionPayload("Netflix"), "")
	require.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestSubscriptions_Delete_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	createRec := app.do("POST", "/subscriptions", newSubscriptionPayload("Netflix"), token)
	var created models.Subscription
	decodeJSON(t, createRec, &created)

	deleteRec := app.do("DELETE", "/subscriptions/"+created.ID, nil, token)
	require.Equal(t, http.StatusNoContent, deleteRec.Code)

	listRec := app.do("GET", "/subscriptions", nil, token)
	var subs []models.Subscription
	decodeJSON(t, listRec, &subs)
	require.Empty(t, subs)
}

func TestSubscriptions_Delete_NoToken(t *testing.T) {
	app := newTestApp(t)

	rec := app.do("DELETE", "/subscriptions/some-id", nil, "")
	require.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestSubscriptions_Delete_NotFound(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("DELETE", "/subscriptions/does-not-exist", nil, token)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

func TestSubscriptions_Delete_OtherUsersSubscriptionNotRemoved(t *testing.T) {
	app := newTestApp(t)
	tokenA := app.registerUser(t, "a@test.com", "password123")
	tokenB := app.registerUser(t, "b@test.com", "password123")

	createRec := app.do("POST", "/subscriptions", newSubscriptionPayload("Netflix"), tokenA)
	var created models.Subscription
	decodeJSON(t, createRec, &created)

	// B пытается удалить подписку A — WHERE id=? AND user_id=? не находит
	// строку у B, должно быть 404, а не "успешный" 204 по чужому ID.
	deleteRec := app.do("DELETE", "/subscriptions/"+created.ID, nil, tokenB)
	require.Equal(t, http.StatusNotFound, deleteRec.Code)

	listRec := app.do("GET", "/subscriptions", nil, tokenA)
	var subsA []models.Subscription
	decodeJSON(t, listRec, &subsA)
	require.Len(t, subsA, 1, "подписка A не должна быть удалена запросом от B")
}
