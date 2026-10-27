#!/usr/bin/env bash
# Run every headless test and exit non-zero if any fails (release checklist QA-01,
# sops/09-game-release-checklist.md: the project's {test_cmd}).
#
# Usage: tools/run_tests.sh [--no-import] [--timeout=SECONDS] [NAME ...]
#   --no-import       skip `godot --import` (the .godot/ cache is already current)
#   --timeout=SECONDS per test (default 400); a test that runs longer counts as failed
#   NAME ...          only these tests (test_save, tests/test_save.gd, ...); default: the asset
#                     gate (tools/check_assets.mjs) and every
#                     project/tests/*.gd (verify_slice.gd and each test_*.gd)
#
# A test passes when Godot exits 0 and the log has a "RESULT: PASS" line and no "RESULT: FAIL".
# Logs go to .cache/tests/<name>.log (gitignored); a failing test's FAIL lines are printed.
# GODOT names the Godot binary (default: godot on PATH). Tests never touch the player's save or
# settings (QA-04: WorldState, Music and AudioSettings switch to test files under -s tests/...).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
IMPORT=1
TIMEOUT=400
NAMES=()
for arg in "$@"; do
  case "$arg" in
    --no-import) IMPORT=0 ;;
    --timeout=*) TIMEOUT="${arg#--timeout=}" ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    -*) echo "run_tests: unknown option $arg" >&2; exit 2 ;;
    *) n="$(basename "$arg")"; NAMES+=("${n%.gd}") ;;
  esac
done

command -v "$GODOT" >/dev/null || { echo "run_tests: $GODOT not found (set GODOT)" >&2; exit 2; }
LOGS="$ROOT/.cache/tests"
mkdir -p "$LOGS"

NAMED=$([[ ${#NAMES[@]} -gt 0 ]] && echo 1 || echo 0)
if [[ ${#NAMES[@]} -eq 0 ]]; then
  for t in "$ROOT"/project/tests/*.gd; do
    NAMES+=("$(basename "$t" .gd)")
  done
fi

if [[ $IMPORT -eq 1 ]]; then
  echo "== import"
  if ! "$GODOT" --headless --path "$ROOT/project" --import > "$LOGS/_import.log" 2>&1; then
    echo "run_tests: import failed (see $LOGS/_import.log)" >&2
    exit 1
  fi
fi

failed=()
start=$(date +%s)
# The asset conformance gate (bd 4wb) counts as a test: tools/check_assets.mjs, the Node port of
# tools/check_assets.py (same checks and messages; its gen_sources.mjs writes the same SOURCES.md).
if [[ $NAMED -eq 0 ]]; then
  if node "$ROOT/tools/check_assets.mjs" > "$LOGS/check_assets.log" 2>&1; then
    printf 'PASS     %-24s        %s\n' check_assets "$(tail -1 "$LOGS/check_assets.log")"
  else
    printf 'FAIL     %-24s        %s\n' check_assets "$(tail -1 "$LOGS/check_assets.log")"
    grep '^FAIL' "$LOGS/check_assets.log" | head -20 | sed 's/^/           /'
    failed+=(check_assets)
  fi
fi
for name in "${NAMES[@]}"; do
  if [[ ! -f "$ROOT/project/tests/$name.gd" ]]; then
    echo "MISSING  $name"
    failed+=("$name")
    continue
  fi
  log="$LOGS/$name.log"
  t0=$(date +%s)
  timeout "$TIMEOUT" "$GODOT" --headless --path "$ROOT/project" -s "tests/$name.gd" > "$log" 2>&1
  code=$?
  secs=$(( $(date +%s) - t0 ))
  result="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^RESULT:' | tail -1)"
  if [[ $code -eq 0 ]] && grep -q 'RESULT: PASS' <<<"$result" && ! sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -q '^RESULT: FAIL'; then
    printf 'PASS     %-24s %4ss  %s\n' "$name" "$secs" "$result"
  else
    why="exit $code"
    [[ $code -eq 124 ]] && why="timed out after ${TIMEOUT}s"
    [[ -z "$result" ]] && why="$why, no RESULT line"
    printf 'FAIL     %-24s %4ss  %s (%s)\n' "$name" "$secs" "${result:-}" "$why"
    sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E '^FAIL|SCRIPT ERROR|Parse Error' | head -20 | sed 's/^/           /'
    failed+=("$name")
  fi
done

total=$(( ${#NAMES[@]} + (NAMED == 0 ? 1 : 0) ))
echo "== $(( total - ${#failed[@]} ))/$total passed in $(( $(date +%s) - start ))s; logs in ${LOGS#$ROOT/}/"
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
exit 0
