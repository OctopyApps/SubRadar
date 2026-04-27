CREATE TABLE IF NOT EXISTS categories (
                                          id         TEXT PRIMARY KEY,               -- UUID
                                          user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    icon       TEXT NOT NULL DEFAULT 'ellipsis.circle',  -- SF Symbol
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, name)
    );

CREATE TABLE IF NOT EXISTS currencies (
                                          id           TEXT PRIMARY KEY,             -- UUID
                                          user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code         TEXT NOT NULL,                -- "RUB", "USD", кастомный
    symbol       TEXT NOT NULL,                -- "₽", "$"
    display_name TEXT NOT NULL,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, code)
    );

CREATE INDEX IF NOT EXISTS idx_categories_user_id ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_currencies_user_id ON currencies(user_id);