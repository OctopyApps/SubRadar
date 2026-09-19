-- ============================================================
-- Миграция 000004: Web Push уведомления о скором списании
-- ============================================================

-- Дефолт пользователя: за сколько дней до next_billing_date слать пуш.
-- JSON-массив дней, например "[1,3]".
ALTER TABLE users ADD COLUMN push_lead_times TEXT NOT NULL DEFAULT '[1]';

-- Одна запись — один браузер/устройство, на который подписался юзер
-- через ServiceWorkerRegistration.pushManager.subscribe().
CREATE TABLE IF NOT EXISTS push_subscriptions (
    id         TEXT    PRIMARY KEY,           -- UUID
    user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    endpoint   TEXT    NOT NULL UNIQUE,       -- адрес push-сервиса браузера
    p256dh     TEXT    NOT NULL,
    auth       TEXT    NOT NULL,
    lead_times TEXT,                          -- override дефолта юзера, NULL = использовать push_lead_times
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);

-- Журнал отправленных напоминаний — не даёт фоновой джобе продублировать
-- пуш на следующем тике для того же billing-цикла подписки.
CREATE TABLE IF NOT EXISTS push_notifications_sent (
    push_subscription_id    TEXT    NOT NULL REFERENCES push_subscriptions(id) ON DELETE CASCADE,
    billing_subscription_id TEXT    NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    lead_time_day           INTEGER NOT NULL,
    billing_date            TEXT    NOT NULL,  -- next_billing_date на момент отправки (YYYY-MM-DD)
    sent_at                 DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (push_subscription_id, billing_subscription_id, lead_time_day, billing_date)
);
