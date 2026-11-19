#!/usr/bin/env bash
# Usage: sudo bash 03_quarantine_php.sh /var/www/html/assets/records.php
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ] || [ -L "$1" ] || [[ "$1" != *.php ]] || [ "$(basename "$1")" = 'index.php' ]; then
    echo "Usage: sudo bash $0 /path/to/suspicious.php" >&2
    exit 1
fi
if [ "$(id -u)" -ne 0 ]; then echo 'Run with sudo' >&2; exit 1; fi

FILE="$1"
QUARANTINE='/root/cis4930-quarantine'
mkdir -p -m 700 "$QUARANTINE"
BACKUP="$QUARANTINE/$(basename "$FILE").$(date +%Y%m%d_%H%M%S)_$$"

echo '========== BEFORE =========='
ls -l "$FILE"
sha256sum "$FILE"
mv -- "$FILE" "$BACKUP"
chmod 600 "$BACKUP"
echo '========== AFTER =========='
echo "Removed from web directory; preserved outside web root: $BACKUP"
echo "Rollback if necessary: sudo mv '$BACKUP' '$FILE'"
