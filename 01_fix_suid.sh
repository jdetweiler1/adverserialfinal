#!/usr/bin/env bash
# Usage: sudo bash 01_fix_suid.sh /usr/bin/find
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ] || [ -L "$1" ]; then
    echo "Usage: sudo bash $0 /path/to/binary" >&2
    exit 1
fi
if [ "$(id -u)" -ne 0 ]; then echo 'Run with sudo' >&2; exit 1; fi

FILE="$1"
BEFORE=$(stat -c '%a' "$FILE")
echo '========== BEFORE =========='
ls -l "$FILE"

if [ -u "$FILE" ]; then
    chmod u-s "$FILE"
    echo 'Removed SUID bit'
else
    echo 'SUID bit was already absent; no change needed'
fi

echo '========== AFTER =========='
ls -l "$FILE"
echo "Original mode: $BEFORE"
echo "Rollback if necessary: sudo chmod $BEFORE '$FILE'"
