# SubRadar BackEnd

## Конфигурация

Скопируйте `config.example.yaml` в `config.yaml` и заполните значения
(`config.yaml` не коммитится в git — см. `.gitignore`):

```
cp config.example.yaml config.yaml
```

**Обязательные секреты.** При старте сервер проверяет `auth.jwt_secret`
и (если `auth.self_hosted: true`) `auth.server_secret`:

- `jwt_secret` не может быть равен дефолтному значению-заглушке
  (`change-me-in-production`) и должен быть длиной **не менее 32 символов**.
- если включён `self_hosted`, `server_secret` тоже обязателен и должен
  быть **не короче 32 символов**.

Если условие не выполняется, сервер завершает запуск с `log.Fatal` — это
сделано намеренно, чтобы нельзя было случайно задеплоить бэкенд с
заведомо известным/предсказуемым секретом. Сгенерировать секрет:

```
openssl rand -hex 32
```

Значения можно задать и через переменные окружения
(`SUBRADAR_AUTH_JWT_SECRET`, `SUBRADAR_AUTH_SERVER_SECRET`) вместо
`config.yaml`.

**CORS.** Нужен, только если к бэкенду обращается веб-клиент из браузера
(WebAdmin, будущий PWA) — на мобильные приложения (iOS/Android) CORS не
влияет никак, у них нет заголовка `Origin`.

- `cors.allow_all: true` — разрешить любой origin. Подходит для dev и для
  self-hosted (единственный пользователь на своём сервере — риск ниже).
- `cors.origins: ["https://app.example.com"]` — явный список разрешённых
  origin. Нужен для `shared`-режима на публичном сервере с чужими
  пользователями.
- Если `auth.self_hosted: true`, а `cors.allow_all` не задан явно ни в
  `config.yaml`, ни через `SUBRADAR_CORS_ALLOW_ALL` — сервер по умолчанию
  включает `cors.allow_all` сам (в лог пишется соответствующее сообщение).
  Явно заданное значение (`true` или `false`) всегда имеет приоритет.
- В `shared`-режиме (`self_hosted: false`) дефолт остаётся `false` —
  если нужен веб-клиент, задайте `cors.origins` явно.

## API

```
POST   /auth/register          # Регистрация логин+пароль
POST   /auth/login             # Вход логин+пароль
POST   /auth/google            # Вход через Google (id_token)
POST   /auth/apple             # Вход через Apple (identity_token)
POST   /auth/self-hosted       # Вход по секретному ключу (self-hosted режим)

GET    /subscriptions          # Список подписок
POST   /subscriptions          # Создать
PUT    /subscriptions/:id      # Обновить
DELETE /subscriptions/:id      # Удалить

GET    /tags                   # Список тегов
POST   /tags                   # Создать
DELETE /tags/:id               # Удалить
```

