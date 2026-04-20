# iOS — Архитектура

## Паттерн: MVVM

Каждый экран состоит из трёх слоёв:

```
View  →  ViewModel  →  StorageService (протокол)
```

- **View** — только UI, никакой бизнес-логики
- **ViewModel** — `@MainActor final class`, наследует `ObservableObject`, держит состояние и обрабатывает действия пользователя
- **StorageService** — протокол, View и ViewModel не знают о конкретной реализации (Local или Remote)

---

## AppState

`AppState` — единственный глобальный объект, живёт на уровне `App`. Хранит:

- `currentScreen` — какой экран показывать
- `storageMode` — текущий режим хранения
- `currencies`, `categories` — пользовательские списки
- `notificationSettings` — настройки уведомлений
- `colorSchemePreference` — тема
- `selectedIconName` — иконка приложения

`AppState` передаётся через `.environmentObject` и доступен в любой вьюхе через `@EnvironmentObject private var appState: AppState`.

**Важно:** `AppState` не хранит подписки. Подписки живут в `StorageService` и загружаются в конкретных `ViewModel`.

---

## StorageService

Единый протокол для работы с данными:

```swift
protocol StorageService: AnyObject {
    func fetchSubscriptions() async throws -> [Subscription]
    func save(_ subscription: Subscription) async throws
    func update(_ subscription: Subscription) async throws
    func delete(_ subscription: Subscription) async throws

    func fetchTags() async throws -> [Tag]
    func saveTagIfNeeded(name: String) async throws -> Tag
    func deleteTag(_ tag: Tag) async throws
}
```

Конкретную реализацию создаёт `StorageServiceFactory` на основе текущего `AppConfiguration`:

```swift
// Использование
let config = UserDefaultsService.shared.configuration ?? .local()
let storage = StorageServiceFactory.make(for: config)
```

### LocalStorageService

Реализация на **SwiftData**. Хранит данные в SQLite на устройстве. Использует два `@Model`:
- `SubscriptionEntity` — подписка
- `TagEntity` — тег

Конвертация между domain-моделью (`Subscription`) и SwiftData-сущностью (`SubscriptionEntity`) происходит через `init(from:)` и `toDomain(resolvedCurrency:resolvedCategory:)`.

### RemoteStorageService

Реализация для работы с Go-бэкендом. На данный момент возвращает `.notImplemented` — в разработке.

---

## Три режима хранения

| Режим | Конфигурация | StorageService |
|---|---|---|
| `local` | `AppConfiguration.local()` | `LocalStorageService` |
| `shared` | `AppConfiguration.shared()` | `RemoteStorageService` (api.subradar.io) |
| `selfHosted` | `AppConfiguration.selfHosted(serverConfiguration:)` | `RemoteStorageService` (пользовательский URL) |

Конфигурация сохраняется в `UserDefaults` через `UserDefaultsService`. Auth-токен — в `Keychain` через `KeychainService`.

### Смена режима

Смена режима происходит в `StorageModeSettingsView`. Логика:

1. Пользователь выбирает новый режим
2. Если есть подписки — предлагается их перенести
3. Записывается новый `AppConfiguration` через `UserDefaultsService.shared.configuration`
4. **Не меняется** `AppState.currentScreen` — пользователь остаётся на главном экране

---

## Генерация дат оплат (CalendarViewModel)

Подписки хранят только `nextBillingDate` — ближайшую дату списания. Для построения календаря `CalendarViewModel.paymentDates(for:in:)` генерирует все даты в нужном диапазоне на лету, шагая от `nextBillingDate` вперёд и назад на `billingPeriod`.

```
nextBillingDate → шагаем назад пока не выйдем за начало периода
                → шагаем вперёд и собираем все даты внутри периода
```

---

## Уведомления

`NotificationService` — `@MainActor` singleton. Планирует локальные `UNCalendarNotificationTrigger` уведомления на основе `nextBillingDate` каждой подписки и `NotificationSettings.leadTimes`.

Уведомления **не повторяются автоматически** — их нужно перепланировать после каждого изменения подписок. Точка перепланирования — `NotificationsView` при изменении настроек.

---

## Конфигурация сборки

- **DEBUG**: на главном экране показывается кнопка «Сбросить» — сбрасывает `AppConfiguration` и возвращает на онбординг. Удобно для тестирования онбординга без удаления приложения.
- **RELEASE**: кнопка скрыта через `#if DEBUG`.
