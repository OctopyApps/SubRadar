#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SubRadar Backend — Install Script
# Usage: curl -fsSL https://raw.githubusercontent.com/OctopyApps/SubRadar-BackEnd/main/install.sh | bash
# =============================================================================

REPO="OctopyApps/SubRadar-BackEnd"
BINARY_NAME="subradar"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/subradar"
DATA_DIR="/var/lib/subradar"
SERVICE_USER="subradar"

# --- Цвета для вывода ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[SubRadar]${NC} $1"; }
success() { echo -e "${GREEN}[SubRadar]${NC} $1"; }
warn()    { echo -e "${YELLOW}[SubRadar]${NC} $1"; }
error()   { echo -e "${RED}[SubRadar]${NC} $1"; exit 1; }

# --- Проверка root ---
if [ "$EUID" -ne 0 ]; then
  error "Запустите скрипт с правами root: sudo bash install.sh"
fi

# --- Определение архитектуры ---
detect_arch() {
  local arch
  arch=$(uname -m)
  case "$arch" in
    x86_64)  echo "amd64" ;;
    aarch64) echo "arm64" ;;
    armv7l)  echo "arm64" ;;
    *) error "Неподдерживаемая архитектура: $arch" ;;
  esac
}

# --- Получение последней версии с GitHub ---
get_latest_version() {
  local version
  version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  if [ -z "$version" ]; then
    error "Не удалось получить последнюю версию с GitHub. Проверьте интернет-соединение."
  fi
  echo "$version"
}

echo ""
echo -e "${BLUE}╔═══════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SubRadar Backend Installer    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════╝${NC}"
echo ""

# --- Определяем версию и архитектуру ---
ARCH=$(detect_arch)
info "Архитектура: linux-${ARCH}"

info "Получаем последнюю версию..."
VERSION=$(get_latest_version)
info "Версия: ${VERSION}"

BINARY_FILE="${BINARY_NAME}-linux-${ARCH}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${BINARY_FILE}"

# --- Скачиваем бинарник ---
info "Скачиваем бинарник..."
TMP_FILE=$(mktemp)
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMP_FILE"; then
  rm -f "$TMP_FILE"
  error "Не удалось скачать бинарник. URL: ${DOWNLOAD_URL}"
fi

# --- Верифицируем checksum ---
info "Проверяем контрольную сумму..."
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${VERSION}/checksums.txt"
CHECKSUMS_FILE=$(mktemp)
if curl -fsSL "$CHECKSUMS_URL" -o "$CHECKSUMS_FILE" 2>/dev/null; then
  EXPECTED=$(grep "$BINARY_FILE" "$CHECKSUMS_FILE" | awk '{print $1}')
  ACTUAL=$(sha256sum "$TMP_FILE" | awk '{print $1}')
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    rm -f "$TMP_FILE" "$CHECKSUMS_FILE"
    error "Контрольная сумма не совпадает. Файл повреждён."
  fi
  success "Контрольная сумма совпадает"
else
  warn "Не удалось скачать checksums.txt, пропускаем проверку"
fi
rm -f "$CHECKSUMS_FILE"

# --- Устанавливаем бинарник ---
info "Устанавливаем бинарник в ${INSTALL_DIR}/${BINARY_NAME}..."
install -m 755 "$TMP_FILE" "${INSTALL_DIR}/${BINARY_NAME}"
rm -f "$TMP_FILE"
success "Бинарник установлен"

# --- Создаём системного пользователя ---
if ! id "$SERVICE_USER" &>/dev/null; then
  info "Создаём пользователя ${SERVICE_USER}..."
  useradd --system --no-create-home --shell /bin/false "$SERVICE_USER"
fi

# --- Создаём директории ---
mkdir -p "$CONFIG_DIR" "$DATA_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"

# --- Создаём config.yaml если его нет ---
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
  info "Создаём конфиг ${CONFIG_FILE}..."
  cat > "$CONFIG_FILE" <<EOF
# SubRadar Backend — конфигурация
# Документация: https://github.com/${REPO}

server:
  port: 8080

storage:
  # Выберите драйвер: sqlite | postgres
  driver: sqlite

  sqlite:
    path: ${DATA_DIR}/subradar.db

  postgres:
    # DSN формат: postgres://user:password@host:5432/dbname?sslmode=disable
    dsn: ""

auth:
  jwt_secret: "$(openssl rand -hex 32)"
  self_hosted: true
  server_secret: "$(openssl rand -hex 24)"
EOF
  chown root:"$SERVICE_USER" "$CONFIG_FILE"
  chmod 640 "$CONFIG_FILE"
  success "Конфиг создан: ${CONFIG_FILE}"
else
  warn "Конфиг уже существует, не перезаписываем: ${CONFIG_FILE}"
fi

# --- Предлагаем установить systemd ---
echo ""
read -r -p "$(echo -e "${YELLOW}[SubRadar]${NC} Установить systemd-сервис для автозапуска? [Y/n] ")" INSTALL_SYSTEMD
INSTALL_SYSTEMD=${INSTALL_SYSTEMD:-Y}

if [[ "$INSTALL_SYSTEMD" =~ ^[Yy]$ ]]; then
  SERVICE_FILE="/etc/systemd/system/subradar.service"
  info "Создаём systemd-сервис..."
  cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=SubRadar Backend
Documentation=https://github.com/${REPO}
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
ExecStart=${INSTALL_DIR}/${BINARY_NAME} --config=${CONFIG_FILE}
Restart=on-failure
RestartSec=5s

# Безопасность
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${DATA_DIR}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable subradar
  systemctl start subradar

  sleep 2
  if systemctl is-active --quiet subradar; then
    success "Сервис запущен и добавлен в автозапуск"
  else
    warn "Сервис установлен, но не запустился. Проверьте: journalctl -u subradar -n 50"
  fi
fi

# --- Итог ---
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   SubRadar ${VERSION} установлен!       ${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "  Бинарник:  ${BLUE}${INSTALL_DIR}/${BINARY_NAME}${NC}"
echo -e "  Конфиг:    ${BLUE}${CONFIG_FILE}${NC}"
echo -e "  Данные:    ${BLUE}${DATA_DIR}${NC}"
echo ""
echo -e "  Полезные команды:"
echo -e "    ${YELLOW}subradar --version${NC}               — версия"
echo -e "    ${YELLOW}systemctl status subradar${NC}        — статус сервиса"
echo -e "    ${YELLOW}journalctl -u subradar -f${NC}        — логи в реальном времени"
echo -e "    ${YELLOW}nano ${CONFIG_FILE}${NC}   — редактировать конфиг"
echo ""
