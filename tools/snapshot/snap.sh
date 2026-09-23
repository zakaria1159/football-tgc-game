#!/bin/sh
# Dev-only: run the game in a temp copy with a scripted scenario and save screenshots.
# Usage: tools/snapshot/snap.sh <scenario> [outdir]
# Scenarios are defined in tools/snapshot/scenarios.lua. PNGs land in <outdir>/<scenario>_<label>.png
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCEN="${1:?usage: snap.sh <scenario> [outdir]}"
OUT="${2:-$ROOT/.snapshots}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rsync -a --exclude .git --exclude .snapshots --exclude .superpowers "$ROOT/" "$TMP/"
mv "$TMP/main.lua" "$TMP/real_main.lua"
cp "$ROOT/tools/snapshot/wrapper.lua" "$TMP/main.lua"
mkdir -p "$OUT"
rm -f "$OUT/${SCEN}"_*.png
SNAP_OUT="$OUT" SNAP_SCENARIO="$SCEN" love "$TMP"
ls "$OUT/${SCEN}"_*.png
