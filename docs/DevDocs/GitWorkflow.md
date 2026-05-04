# SubRadar — Git Workflow

## Структура веток

```
main        — зеркало стабильного кода. Только через PR. Не трогается напрямую.
backend     — код Go-бэкенда. Фичи и фиксы мёржатся сюда через PR.
ios         — код iOS-приложения. Фичи и фиксы мёржатся сюда через PR.
dev         — интеграционная ветка. Сюда сливаются backend и ios для проверки совместимости.
feature/*   — отдельная ветка под каждую фичу или фикс.
```

Прямые коммиты в `main`, `backend`, `ios`, `dev` — запрещены. Всё только через PR на GitHub.

---

## Три типа релизов и их теги

GitHub Actions запускается автоматически при пуше тега. Формат тега определяет какой воркфлоу сработает:

| Тег | Воркфлоу | Что происходит |
|---|---|---|
| `backend/v1.2.3` | `BackEndRelease.yml` | Собирает бинарники Go под все платформы, создаёт GitHub Release |
| `ios/v1.2.3` | `iOSRelease.yml` | Собирает архив Xcode, создаёт GitHub Release |
| `v1.3.0` | `MajorRelease.yml` | Собирает и бэкенд и iOS, создаёт один общий GitHub Release |

**Важно:** теги с префиксом `ios/` и `backend/` явно исключены из `MajorRelease.yml` — двойного запуска не будет.

### Release Notes

Перед постановкой тега нужно создать файл с описанием релиза — Actions читает его автоматически:

```
docs/UserDocs/ReleaseNotes/BackEndReleaseNotes/v1.2.3.md   ← для backend/v1.2.3
docs/UserDocs/ReleaseNotes/iOSReleaseNotes/v1.2.3.md       ← для ios/v1.2.3
docs/UserDocs/ReleaseNotes/MajorReleaseNotes/v1.2.3.md     ← для v1.2.3
```

Если файл не найден — в релизе будет заглушка "No release notes found".

---

## Версионирование

Формат: `vMAJOR.MINOR.PATCH`

| Тип изменения | Пример | Версия |
|---|---|---|
| Исправление бага, не меняет API | Фикс дат, фикс ID | `v0.1.1` → `v0.1.2` |
| Новая функциональность, обратно совместима | Pull-to-refresh, миграция данных | `v0.1.x` → `v0.2.0` |
| Ломающее изменение API | Смена формата запросов | `v0.x.y` → `v1.0.0` |

Бэкенд и iOS версионируются **независимо** через свои теги. Мажорный релиз (`v1.x.0`) синхронизирует оба компонента — используй его когда фича затрагивает и бэкенд и приложение одновременно.

---

## Типичный цикл разработки

### 1. Начать фичу

Определи что затрагивает фича — бэкенд, iOS или оба компонента. Ответвляйся от соответствующей ветки:

```bash
# Фича только для бэкенда
git checkout backend
git pull origin backend
git checkout -b feature/название-фичи   

# Фича только для iOS
git checkout ios
git pull origin ios
git checkout -b feature/название-фичи

# Фича затрагивает оба компонента — ответвляйся от dev
git checkout dev
git pull origin dev
git checkout -b feature/название-фичи
```

Примеры названий веток:
```
feature/pull-to-refresh
feature/delete-confirmation
feature/migration-between-modes
fix/date-decoding-nanoseconds
fix/subscription-id-mismatch
```

### 2. Коммитить изменения

```bash
# Посмотреть что изменилось
git status
git diff

# Добавить конкретные файлы
git add backend/internal/models/subscription.go
git add ios/SubRadar/Features/Subscriptions/SubscriptionsView.swift

# Или всё сразу (проверь git status перед этим)
git add .

# Закоммитить
git commit -m "fix: исправить декодирование дат с наносекундами"
```

Формат сообщений коммитов:
```
feat: новая функциональность
fix: исправление бага
refactor: рефакторинг без изменения поведения
docs: изменения в документации
chore: обновление зависимостей, конфигов
```

### 3. Запушить и создать PR на GitHub

```bash
git push origin feature/название-фичи
```

На GitHub появится баннер «Compare & pull request». Настройки PR:

- Фича бэкенда → **base:** `backend` ← **compare:** `feature/название`
- Фича iOS → **base:** `ios` ← **compare:** `feature/название`
- Фича обоих → **base:** `dev` ← **compare:** `feature/название`

После мёржа PR — удали ветку прямо на GitHub (кнопка "Delete branch").

### 4. Обновить локальную ветку после мёржа

```bash
git checkout backend   # или ios / dev
git pull origin backend

# Удалить локальную feature-ветку
git branch -d feature/название-фичи
```

---

## Релиз бэкенда

Когда в ветке `backend` накопились изменения и всё проверено:

### 1. Слить backend → dev для проверки совместимости с iOS

На GitHub: PR `backend` → `dev`. После мёржа проверяешь что всё работает вместе.

### 2. Слить backend → main

На GitHub: PR `backend` → `main`.

### 3. Создать release notes

Создай файл `docs/UserDocs/ReleaseNotes/BackEndReleaseNotes/v0.2.0.md`, закоммить и запушь в `main`.

### 4. Поставить тег

```bash
git checkout main
git pull origin main

git tag -a backend/v0.2.0 -m "Backend v0.2.0"
git push origin backend/v0.2.0
```

GitHub Actions подхватит тег, соберёт бинарники под все платформы и создаст GitHub Release автоматически.

---

## Релиз iOS

### 1. Слить ios → dev для проверки совместимости

На GitHub: PR `ios` → `dev`.

### 2. Слить ios → main

На GitHub: PR `ios` → `main`.

### 3. Создать release notes

Создай файл `docs/UserDocs/ReleaseNotes/iOSReleaseNotes/v0.2.0.md`, закоммить и запушь в `main`.

### 4. Поставить тег

```bash
git checkout main
git pull origin main

git tag -a ios/v0.2.0 -m "iOS v0.2.0"
git push origin ios/v0.2.0
```

---

## Мажорный релиз (бэкенд + iOS вместе)

Когда фича затрагивает оба компонента и они должны выходить синхронно:

### 1. Убедиться что оба компонента в dev протестированы вместе

### 2. Слить dev → main

На GitHub: PR `dev` → `main`.

### 3. Создать release notes

Создай файл `docs/UserDocs/ReleaseNotes/MajorReleaseNotes/v0.2.0.md`, закоммить и запушь в `main`.

### 4. Поставить тег без префикса

```bash
git checkout main
git pull origin main

git tag -a v0.2.0 -m "SubRadar v0.2.0"
git push origin v0.2.0
```

`MajorRelease.yml` соберёт и бэкенд и iOS и создаст один общий GitHub Release.

### 5. Синхронизировать ветки после мажорного релиза

```bash
git checkout backend && git merge main && git push origin backend
git checkout ios     && git merge main && git push origin ios
git checkout dev     && git merge main && git push origin dev
```

---

## Hotfix — срочный фикс в продакшене

Если в `main` нашёлся критический баг:

```bash
# Ответвляемся от main (не от backend/ios/dev!)
git checkout main
git pull origin main
git checkout -b fix/название-бага

# Чиним, коммитим
git add .
git commit -m "fix: описание бага"
git push origin fix/название-бага
```

На GitHub:
1. PR `fix/название-бага` → `main`
2. Создать release notes
3. Поставить патч-тег (`backend/v0.1.1` или `ios/v0.1.1`)
4. PR `main` → `backend` (и/или `ios`, `dev`) — чтобы фикс попал во все ветки

---

## Полезные команды

```bash
# Посмотреть все ветки (локальные и удалённые)
git branch -a

# Посмотреть историю коммитов с графом веток
git log --oneline --graph --all

# Посмотреть все теги
git tag

# Посмотреть теги с фильтром
git tag -l "backend/*"
git tag -l "ios/*"

# Отменить последний коммит (изменения останутся в файлах)
git reset --soft HEAD~1

# Посмотреть что войдёт в коммит
git diff --staged

# Обновить feature-ветку если основная ушла вперёд
git fetch origin
git rebase origin/backend   # или ios / dev
```

---

## Шпаргалка

```bash
# ── Начало работы ───────────────────────────────────────────────
git checkout backend && git pull origin backend   # или ios / dev
git checkout -b feature/моя-фича

# ── Работа ──────────────────────────────────────────────────────
git add .
git commit -m "feat: описание"
git push origin feature/моя-фича
# → PR на GitHub (backend ← feature/моя-фича)
# → Мёрж PR на GitHub
git checkout backend && git pull origin backend
git branch -d feature/моя-фича

# ── Релиз бэкенда ───────────────────────────────────────────────
# → PR на GitHub (backend → dev)  — тест совместимости
# → PR на GitHub (backend → main)
# Создать docs/UserDocs/ReleaseNotes/BackEndReleaseNotes/v0.2.0.md
git checkout main && git pull origin main
git tag -a backend/v0.2.0 -m "Backend v0.2.0"
git push origin backend/v0.2.0
# ✓ Actions собрал бинарники и создал GitHub Release

# ── Релиз iOS ───────────────────────────────────────────────────
# → PR на GitHub (ios → dev)  — тест совместимости
# → PR на GitHub (ios → main)
# Создать docs/UserDocs/ReleaseNotes/iOSReleaseNotes/v0.2.0.md
git checkout main && git pull origin main
git tag -a ios/v0.2.0 -m "iOS v0.2.0"
git push origin ios/v0.2.0
# ✓ Actions собрал архив Xcode и создал GitHub Release

# ── Мажорный релиз (оба компонента) ─────────────────────────────
# → PR на GitHub (dev → main)
# Создать docs/UserDocs/ReleaseNotes/MajorReleaseNotes/v0.2.0.md
git checkout main && git pull origin main
git tag -a v0.2.0 -m "SubRadar v0.2.0"
git push origin v0.2.0
# ✓ Actions собрал всё вместе и создал общий GitHub Release
git checkout backend && git merge main && git push origin backend
git checkout ios     && git merge main && git push origin ios
git checkout dev     && git merge main && git push origin dev
```
