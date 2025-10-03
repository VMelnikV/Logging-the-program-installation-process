#!/bin/bash
# deb-watch-unified_EN.sh
# Using:
#   sudo ./deb-watch-unified.sh --deb gimp.deb
#   sudo ./deb-watch-unified.sh --apt gimp
#   sudo ./deb-watch-unified.sh --flatpak org.gimp.GIMP
#   sudo ./deb-watch-unified.sh --snap vlc
#   sudo ./deb-watch-unified.sh --gui
#
# All changes are logged in $TMPDIR

TMPDIR=$(mktemp -d)
LOG="$TMPDIR/changes.log"
FILES_REPORT="$TMPDIR/files_report.txt"

### ====== Checking the necessary tools ======
check_dependencies() {
    local missing=()
    for cmd in fatrace file diff; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "[ERROR] Missing necessary tools:"
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

# Calling the check at the beginning
check_dependencies


### ====== Checking root rights ======
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

### ====== User ======
RUN_USER=${SUDO_USER:-$(whoami)}

run_as_user() {
    local command="$1"
    echo "[*] Run as user: $RUN_USER"
    su - "$RUN_USER" -c "$command"
}

### ====== We start monitoring ======
echo "[*] Start monitoring file changes..."
fatrace -t -o "$LOG" &
MONITOR=$!

### ====== Basic logic ======
case "$MODE" in
    --deb)
        [ $# -ne 1 ] && usage
        DEB="$1"
        echo "[*] Installing a package from a file: $DEB"
        dpkg -i "$DEB"
        ;;
    --apt)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Installing the package via apt: $PKG"
        apt-get install -y "$PKG"
        ;;
    --flatpak)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Installing from Flatpak: $PKG"
        flatpak install -y "$PKG"
        ;;
    --snap)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Installing with Snap: $PKG"
        snap install "$PKG"
        ;;
    --gui)
        echo "[*] GUI mode: open Software Manager and install the program"
        echo "[*] Once the installation is complete, press Enter in this terminal."
        read -p "[*] Waiting for the GUI installation to complete..." dummy
        ;;
    *)
        usage
        ;;
esac

### ====== We are completing monitoring. ======
echo "[*] Stop monitoring..."
kill $MONITOR
wait $MONITOR 2>/dev/null

### ====== Analysis of results ======
> "$FILES_REPORT"
ALL_FILES=$(awk '{print $2}' "$LOG" | sort -u)

echo "========== FILES (NEW / CHANGED) ==========" >> "$FILES_REPORT"
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

        # If text file → show diff with previous state (if any)
        if [ "$STATUS" = "CHANGED" ] && file "$FILE" | grep -q 'text'; then
            SNAP_BEFORE="$TMPDIR/before$(echo "$FILE" | sed 's/\//_/g')"
            cp "$FILE" "$TMPDIR/after$(echo "$FILE" | sed 's/\//_/g')" 2>/dev/null
            if [ -f "$SNAP_BEFORE" ]; then
                echo ">>> DIFF $FILE" >> "$FILES_REPORT"
                diff -u "$SNAP_BEFORE" "$FILE" >> "$FILES_REPORT" 2>/dev/null || true
            else
                # We save the first picture so that we can compare later
                cp "$FILE" "$SNAP_BEFORE" 2>/dev/null
            fi
        fi
    fi
done

echo "========== FATrace LOG ==========" >> "$FILES_REPORT"
cat "$LOG" >> "$FILES_REPORT"

### ====== Results ======
echo "[*] Logs and results:"
echo "  Full log: $LOG"
echo "  File list and diff: $FILES_REPORT"
echo "[*] Temporary data: $TMPDIR"

echo "=== ADDITIONAL INFORMATION ===" >> "$FILES_REPORT"
echo "User root: $(whoami)" >> "$FILES_REPORT"
echo "Monitored user: $RUN_USER" >> "$FILES_REPORT"
