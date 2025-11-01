#!/bin/bash

# ========================================
# Cursor Safe Reset Tool (macOS)
# ========================================
# БЕЗОПАСНЫЙ сброс БЕЗ удаления пользовательских данных
# НЕ трогает: настройки, расширения, workspace, историю
# ========================================

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Конфигурация
CURSOR_BASE="$HOME/Library/Application Support/Cursor"
STORAGE_FILE="$CURSOR_BASE/User/globalStorage/storage.json"
BACKUP_DIR="$CURSOR_BASE/User/globalStorage/backups"

# Лого
show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${GREEN}Cursor Safe Reset Tool (macOS)${CYAN}  ║${NC}"
    echo -e "${CYAN}║  ${YELLOW}БЕЗ удаления пользовательских данных${CYAN} ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════╝${NC}"
    echo
}

# Логирование
log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[→]${NC} $1"
}

# Проверка системы
check_system() {
    log_step "Проверка системы..."
    
    if [[ $(uname) != "Darwin" ]]; then
        log_error "Этот скрипт только для macOS!"
        exit 1
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Требуется Python3!"
        log_warn "Установите: brew install python3"
        exit 1
    fi
    
    log_info "macOS ✓"
    log_info "Python3 ✓"
}

# Закрытие Cursor
close_cursor() {
    log_step "Закрытие Cursor..."
    
    pkill -f "Cursor" 2>/dev/null || true
    sleep 2
    
    if pgrep -f "Cursor" >/dev/null; then
        pkill -9 -f "Cursor" 2>/dev/null || true
        sleep 2
    fi
    
    log_info "Cursor закрыт"
}

# Проверка файлов
check_files() {
    log_step "Проверка структуры..."
    
    if [ ! -f "$STORAGE_FILE" ]; then
        log_error "storage.json не найден!"
        log_warn "Запусти Cursor один раз для создания конфигурации"
        exit 1
    fi
    
    log_info "Файлы найдены"
}

# Бэкап (только критичных файлов)
backup_data() {
    log_step "Создание бэкапа..."
    
    mkdir -p "$BACKUP_DIR"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/storage.backup_$timestamp.json"
    
    if cp "$STORAGE_FILE" "$backup_file"; then
        chmod 644 "$backup_file"
        log_info "Бэкап создан: storage.backup_$timestamp.json"
        return 0
    else
        log_error "Ошибка создания бэкапа!"
        exit 1
    fi
}

# Генерация ID (актуальный метод 2024)
generate_new_ids() {
    # machineId - 64 hex (SHA-256 style)
    MACHINE_ID=$(openssl rand -hex 32)
    
    # macMachineId - 64 hex (SHA-256 style)
    MAC_MACHINE_ID=$(openssl rand -hex 32)
    
    # devDeviceId - UUID lowercase
    DEV_DEVICE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    
    # sqmId - UUID uppercase с {}
    SQM_ID="{$(uuidgen)}"
}

# Редактирование storage.json (все telemetry ID)
edit_storage_json() {
    log_step "Изменение Machine ID..."
    
    generate_new_ids
    
    python3 -c "
import json
import sys

try:
    with open('$STORAGE_FILE', 'r', encoding='utf-8') as f:
        config = json.load(f)
    
    # Меняем ВСЕ telemetry ID (критично для новых версий)
    config['telemetry.machineId'] = '$MACHINE_ID'
    config['telemetry.macMachineId'] = '$MAC_MACHINE_ID'
    config['telemetry.devDeviceId'] = '$DEV_DEVICE_ID'
    config['telemetry.sqmId'] = '$SQM_ID'
    
    with open('$STORAGE_FILE', 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2, ensure_ascii=False)
    
    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
"
    
    if [ $? -eq 0 ]; then
        log_info "Machine ID изменён"
        return 0
    else
        log_error "Ошибка изменения!"
        return 1
    fi
}

# Очистка ВСЕХ tracking кэшей (усиленная версия 2024)
clean_tracking_caches() {
    log_step "Глубокая очистка кэшей отслеживания..."
    
    local cleaned=0
    
    # 1. Cursor Caches (НЕ трогаем CachedData с расширениями!)
    local cache_dirs=(
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/Cache"
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/Code Cache"
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/DawnCache"
        "$CURSOR_BASE/GPUCache"
        "$CURSOR_BASE/CachedExtensionVSIXs"
        "$CURSOR_BASE/Cache"
        "$CURSOR_BASE/Code Cache"
    )
    
    for dir in "${cache_dirs[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir" 2>/dev/null && ((cleaned++)) || true
        fi
    done
    
    # 2. IndexedDB / LocalStorage / Session Storage (tracking данные)
    local storage_patterns=(
        "$CURSOR_BASE/Local Storage/leveldb"
        "$CURSOR_BASE/IndexedDB"
        "$CURSOR_BASE/Session Storage"
    )
    
    for pattern in "${storage_patterns[@]}"; do
        if [ -e "$pattern" ]; then
            rm -rf "$pattern" 2>/dev/null && ((cleaned++)) || true
        fi
    done
    
    # 3. Cookies (могут содержать telemetry tracking)
    local cookie_paths=(
        "$CURSOR_BASE/Cookies"
        "$CURSOR_BASE/Cookies-journal"
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/Cookies"
    )
    
    for cookie in "${cookie_paths[@]}"; do
        if [ -e "$cookie" ]; then
            rm -rf "$cookie" 2>/dev/null && ((cleaned++)) || true
        fi
    done
    
    # 4. Network Cache (могут хранить tracking запросы)
    local network_caches=(
        "$CURSOR_BASE/Network Persistent State"
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/NetworkCache"
    )
    
    for cache in "${network_caches[@]}"; do
        if [ -e "$cache" ]; then
            rm -rf "$cache" 2>/dev/null && ((cleaned++)) || true
        fi
    done
    
    # 5. Blob Storage (может содержать tracking данные)
    if [ -d "$CURSOR_BASE/blob_storage" ]; then
        rm -rf "$CURSOR_BASE/blob_storage" 2>/dev/null && ((cleaned++)) || true
    fi
    
    log_info "Глубокая очистка: $cleaned элементов"
}

# Показать что НЕ было тронуто
show_preserved() {
    echo
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ${CYAN}Сохранены пользовательские данные:${GREEN}        ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  ✓ Настройки редактора (settings.json)       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ Установленные расширения                  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ Workspace данные                          ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ История файлов                            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}  ✓ Snippets и keybindings                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
    echo
}

# Показать новые ID
show_new_ids() {
    echo
    echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${YELLOW}Новые идентификаторы:${BLUE}                       ║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC}  machineId: ${MACHINE_ID:0:30}...    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  macMachineId: ${MAC_MACHINE_ID:0:27}...    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  devDeviceId: $DEV_DEVICE_ID  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}  sqmId: $SQM_ID ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
    echo
}

# Главная функция
main() {
    show_header
    
    # Проверки
    check_system
    echo
    check_files
    echo
    
    # Закрыть Cursor
    close_cursor
    echo
    
    # Бэкап
    backup_data
    echo
    
    # Изменение storage.json
    if ! edit_storage_json; then
        log_error "Не удалось изменить storage.json"
        exit 1
    fi
    echo
    
    # Очистка кэшей
    clean_tracking_caches
    
    # Показать результаты
    show_new_ids
    show_preserved
    
    # Финал
    echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ${CYAN}✅ ГОТОВО! Запусти Cursor${GREEN}                    ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
    echo
    log_info "Бэкап хранится в: $BACKUP_DIR"
    echo
}

main "$@"

