#!/usr/bin/env bash
# Usage: ./initial_access_enum.sh LINUX_IP WINDOWS_IP
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 LINUX_IP WINDOWS_IP" >&2
    exit 1
fi

for tool in curl smbclient; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done

LINUX_IP="$1"
WINDOWS_IP="$2"
OUT="initial_access_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

check_web() {
    local name="$1" ip="$2" status title
    status=$(curl -sS --max-time 10 -o "$OUT/${name}_http.html" \
        -w '%{http_code}' "http://$ip/" 2>"$OUT/${name}_http_error.txt") || status="unreachable"
    title=$(grep -Eio '<title[^>]*>[^<]*</title>' "$OUT/${name}_http.html" 2>/dev/null \
        | head -n 1 | sed -E 's#</?title[^>]*>##g' || true)
    grep -Eoi 'href="[^"]+"' "$OUT/${name}_http.html" 2>/dev/null \
        | head -n 30 > "$OUT/${name}_links.txt" || true
    echo "$name HTTP: $status${title:+ | Title: $title}"
    if [ -s "$OUT/${name}_links.txt" ]; then
        echo "  Links: $(head -n 5 "$OUT/${name}_links.txt" | paste -sd ', ' -)"
    fi
}

echo "Linux target: $LINUX_IP"
check_web linux "$LINUX_IP"

if curl -fsS --max-time 10 -u anonymous:anonymous --list-only \
    "ftp://$LINUX_IP/" -o "$OUT/linux_ftp_root.txt" \
    2>"$OUT/linux_ftp_error.txt"; then
    echo "Linux FTP: anonymous listing allowed"
    echo "  Root entries: $(head -n 10 "$OUT/linux_ftp_root.txt" | paste -sd ', ' -)"
    curl -fsS --max-time 10 -u anonymous:anonymous --list-only \
        "ftp://$LINUX_IP/pub/" -o "$OUT/linux_ftp_pub.txt" \
        2>"$OUT/linux_ftp_pub_error.txt" || true
else
    echo "Linux FTP: anonymous listing unavailable"
fi

echo "Windows target: $WINDOWS_IP"
check_web windows "$WINDOWS_IP"

if timeout 15 smbclient -N -g -L "//$WINDOWS_IP" \
    > "$OUT/windows_smb.txt" 2>"$OUT/windows_smb_error.txt"; then
    shares=$(grep '^Disk|' "$OUT/windows_smb.txt" | cut -d'|' -f2 | paste -sd ', ' - || true)
    if [ -n "$shares" ]; then
        echo "Windows SMB: anonymous share names listed: $shares"
    else
        echo "Windows SMB: no anonymous share names listed"
    fi
else
    echo "Windows SMB: anonymous listing failed or denied"
fi

printf '\nFull evidence saved: %s/\n' "$OUT"
