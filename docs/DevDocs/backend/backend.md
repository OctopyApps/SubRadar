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
8. [Тестирование](#8-тестирование)

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

`config.yaml` не коммитится в git — скопируйте шаблон и подставьте свои
значения:

```bash
cp config.example.yaml config.yaml
```

`config.example.yaml` — плейсхолдеры `CHANGE_ME`, реальные секреты
сгенерируйте сами (см. [раздел 3](#3-конфигурация) — там же почему
короткие/дефолтные секреты не проходят валидацию при старте).

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

### Остановка сервера

Сервер обрабатывает `SIGINT`/`SIGTERM` (`Ctrl+C`, `systemctl stop/restart`)
через graceful shutdown: перестаёт принимать новые запросы, ждёт
завершения текущих (до 10с), потом закрывает соединение с БД. HTTP-сервер
также настроен с таймаутами (`ReadHeaderTimeout`, `ReadTimeout`,
`WriteTimeout`, `IdleTimeout`) — защита от зависших/медленных соединений.

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
  cookie_secure: false                          # см. "Токен: cookie" ниже

cors:
  allow_all: false                              # см. "CORS" ниже
  # origins: ["https://app.example.com"]

push:
  # vapid_public_key: "..."                     # см. "Web Push" ниже
  # vapid_private_key: "..."
  # vapid_subscriber: "mailto:you@example.com"
  check_hour: 10
```

### Генерация секретов

```bash
openssl rand -hex 32   # для jwt_secret / server_secret
```

**Обязательная проверка при старте.** Сервер завершает запуск
(`log.Fatal`), если:
- `jwt_secret` равен дефолтному значению-заглушке (`change-me-in-production`)
  или короче 32 символов;
- `self_hosted: true`, а `server_secret` короче 32 символов.

Это намеренно — иначе бэкенд можно случайно задеплоить с заведомо
известным/предсказуемым секретом, и JWT или self-hosted вход можно
подделать/подобрать.

### Переменные окружения (примеры)

```bash
export SUBRADAR_SERVER_PORT=9000
export SUBRADAR_STORAGE_POSTGRES_DSN="postgres://user:pass@localhost:5432/subradar"
export SUBRADAR_AUTH_JWT_SECRET="my-secret"
export SUBRADAR_AUTH_SERVER_SECRET="my-server-secret"
```

### CORS

Нужен, только если к бэкенду обращается веб-клиент из браузера (WebAdmin,
будущий PWA) — на мобильные приложения (iOS/Android) CORS не влияет никак,
у них нет заголовка `Origin`.

- `cors.allow_all: true` — разрешить любой origin. Подходит для dev и для
  self-hosted (единственный пользователь на своём сервере — риск ниже).
- `cors.origins: ["https://app.example.com"]` — явный список разрешённых
  origin. Нужен для централизованного режима на публичном сервере с чужими
  пользователями.
- Если `self_hosted: true`, а `cors.allow_all` не задан явно ни в
  `config.yaml`, ни через `SUBRADAR_CORS_ALLOW_ALL` — сервер по умолчанию
  включает `cors.allow_all` сам (в лог пишется сообщение). Явно заданное
  значение (`true` или `false`) всегда имеет приоритет.
- В централизованном режиме (`self_hosted: false`) дефолт остаётся
  `false` — если нужен веб-клиент, задайте `cors.origins` явно.

### Токен: тело ответа vs httpOnly cookie

`/auth/login`, `/auth/register` и `/auth/self-hosted` всегда возвращают
`{"token": "..."}` в теле (так работает iOS-клиент, храня токен в
Keychain), и дополнительно ставят JWT в httpOnly cookie `subradar_token`.
Auth middleware принимает токен из `Authorization: Bearer` **или** из этой
cookie — веб-клиент может использовать любой вариант вместо
`localStorage`.

- Cookie всегда `HttpOnly` — JS не может её прочитать (защита от кражи
  токена через XSS).
- `Secure` управляется `auth.cookie_secure` (дефолт `false`). Включайте
  `true` **только за HTTPS** — браузер не отправит `Secure`-cookie по
  обычному `http://`. Для self-hosted без TLS оставляйте `false`.

### Rate limit на /auth/*

`/auth/register`, `/auth/login`, `/auth/self-hosted`, `/auth/google`,
`/auth/apple` ограничены `httprate` — 5 попыток в минуту с одного IP,
чтобы усложнить перебор пароля/секрета теперь, когда эти эндпоинты
достижимы из браузера.

### Web Push

Напоминания о скором списании для веб-клиента (PWA) — у браузера нет
аналога локальных уведомлений iOS, поэтому сервер сам шлёт push через
`pushManager.subscribe()`. Полностью опционален: если
`push.vapid_public_key`/`push.vapid_private_key` не заданы — `/push/*` не
регистрируются и фоновая джоба не запускается.

- Сгенерировать ключи один раз:
  ```go
  privateKey, publicKey, _ := webpush.GenerateVAPIDKeys() // github.com/SherClockHolmes/webpush-go
  ```
- `push.vapid_subscriber` — контакт для push-сервиса, `"mailto:you@example.com"`.
- `push.check_hour` (дефолт `10`) — час (0-23) по времени сервера, когда
  раз в сутки проверяются все подписки на приближающееся списание.
- `users.push_lead_times` (за сколько дней до списания напомнить, дефолт
  `[1]`) меняется через `PATCH /auth/me`; конкретное устройство может
  задать свой override при подписке (`POST /push/subscribe`).
- Дедупликация: одно и то же напоминание (устройство × подписка × день ×
  дата списания) не отправится дважды, даже если джоба перезапустится.
- Подписка, которую push-сервис считает мёртвой (404/410), удаляется
  автоматически при следующей проверке.

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
├── role           TEXT           — "user" | "admin"; первый зарегистрированный юзер = admin
├── is_blocked     INTEGER        — 0/1
├── blocked_at     DATETIME
├── blocked_reason TEXT
├── display_name   TEXT
├── last_seen_at   DATETIME       — обновляется асинхронно при каждом запросе с валидным токеном
├── push_lead_times TEXT          — JSON-массив дней (дефолт "[1]"), см. "Web Push" в разделе 3
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

categories                        — пользовательские + системные (is_system = 1, видны всем)
├── id         TEXT PK            — UUID
├── user_id    INTEGER FK → users.id, NULL для системных
├── name       TEXT
├── icon       TEXT               — SF Symbol name
├── is_system  INTEGER            — 0/1; системные создаёт/удаляет только admin (/admin/categories)
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

push_subscriptions                — одна запись = одно устройство/браузер (см. "Web Push" в разделе 3)
├── id         TEXT PK            — UUID
├── user_id    INTEGER FK → users.id
├── endpoint   TEXT UNIQUE        — адрес push-сервиса браузера
├── p256dh     TEXT               — ключ подписки, не отдаётся через API
├── auth       TEXT               — ключ подписки, не отдаётся через API
├── lead_times TEXT               — JSON-массив дней, override users.push_lead_times; NULL = дефолт юзера
└── created_at DATETIME

push_notifications_sent           — журнал отправленных напоминаний (дедуп фоновой джобы)
├── push_subscription_id    TEXT  FK → push_subscriptions.id
├── billing_subscription_id TEXT  FK → subscriptions.id
├── lead_time_day           INTEGER
├── billing_date            TEXT  — next_billing_date на момент отправки (YYYY-MM-DD)
└── sent_at                 DATETIME
   PRIMARY KEY (push_subscription_id, billing_subscription_id, lead_time_day, billing_date)
```

Все таблицы используют `ON DELETE CASCADE` на внешних ключах — при
удалении пользователя (или его подписки/push-подписки) связанные данные
удаляются автоматически.

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

Вместо заголовка можно передать токен через httpOnly cookie `subradar_token`
(её ставит сервер при логине) — см. "Токен: cookie" в разделе 3.
Middleware проверяет оба варианта.

При каждом запросе с валидным токеном middleware дополнительно проверяет
пользователя в БД (актуальный статус блокировки/роль) и обновляет
`last_seen_at` асинхронно.

**Срок жизни токена:** 30 дней. После истечения нужно заново войти.

### Роли и блокировка

Первый зарегистрированный пользователь получает роль `admin` (актуально
для self-hosted — единственный юзер на сервере). Все следующие — `user`.
Роль лежит в JWT-контексте запроса и используется в admin-only
эндпоинтах (`/admin/*`, раздел 6).

Заблокированный (`is_blocked: true`) пользователь получает `403` на любой
защищённый эндпоинт, даже с валидным токеном — блокировка проверяется на
каждый запрос, не только при логине.

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

**Google / Apple (OAuth)**

Роуты `POST /auth/google` и `POST /auth/apple` зарегистрированы, но пока
не реализованы — отвечают `501 Not Implemented`.

### Ошибки авторизации

| HTTP код | Причина |
|---|---|
| 401 | Нет заголовка Authorization/cookie, токен истёк или неверный |
| 403 | Self-hosted режим не включён / аккаунт заблокирован / не admin на `/admin/*` |
| 409 | Email уже зарегистрирован |
| 429 | Rate limit на `/auth/*` (5 запросов в минуту с IP) |
| 501 | `/auth/google`, `/auth/apple` — ещё не реализованы |

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
| POST | `/auth/google` | Заглушка, `501` |
| POST | `/auth/apple` | Заглушка, `501` |
| GET | `/push/vapid-public-key` | Только если настроен Web Push, см. раздел 3 |

`/auth/*` (кроме `/auth/me/*`) ограничены rate limit — 5 запросов в минуту с IP.

### Защищённые (нужен JWT)

#### Профиль

| Метод | Путь | Описание |
|---|---|---|
| GET | `/auth/me` | Публичный профиль текущего пользователя |
| PATCH | `/auth/me` | Обновить `display_name`, опционально `push_lead_times` |
| POST | `/auth/me/change-password` | Сменить пароль (недоступно для self-hosted аккаунта без пароля) |

**Тело запроса PATCH `/auth/me`:**
```json
{ "display_name": "Иван", "push_lead_times": [1, 3] }
```
`push_lead_times` опционален — если не передать поле, значение не
меняется; пустой массив `[]` отключает дефолтные напоминания.

**Тело запроса POST `/auth/me/change-password`:**
```json
{ "old_password": "...", "new_password": "..." }
```

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

#### Admin-only (нужна роль `admin`, иначе `403`)

| Метод | Путь | Описание |
|---|---|---|
| GET | `/admin/stats` | Статистика: всего юзеров/админов/заблокированных, новых за 30 дней |
| GET | `/admin/users` | Список пользователей, `?limit=20&offset=0&role=admin&search=john` (limit ≤ 100) |
| GET | `/admin/users/{id}` | Один пользователь |
| PATCH | `/admin/users/{id}` | Изменить `role`/`is_blocked`/`blocked_reason`/`display_name` |
| DELETE | `/admin/users/{id}` | Удалить пользователя и все его данные |
| GET | `/admin/categories` | Список системных категорий (`is_system: true`, видны всем юзерам) |
| POST | `/admin/categories` | Создать системную категорию |
| DELETE | `/admin/categories/{id}` | Удалить системную категорию |

**Тело запроса PATCH `/admin/users/{id}`** (все поля опциональны, меняется
только то, что передано):
```json
{ "role": "admin", "is_blocked": true, "blocked_reason": "спам", "display_name": "Иван" }
```

**Тело запроса POST `/admin/categories`:**
```json
{ "name": "Игры", "icon": "gamecontroller" }
```

#### Web Push (опционально, см. "Web Push" в разделе 3)

| Метод | Путь | Описание |
|---|---|---|
| GET | `/push/vapid-public-key` | Публичный, нужен для `pushManager.subscribe()` |
| POST | `/push/subscribe` | Подписать текущее устройство на Web Push |
| DELETE | `/push/subscribe` | Отписать |

**Тело запроса POST `/push/subscribe`:**
```json
{
  "endpoint": "https://fcm.googleapis.com/...",
  "keys": { "p256dh": "...", "auth": "..." },
  "lead_times": [1, 3]
}
```
`lead_times` опционален — override дефолта пользователя (`push_lead_times`
из `/auth/me`) для этого конкретного устройства.

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
│   │   ├── jwt.go              — генерация JWT + httpOnly cookie токена
│   │   ├── middleware.go       — HTTP middleware: токен (заголовок или cookie), user_id/role в контекст
│   │   ├── admin_middleware.go — HTTP middleware: доступ только для role=admin
│   │   └── local.go            — bcrypt хэширование паролей
│   ├── models/                 — Go структуры (User, Subscription, Tag, Category, Currency, PushSubscription)
│   ├── repository/             — работа с БД (SQL запросы)
│   ├── handlers/               — HTTP хендлеры (декодирование запроса → репозиторий → ответ)
│   ├── pushjob/                — фоновая джоба Web Push (раз в сутки, см. "Web Push" в разделе 3)
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

---

## 8. Тестирование

Запуск всех тестов (юнит + интеграционные), из `backend/`:

```bash
tests/RUN_ALL.sh
```

Прогоняет `gofmt`, `go vet` и `go test` по всем зарегистрированным
директориям с тестами. Тот же скрипт гоняется в CI на каждый PR в `main`
и `dev`, затрагивающий `backend/**` (`.github/workflows/backend-tests.yml`).

**При добавлении нового кода — тесты обязательны:**

- Юнит-тесты для пакета кладите рядом с кодом: `internal/<pkg>/*_test.go`
  (доступ к неэкспортированным функциям — используйте для чистой логики
  без сайд-эффектов, см. `internal/config/config_test.go`).
- Интеграционные (через HTTP, поднимают реальный роутер + SQLite) — в
  `tests/integration/*_test.go`.
- **Новую директорию** с тестами (новый `internal/<pkg>`, новую
  поддиректорию в `tests/`) нужно вручную добавить в `TEST_PATHS` в
  `tests/RUN_ALL.sh` — иначе сам скрипт откажется работать с понятной
  ошибкой на шаге проверки регистрации. Просто новый `*_test.go` в уже
  зарегистрированной директории добавлять никуда не нужно, подхватится
  сам.
