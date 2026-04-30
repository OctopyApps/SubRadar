# install.sh — Документация

Скрипт установки SubRadar Backend на Linux сервер. Автоматически скачивает бинарник с GitHub, создаёт конфиг с безопасными случайными ключами и настраивает systemd для автозапуска.

---

## Быстрый старт

```bash
curl -fsSL https://raw.githubusercontent.com/OctopyApps/SubRadar/main/install.sh | sudo bash
```

---

## Требования

- Linux (x86_64 или ARM64)
- Права root (`sudo`)
- `curl` и `openssl` — обычно уже установлены

---

## Что делает скрипт

1. Определяет архитектуру сервера (amd64 или arm64)
2. Получает последнюю версию бэкенда с GitHub
3. Скачивает бинарник и проверяет контрольную сумму SHA256
4. Устанавливает бинарник в `/usr/local/bin/subradar`
5. Создаёт системного пользователя `subradar` (без shell, без домашней папки)
6. Создаёт директории `/etc/subradar/` и `/var/lib/subradar/`
7. Генерирует `/etc/subradar/config.yaml` со случайными секретами
8. Предлагает установить и запустить systemd-сервис

---

## Режимы запуска

### Установка с GitHub (стандартный)

```bash
curl -fsSL https://raw.githubusercontent.com/OctopyApps/SubRadar/main/install.sh | sudo bash
```

Скрипт сам найдёт последнюю версию и скачает подходящий бинарник.

### Установка локального бинарника

Если вы собрали бинарник сами или скачали вручную:

```bash
sudo bash install.sh --local /путь/к/бинарнику
```

Полезно при разработке или в среде без доступа к GitHub.

### Удаление

```bash
sudo bash install.sh --uninstall
```

Останавливает сервис, удаляет бинарник и systemd-юнит. Данные и конфиг не удаляются автоматически — скрипт спросит отдельно.

---

## Файлы которые создаёт скрипт

| Путь | Описание |
|---|---|
| `/usr/local/bin/subradar` | Бинарник сервера |
| `/etc/subradar/config.yaml` | Конфигурация (права 640, owner root:subradar) |
| `/var/lib/subradar/subradar.db` | База данных SQLite |
| `/etc/systemd/system/subradar.service` | Systemd-юнит (если выбрана установка) |

---

## Сгенерированный config.yaml

После установки конфиг выглядит так (секреты генерируются случайно через `openssl rand`):

```yaml
server:
  port: 8080

storage:
  driver: sqlite
  sqlite:
    path: /var/lib/subradar/subradar.db
  postgres:
    dsn: ""

auth:
  jwt_secret: "<случайная строка 64 символа>"
  self_hosted: true
  server_secret: "<случайная строка 48 символов>"
```

Конфиг **не перезаписывается** при повторном запуске скрипта — только если файла ещё нет.

Найти `server_secret` для подключения iOS-приложения:
```bash
sudo grep server_secret /etc/subradar/config.yaml
```

---

## Systemd-сервис

Если при установке выбрать автозапуск, создаётся файл `/etc/systemd/system/subradar.service`:

```ini
[Unit]
Description=SubRadar Backend
After=network.target

[Service]
Type=simple
User=subradar
Group=subradar
ExecStart=/usr/local/bin/subradar --config=/etc/subradar/config.yaml
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/lib/subradar

[Install]
WantedBy=multi-user.target
```

Полезные команды для управления сервисом:

```bash
systemctl status subradar          # статус
systemctl start subradar           # запустить
systemctl stop subradar            # остановить
systemctl restart subradar         # перезапустить (после правки конфига)
journalctl -u subradar -f          # логи в реальном времени
journalctl -u subradar -n 50       # последние 50 строк логов
```

---

## Удаление (подробно)

```bash
sudo bash install.sh --uninstall
```

Скрипт:
1. Останавливает сервис если запущен
2. Убирает из автозапуска
3. Удаляет `/etc/systemd/system/subradar.service`
4. Удаляет `/usr/local/bin/subradar`
5. Удаляет системного пользователя `subradar`
6. Спрашивает — удалить ли `/etc/subradar/` и `/var/lib/subradar/`

> Данные (БД) и конфиг не удаляются без явного подтверждения — чтобы случайно не потерять данные при переустановке.

---

## Частые вопросы

**Где найти секретный ключ для подключения приложения?**
```bash
sudo grep server_secret /etc/subradar/config.yaml
```

**Как поменять порт?**
```bash
sudo nano /etc/subradar/config.yaml
# Изменить server.port
sudo systemctl restart subradar
```

**Как переключиться на PostgreSQL?**
```bash
sudo nano /etc/subradar/config.yaml
# Изменить storage.driver на "postgres"
# Добавить storage.postgres.dsn
sudo systemctl restart subradar
```

**Скрипт не может скачать бинарник — что делать?**

Скачайте вручную со [страницы релизов](https://github.com/OctopyApps/SubRadar/releases) и установите через `--local`:
```bash
sudo bash install.sh --local ./subradar-linux-amd64
```
