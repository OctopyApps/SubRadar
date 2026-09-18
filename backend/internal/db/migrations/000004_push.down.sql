-- ============================================================
-- Откат миграции 000004
-- ============================================================

DROP TABLE IF EXISTS push_notifications_sent;
DROP TABLE IF EXISTS push_subscriptions;

-- SQLite не поддерживает DROP COLUMN до версии 3.35.0.
-- Пересоздаём users без push_lead_times.
CREATE TABLE users_old (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    email          TEXT    NOT NULL UNIQUE,
    password_hash  TEXT    NOT NULL DEFAULT '',
    provider       TEXT    NOT NULL DEFAULT 'local',
    provider_id    TEXT    NOT NULL DEFAULT '',
    role           TEXT    NOT NULL DEFAULT 'user',
    is_blocked     INTEGER NOT NULL DEFAULT 0,
    blocked_at     DATETIME,
    blocked_reason TEXT,
    display_name   TEXT    NOT NULL DEFAULT '',
    last_seen_at   DATETIME,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users_old (id, email, password_hash, provider, provider_id, role,
                        is_blocked, blocked_at, blocked_reason, display_name,
                        last_seen_at, created_at)
SELECT                  id, email, password_hash, provider, provider_id, role,
                        is_blocked, blocked_at, blocked_reason, display_name,
                        last_seen_at, created_at
FROM users;

DROP TABLE users;
ALTER TABLE users_old RENAME TO users;
