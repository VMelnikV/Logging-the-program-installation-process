#!/bin/bash
# deb-watch-unified.sh
# Використання:
#   sudo ./deb-watch-unified.sh --deb gimp.deb
#   sudo ./deb-watch-unified.sh --apt gimp
#   sudo ./deb-watch-unified.sh --flatpak org.gimp.GIMP
#   sudo ./deb-watch-unified.sh --snap vlc
#   sudo ./deb-watch-unified.sh --gui
#
# Всі зміни логуються у $TMPDIR

TMPDIR=$(mktemp -d)
LOG="$TMPDIR/changes.log"
FILES_REPORT="$TMPDIR/files_report.txt"

### ====== Перевірка необхідних інструментів ======
check_dependencies() {
    local missing=()
    for cmd in fatrace file diff; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "[ERROR] Відсутні необхідні інструменти:"
        for m in "${missing[@]}"; do
            case "$m" in
                fatrace) echo "  fatrace → sudo apt install fatrace" ;;
                file)    echo "  file → sudo apt install file" ;;
                diff)    echo "  diff → sudo apt install diffutils" ;;
            esac
        done
        exit 1
    fi
}

# Викликаємо перевірку на початку
check_dependencies


### ====== Перевірка root прав ======
check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        echo "[ERROR] Скрипт потребує root-прав"
        echo "Запустіть: sudo $0 $@"
        exit 1
    fi
}

usage() {
    echo "Usage:"
    echo "  sudo $0 --deb package.deb"
    echo "  sudo $0 --apt package-name"
    echo "  sudo $0 --flatpak flatpak-app-id"
    echo "  sudo $0 --snap snap-name"
    echo "  sudo $0 --gui"
    exit 1
}

[ $# -lt 1 ] && usage
check_root_privileges

MODE=$1
shift

### ====== Користувач ======
RUN_USER=${SUDO_USER:-$(whoami)}

run_as_user() {
    local command="$1"
    echo "[*] Запускаємо від імені користувача: $RUN_USER"
    su - "$RUN_USER" -c "$command"
}

### ====== Запускаємо моніторинг ======
echo "[*] Запускаємо моніторинг файлових змін..."
fatrace -t -o "$LOG" &
MONITOR=$!

### ====== Основна логіка ======
case "$MODE" in
    --deb)
        [ $# -ne 1 ] && usage
        DEB="$1"
        echo "[*] Встановлюємо пакет з файлу: $DEB"
        dpkg -i "$DEB"
        ;;
    --apt)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Встановлюємо пакет через apt: $PKG"
        apt-get install -y "$PKG"
        ;;
    --flatpak)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Встановлюємо Flatpak: $PKG"
        flatpak install -y "$PKG"
        ;;
    --snap)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Встановлюємо Snap: $PKG"
        snap install "$PKG"
        ;;
    --gui)
        echo "[*] Режим GUI: відкрийте Software Manager і встановіть програму"
        echo "[*] Після завершення установки натисніть Enter у цьому терміналі."
        read -p "[*] Очікування завершення GUI установки..." dummy
        ;;
    *)
        usage
        ;;
esac

### ====== Завершуємо моніторинг ======
echo "[*] Зупиняємо моніторинг..."
kill $MONITOR
wait $MONITOR 2>/dev/null

### ====== Аналіз результатів ======
> "$FILES_REPORT"
ALL_FILES=$(awk '{print $2}' "$LOG" | sort -u)

echo "========== ФАЙЛИ (NEW / CHANGED) ==========" >> "$FILES_REPORT"
for FILE in $ALL_FILES; do
    [ ! -f "$FILE" ] && continue

    STATUS=""
    if grep -q "C $FILE" "$LOG"; then
        STATUS="NEW"
    elif grep -q "W $FILE" "$LOG"; then
        STATUS="CHANGED"
    fi

    if [ -n "$STATUS" ]; then
        echo "$STATUS $FILE" >> "$FILES_REPORT"

        # Якщо текстовий файл → показуємо diff з попереднім станом (якщо був)
        if [ "$STATUS" = "CHANGED" ] && file "$FILE" | grep -q 'text'; then
            SNAP_BEFORE="$TMPDIR/before$(echo "$FILE" | sed 's/\//_/g')"
            cp "$FILE" "$TMPDIR/after$(echo "$FILE" | sed 's/\//_/g')" 2>/dev/null
            if [ -f "$SNAP_BEFORE" ]; then
                echo ">>> DIFF $FILE" >> "$FILES_REPORT"
                diff -u "$SNAP_BEFORE" "$FILE" >> "$FILES_REPORT" 2>/dev/null || true
            else
                # Зберігаємо перший знімок, щоб потім можна було порівнювати
                cp "$FILE" "$SNAP_BEFORE" 2>/dev/null
            fi
        fi
    fi
done

echo "========== FATrace LOG ==========" >> "$FILES_REPORT"
cat "$LOG" >> "$FILES_REPORT"

### ====== Підсумки ======
echo "[*] Логи і результати:"
echo "  Повний лог: $LOG"
echo "  Список файлів і diff: $FILES_REPORT"
echo "[*] Тимчасові дані: $TMPDIR"

echo "=== ДОДАТКОВА ІНФОРМАЦІЯ ===" >> "$FILES_REPORT"
echo "Користувач root: $(whoami)" >> "$FILES_REPORT"
echo "Моніторований користувач: $RUN_USER" >> "$FILES_REPORT"
