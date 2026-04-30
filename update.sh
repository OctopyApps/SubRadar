#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SubRadar Backend — Update Script
# Usage: curl -fsSL https://raw.githubusercontent.com/OctopyApps/SubRadar/main/update.sh | sudo bash
# =============================================================================

REPO="OctopyApps/SubRadar"
BINARY_NAME="subradar"
INSTALL_DIR="/usr/local/bin"
CONFIG_FILE="/etc/subradar/config.yaml"

# --- Цвета ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[SubRadar]${NC} $1"; }
success() { echo -e "${GREEN}[SubRadar]${NC} $1"; }
warn()    { echo -e "${YELLOW}[SubRadar]${NC} $1"; }
error()   { echo -e "${RED}[SubRadar]${NC} $1"; exit 1; }

echo ""
echo -e "${BLUE}╔═══════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SubRadar Backend Updater      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════╝${NC}"
echo ""

# --- Проверка root ---
if [ "$EUID" -ne 0 ]; then
  error "Запустите скрипт с правами root: sudo bash update.sh"
fi

# --- Проверка что бэкенд вообще установлен ---
if [ ! -f "${INSTALL_DIR}/${BINARY_NAME}" ]; then
  error "SubRadar не установлен. Сначала запустите install.sh"
fi

# --- Текущая версия ---
CURRENT_VERSION=$("${INSTALL_DIR}/${BINARY_NAME}" --version 2>/dev/null || echo "неизвестна")
info "Текущая версия: ${CURRENT_VERSION}"

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
  version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases" \
    | grep '"tag_name"' \
    | grep 'backend/' \
    | head -1 \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
  if [ -z "$version" ]; then
    error "Не удалось получить последнюю версию с GitHub. Проверьте интернет-соединение."
  fi
  echo "$version"
}

ARCH=$(detect_arch)
info "Архитектура: linux-${ARCH}"

info "Получаем последнюю версию..."
LATEST_TAG=$(get_latest_version)
LATEST_VERSION="${LATEST_TAG#backend/}"
info "Последняя версия: ${LATEST_VERSION}"

# --- Проверяем не устарела ли версия ---
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
  success "У вас уже установлена последняя версия (${CURRENT_VERSION})"
  exit 0
fi

info "Обновляем ${CURRENT_VERSION} → ${LATEST_VERSION}"
echo ""

# --- Скачиваем новый бинарник ---
BINARY_FILE="${BINARY_NAME}-linux-${ARCH}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${BINARY_FILE}"

info "Скачиваем бинарник..."
TMP_FILE=$(mktemp)
if ! curl -fsSL "$DOWNLOAD_URL" -o "$TMP_FILE"; then
  rm -f "$TMP_FILE"
  error "Не удалось скачать бинарник. URL: ${DOWNLOAD_URL}"
fi

# --- Проверяем контрольную сумму ---
info "Проверяем контрольную сумму..."
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/checksums.txt"
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

# --- Останавливаем сервис ---
SERVICE_RUNNING=false
if systemctl is-active --quiet subradar 2>/dev/null; then
  SERVICE_RUNNING=true
  info "Останавливаем сервис..."
  systemctl stop subradar
fi

# --- Заменяем бинарник ---
info "Устанавливаем новый бинарник..."
install -m 755 "$TMP_FILE" "${INSTALL_DIR}/${BINARY_NAME}"
rm -f "$TMP_FILE"
success "Бинарник обновлён"

# --- Применяем миграции ---
if [ -f "$CONFIG_FILE" ]; then
  info "Применяем миграции базы данных..."
  if "${INSTALL_DIR}/${BINARY_NAME}" --config="$CONFIG_FILE" --migrate-only 2>/dev/null; then
    success "Миграции применены"
  else
    warn "Флаг --migrate-only не поддерживается — миграции применятся при старте сервиса"
  fi
else
  warn "Конфиг не найден (${CONFIG_FILE}), миграции применятся при старте сервиса"
fi

# --- Перезапускаем сервис ---
if [ "$SERVICE_RUNNING" = true ]; then
  info "Запускаем сервис..."
  systemctl start subradar

  sleep 2
  if systemctl is-active --quiet subradar; then
    success "Сервис запущен"
  else
    error "Сервис не запустился после обновления. Проверьте: journalctl -u subradar -n 50"
  fi
else
  warn "Сервис не был запущен до обновления — не запускаем автоматически"
  info "Запустить вручную: systemctl start subradar"
fi

# --- Итог ---
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   SubRadar обновлён до ${LATEST_VERSION}!         ${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Полезные команды:"
echo -e "    ${YELLOW}systemctl status subradar${NC}        — статус сервиса"
echo -e "    ${YELLOW}journalctl -u subradar -f${NC}        — логи в реальном времени"
echo ""
