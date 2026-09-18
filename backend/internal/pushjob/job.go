// Package pushjob — фоновая джоба, раз в сутки шлёт Web Push напоминания
// о скором списании подписок (see BACKEND_SUGGESTIONS.md, п.3).
package pushjob

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"

	"github.com/OctopyApps/SubRadar-BackEnd/internal/config"
	"github.com/OctopyApps/SubRadar-BackEnd/internal/repository"
)

// pushTTL — сколько push-сервис хранит уведомление, если устройство offline.
const pushTTL = 24 * 3600

// Runner — раз в сутки в cfg.PushCheckHour проверяет все подписки на
// приближающееся списание и шлёт Web Push тем, у кого совпал lead time.
type Runner struct {
	cfg  *config.Config
	repo *repository.PushSubscriptionRepository
}

func New(cfg *config.Config, repo *repository.PushSubscriptionRepository) *Runner {
	return &Runner{cfg: cfg, repo: repo}
}

// Start блокирует вызывающую горутину до отмены ctx. Первый запуск —
// в ближайшие cfg.PushCheckHour:00 по времени сервера (сегодня, если этот
// час ещё не наступил, иначе завтра), дальше — раз в 24 часа.
func (j *Runner) Start(ctx context.Context) {
	wait := durationUntilNextRun(time.Now(), j.cfg.PushCheckHour)
	log.Printf("push: следующая проверка напоминаний через %s (в %02d:00)", wait.Round(time.Second), j.cfg.PushCheckHour)

	timer := time.NewTimer(wait)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return
	case <-timer.C:
	}

	j.runOnce()

	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			j.runOnce()
		}
	}
}

// durationUntilNextRun считает, сколько ждать до ближайшего hour:00.
func durationUntilNextRun(now time.Time, hour int) time.Duration {
	next := time.Date(now.Year(), now.Month(), now.Day(), hour, 0, 0, 0, now.Location())
	if !next.After(now) {
		next = next.AddDate(0, 0, 1)
	}
	return next.Sub(now)
}

// runOnce — одна проверка всех подписок. Ошибка одного пуша не должна
// прерывать проверку остальных, поэтому все ошибки только логируются.
func (j *Runner) runOnce() {
	candidates, err := j.repo.ListCandidates()
	if err != nil {
		log.Printf("push: ошибка получения кандидатов: %v", err)
		return
	}

	now := time.Now()
	sent := 0
	for _, c := range candidates {
		daysUntil := int(math.Round(c.NextBillingDate.Sub(now).Hours() / 24))
		if !containsInt(c.LeadTimes, daysUntil) {
			continue
		}

		billingDateKey := c.NextBillingDate.Format("2006-01-02")
		already, err := j.repo.AlreadySent(c.PushSubscriptionID, c.BillingSubscriptionID, daysUntil, billingDateKey)
		if err != nil {
			log.Printf("push: ошибка проверки дублей (subscription=%s): %v", c.BillingSubscriptionID, err)
			continue
		}
		if already {
			continue
		}

		if err := j.send(c, daysUntil); err != nil {
			if isGone(err) {
				if delErr := j.repo.DeleteByEndpoint(c.Endpoint); delErr != nil {
					log.Printf("push: ошибка удаления мёртвой подписки: %v", delErr)
				} else {
					log.Printf("push: подписка %s мёртвая (push-сервис вернул Gone), удалена", c.PushSubscriptionID)
				}
				continue
			}
			log.Printf("push: ошибка отправки (subscription=%s, push=%s): %v", c.BillingSubscriptionID, c.PushSubscriptionID, err)
			continue
		}

		if err := j.repo.MarkSent(c.PushSubscriptionID, c.BillingSubscriptionID, daysUntil, billingDateKey); err != nil {
			log.Printf("push: ошибка записи в журнал отправленных: %v", err)
		}
		sent++
	}

	log.Printf("push: проверка завершена, кандидатов=%d, отправлено=%d", len(candidates), sent)
}

type goneError struct{ statusCode int }

func (e *goneError) Error() string {
	return fmt.Sprintf("push-сервис вернул статус %d", e.statusCode)
}

func isGone(err error) bool {
	ge, ok := err.(*goneError)
	return ok && (ge.statusCode == http.StatusNotFound || ge.statusCode == http.StatusGone)
}

func (j *Runner) send(c repository.PushCandidate, daysUntil int) error {
	payload, err := json.Marshal(map[string]string{
		"title": "Скоро списание",
		"body":  fmt.Sprintf("%s — списание через %d дн.", c.BillingSubscriptionName, daysUntil),
	})
	if err != nil {
		return err
	}

	sub := &webpush.Subscription{
		Endpoint: c.Endpoint,
		Keys:     webpush.Keys{P256dh: c.P256dh, Auth: c.Auth},
	}

	resp, err := webpush.SendNotification(payload, sub, &webpush.Options{
		Subscriber:      j.cfg.VAPIDSubscriber,
		VAPIDPublicKey:  j.cfg.VAPIDPublicKey,
		VAPIDPrivateKey: j.cfg.VAPIDPrivateKey,
		TTL:             pushTTL,
	})
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone {
		return &goneError{statusCode: resp.StatusCode}
	}
	if resp.StatusCode >= 300 {
		return fmt.Errorf("push-сервис вернул статус %d", resp.StatusCode)
	}
	return nil
}

func containsInt(xs []int, v int) bool {
	for _, x := range xs {
		if x == v {
			return true
		}
	}
	return false
}
