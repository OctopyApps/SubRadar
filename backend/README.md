# SubRadar BackEnd

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

