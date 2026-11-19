#!/usr/bin/env bash
# Usage: ./generic_recon.sh SUBNET PORTS
set -euo pipefail

if [ "$#" -ne 2 ] || [[ ! "$2" =~ ^[0-9,-]+$ ]]; then
    echo "Usage: $0 SUBNET PORTS (e.g. 22,80,445 or 1-1000)" >&2
    exit 1
fi

command -v nmap >/dev/null || { echo "nmap is required" >&2; exit 1; }

OUT="generic_recon_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"
TEMP=$(mktemp)
trap 'rm -f "$TEMP"' EXIT

nmap -Pn -n -sT -T4 --open -p "$2" \
    --exclude 172.16.10.250,172.16.10.254 \
    -oN "$OUT/scan.txt" -oG "$TEMP" "$1" >/dev/null

awk '
/Ports: / {
    ip = $2
    split($0, parts, "Ports: ")
    count = split(parts[2], entries, ", ")
    ports = ""

    for (i = 1; i <= count; i++) {
        split(entries[i], fields, "/")
        if (fields[2] == "open" && fields[3] == "tcp")
            ports = ports (ports == "" ? "" : ",") fields[1]
    }

    if (ports != "") {
        printf "%s | Ports: %s\n", ip, ports
        found = 1
    }
}
END { if (!found) print "No matching hosts found" }
' "$TEMP"

echo "Full scan: $OUT/scan.txt"
