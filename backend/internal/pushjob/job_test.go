package pushjob

import (
	"crypto/elliptic"
	"crypto/rand"
	"encoding/base64"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"
	"github.com/stretchr/testify/require"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/db"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/models"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
)

func TestDurationUntilNextRun(t *testing.T) {
	loc := time.UTC

	// Сейчас 09:00, час проверки — 10:00 -> сегодня, через 1 час.
	now := time.Date(2026, 1, 1, 9, 0, 0, 0, loc)
	require.Equal(t, time.Hour, durationUntilNextRun(now, 10))

	// Ровно 10:00 -> "уже наступило", следующий запуск завтра.
	now2 := time.Date(2026, 1, 1, 10, 0, 0, 0, loc)
	require.Equal(t, 24*time.Hour, durationUntilNextRun(now2, 10))

	// 11:00, час проверки прошёл -> завтра.
	now3 := time.Date(2026, 1, 1, 11, 0, 0, 0, loc)
	require.Equal(t, 23*time.Hour, durationUntilNextRun(now3, 10))
}

func TestContainsInt(t *testing.T) {
	require.True(t, containsInt([]int{1, 3, 7}, 3))
	require.False(t, containsInt([]int{1, 3, 7}, 2))
	require.False(t, containsInt(nil, 1))
}

func TestIsGone(t *testing.T) {
	require.True(t, isGone(&goneError{statusCode: http.StatusNotFound}))
	require.True(t, isGone(&goneError{statusCode: http.StatusGone}))
	require.False(t, isGone(&goneError{statusCode: http.StatusInternalServerError}))
	require.False(t, isGone(nil))
}

// fakeSubscriptionKeys генерирует валидную (для webpush-go) пару p256dh/auth —
// p256dh должен быть настоящей точкой на кривой P256, иначе SendNotification
// падает на этапе шифрования, не дойдя до HTTP.
func fakeSubscriptionKeys(t *testing.T) (p256dh, auth string) {
	t.Helper()
	curve := elliptic.P256()
	_, x, y, err := elliptic.GenerateKey(curve, rand.Reader)
	require.NoError(t, err)
	pub := elliptic.Marshal(curve, x, y)

	authBytes := make([]byte, 16)
	_, err = rand.Read(authBytes)
	require.NoError(t, err)

	return base64.RawURLEncoding.EncodeToString(pub), base64.RawURLEncoding.EncodeToString(authBytes)
}

// TestRunOnce_SendsMatchesDedupsAndCleansUpGone — сквозная проверка через
// реальное шифрование webpush-go против фейкового push-сервиса: первый
// запрос -> успех + запись в журнал, второй -> 410 Gone -> подписка
// удаляется, повторный runOnce не шлёт дубликат.
func TestRunOnce_SendsMatchesDedupsAndCleansUpGone(t *testing.T) {
	privKey, pubKey, err := webpush.GenerateVAPIDKeys()
	require.NoError(t, err)

	callCount := 0
	pushSvc := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		callCount++
		if callCount == 1 {
			w.WriteHeader(http.StatusCreated)
			return
		}
		w.WriteHeader(http.StatusGone)
	}))
	defer pushSvc.Close()

	conn, err := db.Connect("sqlite", ":memory:")
	require.NoError(t, err)
	t.Cleanup(func() { conn.Close() })

	users := repository.NewUserRepository(conn)
	subs := repository.NewSubscriptionRepository(conn)
	pushRepo := repository.NewPushSubscriptionRepository(conn)

	uid, err := users.Create("sanity@test.local", "hash", models.AuthProviderLocal, "")
	require.NoError(t, err)
	require.NoError(t, users.SetPushLeadTimes(uid, []int{1}))

	subID := "22222222-2222-2222-2222-222222222222"
	require.NoError(t, subs.Create(&models.Subscription{
		ID: subID, UserID: uid, Name: "Netflix", Category: "video",
		Price: 999, Currency: "RUB", BillingPeriod: "мес",
		Color: "#000", IconName: "tv",
		StartDate:       models.RFC3339Seconds(time.Now()),
		NextBillingDate: models.RFC3339Seconds(time.Now().AddDate(0, 0, 1)), // daysUntil == 1
	}))

	p256dh1, auth1 := fakeSubscriptionKeys(t)
	p256dh2, auth2 := fakeSubscriptionKeys(t)
	_, err = pushRepo.Upsert(uid, pushSvc.URL+"/ep1", p256dh1, auth1, nil)
	require.NoError(t, err)
	_, err = pushRepo.Upsert(uid, pushSvc.URL+"/ep2", p256dh2, auth2, nil)
	require.NoError(t, err)

	cfg := &config.Config{
		VAPIDPublicKey: pubKey, VAPIDPrivateKey: privKey, VAPIDSubscriber: "mailto:test@example.com",
	}
	runner := New(cfg, pushRepo)
	runner.runOnce()

	require.Equal(t, 2, callCount, "оба candidate должны получить попытку отправки")

	candidates, err := pushRepo.ListCandidates()
	require.NoError(t, err)
	require.Len(t, candidates, 1, "вторая подписка должна быть удалена после Gone")
	survivor := candidates[0]

	billingDateKey := time.Now().AddDate(0, 0, 1).Format("2006-01-02")
	sent, err := pushRepo.AlreadySent(survivor.PushSubscriptionID, subID, 1, billingDateKey)
	require.NoError(t, err)
	require.True(t, sent, "выживший candidate должен быть отмечен как отправленный")

	callsBefore := callCount
	runner.runOnce()
	require.Equal(t, callsBefore, callCount, "повторный runOnce не должен слать дубликат (дедуп)")
}

func TestRunOnce_NoMatchingLeadTime_NoSend(t *testing.T) {
	privKey, pubKey, err := webpush.GenerateVAPIDKeys()
	require.NoError(t, err)

	callCount := 0
	pushSvc := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		callCount++
		w.WriteHeader(http.StatusCreated)
	}))
	defer pushSvc.Close()

	conn, err := db.Connect("sqlite", ":memory:")
	require.NoError(t, err)
	t.Cleanup(func() { conn.Close() })

	users := repository.NewUserRepository(conn)
	subs := repository.NewSubscriptionRepository(conn)
	pushRepo := repository.NewPushSubscriptionRepository(conn)

	uid, err := users.Create("sanity2@test.local", "hash", models.AuthProviderLocal, "")
	require.NoError(t, err)
	// Дефолт юзера [1], но списание через 10 дней -> не совпадает.
	require.NoError(t, subs.Create(&models.Subscription{
		ID: "33333333-3333-3333-3333-333333333333", UserID: uid, Name: "Netflix",
		Price: 999, Currency: "RUB", BillingPeriod: "мес", Color: "#000", IconName: "tv",
		StartDate:       models.RFC3339Seconds(time.Now()),
		NextBillingDate: models.RFC3339Seconds(time.Now().AddDate(0, 0, 10)),
	}))

	p256dh, auth := fakeSubscriptionKeys(t)
	_, err = pushRepo.Upsert(uid, pushSvc.URL+"/ep", p256dh, auth, nil)
	require.NoError(t, err)

	cfg := &config.Config{VAPIDPublicKey: pubKey, VAPIDPrivateKey: privKey, VAPIDSubscriber: "mailto:test@example.com"}
	New(cfg, pushRepo).runOnce()

	require.Equal(t, 0, callCount, "не должно быть отправок, когда день не совпадает с lead_times")
}
