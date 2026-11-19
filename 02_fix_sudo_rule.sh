#!/usr/bin/env bash
# Usage: sudo bash 02_fix_sudo_rule.sh bbriggs /etc/sudoers.d/90-blacklodge
set -euo pipefail

if [ "$#" -ne 2 ] || [[ ! "$1" =~ ^[a-z_][a-z0-9_-]*$ ]] || [[ "$2" != /etc/sudoers.d/* ]] || [ ! -f "$2" ]; then
    echo "Usage: sudo bash $0 USER /etc/sudoers.d/FILE" >&2
    exit 1
fi
if [ "$(id -u)" -ne 0 ]; then echo 'Run with sudo' >&2; exit 1; fi

USER_NAME="$1"
FILE="$2"
PATTERN="^${USER_NAME}[[:space:]]+ALL=\\(ALL\\)[[:space:]]+NOPASSWD:[[:space:]]*/usr/bin/awk[[:space:]]*$"

if ! grep -Eq "$PATTERN" "$FILE"; then
    echo 'Exact passwordless awk rule not found; no changes made'
    exit 1
fi

BACKUP="/root/$(basename "$FILE").$(date +%Y%m%d_%H%M%S).bak"
cp -p "$FILE" "$BACKUP"
echo '========== BEFORE =========='
grep -En "$PATTERN" "$FILE"

# Remove only the verified offending line; preserve other sudo rules.
sed -i -E "\\#${PATTERN}#d" "$FILE"
if ! visudo -c >/dev/null 2>&1; then
    cp -p "$BACKUP" "$FILE"
    echo 'Sudoers validation failed; restored backup' >&2
    exit 1
fi

echo '========== AFTER =========='
echo 'Exact passwordless awk rule removed; sudoers syntax valid'
echo "Backup: $BACKUP"
