CREATE TABLE IF NOT EXISTS users (
id            INTEGER PRIMARY KEY AUTOINCREMENT,
email         TEXT NOT NULL UNIQUE,
password_hash TEXT NOT NULL DEFAULT '',
provider      TEXT NOT NULL DEFAULT 'local', -- local | google | apple
provider_id   TEXT NOT NULL DEFAULT '',      -- sub от Google/Apple
created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS subscriptions (
id                TEXT PRIMARY KEY,           -- UUID
user_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
name              TEXT NOT NULL,
category          TEXT NOT NULL DEFAULT '',
price             REAL NOT NULL DEFAULT 0,
currency          TEXT NOT NULL DEFAULT 'RUB',
billing_period    TEXT NOT NULL DEFAULT 'мес',
color             TEXT NOT NULL DEFAULT '#6C5CE7',
icon_name         TEXT NOT NULL DEFAULT 'creditcard',
start_date        DATETIME NOT NULL,
next_billing_date DATETIME NOT NULL,
tag               TEXT,
url               TEXT,
image_data        BLOB,
created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tags (
id         TEXT PRIMARY KEY,               -- UUID
user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
name       TEXT NOT NULL,
created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags(user_id);