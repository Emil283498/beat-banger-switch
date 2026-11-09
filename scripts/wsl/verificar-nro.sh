#!/usr/bin/env bash
# Prints basic information about a produced .nro.
#
# Usage:
#   bash scripts/wsl/verificar-nro.sh [path/to/beat-banger.nro]
#   NRO=/path/to/file.nro bash scripts/wsl/verificar-nro.sh
set -euo pipefail

NRO="${1:-${NRO:-./beat-banger.nro}}"

[ -f "$NRO" ] || { echo "ERROR: NRO not found: $NRO" >&2; exit 1; }

echo "== first bytes:"
xxd -l 64 "$NRO" || true

echo "== markers:"
grep -a -o -m1 'NRO0' "$NRO" | head -1 || true
grep -a -o -m1 'ASET' "$NRO" | head -1 || true
grep -a -o -m1 'Beat Banger' "$NRO" | head -1 || true
grep -a -o -m1 'homebrew' "$NRO" | head -1 || true
grep -a -o -m1 '1\.0\.0' "$NRO" | head -1 || true

echo "== size:"
stat -c '%s bytes' "$NRO"

echo "== sha256:"
sha256sum "$NRO"
