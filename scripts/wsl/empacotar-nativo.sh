#!/usr/bin/env bash
# Packages a Nintendo Switch NRO from a Godot ELF, without Docker.
#
# Usage:
#   empacotar-nativo.sh <elf> <out.nro> <title> <author> <version> <icon.jpg> <romfs-dir>
#
# Requires devkitPro tools: nacptool, elf2nro.
set -euo pipefail

T="${DEVKITPRO:-/opt/devkitpro}/tools/bin"

[ $# -eq 7 ] || { echo "usage: $0 <elf> <out.nro> <title> <author> <version> <icon.jpg> <romfs-dir>" >&2; exit 2; }

ELF=$1
OUT=$2
TITULO=$3
AUTOR=$4
VERSAO=$5
ICONE=$6
ROMFS=$7

[ -f "$ELF" ] || { echo "ERROR: ELF not found: $ELF" >&2; exit 1; }
[ -f "$ICONE" ] || { echo "ERROR: icon not found: $ICONE" >&2; exit 1; }
[ -d "$ROMFS" ] || { echo "ERROR: romfs dir not found: $ROMFS" >&2; exit 1; }

NACP=$(mktemp /tmp/XXXXXX.nacp)
trap 'rm -f "$NACP"' EXIT

"$T/nacptool" --create "$TITULO" "$AUTOR" "$VERSAO" "$NACP" >/dev/null
"$T/elf2nro" "$ELF" "$OUT" --icon="$ICONE" --nacp="$NACP" --romfsdir="$ROMFS" >/dev/null
ls -la "$OUT"
