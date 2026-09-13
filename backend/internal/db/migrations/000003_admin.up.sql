-- ============================================================
-- Миграция 000003: поддержка ролей и системных категорий
-- ============================================================

-- ------------------------------------------------------------
-- 1. Расширяем таблицу users
-- ------------------------------------------------------------

ALTER TABLE users ADD COLUMN role         TEXT     NOT NULL DEFAULT 'user';
ALTER TABLE users ADD COLUMN is_blocked   INTEGER  NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN blocked_at   DATETIME;
ALTER TABLE users ADD COLUMN blocked_reason TEXT;
ALTER TABLE users ADD COLUMN display_name TEXT     NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN last_seen_at DATETIME;

-- ------------------------------------------------------------
-- 2. Пересоздаём categories — нужно сделать user_id nullable
--    (системные категории не принадлежат никакому пользователю)
--    SQLite не поддерживает ALTER COLUMN, поэтому: create → copy → drop → rename
-- ------------------------------------------------------------

CREATE TABLE categories_new (
    id         TEXT    PRIMARY KEY,
    user_id    INTEGER REFERENCES users(id) ON DELETE CASCADE, -- NULL для системных
    name       TEXT    NOT NULL,
    icon       TEXT    NOT NULL DEFAULT 'ellipsis.circle',
    is_system  INTEGER NOT NULL DEFAULT 0,                     -- 1 = видна всем пользователям
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
);

INSERT INTO categories_new (id, user_id, name, icon, is_system, created_at)
SELECT                       id, user_id, name, icon, 0,         created_at
FROM categories;

DROP TABLE categories;
ALTER TABLE categories_new RENAME TO categories;

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);