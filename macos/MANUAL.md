# 🔧 Ручная инструкция для macOS

Если автоматический скрипт не работает или хочешь контроль — используй ручной метод.

---

## 📋 Шаг 1: Закрой Cursor полностью

Убедись что Cursor не запущен:

```bash
killall Cursor
```

---

## 🧹 Шаг 2: Очисти кэши (БЕЗ удаления настроек!)

Открой **Терминал** и выполни:

```bash
# Закрыть Cursor (если забыл)
killall Cursor

# Очистить кэши отслеживания
rm -rf ~/Library/Caches/com.todesktop.230313mzl4w4u92/Cache
rm -rf ~/Library/Caches/com.todesktop.230313mzl4w4u92/Code\ Cache
rm -rf ~/Library/Application\ Support/Cursor/GPUCache
rm -rf ~/Library/Application\ Support/Cursor/CachedExtensionVSIXs

# Очистить IndexedDB и LocalStorage
rm -rf ~/Library/Application\ Support/Cursor/Local\ Storage/leveldb
rm -rf ~/Library/Application\ Support/Cursor/IndexedDB
rm -rf ~/Library/Application\ Support/Cursor/Session\ Storage
```

---

## 📝 Шаг 3: Открой storage.json

```bash
open -a TextEdit ~/Library/Application\ Support/Cursor/User/globalStorage/storage.json
```

Откроется файл в TextEdit.

---

## 🔑 Шаг 4: Сгенерируй новые ID

В том же Терминале выполни команды по очереди:

### machineId (64 символа):

```bash
openssl rand -hex 32
```

**Пример результата:** `a1b2c3d4e5f6...` (64 символа)

### macMachineId (64 символа):

```bash
openssl rand -hex 32
```

**Пример результата:** `f6e5d4c3b2a1...` (64 символа)

### devDeviceId (UUID lowercase):

```bash
uuidgen | tr '[:upper:]' '[:lower:]'
```

**Пример результата:** `123e4567-e89b-12d3-a456-426614174000`

### sqmId (UUID с фигурными скобками):

```bash
echo "{$(uuidgen)}"
```

**Пример результата:** `{123E4567-E89B-12D3-A456-426614174000}`

---

## 🔄 Шаг 5: Замени ID в storage.json

В открытом файле **storage.json** найди строки и замени значения:

### Было:

```json
{
  "telemetry.machineId": "старое_значение_64_символа",
  "telemetry.macMachineId": "старое_значение_64_символа",
  "telemetry.devDeviceId": "старый-uuid-в-lowercase",
  "telemetry.sqmId": "{СТАРЫЙ-UUID-В-UPPERCASE}"
}
```

### Стало (вставь СВОИ сгенерированные значения):

```json
{
  "telemetry.machineId": "a1b2c3d4e5f6...",
  "telemetry.macMachineId": "f6e5d4c3b2a1...",
  "telemetry.devDeviceId": "123e4567-e89b-12d3-a456-426614174000",
  "telemetry.sqmId": "{123E4567-E89B-12D3-A456-426614174000}"
}
```

**Сохрани файл:** `Cmd + S`

---

## ✅ Шаг 6: Запусти Cursor

Открой Cursor — готово! 🎉

---

## 🛡️ Что мы НЕ трогали:

✅ Настройки редактора (settings.json)  
✅ Расширения  
✅ Workspace и проекты  
✅ Историю файлов  
✅ Keybindings и snippets

Удалили **только** кэши отслеживания и изменили telemetry ID.

---

## ❓ Проблемы?

### storage.json не открывается

Проверь что путь правильный:

```bash
ls -la ~/Library/Application\ Support/Cursor/User/globalStorage/storage.json
```

Если файла нет — запусти Cursor один раз, потом закрой и повтори.

### Cursor не запускается после изменений

Восстанови из бэкапа (если делал):

```bash
cp ~/Library/Application\ Support/Cursor/User/globalStorage/backups/storage.backup_*.json ~/Library/Application\ Support/Cursor/User/globalStorage/storage.json
```

Или удали storage.json и дай Cursor создать новый:

```bash
rm ~/Library/Application\ Support/Cursor/User/globalStorage/storage.json
```

---

## 💡 Совет

Если делаешь вручную часто — сохрани команды генерации ID в отдельный скрипт:

```bash
echo "#!/bin/bash
echo 'machineId:'
openssl rand -hex 32
echo ''
echo 'macMachineId:'
openssl rand -hex 32
echo ''
echo 'devDeviceId:'
uuidgen | tr '[:upper:]' '[:lower:]'
echo ''
echo 'sqmId:'
echo \"{$(uuidgen)}\"
" > ~/generate-cursor-ids.sh

chmod +x ~/generate-cursor-ids.sh
```

Теперь просто:

```bash
~/generate-cursor-ids.sh
```

---

**Успехов!** 🚀
