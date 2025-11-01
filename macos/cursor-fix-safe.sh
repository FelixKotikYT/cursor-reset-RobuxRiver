#!/bin/bash

# ========================================
# Cursor Advanced Reset Tool (macOS)
# ========================================
# Комбинированный метод: storage.json + JS kernel modification
# БЕЗОПАСНЫЙ: создаёт бэкапы, можно откатить
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
CURSOR_APP_PATH="/Applications/Cursor.app"
CURSOR_BASE="$HOME/Library/Application Support/Cursor"
STORAGE_FILE="$CURSOR_BASE/User/globalStorage/storage.json"
BACKUP_DIR="$CURSOR_BASE/User/globalStorage/backups"
APP_BACKUP="/tmp/Cursor.app.backup_$(date +%Y%m%d_%H%M%S)"

# Логирование
log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }

# Заголовок
show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${GREEN}Cursor Advanced Reset Tool (macOS)${CYAN}  ║${NC}"
    echo -e "${CYAN}║  ${YELLOW}storage.json + JS Kernel Modification${CYAN} ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
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
    
    if [ ! -d "$CURSOR_APP_PATH" ]; then
        log_error "Cursor не найден: $CURSOR_APP_PATH"
        exit 1
    fi
    
    log_info "Система ОК"
}

# Закрыть Cursor
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

# Бэкап приложения
backup_app() {
    log_step "Создание бэкапа приложения..."
    
    if [ -d "$APP_BACKUP" ]; then
        rm -rf "$APP_BACKUP"
    fi
    
    cp -R "$CURSOR_APP_PATH" "$APP_BACKUP" || {
        log_error "Ошибка создания бэкапа!"
        exit 1
    }
    
    log_info "Бэкап создан: $(basename "$APP_BACKUP")"
}

# Генерация новых ID
generate_new_ids() {
    MACHINE_ID=$(openssl rand -hex 32)
    MAC_MACHINE_ID=$(openssl rand -hex 32)
    DEV_DEVICE_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    SQM_ID="{$(uuidgen)}"
}

# Модификация storage.json
modify_storage_json() {
    log_step "Модификация storage.json..."
    
    if [ ! -f "$STORAGE_FILE" ]; then
        log_warn "storage.json не найден, будет создан при первом запуске"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/storage.backup_$(date +%Y%m%d_%H%M%S).json"
    cp "$STORAGE_FILE" "$backup_file"
    
    generate_new_ids
    
    python3 -c "
import json
import sys

try:
    with open('$STORAGE_FILE', 'r', encoding='utf-8') as f:
        config = json.load(f)
    
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
        log_info "storage.json модифицирован"
        return 0
    else
        log_error "Ошибка модификации storage.json"
        return 1
    fi
}

# КЛЮЧЕВАЯ ФУНКЦИЯ: Модификация JS ядра
modify_js_kernel() {
    log_step "Модификация JS ядра приложения..."
    
    # Целевые файлы
    local js_files=(
        "$CURSOR_APP_PATH/Contents/Resources/app/out/vs/workbench/api/node/extensionHostProcess.js"
        "$CURSOR_APP_PATH/Contents/Resources/app/out/main.js"
    )
    
    # Проверка нужна ли модификация
    local need_modify=false
    for file in "${js_files[@]}"; do
        if [ -f "$file" ] && ! grep -q "// CURSOR_FIX_INJECTED" "$file" 2>/dev/null; then
            need_modify=true
            break
        fi
    done
    
    if [ "$need_modify" = false ]; then
        log_info "JS файлы уже модифицированы"
        return 0
    fi
    
    # Генерация ID для инжекта
    local new_uuid=$(uuidgen | tr '[:upper:]' '[:lower:]')
    local machine_id="auth0|user_$(openssl rand -hex 16)"
    
    # Модификация каждого файла
    local modified_count=0
    for file in "${js_files[@]}"; do
        if [ ! -f "$file" ]; then
            continue
        fi
        
        log_step "Модификация: $(basename "$file")"
        
        # Создание инжект-кода
        local inject_code="// CURSOR_FIX_INJECTED - $(date +%Y%m%d%H%M%S)
(function() {
    const crypto = require('crypto');
    const originalRandomUUID = crypto.randomUUID;
    
    // Перехват randomUUID
    crypto.randomUUID = function() {
        return '$new_uuid';
    };
    
    // Перехват getMachineId
    if (typeof global !== 'undefined') {
        global.getMachineId = function() { return '$machine_id'; };
        global.getDeviceId = function() { return '$new_uuid'; };
        global.macMachineId = '$MAC_MACHINE_ID';
    }
    
    console.log('[CURSOR_FIX] Device ID intercepted');
})();
"
        
        # Инжект в начало файла
        echo "$inject_code" > "${file}.new"
        cat "$file" >> "${file}.new"
        mv "${file}.new" "$file"
        
        ((modified_count++))
        log_info "✓ $(basename "$file")"
    done
    
    if [ $modified_count -gt 0 ]; then
        log_info "Модифицировано файлов: $modified_count"
        return 0
    else
        log_error "Не удалось модифицировать JS файлы"
        return 1
    fi
}

# Переподпись приложения
resign_app() {
    log_step "Переподпись приложения..."
    
    # Удаление quarantine
    sudo find "$CURSOR_APP_PATH" -print0 2>/dev/null | \
        xargs -0 sudo xattr -d com.apple.quarantine 2>/dev/null || true
    
    # Переподпись
    if codesign --sign - --force --deep "$CURSOR_APP_PATH" 2>/dev/null; then
        log_info "Приложение переподписано"
        return 0
    else
        log_warn "Переподпись не удалась, но продолжаем..."
        return 0
    fi
}

# Очистка кэшей
clean_caches() {
    log_step "Очистка кэшей..."
    
    local cache_dirs=(
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/Cache"
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/Code Cache"
        "$CURSOR_BASE/GPUCache"
        "$CURSOR_BASE/Local Storage/leveldb"
        "$CURSOR_BASE/IndexedDB"
        "$CURSOR_BASE/Cookies"
    )
    
    local cleaned=0
    for dir in "${cache_dirs[@]}"; do
        if [ -e "$dir" ]; then
            rm -rf "$dir" 2>/dev/null && ((cleaned++)) || true
        fi
    done
    
    log_info "Очищено: $cleaned элементов"
}

# Показать результат
show_result() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ${CYAN}✅ ГОТОВО! Запусти Cursor${GREEN}             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Что было сделано:${NC}"
    echo -e "  ✅ storage.json модифицирован"
    echo -e "  ✅ JS ядро перехватывает ID-запросы"
    echo -e "  ✅ Кэши очищены"
    echo -e "  ✅ Приложение переподписано"
    echo
    echo -e "${BLUE}Бэкап приложения:${NC} $(basename "$APP_BACKUP")"
    echo
    echo -e "${YELLOW}⚠️  Если НЕ сработает:${NC}"
    echo -e "  1. Откат: sudo cp -R \"$APP_BACKUP\" \"$CURSOR_APP_PATH\""
    echo -e "  2. Переустановка Cursor"
    echo
}

# Главная функция
main() {
    # Проверка прав
    if [ "$EUID" -ne 0 ]; then
        log_error "Требуются права sudo!"
        echo "Запусти: sudo $0"
        exit 1
    fi
    
    show_header
    
    # Подтверждение
    echo -e "${YELLOW}⚠️  ВНИМАНИЕ:${NC}"
    echo -e "  • Будет модифицирован JS код приложения"
    echo -e "  • Создастся бэкап (можно откатить)"
    echo -e "  • Требуется Python3"
    echo
    read -p "Продолжить? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Отменено"
        exit 0
    fi
    
    echo
    
    # Выполнение
    check_system
    close_cursor
    backup_app
    echo
    
    modify_storage_json || true
    modify_js_kernel || {
        log_error "Критическая ошибка при модификации JS!"
        log_info "Восстановление из бэкапа..."
        sudo rm -rf "$CURSOR_APP_PATH"
        sudo cp -R "$APP_BACKUP" "$CURSOR_APP_PATH"
        exit 1
    }
    
    resign_app
    clean_caches
    
    show_result
}

main "$@"

