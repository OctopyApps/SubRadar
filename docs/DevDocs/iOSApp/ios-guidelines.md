# iOS — Гайдлайны по написанию кода

## Общие принципы

- Язык кода и комментариев — **русский** (названия переменных и типов — английские)
- Каждый новый экран — отдельная папка в `Features/` с файлами `*View.swift` и `*ViewModel.swift`
- Никакой бизнес-логики во View — только отображение и вызов методов ViewModel
- Все операции с хранилищем — `async/await`, вызываются через `Task { }` во View

---

## Структура файла View

```swift
struct MyFeatureView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = MyFeatureViewModel()

    var body: some View {
        // ...
    }

    // MARK: - Subviews (private var, не отдельные структуры если используются один раз)

    private var header: some View { ... }
    private var contentSection: some View { ... }
}

// MARK: - Reusable subcomponents (если переиспользуются — выносим в отдельную private struct)

private struct MyCard: View { ... }
```

**Порядок секций** внутри файла через `// MARK: -`:
1. `// MARK: - Properties` (если есть локальные `@State`)
2. `// MARK: - Body`
3. `// MARK: - [Название секции]` для каждого крупного блока UI
4. Отдельные компоненты — в конце файла

---

## Структура файла ViewModel

```swift
@MainActor
final class MyFeatureViewModel: ObservableObject {

    // MARK: - Published state
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var error: StorageError?

    // MARK: - Private
    private let storage: any StorageService

    init(storage: any StorageService) {
        self.storage = storage
    }

    // MARK: - Intents (методы которые вызывает View)

    func load() async {
        isLoading = true
        items = (try? await storage.fetchSubscriptions()) ?? []
        isLoading = false
    }
}
```

- Все ViewModel помечены `@MainActor` и `final`
- Зависимости (storage) передаются через `init`, не создаются внутри
- Публичные методы — «интенты», называются глаголами: `load()`, `save()`, `openEdit(_:)`

---

## Работа с хранилищем

Всегда получай `storage` через фабрику, не создавай напрямую:

```swift
// ✅ Правильно
let config = UserDefaultsService.shared.configuration ?? .local()
let storage = StorageServiceFactory.make(for: config)

// ❌ Неправильно
let storage = LocalStorageService()
```

Ошибки хранилища — всегда `StorageError`. Обрабатывай через `do/catch` или `try?`:

```swift
// Если ошибка некритична
let subs = (try? await storage.fetchSubscriptions()) ?? []

// Если нужно показать пользователю
do {
    try await storage.save(subscription)
} catch let e as StorageError {
    self.error = e
} catch {}
```

---

## Цветовая система

Все цвета — через семантические токены из `Assets.xcassets` и `AppColors.swift`. Никаких хардкодных hex-значений в UI-коде, кроме цвета иконки конкретной подписки (`subscription.color`).

| Токен | Назначение |
|---|---|
| `Color.srBackground` | Фон экранов |
| `Color.srSurface` | Фон таб-бара, нижних панелей |
| `Color.srSurface2` | Фон карточек, полей ввода |
| `Color.srBorder` | Обводки, разделители |
| `Color.srAccent` | Основной акцентный цвет (фиолетовый) |
| `Color.srAccentLight` | Светлый вариант акцента |
| `Color.srTextPrimary` | Основной текст |
| `Color.srTextSecondary` | Второстепенный текст (подписи, описания) |
| `Color.srTextTertiary` | Третьестепенный (плейсхолдеры, неактивные элементы) |
| `Color.srDanger` | Ошибки, удаление |
| `Color.srWarning` | Предупреждения |
| `Color.srTeal` | Self-hosted акцент |
| `Color.srModeLocal` | Акцент локального режима |
| `Color.srModeShared` | Акцент общего сервера |

---

## Типографика

Стандартный шрифт — SF Pro через `.font(.system(...))`. Кастомных шрифтов нет.

| Контекст | Размер | Вес |
|---|---|---|
| Заголовок экрана (навбар) | 17 | semibold |
| Крупный заголовок (hero) | 28–36 | bold |
| Заголовок карточки | 16–18 | semibold / medium |
| Основной текст | 15–16 | regular |
| Подпись / описание | 12–13 | regular |
| Лейблы секций (caps) | 11 | semibold + kerning 0.5 |

Заголовки экранов — с `kerning(-0.3)`. Hero-числа — с `kerning(-0.6)` и выше.

---

## Компоненты форм

Переиспользуемые компоненты форм находятся в `SubscriptionFormView.swift`:

- `FormCard` — карточка-контейнер с фоном и обводкой
- `FormField` — строка с лейблом слева (ширина 100pt) и контентом справа
- `CurrencyChip`, `PeriodChip`, `CategoryChip` — чипы выбора
- `TagSuggestionChip` — чип подсказки тега

При создании новых форм — переиспользуй эти компоненты или выноси в отдельный файл если они нужны в нескольких местах.

---

## Анимации

```swift
// Переключение экранов (глобальная навигация)
withAnimation(.easeInOut(duration: 0.4)) { appState.currentScreen = .main }

// Появление / исчезновение элементов
withAnimation(.easeInOut(duration: 0.2)) { showSomething = true }

// Нажатие кнопок (scale)
.animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
```

Интерактивный скролл — `.interactiveSpring(response: 0.3, dampingFraction: 0.8)`.

---

## Sheet-навигация

Шиты открываются через `@Published var isSomethingOpen = false` во ViewModel или локальный `@State` во View.

```swift
// Во View
.sheet(isPresented: $viewModel.isAddingSubscription) {
    AddSubscriptionView(storage: viewModel.storage) { subscription in
        viewModel.subscriptionAdded(subscription)
    }
    .environmentObject(appState)
}
```

**Всегда передавай `.environmentObject(appState)` в шит** — иначе `AppState` не будет доступен внутри.

Когда шит открывается из другого шита — используй `onDismiss` для очистки состояния:

```swift
.sheet(isPresented: $showServerSetup, onDismiss: { pendingMode = nil }) { ... }
```

---

## Добавление нового экрана — чеклист

1. Создай папку `Features/МоёФича/`
2. Создай `МоёФичаView.swift` и `МоёФичаViewModel.swift`
3. ViewModel принимает `storage: any StorageService` в `init` если работает с данными
4. Добавь оба файла в таргет `SubRadar` в Xcode
5. Открывай экран через `.sheet` из родительского View
6. Передавай `.environmentObject(appState)` при открытии шита
