# SubRadar Backend — Документация

> Полное описание архитектуры, конфигурации и API бэкенда SubRadar.

---

## Содержание

1. [Обзор](#1-обзор)
2. [Как запустить локально](#2-как-запустить-локально)
3. [Конфигурация](#3-конфигурация)
4. [База данных и миграции](#4-база-данных-и-миграции)
5. [Авторизация](#5-авторизация)
6. [API — эндпоинты](#6-api--эндпоинты)
7. [Архитектура кода](#7-архитектура-кода)

---

## 1. Обзор

SubRadar Backend — REST API сервер написанный на Go. Хранит подписки, теги, категории и валюты пользователей. Поддерживает несколько пользователей — каждый видит только свои данные.

**Стек:**
- Go + Chi router
- SQLite (по умолчанию) или PostgreSQL
- JWT авторизация (HS256, срок жизни токена 30 дней)
- golang-migrate для миграций (применяются автоматически при старте)

**Три режима работы:**

| Режим | Описание |
|---|---|
| Self-hosted | Пользователь разворачивает на своём сервере, вход по секретному ключу |
| Централизованный | Общий сервер SubRadar, вход по email/паролю |
| Локальный | Бэкенд не нужен, данные хранятся на устройстве |

---

## 2. Как запустить локально

### Из исходников

```bash
git clone https://github.com/OctopyApps/SubRadar.git
cd SubRadar/backend

go mod download
go build -o subradar ./cmd/server

./subradar --config=config.yaml
```

### Минимальный config.yaml для разработки

```yaml
server:
  port: 8080

storage:
  driver: sqlite
  sqlite:
    path: ./subradar.db

auth:
  jwt_secret: "dev-secret-change-in-production"
  self_hosted: true
  server_secret: "1234"
```

Запуск:
```bash
./subradar --config=config.yaml
```

Проверка что сервер работает:
```bash
curl http://localhost:8080/health
# {"status":"ok"}
```

### Флаги командной строки

| Флаг | Описание |
|---|---|
| `--config=/path/to/config.yaml` | Путь к файлу конфигурации |
| `--version` | Вывести версию и выйти |

---

## 3. Конфигурация

Конфиг читается из `config.yaml`. Все параметры можно переопределить через переменные окружения с префиксом `SUBRADAR_` — это удобно для продакшена чтобы не хранить секреты в файле.

### Полный config.yaml

```yaml
server:
  port: 8080                    # Порт сервера (env: SUBRADAR_SERVER_PORT)

storage:
  driver: sqlite                # "sqlite" или "postgres" (env: SUBRADAR_STORAGE_DRIVER)

  sqlite:
    path: /var/lib/subradar/subradar.db   # Путь к файлу БД

  postgres:
    dsn: ""                     # postgres://user:password@host:5432/dbname?sslmode=disable
                                # (env: SUBRADAR_STORAGE_POSTGRES_DSN)

auth:
  jwt_secret: "замените-на-случайную-строку"   # Секрет для подписи JWT токенов
  self_hosted: true                             # Включить self-hosted режим
  server_secret: "замените-на-случайную-строку" # Секрет для входа в self-hosted режиме
```

### Генерация секретов

```bash
openssl rand -hex 32   # для jwt_secret
openssl rand -hex 24   # для server_secret
```

### Переменные окружения (примеры)

```bash
export SUBRADAR_SERVER_PORT=9000
export SUBRADAR_STORAGE_POSTGRES_DSN="postgres://user:pass@localhost:5432/subradar"
export SUBRADAR_AUTH_JWT_SECRET="my-secret"
export SUBRADAR_AUTH_SERVER_SECRET="my-server-secret"
```

---

## 4. База данных и миграции

Миграции применяются **автоматически при каждом старте сервера** — вручную ничего делать не нужно. Используется библиотека `golang-migrate`, файлы миграций встроены в бинарник через `embed.FS`.

### Схема базы данных

```
users
├── id             INTEGER PK AUTOINCREMENT
├── email          TEXT UNIQUE
├── password_hash  TEXT           — bcrypt хэш, пустой для self-hosted
├── provider       TEXT           — "local" | "google" | "apple"
├── provider_id    TEXT           — sub от Google/Apple OAuth
└── created_at     DATETIME

subscriptions
├── id                TEXT PK     — UUID
├── user_id           INTEGER FK → users.id
├── name              TEXT
├── category          TEXT        — название категории
├── price             REAL
├── currency          TEXT        — код валюты ("RUB", "USD")
├── billing_period    TEXT        — "мес" | "год" | "день"
├── color             TEXT        — hex цвет иконки
├── icon_name         TEXT        — SF Symbol name
├── start_date        DATETIME
├── next_billing_date DATETIME
├── tag               TEXT
├── url               TEXT
├── image_data        BLOB        — логотип в бинарном виде
├── created_at        DATETIME
└── updated_at        DATETIME

tags
├── id         TEXT PK            — UUID
├── user_id    INTEGER FK → users.id
├── name       TEXT
└── created_at DATETIME
   UNIQUE(user_id, name)

categories                        — только пользовательские (дефолты захардкожены на клиенте)
├── id         TEXT PK            — UUID
├── user_id    INTEGER FK → users.id
├── name       TEXT
├── icon       TEXT               — SF Symbol name
└── created_at DATETIME
   UNIQUE(user_id, name)

currencies                        — только пользовательские (дефолты захардкожены на клиенте)
├── id           TEXT PK          — UUID
├── user_id      INTEGER FK → users.id
├── code         TEXT             — "RUB", "USD", кастомный
├── symbol       TEXT             — "₽", "$"
├── display_name TEXT
└── created_at   DATETIME
   UNIQUE(user_id, code)
```

Все таблицы используют `ON DELETE CASCADE` — при удалении пользователя все его данные удаляются автоматически.

### SQLite vs PostgreSQL

| | SQLite | PostgreSQL |
|---|---|---|
| Когда использовать | Self-hosted, один пользователь | Централизованный сервер, много пользователей |
| Настройка | Только путь к файлу | DSN строка подключения |
| Особенности | WAL режим, один writer | Полноценный RDBMS |

---

## 5. Авторизация

Все защищённые эндпоинты требуют заголовок:
```
Authorization: Bearer <jwt_token>
```

Токен содержит `user_id` — по нему все запросы фильтруются автоматически в middleware. Пользователь физически не может получить данные другого пользователя.

**Срок жизни токена:** 30 дней. После истечения нужно заново войти.

### Режимы входа

**Self-hosted (вход по секретному ключу)**

Используется когда `auth.self_hosted: true` в конфиге. При первом входе автоматически создаётся единственный пользователь `admin@self-hosted.local`. Все последующие входы возвращают токен этого же пользователя.

```bash
curl -X POST http://localhost:8080/auth/self-hosted \
  -H "Content-Type: application/json" \
  -d '{"secret": "ваш_server_secret"}'

# {"token": "eyJ..."}
```

**Email/пароль (централизованный сервер)**

Регистрация создаёт нового пользователя и сразу возвращает токен — повторный вход не нужен. Пароль минимум 8 символов, хранится как bcrypt хэш.

```bash
# Регистрация
curl -X POST http://localhost:8080/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "mypassword"}'

# Вход
curl -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "mypassword"}'
```

### Ошибки авторизации

| HTTP код | Причина |
|---|---|
| 401 | Нет заголовка Authorization, токен истёк или неверный |
| 403 | Self-hosted режим не включён в конфиге |
| 409 | Email уже зарегистрирован |

---

## 6. API — эндпоинты

Все ответы в формате JSON. Даты в формате ISO 8601.

### Публичные (без токена)

| Метод | Путь | Описание |
|---|---|---|
| GET | `/health` | Проверка что сервер работает |
| POST | `/auth/register` | Регистрация по email/паролю |
| POST | `/auth/login` | Вход по email/паролю |
| POST | `/auth/self-hosted` | Вход по секретному ключу |

### Защищённые (нужен JWT)

#### Подписки

| Метод | Путь | Описание |
|---|---|---|
| GET | `/subscriptions` | Список всех подписок пользователя |
| POST | `/subscriptions` | Создать подписку |
| PUT | `/subscriptions/{id}` | Обновить подписку |
| DELETE | `/subscriptions/{id}` | Удалить подписку |

**Тело запроса POST/PUT `/subscriptions`:**
```json
{
  "name": "Netflix",
  "category": "Развлечения",
  "price": 999.0,
  "currency": "RUB",
  "billing_period": "мес",
  "color": "#E50914",
  "icon_name": "play.circle",
  "start_date": "2024-01-01T00:00:00Z",
  "next_billing_date": "2025-06-01T00:00:00Z",
  "tag": "семья",
  "url": "https://netflix.com",
  "image_data": null
}
```

#### Теги

| Метод | Путь | Описание |
|---|---|---|
| GET | `/tags` | Список всех тегов пользователя |
| POST | `/tags` | Создать тег (идемпотентно по имени) |
| DELETE | `/tags/{id}` | Удалить тег |

**Тело запроса POST `/tags`:**
```json
{ "name": "семья" }
```

#### Категории

| Метод | Путь | Описание |
|---|---|---|
| GET | `/categories` | Пользовательские категории |
| POST | `/categories` | Создать категорию (идемпотентно по имени) |
| DELETE | `/categories/{id}` | Удалить категорию |

**Тело запроса POST `/categories`:**
```json
{ "name": "Игры", "icon": "gamecontroller" }
```

#### Валюты

| Метод | Путь | Описание |
|---|---|---|
| GET | `/currencies` | Пользовательские валюты |
| POST | `/currencies` | Создать валюту (идемпотентно по коду) |
| DELETE | `/currencies/{id}` | Удалить валюту |

**Тело запроса POST `/currencies`:**
```json
{ "code": "JPY", "symbol": "¥", "display_name": "Иена" }
```

### Формат ошибок

Все ошибки возвращаются в едином формате:
```json
{ "error": "описание ошибки" }
```

---

## 7. Архитектура кода

```
backend/
├── cmd/server/main.go          — точка входа: флаги, конфиг, БД, роутер, запуск
├── internal/
│   ├── config/config.go        — загрузка конфига из yaml + env (Viper)
│   ├── db/
│   │   ├── db.go               — подключение к БД + автоматические миграции
│   │   └── migrations/         — SQL файлы миграций (встроены в бинарник)
│   ├── auth/
│   │   ├── jwt.go              — генерация и парсинг JWT токенов
│   │   ├── middleware.go       — HTTP middleware: проверка токена, user_id в контекст
│   │   └── local.go            — bcrypt хэширование паролей
│   ├── models/                 — Go структуры (User, Subscription, Tag, Category, Currency)
│   ├── repository/             — работа с БД (SQL запросы)
│   ├── handlers/               — HTTP хендлеры (декодирование запроса → репозиторий → ответ)
│   └── server/router.go        — Chi роутер: регистрация всех маршрутов и middleware
```

**Поток запроса:**
```
HTTP запрос
  → Chi Router
  → Middleware (Logger, RealIP, Recoverer, Content-Type)
  → [Auth Middleware — если защищённый маршрут]
  → Handler (декодирует тело, валидирует)
  → Repository (SQL запрос с user_id)
  → JSON ответ
```

**Принцип изоляции данных:** `user_id` извлекается из JWT в middleware и кладётся в контекст запроса. Каждый репозиторный метод принимает `userID int64` и добавляет `WHERE user_id = ?` к каждому запросу — пользователь физически не может получить чужие данные даже при прямых запросах к API.
