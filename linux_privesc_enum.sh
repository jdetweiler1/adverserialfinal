#!/usr/bin/env bash
# Usage: bash linux_privesc_enum.sh (run on the Linux target after login)
set -uo pipefail

OUT="${TMPDIR:-/tmp}/linux_privesc_$(date +%Y%m%d_%H%M%S)_$$.txt"

{
    echo '========== USER AND SYSTEM =========='
    date -Is
    id
    whoami
    hostname
    uname -a
    cat /etc/os-release 2>/dev/null || true

    echo '========== SUDO PERMISSIONS =========='
    sudo -n -l 2>&1 || true

    echo '========== SUID BINARIES =========='
    find /usr/bin /usr/sbin /bin /sbin -type f -perm -4000 -ls 2>/dev/null | sort -u || true

    echo '========== FILE CAPABILITIES =========='
    if command -v getcap >/dev/null 2>&1; then
        getcap -r /usr/bin /usr/sbin 2>/dev/null || true
    else
        echo 'getcap unavailable'
    fi

    echo '========== INTERACTIVE USERS =========='
    getent passwd | awk -F: '$7 ~ /(\/bash|\/zsh|\/sh)$/ {print $1, $3, $6, $7}'

    echo '========== LISTENING PORTS =========='
    ss -lnt 2>/dev/null || true

    echo '========== CRON LOCATIONS =========='
    crontab -l 2>&1 || true
    ls -ld /etc/cron* 2>/dev/null || true

    echo '========== SYSTEMD TIMERS =========='
    systemctl list-timers --all --no-pager 2>&1 || true

    echo '========== INTERESTING DIRECTORY PERMISSIONS =========='
    ls -ld /home/ftp /home/ftp/upload /var/www/html /opt /tmp 2>/dev/null || true
} > "$OUT" 2>&1

echo '========== LINUX ENUMERATION =========='
echo "Identity: $(id)"
echo 'Sudo permissions (noninteractive check):'
awk '/^========== SUDO PERMISSIONS/{on=1;next} /^==========/{on=0} on' "$OUT" | head -n 14
echo 'SUID binaries:'
awk '/^========== SUID BINARIES/{on=1;next} /^==========/{on=0} on' "$OUT" | head -n 35
echo "Full report: $OUT"
