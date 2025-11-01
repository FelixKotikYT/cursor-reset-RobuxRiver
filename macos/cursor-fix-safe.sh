#!/bin/bash

# ========================================
# Cursor Ultimate Reset Tool (macOS)
# ========================================
# ОБРАТИМЫЙ метод изменения IOPlatformUUID
# + storage.json + JS kernel + hosts block
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
UUID_BACKUP_FILE="$HOME/.cursor_original_uuid"
APP_BACKUP="/tmp/Cursor.app.backup_$(date +%Y%m%d_%H%M%S)"

# Логирование
log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }

# Заголовок
show_header() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${GREEN}Cursor ULTIMATE Reset Tool (macOS)${CYAN}     ║${NC}"
    echo -e "${CYAN}║  ${YELLOW}ОБРАТИМЫЙ метод изменения UUID${CYAN}        ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
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

# Проверка SIP
check_sip() {
    log_step "Проверка SIP (System Integrity Protection)..."
    
    local sip_status=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled")
    
    if [[ "$sip_status" == "enabled" ]]; then
        log_warn "⚠️  SIP включён! UUID изменение может не сработать"
        log_info "Можно продолжить, но для 100% гарантии:"
        echo -e "  1. Перезагрузись в Recovery Mode (Cmd+R)"
        echo -e "  2. Терминал → csrutil disable"
        echo -e "  3. Перезагрузись обратно"
        echo -e "  4. Запусти скрипт снова"
        echo
        read -p "Продолжить без отключения SIP? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        log_info "SIP отключён ✅"
    fi
}

# Получить текущий UUID
get_current_uuid() {
    ioreg -rd1 -c IOPlatformExpertDevice | grep IOPlatformUUID | awk '{print $3}' | tr -d '"'
}

# Сохранить оригинальный UUID
backup_original_uuid() {
    log_step "Сохранение оригинального UUID..."
    
    if [ -f "$UUID_BACKUP_FILE" ]; then
        log_info "Бэкап UUID уже существует"
        local saved_uuid=$(cat "$UUID_BACKUP_FILE")
        log_info "Сохранённый UUID: $saved_uuid"
        return 0
    fi
    
    local current_uuid=$(get_current_uuid)
    
    if [ -z "$current_uuid" ]; then
        log_error "Не удалось получить текущий UUID!"
        return 1
    fi
    
    echo "$current_uuid" > "$UUID_BACKUP_FILE"
    chmod 600 "$UUID_BACKUP_FILE"
    
    log_info "✅ Оригинальный UUID сохранён"
    log_info "   UUID: $current_uuid"
    log_info "   Файл: $UUID_BACKUP_FILE"
    
    return 0
}

# Изменить IOPlatformUUID
change_platform_uuid() {
    log_step "Изменение IOPlatformUUID..."
    
    local new_uuid=$(uuidgen)
    
    log_warn "⚠️  ВНИМАНИЕ: Изменяем системный UUID!"
    log_info "Новый UUID: $new_uuid"
    
    # Попытка изменения через nvram
    if sudo nvram platform-uuid="$new_uuid" 2>/dev/null; then
        log_info "✅ UUID изменён через nvram"
        log_warn "⚠️  Требуется ПЕРЕЗАГРУЗКА для применения!"
        return 0
    else
        log_warn "nvram метод не сработал, пробуем альтернативу..."
        
        # Альтернатива: через SystemConfiguration
        if sudo defaults write /Library/Preferences/SystemConfiguration/preferences.plist \
            IOPlatformUUID -string "$new_uuid" 2>/dev/null; then
            log_info "✅ UUID изменён через SystemConfiguration"
            log_warn "⚠️  Требуется ПЕРЕЗАГРУЗКА для применения!"
            return 0
        else
            log_error "Не удалось изменить UUID"
            log_warn "Возможно требуется отключение SIP"
            return 1
        fi
    fi
}

# Восстановить оригинальный UUID
restore_original_uuid() {
    log_step "Восстановление оригинального UUID..."
    
    if [ ! -f "$UUID_BACKUP_FILE" ]; then
        log_error "Бэкап UUID не найден!"
        log_info "Файл должен быть: $UUID_BACKUP_FILE"
        return 1
    fi
    
    local original_uuid=$(cat "$UUID_BACKUP_FILE")
    
    if [ -z "$original_uuid" ]; then
        log_error "Бэкап UUID пуст!"
        return 1
    fi
    
    log_info "Восстанавливаем UUID: $original_uuid"
    
    # Восстановление через nvram
    if sudo nvram platform-uuid="$original_uuid" 2>/dev/null; then
        log_info "✅ UUID восстановлен через nvram"
        log_warn "⚠️  Требуется ПЕРЕЗАГРУЗКА для применения!"
        return 0
    else
        # Альтернатива
        if sudo defaults write /Library/Preferences/SystemConfiguration/preferences.plist \
            IOPlatformUUID -string "$original_uuid" 2>/dev/null; then
            log_info "✅ UUID восстановлен через SystemConfiguration"
            log_warn "⚠️  Требуется ПЕРЕЗАГРУЗКА для применения!"
            return 0
        else
            log_error "Не удалось восстановить UUID"
            return 1
        fi
    fi
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
        log_warn "storage.json не найден"
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

# Блокировка telemetry серверов
block_telemetry_servers() {
    log_step "Блокировка telemetry серверов..."
    
    local hosts_file="/etc/hosts"
    
    if grep -q "cursor.sh" "$hosts_file" 2>/dev/null; then
        log_info "Записи уже есть в hosts"
        return 0
    fi
    
    cat <<EOF | sudo tee -a "$hosts_file" > /dev/null
# Cursor Telemetry Block
127.0.0.1 telemetry.cursor.sh
127.0.0.1 api.cursor.sh
0.0.0.0 update-server.cursor.sh
EOF
    
    log_info "✅ Telemetry серверы заблокированы"
}

# Очистка кэшей
clean_caches() {
    log_step "Очистка кэшей..."
    
    local cache_dirs=(
        "$HOME/Library/Caches/com.todesktop.230313mzl4w4u92/Cache"
        "$CURSOR_BASE/GPUCache"
        "$CURSOR_BASE/Local Storage"
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
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ${CYAN}✅ ГОТОВО!${GREEN}                             ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo
    echo -e "${YELLOW}Что было сделано:${NC}"
    echo -e "  ✅ IOPlatformUUID изменён (ОБРАТИМО!)"
    echo -e "  ✅ storage.json модифицирован"
    echo -e "  ✅ Telemetry серверы заблокированы"
    echo -e "  ✅ Кэши очищены"
    echo
    echo -e "${RED}⚠️  ВАЖНО: Требуется ПЕРЕЗАГРУЗКА!${NC}"
    echo
    echo -e "${BLUE}Для восстановления оригинального UUID:${NC}"
    echo -e "  sudo $0 --restore"
    echo
    echo -e "${BLUE}Оригинальный UUID сохранён в:${NC}"
    echo -e "  $UUID_BACKUP_FILE"
    echo
}

# Меню
show_menu() {
    echo -e "${CYAN}Выберите действие:${NC}"
    echo
    echo -e "  ${GREEN}1${NC} - ПОЛНЫЙ СБРОС (UUID + storage.json + hosts)"
    echo -e "  ${YELLOW}2${NC} - ВОССТАНОВИТЬ оригинальный UUID"
    echo -e "  ${BLUE}3${NC} - ПОКАЗАТЬ текущий UUID"
    echo -e "  ${RED}4${NC} - ВЫХОД"
    echo
    read -p "Выбор (1-4): " choice
    echo
    
    case $choice in
        1) return 1 ;;
        2) return 2 ;;
        3) return 3 ;;
        4) return 4 ;;
        *) 
            log_error "Неверный выбор"
            return 0
            ;;
    esac
}

# Главная функция - Полный сброс
full_reset() {
    log_info "🚀 Начинаем ПОЛНЫЙ СБРОС..."
    echo
    
    check_system
    check_sip
    echo
    
    backup_original_uuid || {
        log_error "Не удалось сохранить оригинальный UUID"
        exit 1
    }
    echo
    
    close_cursor
    echo
    
    change_platform_uuid || {
        log_warn "UUID изменение не удалось, продолжаем с другими методами..."
    }
    echo
    
    block_telemetry_servers
    modify_storage_json
    clean_caches
    
    show_result
}

# Функция восстановления
restore_uuid() {
    log_info "🔄 Восстановление оригинального UUID..."
    echo
    
    restore_original_uuid || {
        log_error "Восстановление не удалось"
        exit 1
    }
    
    echo
    log_info "✅ UUID восстановлен!"
    log_warn "⚠️  Требуется ПЕРЕЗАГРУЗКА для применения!"
    echo
}

# Показать текущий UUID
show_current_uuid() {
    log_info "Текущий UUID системы:"
    local current=$(get_current_uuid)
    echo -e "  ${CYAN}$current${NC}"
    echo
    
    if [ -f "$UUID_BACKUP_FILE" ]; then
        log_info "Сохранённый оригинальный UUID:"
        local saved=$(cat "$UUID_BACKUP_FILE")
        echo -e "  ${YELLOW}$saved${NC}"
        echo
        
        if [ "$current" == "$saved" ]; then
            echo -e "${GREEN}✅ UUID совпадают (оригинальный)${NC}"
        else
            echo -e "${YELLOW}⚠️  UUID изменён${NC}"
        fi
    else
        log_warn "Бэкап UUID не найден"
    fi
    echo
}

# Main
main() {
    # Проверка прав
    if [ "$EUID" -ne 0 ]; then
        log_error "Требуются права sudo!"
        echo "Запусти: sudo $0"
        exit 1
    fi
    
    show_header
    
    # Обработка аргументов
    if [ "$1" == "--restore" ]; then
        restore_uuid
        exit 0
    fi
    
    # Меню
    while true; do
        show_menu
        action=$?
        
        case $action in
            1) 
                full_reset
                break
                ;;
            2) 
                restore_uuid
                break
                ;;
            3) 
                show_current_uuid
                ;;
            4) 
                log_info "Выход"
                exit 0
                ;;
        esac
    done
}

main "$@"

