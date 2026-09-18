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

**Токен: тело ответа vs httpOnly cookie.** `/auth/login`, `/auth/register`
и `/auth/self-hosted` всегда возвращают `{"token": "..."}` в теле (это не
меняется — так работает iOS-клиент, храня токен в Keychain), и
дополнительно ставят JWT в httpOnly cookie `subradar_token`. Auth
middleware принимает токен из `Authorization: Bearer` **или** из этой
cookie — клиент может использовать любой вариант.

- Cookie всегда `HttpOnly` — JS не может её прочитать, что и есть смысл
  перехода с `localStorage` (защита от кражи токена через XSS).
- `Secure` управляется `auth.cookie_secure` (дефолт `false`). Включайте
  `true` **только за HTTPS** — браузер не отправит `Secure`-cookie по
  обычному `http://`. Для self-hosted без TLS (например, доступ по
  `http://192.168.1.x:8080`) оставляйте `false`.

**Web Push.** Напоминания о скором списании для веб-клиента (PWA) — у
браузера нет аналога локальных уведомлений iOS, поэтому сервер сам шлёт
push через `pushManager.subscribe()`. Полностью опционален: если
`push.vapid_public_key`/`push.vapid_private_key` не заданы — `/push/*`
не регистрируются и фоновая джоба не запускается.

- Сгенерировать ключи один раз:
  ```go
  privateKey, publicKey, _ := webpush.GenerateVAPIDKeys() // github.com/SherClockHolmes/webpush-go
  ```
- `push.vapid_subscriber` — контакт для push-сервиса, `"mailto:you@example.com"`.
- `push.check_hour` (дефолт `10`) — час (0-23) по времени сервера, когда раз
  в сутки проверяются все подписки на приближающееся списание.
- `users.push_lead_times` (за сколько дней до списания напомнить, дефолт
  `[1]`) меняется через `PATCH /auth/me`; конкретное устройство может
  задать свой override при подписке (`POST /push/subscribe`).
- Дедупликация: одно и то же напоминание (устройство × подписка × день ×
  дата списания) не отправится дважды, даже если джоба перезапустится.
- Подписка, которую push-сервис считает мёртвой (404/410), удаляется
  автоматически при следующей проверке.

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

GET    /push/vapid-public-key  # Публичный, нужен для pushManager.subscribe()
POST   /push/subscribe         # Подписать текущее устройство на Web Push
DELETE /push/subscribe         # Отписать
```

