package integration

import (
	"net/http"
	"testing"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/stretchr/testify/require"
)

// ── Tags ────────────────────────────────────────────────────────────────────

func TestTags_List_EmptyByDefault(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("GET", "/tags", nil, token)
	require.Equal(t, http.StatusOK, rec.Code)

	var tags []models.Tag
	decodeJSON(t, rec, &tags)
	require.NotNil(t, tags)
	require.Empty(t, tags)
}

func TestTags_List_NoToken(t *testing.T) {
	app := newTestApp(t)
	rec := app.do("GET", "/tags", nil, "")
	require.Equal(t, http.StatusUnauthorized, rec.Code)
}

func TestTags_Create_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/tags", map[string]string{"name": "стрим"}, token)
	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())

	var tag models.Tag
	decodeJSON(t, rec, &tag)
	require.NotEmpty(t, tag.ID)
	require.Equal(t, "стрим", tag.Name)
}

func TestTags_Create_MissingName(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/tags", map[string]string{"name": ""}, token)
	require.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestTags_Create_Idempotent(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec1 := app.do("POST", "/tags", map[string]string{"name": "стрим"}, token)
	var tag1 models.Tag
	decodeJSON(t, rec1, &tag1)

	rec2 := app.do("POST", "/tags", map[string]string{"name": "стрим"}, token)
	var tag2 models.Tag
	decodeJSON(t, rec2, &tag2)

	require.Equal(t, tag1.ID, tag2.ID, "повторное создание тега с тем же именем должно вернуть существующий")
}

func TestTags_Delete_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	createRec := app.do("POST", "/tags", map[string]string{"name": "стрим"}, token)
	var tag models.Tag
	decodeJSON(t, createRec, &tag)

	rec := app.do("DELETE", "/tags/"+tag.ID, nil, token)
	require.Equal(t, http.StatusNoContent, rec.Code)
}

func TestTags_Delete_NotFound(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("DELETE", "/tags/does-not-exist", nil, token)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

func TestTags_Delete_OtherUsersTag(t *testing.T) {
	app := newTestApp(t)
	tokenA := app.registerUser(t, "a@test.com", "password123")
	tokenB := app.registerUser(t, "b@test.com", "password123")

	createRec := app.do("POST", "/tags", map[string]string{"name": "стрим"}, tokenA)
	var tag models.Tag
	decodeJSON(t, createRec, &tag)

	rec := app.do("DELETE", "/tags/"+tag.ID, nil, tokenB)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

// ── Categories ──────────────────────────────────────────────────────────────

func TestCategories_Create_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/categories", map[string]string{"name": "Стриминг", "icon": "tv"}, token)
	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())

	var cat models.Category
	decodeJSON(t, rec, &cat)
	require.NotEmpty(t, cat.ID)
	require.Equal(t, "Стриминг", cat.Name)
	require.False(t, cat.IsSystem)
}

func TestCategories_Create_DefaultIcon(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/categories", map[string]string{"name": "Стриминг"}, token)
	require.Equal(t, http.StatusCreated, rec.Code)

	var cat models.Category
	decodeJSON(t, rec, &cat)
	require.Equal(t, "ellipsis.circle", cat.Icon)
}

func TestCategories_Create_MissingName(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/categories", map[string]string{"name": ""}, token)
	require.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestCategories_Delete_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	createRec := app.do("POST", "/categories", map[string]string{"name": "Стриминг"}, token)
	var cat models.Category
	decodeJSON(t, createRec, &cat)

	rec := app.do("DELETE", "/categories/"+cat.ID, nil, token)
	require.Equal(t, http.StatusNoContent, rec.Code)
}

func TestCategories_Delete_NotFound(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("DELETE", "/categories/does-not-exist", nil, token)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

func TestCategories_Delete_OtherUsersCategory(t *testing.T) {
	app := newTestApp(t)
	tokenA := app.registerUser(t, "a@test.com", "password123")
	tokenB := app.registerUser(t, "b@test.com", "password123")

	createRec := app.do("POST", "/categories", map[string]string{"name": "Стриминг"}, tokenA)
	var cat models.Category
	decodeJSON(t, createRec, &cat)

	rec := app.do("DELETE", "/categories/"+cat.ID, nil, tokenB)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

// ── Currencies ──────────────────────────────────────────────────────────────

func TestCurrencies_Create_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/currencies", map[string]string{"code": "USD", "symbol": "$"}, token)
	require.Equal(t, http.StatusCreated, rec.Code, rec.Body.String())

	var cur models.Currency
	decodeJSON(t, rec, &cur)
	require.NotEmpty(t, cur.ID)
	require.Equal(t, "USD", cur.Code)
	require.Equal(t, "USD", cur.DisplayName, "display_name по умолчанию = code")
}

func TestCurrencies_Create_MissingFields(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("POST", "/currencies", map[string]string{"code": "USD"}, token)
	require.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestCurrencies_Delete_Success(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	createRec := app.do("POST", "/currencies", map[string]string{"code": "USD", "symbol": "$"}, token)
	var cur models.Currency
	decodeJSON(t, createRec, &cur)

	rec := app.do("DELETE", "/currencies/"+cur.ID, nil, token)
	require.Equal(t, http.StatusNoContent, rec.Code)
}

func TestCurrencies_Delete_NotFound(t *testing.T) {
	app := newTestApp(t)
	token := app.registerUser(t, "user@test.com", "password123")

	rec := app.do("DELETE", "/currencies/does-not-exist", nil, token)
	require.Equal(t, http.StatusNotFound, rec.Code)
}

func TestCurrencies_Delete_OtherUsersCurrency(t *testing.T) {
	app := newTestApp(t)
	tokenA := app.registerUser(t, "a@test.com", "password123")
	tokenB := app.registerUser(t, "b@test.com", "password123")

	createRec := app.do("POST", "/currencies", map[string]string{"code": "USD", "symbol": "$"}, tokenA)
	var cur models.Currency
	decodeJSON(t, createRec, &cur)

	rec := app.do("DELETE", "/currencies/"+cur.ID, nil, tokenB)
	require.Equal(t, http.StatusNotFound, rec.Code)
}
