# SubRadar Backend — Установка

Бэкенд нужен только если вы хотите синхронизировать подписки между устройствами. Если вам достаточно локального хранения данных прямо на iPhone — бэкенд не нужен.

---

## Варианты установки

| Вариант | Для кого | Сложность |
|---|---|---|
| [Install-скрипт](#1-install-скрипт-рекомендуется) | VPS, Raspberry Pi | ⭐ Одна команда |
| [Вручную](#2-установка-вручную) | Любой Linux | ⭐⭐ Несколько команд |
| [Сборка из исходников](#3-сборка-из-исходников) | Разработчики | ⭐⭐⭐ |

---

## 1. Install-скрипт (рекомендуется)

Подходит для Linux (VPS, Raspberry Pi, домашний сервер). Скрипт автоматически:
- определяет архитектуру вашего сервера
- скачивает и устанавливает бинарник
- создаёт конфиг с безопасными случайными ключами
- предлагает настроить автозапуск через systemd

```bash
curl -fsSL https://raw.githubusercontent.com/OctopyApps/SubRadar-BackEnd/main/install.sh | sudo bash
```

После установки бэкенд будет доступен на порту `8080`. Конфиг находится в `/etc/subradar/config.yaml`.

---

## 2. Установка вручную

### Шаг 1 — Скачайте бинарник

Перейдите на страницу [Releases](https://github.com/OctopyApps/SubRadar-BackEnd/releases/latest) и скачайте файл под вашу платформу:

| Платформа | Файл |
|---|---|
| Linux x86_64 (VPS, большинство серверов) | `subradar-linux-amd64` |
| Linux ARM64 (Raspberry Pi 4/5) | `subradar-linux-arm64` |
| macOS Apple Silicon (M1/M2/M3) | `subradar-darwin-arm64` |
| macOS Intel | `subradar-darwin-amd64` |
| Windows | `subradar-windows-amd64.exe` |

Или через терминал (замените `VERSION` и `ARCH` на нужные значения):

```bash
VERSION=v1.0.0
ARCH=linux-amd64

curl -fsSL "https://github.com/OctopyApps/SubRadar-BackEnd/releases/download/${VERSION}/subradar-${ARCH}" \
  -o subradar

chmod +x subradar
sudo mv subradar /usr/local/bin/
```

### Шаг 2 — Создайте конфиг

```bash
sudo mkdir -p /etc/subradar
sudo nano /etc/subradar/config.yaml
```

Минимальный конфиг:

```yaml
server:
  port: 8080

storage:
  driver: sqlite
  sqlite:
    path: /var/lib/subradar/subradar.db

auth:
  jwt_secret: "замените-на-случайную-строку"
  self_hosted: true
  server_secret: "замените-на-случайную-строку"
```

Сгенерировать случайные строки для секретов:

```bash
openssl rand -hex 32
```

### Шаг 3 — Запустите

```bash
subradar --config=/etc/subradar/config.yaml
```

### Шаг 4 — Автозапуск через systemd (опционально)

Создайте файл сервиса:

```bash
sudo nano /etc/systemd/system/subradar.service
```

Содержимое:

```ini
[Unit]
Description=SubRadar Backend
After=network.target

[Service]
Type=simple
User=subradar
ExecStart=/usr/local/bin/subradar --config=/etc/subradar/config.yaml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

Включите и запустите:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now subradar
```

---

## 3. Сборка из исходников

Потребуется Go 1.21+.

```bash
git clone https://github.com/OctopyApps/SubRadar-BackEnd.git
cd SubRadar-BackEnd/backend

go mod download
go build -o subradar ./cmd/server

./subradar --config=config.yaml
```

---

## Настройка

### PostgreSQL вместо SQLite

Если хотите использовать PostgreSQL — измените секцию `storage` в конфиге:

```yaml
storage:
  driver: postgres
  postgres:
    dsn: "postgres://user:password@localhost:5432/subradar?sslmode=disable"
```

Либо передайте DSN через переменную окружения (рекомендуется — пароль не попадёт в файл):

```bash
export SUBRADAR_STORAGE_POSTGRES_DSN="postgres://user:password@localhost:5432/subradar?sslmode=disable"
```

### Порт

По умолчанию бэкенд слушает порт `8080`. Изменить:

```yaml
server:
  port: 9000
```

Или через переменную окружения:

```bash
export SUBRADAR_SERVER_PORT=9000
```

---

## Полезные команды

```bash
# Версия
subradar --version

# Статус сервиса
systemctl status subradar

# Логи в реальном времени
journalctl -u subradar -f

# Перезапуск после изменения конфига
systemctl restart subradar
```

---

## Подключение iOS-приложения

После запуска бэкенда откройте SubRadar на iPhone, выберите режим **«Свой сервер»** и введите адрес:

```
http://ВАШ_IP:8080
```

Если сервер доступен из интернета — рекомендуем настроить HTTPS через [nginx + certbot](https://certbot.eff.org/).
