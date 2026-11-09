#!/usr/bin/env bash
# Packages the compiled Godot Switch ELF into a .nro (nacptool + elf2nro).
#
# Environment variables (all optional):
#   GODOT_SRC  godot-switch-nro source tree (default: $HOME/godot-switch-nro-trabalho/godot)
#   ELF        input ELF (default: $GODOT_SRC/bin/godot.switch.template_release.arm64)
#   NRO        output .nro (default: ./beat-banger.nro)
#   TITLE      NACP title (default: Beat Banger)
#   AUTHOR     NACP author (default: homebrew)
#   VERSION    NACP version (default: 1.0.0)
#   ICON       icon JPEG (default: ./romfs/icone.jpg)
#   ROMFS      romfs directory (default: ./romfs)
#
# Usage:
#   bash scripts/wsl/finalizar.sh
set -euo pipefail

: "${GODOT_SRC:=$HOME/godot-switch-nro-trabalho/godot}"
: "${ELF:=$GODOT_SRC/bin/godot.switch.template_release.arm64}"
: "${NRO:=./beat-banger.nro}"
: "${TITLE:=Beat Banger}"
: "${AUTHOR:=homebrew}"
: "${VERSION:=1.0.0}"
: "${ICON:=./romfs/icone.jpg}"
: "${ROMFS:=./romfs}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f "$ELF" ] || { echo "ERROR: ELF not found: $ELF" >&2; exit 1; }
[ -f "$ICON" ] || { echo "ERROR: icon not found: $ICON" >&2; exit 1; }
[ -d "$ROMFS" ] || { echo "ERROR: romfs not found: $ROMFS" >&2; exit 1; }

echo "== ELF: $(ls -l "$ELF")"
echo "== NRO: $NRO ($TITLE / $AUTHOR / $VERSION)"

bash "$SCRIPT_DIR/empacotar-nativo.sh" \
    "$ELF" "$NRO" "$TITLE" "$AUTHOR" "$VERSION" "$ICON" "$ROMFS"

echo "== done:"
ls -la "$NRO"
