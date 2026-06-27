#!/usr/bin/env bash
set -euo pipefail

JSON_URL="https://raw.githubusercontent.com/pvd-dog/russia-no-vpn-list/main/russia-no-vpn-list_by_%40pvd_dog.json"
OUTPUT_IPSET="${1:-config/lists/pvd-dog-ipset.txt}"

TMP_JSON=$(mktemp)
TMP_TXT=$(mktemp)
trap "rm -f $TMP_JSON $TMP_TXT" EXIT

echo "Downloading $JSON_URL ..."
curl -fsSL "$JSON_URL" -o "$TMP_JSON"

TOTAL=$(jq length "$TMP_JSON")
echo "Total entries: $TOTAL"

jq -r '.[].ip' "$TMP_JSON" \
  | sort -u > "$TMP_TXT"

IPS=$(wc -l < "$TMP_TXT")
echo "IP entries: $IPS"

echo "# Auto-generated from $JSON_URL" > "$OUTPUT_IPSET"
echo "# Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT_IPSET"
echo >> "$OUTPUT_IPSET"
cat "$TMP_TXT" >> "$OUTPUT_IPSET"

echo "Written to $OUTPUT_IPSET"
