-- ============================================================
-- Откат миграции 000003
-- ============================================================

-- ------------------------------------------------------------
-- 1. Откатываем categories — возвращаем NOT NULL на user_id,
--    убираем is_system
-- ------------------------------------------------------------

CREATE TABLE categories_old (
                                id         TEXT    PRIMARY KEY,
                                user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                                name       TEXT    NOT NULL,
                                icon       TEXT    NOT NULL DEFAULT 'ellipsis.circle',
                                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                                UNIQUE(user_id, name)
);

-- Системные категории (user_id IS NULL) при откате теряются — это ожидаемо
INSERT INTO categories_old (id, user_id, name, icon, created_at)
SELECT                       id, user_id, name, icon, created_at
FROM categories
WHERE user_id IS NOT NULL;

DROP TABLE categories;
ALTER TABLE categories_old RENAME TO categories;

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);

-- ------------------------------------------------------------
-- 2. Откатываем колонки users
--    SQLite не поддерживает DROP COLUMN до версии 3.35.0.
--    Пересоздаём таблицу без новых полей.
-- ------------------------------------------------------------

CREATE TABLE users_old (
                           id            INTEGER PRIMARY KEY AUTOINCREMENT,
                           email         TEXT    NOT NULL UNIQUE,
                           password_hash TEXT    NOT NULL DEFAULT '',
                           provider      TEXT    NOT NULL DEFAULT 'local',
                           provider_id   TEXT    NOT NULL DEFAULT '',
                           created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO users_old (id, email, password_hash, provider, provider_id, created_at)
SELECT                  id, email, password_hash, provider, provider_id, created_at
FROM users;

DROP TABLE users;
ALTER TABLE users_old RENAME TO users;