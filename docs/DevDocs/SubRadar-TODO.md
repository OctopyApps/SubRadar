# SubRadar — Code Review & Roadmap

> Документ фиксирует технический долг, баги и приоритетные фичи по результатам ревью кода.
> Идём сверху вниз, закрываем по одному.

---

## 🔴 Критические проблемы

### 1. `BillingPeriod.rawValue` — строки на русском языке
- **Файл:** `ios/SubRadar/Core/Models/SubscriptionFields/Subscription.swift`
- **Проблема:** `BillingPeriod` хранит `"мес"`, `"год"`, `"день"` как rawValue — это ключи для сериализации в БД и по API. При добавлении локализации или второго языка это сломает всё хранилище и потребует миграцию данных.
- **Решение:** Сменить rawValue на `"monthly"`, `"yearly"`, `"daily"`. Локализованный текст для UI держать отдельно в `var title: String`.
- **Затронутые места:** SwiftData (поле `billingPeriod`), бэкенд БД (поле `billing_period`), API-контракт. Нужна миграция `000003_billing_period_en.up.sql`.
- [ ] Готово

---

### 2. Нет обработки истечения JWT на клиенте
- **Файл:** `ios/SubRadar/Core/Storage/APIClient.swift`, `RemoteStorageService.swift`
- **Проблема:** При 401 от сервера `APIClient` бросает `.serverError(statusCode: 401, ...)`, это маппится в `StorageError.saveFailed` и пользователь видит невнятное «Не удалось сохранить». Реальная причина — истёк токен.
- **Решение:**
  1. Добавить `case unauthorized` в `APIError`
  2. В `validateResponse` отдельно обрабатывать 401 → `throw APIError.unauthorized`
  3. В `APIError.toStorageError()` маппить в `StorageError.unauthorized`
  4. Добавить `case unauthorized` в `StorageError`
  5. В `SubscriptionsViewModel` при `.unauthorized` → `appState.logout()` → переход на онбординг/авторизацию
- [ ] Готово

---

### 3. `image_data` передаётся через JSON как base64
- **Файлы:** `backend/internal/handlers/subscriptions.go`, `ios/Core/Storage/RemoteStorageService.swift`
- **Проблема:** Логотипы подписок (50–200 KB) едут в теле каждого `GET /subscriptions` в виде base64 внутри JSON. При 20 подписках — это до 4 MB на каждый запрос.
- **Решение:**
  1. Добавить эндпоинт `PUT /subscriptions/{id}/image` (multipart/form-data)
  2. В основном ответе `GET /subscriptions` убрать `image_data`, добавить `has_image: bool`
  3. Клиент загружает картинку отдельным запросом и кэширует локально
- **Приоритет:** Можно отложить до появления реальных пользователей, но API-контракт стоит заложить сейчас.
- [ ] Готово

---

### 4. `destroyStore` в `LocalStorageService` без бэкапа
- **Файл:** `ios/SubRadar/Core/Storage/LocalStorageService.swift`
- **Проблема:** Если SwiftData падает при инициализации, `destroyStore` тихо удаляет всю базу пользователя без предупреждения. После `fatalError` в релизе это крэш без шанса восстановления.
- **Решение:**
  1. Перед `destroyStore` сделать копию файла `.db` в `Documents/` с суффиксом `-backup-{timestamp}`
  2. Показать пользователю алерт о том что данные были сброшены
  3. В идеале — залогировать в аналитику (даже просто `print` лучше чем молчание)
- [ ] Готово

---

## 🟡 Технический долг (рефакторинг)

### 5. `APIError.toStorageError()` теряет семантику ошибок
- **Файл:** `ios/SubRadar/Core/Storage/APIClient.swift`
- **Проблема:** 401, 403, 404 — все падают в `saveFailed`. ViewModel не может отличить «не найдено» от «нет прав» от «нет сети».
- **Решение:** Расширить `StorageError` кейсами `unauthorized`, `forbidden`, `notFound`, `serverError(code: Int)` и маппить точно в `toStorageError()`.
- [ ] Готово

---

### 6. `Delete` в репозиториях не различает «нет записи» и «ошибка БД»
- **Файлы:** `backend/internal/repository/subscription_repo.go`, `tag_repo.go`, `category_repo.go`, `currency_repo.go`
- **Проблема:** Если запись не найдена — `RowsAffected = 0`, ошибки нет, клиент получает 204 вместо 404.
- **Решение:** Добавить проверку `RowsAffected` как уже сделано в `Update`:
  ```go
  if rows, _ := result.RowsAffected(); rows == 0 {
      return ErrNotFound
  }
  ```
  В хендлере вернуть 404 при `ErrNotFound`.
- [ ] Готово

---

### 7. Анонимные struct в `RemoteStorageService`
- **Файл:** `ios/SubRadar/Core/Storage/RemoteStorageService.swift`
- **Проблема:** `struct { let name: String; let icon: String }` объявляются прямо внутри методов. Неконсистентно с `SubscriptionRequest`, сложнее тестировать и переиспользовать.
- **Решение:** Вынести в именованные `private struct CategoryRequest`, `CurrencyRequest`, `TagRequest` в конце файла — аналогично `SubscriptionRequest`.
- [ ] Готово

---

### 8. `LocalStorageService` зависит от `AppState` напрямую
- **Файл:** `ios/SubRadar/Core/Storage/LocalStorageService.swift`
- **Проблема:** Storage слой знает про `AppState` — нарушение разделения ответственности. `weak var appState: AppState?` — Storage не должен держать ссылку на глобальное состояние приложения.
- **Решение:** Вынести категории и валюты из `AppState` в отдельный `UserPreferencesService` (протокол), инжектировать его в `LocalStorageService`. `AppState` подписывается на изменения через Combine или колбэк.
- [ ] Готово

---

## 🟢 Новые фичи

### 9. Обновление `nextBillingDate` после списания
- **Проблема:** `nextBillingDate` фиксирована навсегда. Через месяц все даты пользователя устаревают.
- **Решение:**
  - Кнопка «Отметить как оплаченное» на карточке подписки — сдвигает `nextBillingDate` на один период вперёд
  - Опционально: автоматическое обновление при старте приложения для просроченных дат
- [ ] Готово

---

### 10. Экспорт данных
- **Проблема:** Нет возможности выгрузить свои данные — базовая функция для трекеров и open-source приложений.
- **Решение:**
  - iOS: `ShareLink` с CSV/JSON файлом, генерируется локально из `StorageService`
  - Backend: `GET /subscriptions/export?format=csv` (опционально)
  - Формат CSV: `name, price, currency, billing_period, next_billing_date, category, tag, url`
- [ ] Готово

---

### 11. Поиск и сортировка на главном экране
- **Проблема:** При 20+ подписках навигация только по категориям недостаточна.
- **Решение:**
  - Поиск по имени (`.searchable` в SwiftUI)
  - Сортировка: по дате следующего списания / по цене / по названию
  - Фильтр по тегу (в дополнение к категории)
- [ ] Готово

---

### 12. Расширить `BillingPeriod`: weekly и кастомный интервал
- **Проблема:** Нет `weekly` (например, недельные подписки на газеты, игры) и нет кастомного периода.
- **Решение:** Добавить к `Subscription` поля:
  ```swift
  var billingIntervalValue: Int   // например, 2
  var billingIntervalUnit: BillingPeriod  // например, .monthly → каждые 2 месяца
  ```
  Это ломающее изменение модели — требует миграции SwiftData и БД.
- [ ] Готово

---

### 13. `GET /subscriptions/upcoming` на бэкенде
- **Проблема:** Нет эндпоинта для получения подписок с ближайшими датами списания — нужен для будущих push-уведомлений и виджета.
- **Решение:** `GET /subscriptions/upcoming?days=7` — возвращает подписки где `next_billing_date <= now + N days`, отсортированные по дате.
- [ ] Готово

---

### 14. Валидация `nextBillingDate` на бэкенде
- **Файл:** `backend/internal/handlers/subscriptions.go`
- **Проблема:** Бэкенд принимает любую дату без проверки — можно записать дату 1970-01-01 или `null`.
- **Решение:** В `Create` и `Update` хендлерах добавить проверку:
  ```go
  if s.NextBillingDate.Time().Before(time.Date(2000, 1, 1, 0, 0, 0, 0, time.UTC)) {
      respondError(w, http.StatusBadRequest, "некорректная дата следующего списания")
      return
  }
  ```
- [ ] Готово

---

### 15. Rate limiting на `/auth/*`
- **Файл:** `backend/internal/server/router.go`
- **Проблема:** Эндпоинты `/auth/login` и `/auth/register` открыты без ограничений — уязвимость для брутфорса паролей.
- **Решение:** Подключить `github.com/go-chi/httprate`:
  ```go
  r.With(httprate.LimitByIP(5, time.Minute)).Post("/auth/login", authHandler.Login)
  r.With(httprate.LimitByIP(3, time.Minute)).Post("/auth/register", authHandler.Register)
  ```
- [ ] Готово

---

## 📋 Мелочи

### 16. `/health` не проверяет БД
- **Файл:** `backend/internal/server/router.go`
- **Проблема:** Возвращает `{"status":"ok"}` даже если БД недоступна.
- **Решение:** Добавить `db.Ping()` и возвращать 503 при ошибке.
- [ ] Готово

---

### 17. Нет `updatedAt` в SwiftData `SubscriptionEntity`
- **Файл:** `ios/SubRadar/Core/Storage/LocalStorageService.swift`
- **Проблема:** Бэкенд хранит и возвращает `updated_at`, но в SwiftData сущности этого поля нет. При будущей синхронизации это поле нужно для инкрементального обновления.
- **Решение:** Добавить `var updatedAt: Date` в `SubscriptionEntity` и заполнять при `update(from:)`.
- [ ] Готово

---

### 18. `KeychainService.shared` — синглтон в `RemoteStorageService`
- **Файл:** `ios/SubRadar/Core/Storage/RemoteStorageService.swift`
- **Проблема:** `init` обращается к `KeychainService.shared` напрямую, хотя `APIClient` уже принимает `tokenProvider: () -> String?`. При поддержке нескольких серверов/аккаунтов синглтон сломается.
- **Решение:** Передавать `tokenProvider` в `RemoteStorageService.init` извне (через `StorageServiceFactory`), не обращаться к `shared` внутри.
- [ ] Готово

---

### 19. `PATCH` вместо `PUT` для частичного обновления подписки
- **Файл:** `backend/internal/handlers/subscriptions.go`
- **Проблема:** `PUT /subscriptions/{id}` требует отправить все поля включая `image_data` — дорого при изменении только названия.
- **Решение:** Добавить `PATCH /subscriptions/{id}` с partial update через nullable поля или JSON Merge Patch (RFC 7396).
- [ ] Готово

---

*Последнее обновление: 07.05.2026*
