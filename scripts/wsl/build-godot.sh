#!/usr/bin/env bash
# Builds the Godot 4.7.2 Nintendo Switch engine (template_release, OpenGL).
#
# Requirements: WSL1 (or Linux), devkitPro (devkitA64 + libnx + switch-mesa),
# scons. See docs/BUILD.md.
#
# Environment variables (all optional):
#   GODOT_SRC  path to the godot-switch-nro source tree
#              (default: $HOME/godot-switch-nro-trabalho/godot)
#   DEVKITPRO  devkitPro prefix (default: /opt/devkitpro)
#   JOBS       parallel jobs (default: 2)
#   LTO        lto mode (default: none)
#   TARGET     scons target (default: template_release)
#   LOG        build log path (default: $GODOT_SRC/../build.log)
#
# Usage:
#   bash scripts/wsl/build-godot.sh
set -euo pipefail

: "${GODOT_SRC:=$HOME/godot-switch-nro-trabalho/godot}"
: "${DEVKITPRO:=/opt/devkitpro}"
: "${JOBS:=2}"
: "${LTO:=none}"
: "${TARGET:=template_release}"
: "${LOG:=$(dirname "$GODOT_SRC")/build.log}"

export DEVKITPRO
export DEVKITA64="$DEVKITPRO/devkitA64"
export PATH="$DEVKITPRO/tools/bin:$DEVKITPRO/devkitA64/bin:$PATH"

[ -d "$GODOT_SRC" ] || { echo "ERROR: Godot source not found: $GODOT_SRC" >&2; exit 1; }

cd "$GODOT_SRC"

echo "== scons ($(scons --version 2>/dev/null | sed -n '3p'))"
echo "== source: $GODOT_SRC"
echo "== target=$TARGET lto=$LTO jobs=$JOBS"
echo "== log: $LOG"

scons platform=switch target="$TARGET" -j"$JOBS" lto="$LTO" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

echo "== build exit: $status"
if [ "$status" -ne 0 ]; then
    echo "ERROR: scons failed. Do not interrupt an incremental build." >&2
    exit "$status"
fi

ls -la bin/
