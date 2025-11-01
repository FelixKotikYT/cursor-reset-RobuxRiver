# ========================================
# Cursor Safe Reset Tool (Windows)
# ========================================
# БЕЗОПАСНЫЙ сброс БЕЗ удаления пользовательских данных
# НЕ трогает: настройки, расширения, workspace, историю
# ========================================

# Параметры выполнения
param(
    [switch]$Force = $false
)

# Проверка прав администратора
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ Требуются права администратора!" -ForegroundColor Red
    Write-Host "Запусти PowerShell от имени администратора" -ForegroundColor Yellow
    exit 1
}

# Конфигурация
$CURSOR_BASE = "$env:APPDATA\Cursor"
$STORAGE_FILE = "$CURSOR_BASE\User\globalStorage\storage.json"
$BACKUP_DIR = "$CURSOR_BASE\User\globalStorage\backups"

# Цвета (для красоты)
function Write-ColorText {
    param(
        [string]$Text,
        [string]$Color = "White",
        [string]$Prefix = ""
    )
    Write-Host "$Prefix$Text" -ForegroundColor $Color
}

# Логирование
function Log-Info { Write-ColorText -Text "[✓] $args" -Color Green }
function Log-Warn { Write-ColorText -Text "[!] $args" -Color Yellow }
function Log-Error { Write-ColorText -Text "[✗] $args" -Color Red }
function Log-Step { Write-ColorText -Text "[→] $args" -Color Cyan }

# Заголовок
function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  " -NoNewline -ForegroundColor Cyan
    Write-Host "Cursor Safe Reset Tool (Windows)" -NoNewline -ForegroundColor Green
    Write-Host "  ║" -ForegroundColor Cyan
    Write-Host "║  " -NoNewline -ForegroundColor Cyan
    Write-Host "БЕЗ удаления пользовательских данных" -NoNewline -ForegroundColor Yellow
    Write-Host " ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# Проверка системы
function Test-System {
    Log-Step "Проверка системы..."
    
    # Проверка Windows версии
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Log-Warn "Рекомендуется Windows 10 или выше"
    }
    
    Log-Info "Windows ✓"
    return $true
}

# Закрытие Cursor
function Stop-CursorProcess {
    Log-Step "Закрытие Cursor..."
    
    $cursorProcesses = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
    
    if ($cursorProcesses) {
        $cursorProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        # Проверка что закрылся
        $stillRunning = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
        if ($stillRunning) {
            Log-Warn "Cursor всё ещё работает, принудительное закрытие..."
            $stillRunning | Stop-Process -Force
            Start-Sleep -Seconds 2
        }
    }
    
    Log-Info "Cursor закрыт"
    return $true
}

# Проверка файлов
function Test-Files {
    Log-Step "Проверка структуры..."
    
    if (-not (Test-Path $STORAGE_FILE)) {
        Log-Error "storage.json не найден!"
        Log-Warn "Запусти Cursor один раз для создания конфигурации"
        return $false
    }
    
    Log-Info "Файлы найдены"
    return $true
}

# Бэкап
function Backup-Storage {
    Log-Step "Создание бэкапа..."
    
    # Создать папку для бэкапов
    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$BACKUP_DIR\storage.backup_$timestamp.json"
    
    try {
        Copy-Item -Path $STORAGE_FILE -Destination $backupFile -Force
        Log-Info "Бэкап создан: storage.backup_$timestamp.json"
        return $true
    }
    catch {
        Log-Error "Ошибка создания бэкапа: $_"
        return $false
    }
}

# Генерация новых ID
function New-DeviceIDs {
    # machineId - 64 hex (SHA-256 style)
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
    $machineId = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
    
    # macMachineId - 64 hex (SHA-256 style)
    $bytes2 = New-Object byte[] 32
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes2)
    $macMachineId = [System.BitConverter]::ToString($bytes2).Replace("-", "").ToLower()
    
    # devDeviceId - UUID lowercase
    $devDeviceId = [guid]::NewGuid().ToString().ToLower()
    
    # sqmId - UUID uppercase с фигурными скобками
    $sqmId = "{$([guid]::NewGuid().ToString().ToUpper())}"
    
    return @{
        machineId = $machineId
        macMachineId = $macMachineId
        devDeviceId = $devDeviceId
        sqmId = $sqmId
    }
}

# Редактирование storage.json
function Edit-StorageJson {
    Log-Step "Изменение Machine ID..."
    
    try {
        # Читаем JSON
        $config = Get-Content -Path $STORAGE_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Генерируем новые ID
        $newIds = New-DeviceIDs
        
        # Меняем ВСЕ telemetry ID (критично для новых версий)
        $config | Add-Member -MemberType NoteProperty -Name "telemetry.machineId" -Value $newIds.machineId -Force
        $config | Add-Member -MemberType NoteProperty -Name "telemetry.macMachineId" -Value $newIds.macMachineId -Force
        $config | Add-Member -MemberType NoteProperty -Name "telemetry.devDeviceId" -Value $newIds.devDeviceId -Force
        $config | Add-Member -MemberType NoteProperty -Name "telemetry.sqmId" -Value $newIds.sqmId -Force
        
        # Сохраняем обратно
        $config | ConvertTo-Json -Depth 100 | Set-Content -Path $STORAGE_FILE -Encoding UTF8
        
        Log-Info "Machine ID изменён"
        
        # Возвращаем новые ID для отображения
        return $newIds
    }
    catch {
        Log-Error "Ошибка изменения: $_"
        return $null
    }
}

# Очистка ТОЛЬКО кэшей отслеживания
function Clear-TrackingCaches {
    Log-Step "Очистка кэшей отслеживания..."
    
    $cleaned = 0
    
    # Cursor Caches (НЕ трогаем CachedData с расширениями!)
    $cacheDirs = @(
        "$env:LOCALAPPDATA\cursor-updater\pending",
        "$CURSOR_BASE\Cache",
        "$CURSOR_BASE\Code Cache",
        "$CURSOR_BASE\GPUCache",
        "$CURSOR_BASE\CachedExtensionVSIXs"
    )
    
    foreach ($dir in $cacheDirs) {
        if (Test-Path $dir) {
            try {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
                $cleaned++
            }
            catch {
                # Игнорируем ошибки
            }
        }
    }
    
    # IndexedDB / LocalStorage (БЕЗ workspace)
    $storagePaths = @(
        "$CURSOR_BASE\Local Storage",
        "$CURSOR_BASE\IndexedDB",
        "$CURSOR_BASE\Session Storage"
    )
    
    foreach ($path in $storagePaths) {
        if (Test-Path $path) {
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $cleaned++
            }
            catch {
                # Игнорируем ошибки
            }
        }
    }
    
    Log-Info "Очищено кэшей: $cleaned"
}

# Показать что НЕ было тронуто
function Show-Preserved {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  " -NoNewline -ForegroundColor Green
    Write-Host "Сохранены пользовательские данные:" -NoNewline -ForegroundColor Cyan
    Write-Host "        ║" -ForegroundColor Green
    Write-Host "╠═══════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║" -NoNewline -ForegroundColor Green
    Write-Host "  ✓ Настройки редактора (settings.json)       " -NoNewline
    Write-Host "║" -ForegroundColor Green
    Write-Host "║" -NoNewline -ForegroundColor Green
    Write-Host "  ✓ Установленные расширения                  " -NoNewline
    Write-Host "║" -ForegroundColor Green
    Write-Host "║" -NoNewline -ForegroundColor Green
    Write-Host "  ✓ Workspace данные                          " -NoNewline
    Write-Host "║" -ForegroundColor Green
    Write-Host "║" -NoNewline -ForegroundColor Green
    Write-Host "  ✓ История файлов                            " -NoNewline
    Write-Host "║" -ForegroundColor Green
    Write-Host "║" -NoNewline -ForegroundColor Green
    Write-Host "  ✓ Snippets и keybindings                    " -NoNewline
    Write-Host "║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

# Показать новые ID
function Show-NewIDs {
    param($ids)
    
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "║  " -NoNewline -ForegroundColor Blue
    Write-Host "Новые идентификаторы:" -NoNewline -ForegroundColor Yellow
    Write-Host "                       ║" -ForegroundColor Blue
    Write-Host "╠═══════════════════════════════════════════════╣" -ForegroundColor Blue
    Write-Host "║" -NoNewline -ForegroundColor Blue
    Write-Host "  machineId: $($ids.machineId.Substring(0,30))...    " -NoNewline
    Write-Host "║" -ForegroundColor Blue
    Write-Host "║" -NoNewline -ForegroundColor Blue
    Write-Host "  macMachineId: $($ids.macMachineId.Substring(0,27))...    " -NoNewline
    Write-Host "║" -ForegroundColor Blue
    Write-Host "║" -NoNewline -ForegroundColor Blue
    Write-Host "  devDeviceId: $($ids.devDeviceId)  " -NoNewline
    Write-Host "║" -ForegroundColor Blue
    Write-Host "║" -NoNewline -ForegroundColor Blue
    Write-Host "  sqmId: $($ids.sqmId) " -NoNewline
    Write-Host "║" -ForegroundColor Blue
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
}

# Главная функция
function Main {
    Show-Header
    
    # Проверки
    if (-not (Test-System)) { exit 1 }
    Write-Host ""
    
    if (-not (Test-Files)) { exit 1 }
    Write-Host ""
    
    # Закрыть Cursor
    if (-not (Stop-CursorProcess)) { exit 1 }
    Write-Host ""
    
    # Бэкап
    if (-not (Backup-Storage)) { exit 1 }
    Write-Host ""
    
    # Изменение storage.json
    $newIds = Edit-StorageJson
    if ($null -eq $newIds) {
        Log-Error "Не удалось изменить storage.json"
        exit 1
    }
    Write-Host ""
    
    # Очистка кэшей
    Clear-TrackingCaches
    
    # Показать результаты
    Show-NewIDs -ids $newIds
    Show-Preserved
    
    # Финал
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  " -NoNewline -ForegroundColor Green
    Write-Host "✅ ГОТОВО! Запусти Cursor" -NoNewline -ForegroundColor Cyan
    Write-Host "                    ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Log-Info "Бэкап хранится в: $BACKUP_DIR"
    Write-Host ""
}

# Запуск
Main

