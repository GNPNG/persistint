#!/usr/bin/env bash
# Export every preset in project/export_presets.cfg into one versioned folder (release checklist
# BD-10, sops/09-game-release-checklist.md): exports/v<version>-<build id>/<preset name>/<file>,
# where <file> is the file name of the preset's own export_path. Today that is the Web preset;
# desktop presets (BD-01, decision 7) are picked up as they are added.
#
# Usage: tools/build_all.sh [--allow-dirty] [--debug]
#   --allow-dirty  build from a tree with uncommitted changes (the build id gets "-dirty")
#   --debug        --export-debug instead of --export-release
#
# Like tools/deploy_site.sh it writes res://build.json (the build id the main menu shows), imports
# first when project/.godot is missing, and puts project/project.godot and export_presets.cfg back
# afterwards, since opening the project re-serialises them. exports/ is gitignored.
# GODOT names the Godot binary (default: godot on PATH).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-godot}"
ALLOW_DIRTY=0
MODE="--export-release"
for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --debug) MODE="--export-debug" ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "build_all: unknown option $arg" >&2; exit 2 ;;
  esac
done
die() { echo "build_all: $*" >&2; exit 1; }

command -v "$GODOT" >/dev/null || die "$GODOT not found (set GODOT)"
VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_ID="$(git rev-parse --short HEAD)"
if [[ -n "$(git status --porcelain -- . ':!.beads')" ]]; then
  [[ $ALLOW_DIRTY -eq 1 ]] || die "uncommitted changes; commit them or pass --allow-dirty"
  BUILD_ID="$BUILD_ID-dirty"
fi
OUT="exports/v$VERSION-$BUILD_ID"

# name<TAB>export_path for each [preset.N] section.
mapfile -t PRESETS < <(awk -F= '
  /^\[preset\.[0-9]+\]$/ { if (name != "") print name "\t" path; name = ""; path = "" }
  /^name=/ { name = substr($0, 6); gsub(/"/, "", name) }
  /^export_path=/ { path = substr($0, 13); gsub(/"/, "", path) }
  END { if (name != "") print name "\t" path }' project/export_presets.cfg)
[[ ${#PRESETS[@]} -gt 0 ]] || die "no presets in project/export_presets.cfg"

TMP="$(mktemp -d)"
cp project/project.godot "$TMP/project.godot.orig"
cp project/export_presets.cfg "$TMP/export_presets.cfg.orig"
trap 'cp "$TMP/project.godot.orig" "$ROOT/project/project.godot"; cp "$TMP/export_presets.cfg.orig" "$ROOT/project/export_presets.cfg"; rm -rf "$TMP"' EXIT

if [[ ! -d project/.godot ]]; then
  echo "== import (project/.godot missing)"
  "$GODOT" --headless --path project --import >"$TMP/import.log" 2>&1 || { tail -n 40 "$TMP/import.log"; die "import failed"; }
fi
printf '{"build": "%s"}\n' "$BUILD_ID" > project/build.json

echo "== v$VERSION build $BUILD_ID -> $OUT/"
for entry in "${PRESETS[@]}"; do
  name="${entry%%$'\t'*}"
  path="${entry#*$'\t'}"
  file="$(basename "${path:-$name}")"
  dir="$OUT/$name"
  mkdir -p "$dir"
  log="$TMP/export-${name//[^A-Za-z0-9]/_}.log"
  if ! "$GODOT" --headless --path project "$MODE" "$name" "$ROOT/$dir/$file" >"$log" 2>&1; then
    tail -n 40 "$log"
    die "export of preset $name failed"
  fi
  [[ -s "$dir/$file" ]] || { tail -n 40 "$log"; die "preset $name wrote no $file"; }
  grep -E '^(ERROR|SCRIPT ERROR)' "$log" | head -n 10 || true
  printf '  %-12s %4d files  %s\n' "$name" "$(find "$dir" -type f | wc -l)" "$(du -sh "$dir" | cut -f1)"
done
echo "== done: $OUT/"
