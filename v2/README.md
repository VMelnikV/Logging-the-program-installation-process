# Порівняння версій скрипту deb-watch-unified.sh

## 1. Перевірка залежностей / Dependency check
- **UA:** У другій версії змінено спосіб перевірки залежностей:  
  Перша версія перевіряє `fatrace`, `file`, `diff`.  
  Друга версія перевіряє лише `fatrace` та `diff`, додає кольорові повідомлення.
- **EN:** In the second version, the dependency check was modified:  
  The first version checks `fatrace`, `file`, `diff`.  
  The second version checks only `fatrace` and `diff`, with colored output messages.

## 2. Логування / Logging
- **UA:** Перша версія створює `$LOG` та `$FILES_REPORT` у `/tmp`.  
  Друга версія використовує окремі каталоги `logs/` та `reports/` із датою в імені файлів.
- **EN:** The first version creates `$LOG` and `$FILES_REPORT` in `/tmp`.  
  The second version uses separate `logs/` and `reports/` directories with date-stamped filenames.

## 3. Перевірка root прав / Root privilege check
- **UA:** У першій версії: функція `check_root_privileges` з перевіркою `$EUID`.  
  У другій версії: простий `if [ "$(id -u)" -ne 0 ]; then ...` з кольоровим повідомленням.
- **EN:** In the first version: `check_root_privileges` function using `$EUID`.  
  In the second version: simple `if [ "$(id -u)" -ne 0 ]; then ...` with colored output.

## 4. Встановлення пакетів / Installation calls
- **UA:** Перша версія встановлює пакети через `dpkg` / `apt` / `flatpak` / `snap`.  
  Друга версія додає confirm-повідомлення перед виконанням `apt-get`, `flatpak` і `snap`.
- **EN:** The first version installs packages directly via `dpkg` / `apt` / `flatpak` / `snap`.  
  The second version adds confirmation messages before executing `apt-get`, `flatpak`, and `snap`.

## 5. Моніторинг файлових змін / Monitoring
- **UA:** Перша версія запускає `fatrace -t -o "$LOG"`.  
  Друга версія додатково друкує статус у консоль із зеленим кольором.
- **EN:** The first version runs `fatrace -t -o "$LOG"`.  
  The second version additionally prints monitoring status in green.

## 6. Аналіз результатів / Results analysis
- **UA:** У першій версії аналіз йде у `$FILES_REPORT` з `diff` для текстових файлів.  
  У другій версії диф для текстових файлів видалено — залишається тільки список `NEW` / `CHANGED`.
- **EN:** In the first version, analysis goes into `$FILES_REPORT` with `diff` for text files.  
  In the second version, diff for text files is removed — only `NEW` / `CHANGED` list remains.

## 7. Вивід підсумків / Summary output
- **UA:** Перша версія друкує шляхи до логів і додає інформацію про користувача root та SUDO_USER.  
  Друга версія друкує коротше: лише шляхи до логів та каталогів, без додаткової інформації.
- **EN:** The first version prints log paths and adds info about root user and SUDO_USER.  
  The second version prints shorter: only log/report paths, without extra info.
