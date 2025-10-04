#!/bin/bash
# deb-watch-unified.sh
# Usage:
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
DEB_PATHS="$TMPDIR/deb_files_paths.txt"

### ====== Check required tools ======
check_dependencies() {
    local missing=()
    for cmd in fatrace file diff; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "[ERROR] Missing required tools:"
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

# Run dependency check at start
check_dependencies

### ====== Root privilege check ======
check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        echo "[ERROR] This script requires root privileges"
        echo "Run: sudo $0 $@"
        exit 1
    fi
}

### ====== Analyze DEB package paths ======
show_deb_file_paths() {
    local DEB_FILE="$1"
    
    echo "[*] Analyzing DEB package: $DEB_FILE"
    echo "[*] Files will be placed at the following paths:"
    echo "========== FILE PATHS FROM DEB PACKAGE ==========" > "$DEB_PATHS"
    
    if [ ! -f "$DEB_FILE" ]; then
        echo "[ERROR] File $DEB_FILE not found" | tee -a "$DEB_PATHS"
        return 1
    fi
    
    echo "=== Package information ===" >> "$DEB_PATHS"
    dpkg-deb -I "$DEB_FILE" >> "$DEB_PATHS" 2>/dev/null || echo "Unable to retrieve package info" >> "$DEB_PATHS"
    
    echo "" >> "$DEB_PATHS"
    echo "=== Name, version, architecture ===" >> "$DEB_PATHS"
    dpkg-deb -W --showformat='${Package} ${Version} ${Architecture}\n' "$DEB_FILE" >> "$DEB_PATHS" 2>/dev/null || echo "Unable to retrieve name and version" >> "$DEB_PATHS"
    
    echo "" >> "$DEB_PATHS"
    echo "=== FILES TO BE INSTALLED ===" >> "$DEB_PATHS"
    echo "These files will be placed in the filesystem:" >> "$DEB_PATHS"
    dpkg-deb -c "$DEB_FILE" >> "$DEB_PATHS" 2>/dev/null || echo "Unable to list package files" >> "$DEB_PATHS"
    
    echo ""
    echo "=== FILE PATHS TO BE INSTALLED ==="
    dpkg-deb -c "$DEB_FILE" 2>/dev/null | head -20
    local total_files=$(dpkg-deb -c "$DEB_FILE" 2>/dev/null | wc -l)
    echo "... and $((total_files - 20)) more files"
    echo ""
    echo "Full file path list saved to: $DEB_PATHS"
}

### ====== Compare expected vs actual files ======
compare_expected_vs_actual() {
    local DEB_FILE="$1"
    
    echo "" >> "$FILES_REPORT"
    echo "========== COMPARISON: EXPECTED vs ACTUAL FILES ==========" >> "$FILES_REPORT"
    
    echo "=== Files expected to be installed (from DEB) ===" >> "$FILES_REPORT"
    dpkg-deb -c "$DEB_FILE" 2>/dev/null >> "$FILES_REPORT" || echo "Unable to retrieve file list from DEB" >> "$FILES_REPORT"
    
    echo "" >> "$FILES_REPORT"
    echo "=== Files actually created/modified (from monitoring) ===" >> "$FILES_REPORT"
    
    ALL_FILES=$(awk '{print $2}' "$LOG" | sort -u)
    for FILE in $ALL_FILES; do
        [ ! -f "$FILE" ] && continue
        if grep -q "C $FILE" "$LOG" || grep -q "W $FILE" "$LOG"; then
            echo "$FILE" >> "$FILES_REPORT"
        fi
    done
    
    local pkg_name=$(dpkg-deb -W --showformat='${Package}' "$DEB_FILE" 2>/dev/null)
    if [ -n "$pkg_name" ] && [ "$pkg_name" != "unknown" ]; then
        echo "" >> "$FILES_REPORT"
        echo "=== Files registered in package manager ===" >> "$FILES_REPORT"
        dpkg -L "$pkg_name" 2>/dev/null >> "$FILES_REPORT" || echo "Unable to retrieve package files" >> "$FILES_REPORT"
    fi
}

### ====== User ======
RUN_USER=${SUDO_USER:-$(whoami)}

run_as_user() {
    local command="$1"
    echo "[*] Running as user: $RUN_USER"
    su - "$RUN_USER" -c "$command"
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

### ====== Start monitoring ======
echo "[*] Starting file change monitoring..."
fatrace -t -o "$LOG" &
MONITOR=$!

### ====== Main logic ======
case "$MODE" in
    --deb)
        [ $# -ne 1 ] && usage
        DEB="$1"
        
        show_deb_file_paths "$DEB"
        
        echo "[*] Installing package from file: $DEB"
        dpkg -i "$DEB"
        
        local pkg_name=$(dpkg-deb -W --showformat='${Package}' "$DEB" 2>/dev/null || echo "unknown")
        if [ "$pkg_name" != "unknown" ]; then
            echo "[*] Installing dependencies for $pkg_name"
            apt-get install -f -y
        fi
        ;;
    --apt)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Installing package via apt: $PKG"
        apt-get update
        apt-get install -y "$PKG"
        ;;
    --flatpak)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Installing Flatpak: $PKG"
        flatpak install -y "$PKG"
        ;;
    --snap)
        [ $# -ne 1 ] && usage
        PKG="$1"
        echo "[*] Installing Snap: $PKG"
        snap install "$PKG"
        ;;
    --gui)
        echo "[*] GUI mode: open Software Manager and install the app"
        echo "[*] Press Enter here after installation is finished."
        read -p "[*] Waiting for GUI installation..." dummy
        ;;
    *)
        usage
        ;;
esac

### ====== Stop monitoring ======
echo "[*] Stopping monitoring..."
kill $MONITOR
wait $MONITOR 2>/dev/null

### ====== Analyze results ======
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

        if [ "$STATUS" = "CHANGED" ] && file "$FILE" | grep -q 'text'; then
            SNAP_BEFORE="$TMPDIR/before$(echo "$FILE" | sed 's/\//_/g')"
            cp "$FILE" "$TMPDIR/after$(echo "$FILE" | sed 's/\//_/g')" 2>/dev/null
            if [ -f "$SNAP_BEFORE" ]; then
                echo ">>> DIFF $FILE" >> "$FILES_REPORT"
                diff -u "$SNAP_BEFORE" "$FILE" >> "$FILES_REPORT" 2>/dev/null || true
            else
                cp "$FILE" "$SNAP_BEFORE" 2>/dev/null
            fi
        fi
    fi
done

if [ "$MODE" = "--deb" ] && [ -n "$DEB" ]; then
    compare_expected_vs_actual "$DEB"
fi

echo "========== FATrace LOG ==========" >> "$FILES_REPORT"
cat "$LOG" >> "$FILES_REPORT"

### ====== Summary ======
echo "[*] Logs and results:"
echo "  Full log: $LOG"
echo "  File list and diffs: $FILES_REPORT"
if [ "$MODE" = "--deb" ] && [ -n "$DEB" ]; then
    echo "  DEB file paths: $DEB_PATHS"
fi
echo "[*] Temporary data: $TMPDIR"

echo "=== ADDITIONAL INFORMATION ===" >> "$FILES_REPORT"
echo "Root user: $(whoami)" >> "$FILES_REPORT"
echo "Monitored user: $RUN_USER" >> "$FILES_REPORT"
