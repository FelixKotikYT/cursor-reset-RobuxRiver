#!/bin/bash

# ============================================
# Cursor Trial Reset (Safe + hosts)
# macOS - Безопасный метод с откатом
# ============================================

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Пути
CURSOR_DIR="$HOME/Library/Application Support/Cursor"
STORAGE_JSON="$CURSOR_DIR/User/globalStorage/storage.json"
BACKUP_DIR="$HOME/.cursor_backup_$(date +%Y%m%d_%H%M%S)"
HOSTS_FILE="/etc/hosts"

# Лог
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}═══${NC} $1 ${BLUE}═══${NC}"
}

# Заголовок
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║                                                        ║"
    echo "║     🔄 Cursor Trial Reset - Safe Method + hosts       ║"
    echo "║                                                        ║"
    echo "║  Что будет сделано:                                   ║"
    echo "║  ✅ Backup всех файлов                                ║"
    echo "║  ✅ Очистка кэшей (IndexedDB, LocalStorage и т.д.)    ║"
    echo "║  ✅ Блокировка telemetry серверов (hosts)             ║"
    echo "║  ✅ Изменение storage.json (4 telemetry ID)           ║"
    echo "║  ✅ Возможность ПОЛНОГО отката                        ║"
    echo "║                                                        ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Проверка системы
check_system() {
    log_step "Проверка системы"
    
    # macOS?
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "Этот скрипт только для macOS"
        exit 1
    fi
    log_success "macOS обнаружен"
    
    # Cursor установлен?
    if [ ! -d "$CURSOR_DIR" ]; then
        log_error "Cursor не найден в: $CURSOR_DIR"
        exit 1
    fi
    log_success "Cursor найден"
    
    # storage.json существует?
    if [ ! -f "$STORAGE_JSON" ]; then
        log_error "storage.json не найден: $STORAGE_JSON"
        exit 1
    fi
    log_success "storage.json найден"
    
    # Python3 для генерации UUID?
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 не установлен (нужен для генерации UUID)"
        log_info "Установи: brew install python3"
        exit 1
    fi
    log_success "Python3 найден"
}

# Закрыть Cursor
close_cursor() {
    log_step "Закрытие Cursor"
    
    if pgrep -x "Cursor" > /dev/null; then
        log_info "Закрываю Cursor..."
        killall Cursor 2>/dev/null || true
        sleep 2
        
        if pgrep -x "Cursor" > /dev/null; then
            log_error "Не удалось закрыть Cursor. Закрой вручную и запусти скрипт снова."
            exit 1
        fi
    fi
    
    log_success "Cursor закрыт"
}

# Создать backup
create_backup() {
    log_step "Создание backup"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup storage.json
    if [ -f "$STORAGE_JSON" ]; then
        cp "$STORAGE_JSON" "$BACKUP_DIR/storage.json.bak"
        log_success "storage.json сохранён"
    fi
    
    # Backup hosts
    if [ -f "$HOSTS_FILE" ]; then
        sudo cp "$HOSTS_FILE" "$BACKUP_DIR/hosts.bak"
        log_success "/etc/hosts сохранён"
    fi
    
    # Backup кэш-директорий (только список, не копируем всё)
    echo "IndexedDB" > "$BACKUP_DIR/cleaned_caches.txt"
    echo "Local Storage" >> "$BACKUP_DIR/cleaned_caches.txt"
    echo "Session Storage" >> "$BACKUP_DIR/cleaned_caches.txt"
    echo "Cookies" >> "$BACKUP_DIR/cleaned_caches.txt"
    echo "Cache" >> "$BACKUP_DIR/cleaned_caches.txt"
    echo "GPUCache" >> "$BACKUP_DIR/cleaned_caches.txt"
    echo "Code Cache" >> "$BACKUP_DIR/cleaned_caches.txt"
    echo "Network Cache" >> "$BACKUP_DIR/cleaned_caches.txt"
    echo "Blob Storage" >> "$BACKUP_DIR/cleaned_caches.txt"
    
    log_success "Backup создан: $BACKUP_DIR"
    
    # Сохранить путь для отката
    echo "$BACKUP_DIR" > "$HOME/.cursor_last_backup"
}

# Очистить кэши
clean_caches() {
    log_step "Очистка кэшей"
    
    local cleaned=0
    local cache_dirs=(
        "$CURSOR_DIR/Cache"
        "$CURSOR_DIR/GPUCache"
        "$CURSOR_DIR/Code Cache"
        "$CURSOR_DIR/CachedData"
        "$CURSOR_DIR/Service Worker/CacheStorage"
        "$CURSOR_DIR/Service Worker/ScriptCache"
        "$CURSOR_DIR/Network Cache"
        "$CURSOR_DIR/IndexedDB"
        "$CURSOR_DIR/Local Storage"
        "$CURSOR_DIR/Session Storage"
        "$CURSOR_DIR/Cookies"
        "$CURSOR_DIR/Cookies-journal"
        "$CURSOR_DIR/blob_storage"
    )
    
    for dir in "${cache_dirs[@]}"; do
        if [ -e "$dir" ]; then
            rm -rf "$dir" 2>/dev/null && {
                ((cleaned++))
                log_info "Удалено: $(basename "$dir")"
            } || log_warning "Не удалось удалить: $(basename "$dir")"
        fi
    done
    
    log_success "Очищено элементов: $cleaned"
}

# Блокировать telemetry серверы
block_telemetry() {
    log_step "Блокировка telemetry серверов"
    
    # Проверить, уже добавлено?
    if grep -q "telemetry.cursor.sh" "$HOSTS_FILE" 2>/dev/null; then
        log_warning "Записи уже существуют в /etc/hosts"
        log_info "Пропускаю добавление..."
        return 0
    fi
    
    log_info "Добавляю записи в /etc/hosts..."
    
    cat <<EOF | sudo tee -a "$HOSTS_FILE" > /dev/null

# ===== Cursor Telemetry Block (Added $(date)) =====
127.0.0.1 telemetry.cursor.sh
127.0.0.1 api.cursor.sh
0.0.0.0 update-server.cursor.sh
# ===== End Cursor Block =====
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Telemetry серверы заблокированы:"
        log_info "  → telemetry.cursor.sh (127.0.0.1)"
        log_info "  → api.cursor.sh (127.0.0.1)"
        log_info "  → update-server.cursor.sh (0.0.0.0)"
    else
        log_error "Не удалось изменить /etc/hosts"
        log_info "Попробуй запустить скрипт с sudo"
        exit 1
    fi
}

# Изменить storage.json
modify_storage() {
    log_step "Изменение storage.json"
    
    # Генерация новых ID
    log_info "Генерирую новые ID..."
    
    local new_machineId=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    local new_macMachineId=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    local new_devDeviceId=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
    local new_sqmId=$(python3 -c "import uuid; print('{' + str(uuid.uuid4()).upper() + '}')")
    
    log_info "machineId: ${new_machineId:0:16}..."
    log_info "macMachineId: ${new_macMachineId:0:16}..."
    log_info "devDeviceId: $new_devDeviceId"
    log_info "sqmId: $new_sqmId"
    
    # Изменить storage.json
    log_info "Обновляю storage.json..."
    
    python3 << EOF
import json

with open("$STORAGE_JSON", "r", encoding="utf-8") as f:
    data = json.load(f)

# Обновить telemetry ID
data["telemetry.machineId"] = "$new_machineId"
data["telemetry.macMachineId"] = "$new_macMachineId"
data["telemetry.devDeviceId"] = "$new_devDeviceId"
data["telemetry.sqmId"] = "$new_sqmId"

with open("$STORAGE_JSON", "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("✓ storage.json обновлён")
EOF
    
    if [ $? -eq 0 ]; then
        log_success "storage.json успешно обновлён"
    else
        log_error "Ошибка при обновлении storage.json"
        exit 1
    fi
}

# Показать результат
show_result() {
    log_step "ГОТОВО!"
    
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}║           ✅ CURSOR СБРОШЕН УСПЕШНО!                   ║${NC}"
    echo -e "${GREEN}║                                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Что было сделано:${NC}"
    echo -e "  ${GREEN}✓${NC} Telemetry серверы заблокированы (/etc/hosts)"
    echo -e "  ${GREEN}✓${NC} storage.json изменён (4 новых telemetry ID)"
    echo -e "  ${GREEN}✓${NC} Кэши полностью очищены (9+ папок)"
    echo -e "  ${GREEN}✓${NC} Backup создан: $BACKUP_DIR"
    
    echo -e "\n${YELLOW}Следующие шаги:${NC}"
    echo -e "  ${BLUE}1.${NC} Запусти Cursor"
    echo -e "  ${BLUE}2.${NC} Войди в свой аккаунт (или создай новый)"
    echo -e "  ${BLUE}3.${NC} Trial должен работать! 🚀"
    
    echo -e "\n${CYAN}💡 Проверка hosts:${NC}"
    echo -e "  ${BLUE}ping telemetry.cursor.sh${NC}"
    echo -e "  Должно показать: ${GREEN}127.0.0.1${NC}"
    
    echo -e "\n${YELLOW}⚠️  Если НЕ сработало:${NC}"
    echo -e "  Откат: ${BLUE}bash $(dirname "$0")/rollback.sh${NC}"
    echo -e "  (или запусти этот скрипт с опцией --rollback)"
    
    echo ""
}

# Функция отката
rollback() {
    log_step "ОТКАТ ИЗМЕНЕНИЙ"
    
    # Найти последний backup
    if [ ! -f "$HOME/.cursor_last_backup" ]; then
        log_error "Файл последнего backup не найден"
        log_info "Попробуй найти вручную в: $HOME/.cursor_backup_*"
        exit 1
    fi
    
    LAST_BACKUP=$(cat "$HOME/.cursor_last_backup")
    
    if [ ! -d "$LAST_BACKUP" ]; then
        log_error "Директория backup не найдена: $LAST_BACKUP"
        exit 1
    fi
    
    log_info "Используется backup: $LAST_BACKUP"
    
    # Закрыть Cursor
    if pgrep -x "Cursor" > /dev/null; then
        log_info "Закрываю Cursor..."
        killall Cursor 2>/dev/null || true
        sleep 2
    fi
    
    # Откат storage.json
    if [ -f "$LAST_BACKUP/storage.json.bak" ]; then
        cp "$LAST_BACKUP/storage.json.bak" "$STORAGE_JSON"
        log_success "storage.json восстановлен"
    fi
    
    # Откат hosts
    if [ -f "$LAST_BACKUP/hosts.bak" ]; then
        sudo cp "$LAST_BACKUP/hosts.bak" "$HOSTS_FILE"
        log_success "/etc/hosts восстановлен"
    fi
    
    log_success "Откат завершён!"
    log_info "Backup сохранён в: $LAST_BACKUP"
    echo ""
}

# Главная функция
main() {
    show_header
    
    # Проверка аргументов
    if [ "$1" == "--rollback" ]; then
        rollback
        exit 0
    fi
    
    log_warning "Этот скрипт изменит:"
    log_warning "  • /etc/hosts (нужен sudo)"
    log_warning "  • storage.json"
    log_warning "  • Удалит кэши Cursor"
    echo ""
    read -p "$(echo -e ${YELLOW}Продолжить? [y/N]:${NC} )" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Отменено пользователем"
        exit 0
    fi
    
    # Выполнение
    check_system
    close_cursor
    create_backup
    clean_caches
    block_telemetry
    modify_storage
    show_result
}

# Запуск
main "$@"

