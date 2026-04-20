# SubRadar

> Free open-source cross-platform app for subscription tracking

SubRadar помогает отслеживать активные подписки, контролировать расходы и получать уведомления о предстоящих списаниях. Приложение работает полностью офлайн или синхронизируется через собственный сервер.

---

## Возможности

- 📋 Список всех активных подписок с датами и суммами списания
- 📅 Календарь платежей — по неделе, месяцу или году
- 🔔 Уведомления о предстоящих списаниях (за 1, 3, 7 дней)
- 💾 Три режима хранения данных на выбор
- 🎨 Светлая и тёмная тема, альтернативные иконки приложения
- 🌍 Поддержка нескольких валют и категорий

---

## Режимы хранения

| Режим | Описание |
|---|---|
| **Локальный** | Данные хранятся только на устройстве, без облака |
| **Общий сервер** | Синхронизация через централизованный сервер SubRadar |
| **Свой сервер** | Self-hosted — разворачиваешь бэкенд на своём сервере |

---

## Стек

### iOS
- Swift + SwiftUI
- SwiftData (локальное хранилище)
- iOS 17+

### Бэкенд
- Go (Golang)
- Chi router
- SQLite (self-hosted) / PostgreSQL (централизованный сервер)
- sqlc + golang-migrate

---

## Структура репозитория

```
SubRadar/
├── ios/          # Swift приложение
├── backend/      # Go сервер
├── docs/         # Документация
├── design/       # Figma экспорт, иконки, assets
└── README.md
```

---

## Документация

- [Структура iOS-проекта](docs/ios/ios-structure.md)
- [Архитектура iOS](docs/ios/ios-architecture.md)
- [Гайдлайны по коду](docs/ios/ios-guidelines.md)
- [Self-hosting](docs/self-hosting.md)
- [API](docs/api.md)
- [Contributing](docs/contributing.md)

---

## Быстрый старт — iOS

1. Клонируй репозиторий
2. Открой `ios/SubRadar/SubRadar.xcodeproj` в Xcode 15+
3. Выбери симулятор или подключённое устройство
4. `Cmd+R` — запуск

Никаких внешних зависимостей, SPM-пакетов и CocoaPods нет.

## Быстрый старт — Self-hosted бэкенд !!TBD!!

```bash
# Скачай бинарник под свою платформу со страницы Releases
curl -L https://github.com/your-org/SubRadar/releases/latest/download/subtracker-linux-amd64 -o subtracker
chmod +x subtracker
./subtracker
```

Подробная инструкция — в [docs/self-hosting.md](docs/self-hosting.md).

---

## Роадмап

- [x] MVP: локальное хранилище + базовый UI
- [x] Календарь платежей
- [x] Уведомления о списаниях
- [ ] Self-hosted бэкенд на Go + синхронизация
- [ ] Homebrew Formula
- [ ] Централизованный платный сервер
- [ ] Android-клиент
- [ ] MacOS клиент
- [ ] WEB клиент

---

## Лицензия

[MIT](LICENSE)