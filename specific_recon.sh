#!/usr/bin/env bash
# Usage: ./specific_recon.sh SUBNET
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 SUBNET" >&2
    exit 1
fi

command -v nmap >/dev/null || { echo "nmap is required" >&2; exit 1; }

OUT="specific_recon_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
TEMP=$(mktemp)
trap 'rm -f "$TEMP"' EXIT

nmap -Pn -n -sT -T4 --open \
    -p 21,22,53,80,88,135,389,445,3389,5985 \
    --exclude 172.16.10.250,172.16.10.254 \
    -oN "$OUT/scan.txt" -oG "$TEMP" "$1" >/dev/null

awk '
/Ports: / {
    ip = $2
    split($0, parts, "Ports: ")
    count = split(parts[2], entries, ", ")
    ports = ""
    win = 0
    linux = 0

    for (i = 1; i <= count; i++) {
        split(entries[i], fields, "/")
        if (fields[2] != "open" || fields[3] != "tcp") continue
        p = fields[1] + 0
        ports = ports (ports == "" ? "" : ",") p
        if (p == 88 || p == 389 || p == 445) win++
        if (p == 21 || p == 22 || p == 80) linux++
    }

    if (win >= 2) {
        printf "Hospital / Windows AD%s: %s | Ports: %s\n", win == 3 ? "" : " (possible)", ip, ports
        found_win = 1
    } else if (linux >= 2) {
        printf "Police / Linux%s: %s | Ports: %s\n", linux == 3 ? "" : " (possible)", ip, ports
        found_linux = 1
    }
}
END {
    if (!found_win) print "Hospital / Windows AD: not identified"
    if (!found_linux) print "Police / Linux: not identified"
}
' "$TEMP"

echo "Full scan: $OUT/scan.txt"
