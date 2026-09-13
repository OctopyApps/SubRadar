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

