# iOS — Структура проекта

## Обзор

iOS-клиент SubRadar написан на **Swift + SwiftUI**, минимальная версия — iOS 17. Локальное хранилище — **SwiftData**. Архитектура — MVVM.

---

## Дерево папок

```
SubRadar/
├── App/
│   ├── SubRadarApp.swift          # @main, точка входа, создаёт AppState
│   └── AppState.swift             # Глобальное состояние приложения
│
├── Core/
│   ├── Models/
│   │   ├── AppConfiguration.swift     # Конфигурация сессии (режим + сервер)
│   │   ├── StorageMode.swift          # enum: local / shared / selfHosted
│   │   ├── ServerConfiguration.swift  # baseURL сервера
│   │   ├── NotificationSettings.swift # Настройки уведомлений
│   │   └── SubscriptionFields/
│   │       ├── Subscription.swift     # Основная модель подписки
│   │       ├── AppCategory.swift      # Категории подписок
│   │       ├── AppCurrency.swift      # Валюты
│   │       └── Tag.swift              # Теги
│   │
│   ├── Services/
│   │   └── NotificationService.swift  # Планировщик UNUserNotification
│   │
│   └── Storage/
│       ├── StorageService.swift        # Протокол: fetchSubscriptions, save, update, delete…
│       ├── StorageServiceFactory.swift # Фабрика: выбирает Local или Remote по конфигу
│       ├── LocalStorageService.swift   # SwiftData реализация
│       ├── RemoteStorageService.swift  # HTTP реализация (в разработке)
│       ├── UserDefaultsService.swift   # Хранение AppConfiguration
│       └── KeychainService.swift       # Хранение auth-токена
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   │
│   ├── Auth/
│   │   ├── AuthView.swift
│   │   ├── AuthViewModel.swift
│   │   ├── RegisterView.swift
│   │   ├── RegisterViewModel.swift
│   │   └── AuthTextField.swift        # Переиспользуемое поле ввода
│   │
│   ├── ServerSetup/
│   │   ├── ServerSetupView.swift      # Форма подключения к self-hosted серверу
│   │   └── ServerSetupViewModel.swift
│   │
│   ├── Subscriptions/
│   │   ├── SubscriptionsView.swift    # Главный экран + TabBar + MenuSheet
│   │   ├── SubscriptionsViewModel.swift
│   │   ├── Add/
│   │   │   ├── AddSubscriptionView.swift
│   │   │   └── AddSubscriptionViewModel.swift
│   │   ├── Edit/
│   │   │   ├── EditSubscriptionView.swift
│   │   │   └── EditSubscriptionViewModel.swift
│   │   └── Form/
│   │       ├── SubscriptionFormView.swift   # Общая форма (Add и Edit её переиспользуют)
│   │       └── SubscriptionFormViewModel.swift
│   │
│   ├── Calendar/
│   │   ├── CalendarView.swift         # Экран календаря (неделя / месяц / год)
│   │   └── CalendarViewModel.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift         # Основной экран настроек
│   │   └── StorageModeSettingsView.swift  # Смена режима хранения
│   │
│   └── Notifications/
│       └── NotificationsView.swift
│
└── Resources/
    ├── AppColors.swift               # Color extensions + LinearGradient helpers
    ├── Assets.xcassets               # Иконки приложения, цвета (srAccent, srBackground…)
    ├── Colors.xcassets               # Дополнительная палитра
    └── AlternateAppIcons/            # Альтернативные иконки приложения
```

---

## Точка входа

`SubRadarApp.swift` создаёт единственный `AppState` как `@StateObject` и передаёт его вниз через `.environmentObject`. Навигация между экранами полностью управляется через `AppState.currentScreen`.

```swift
// Три глобальных состояния приложения
enum AppScreen {
    case onboarding
    case auth(StorageMode)
    case main
}
```

`ContentView` — приватная вьюха внутри `SubRadarApp.swift`, переключает экраны по `currentScreen` с анимацией `.opacity`.

---

## Навигация

Приложение **не использует** `NavigationStack` на верхнем уровне. Основная навигация:

| Механизм | Где используется |
|---|---|
| `AppState.currentScreen` | Onboarding → Auth → Main |
| `.sheet` | Все модальные экраны (Settings, Calendar, Add, Edit…) |
| `TabBar` (кастомный) | Внутри главного экрана |

Кастомный таб-бар находится в `SubscriptionsView` — три кнопки: Календарь, Добавить (+), Меню.
