#!/usr/bin/env bash
# Render a screenshot walkthrough (bd wso): every shot in a shot list (tools/shots/*.json, in the
# format project/scripts/test/shot_walk.gd describes) as <out_dir>/<name>.png, for a visual pass.
#
# Usage: tools/shot_walk.sh [--check] [--no-import] [--timeout=SECONDS] <shots.json> <out_dir> [NAME ...]
#   --check           only check the list against the tree (tools/check_shots.py); no out_dir needed
#   --no-import       skip `godot --import` (the .godot/ cache is already current)
#   --timeout=SECONDS per shot (default 180); a shot that runs longer counts as failed
#   NAME ...          only these shots; default: every shot in the list
#
# The list is checked first (scenes, spawn markers, nodes, methods, dialogue titles; needs python3).
# Each shot then runs in its own Godot process (a fresh game state, and one bad shot can't stop the
# rest), all on one Xvfb display (xvfb-run -s "-screen 0 1280x720x24" when it is installed;
# SHOT_WALK_XVFB=0 uses $DISPLAY instead), with the OpenGL renderer, the dummy audio driver and a
# fixed frame rate (--fixed-fps, SHOT_WALK_FPS, default 60), so a shot's frame counts are the same
# game time on any machine. user:// is a scratch directory (.cache/shot_walk/xdg, emptied at the
# start), so the walk never reads or writes the player's save or settings. Logs go to
# .cache/shot_walk/logs/<name>.log (gitignored). <out_dir>/SUMMARY.txt lists every shot as ok or
# FAIL (with why), the frames a multi-frame shot snapped (<name>@<as>.png, its snap steps) and the
# first engine errors its log has. Exits non-zero if any shot failed.
# GODOT names the Godot binary (default: godot on PATH).
set -uo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
GODOT="${GODOT:-godot}"
FPS="${SHOT_WALK_FPS:-60}"
WALK="scripts/test/shot_walk.gd"
IMPORT=1
CHECK_ONLY=0
TIMEOUT=180
POS=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    --no-import) IMPORT=0 ;;
    --timeout=*) TIMEOUT="${arg#--timeout=}" ;;
    -h|--help) sed -n '2,20p' "$SELF"; exit 0 ;;
    -*) echo "shot_walk: unknown option $arg" >&2; exit 2 ;;
    *) POS+=("$arg") ;;
  esac
done
if [[ ${#POS[@]} -lt 1 || ( $CHECK_ONLY -eq 0 && ${#POS[@]} -lt 2 ) ]]; then
  sed -n '5,9p' "$SELF" >&2
  exit 2
fi
LIST="$(realpath -m "${POS[0]}")"
[[ -f "$LIST" ]] || { echo "shot_walk: no shot list ${POS[0]}" >&2; exit 2; }

if [[ -z "${SHOT_WALK_INNER:-}" ]]; then
  if command -v python3 >/dev/null; then
    if ! python3 -I "$ROOT/tools/check_shots.py" "$LIST"; then
      echo "shot_walk: fix the shot list first (above)" >&2
      exit 1
    fi
  elif [[ $CHECK_ONLY -eq 1 ]]; then
    echo "shot_walk: --check needs python3" >&2
    exit 2
  else
    echo "shot_walk: python3 not found, the shot list is not checked" >&2
  fi
  [[ $CHECK_ONLY -eq 1 ]] && exit 0
  # One Xvfb for the whole walk: run again inside xvfb-run.
  if [[ "${SHOT_WALK_XVFB:-1}" != 0 ]] && command -v xvfb-run >/dev/null; then
    export SHOT_WALK_INNER=xvfb
    exec xvfb-run -a -s "-screen 0 1280x720x24" "$SELF" "$@"
  fi
  [[ -n "${DISPLAY:-}" ]] || echo "shot_walk: no xvfb-run and no DISPLAY; Godot needs a display" >&2
fi
[[ $CHECK_ONLY -eq 1 ]] && exit 0

command -v "$GODOT" >/dev/null || { echo "shot_walk: $GODOT not found (set GODOT)" >&2; exit 2; }
OUT="$(realpath -m "${POS[1]}")"
NAMES=("${POS[@]:2}")
CACHE="$ROOT/.cache/shot_walk"
LOGS="$CACHE/logs"
mkdir -p "$LOGS" "$OUT"

if [[ $IMPORT -eq 1 ]]; then
  echo "== import"
  if ! "$GODOT" --headless --path "$ROOT/project" --import > "$LOGS/_import.log" 2>&1; then
    echo "shot_walk: import failed (see ${LOGS#$ROOT/}/_import.log)" >&2
    exit 1
  fi
fi

# user:// for the walk (the save, settings.cfg): a scratch directory, empty at the start.
export XDG_DATA_HOME="$CACHE/xdg"
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME"

if [[ ${#NAMES[@]} -eq 0 ]]; then
  "$GODOT" --headless --path "$ROOT/project" -s "$WALK" -- "$LIST" --list > "$LOGS/_list.log" 2>&1
  mapfile -t NAMES < <(sed -n 's/^SHOT \([a-z0-9_-]*\)$/\1/p' "$LOGS/_list.log")
  if grep -q '^BAD ' "$LOGS/_list.log"; then
    grep '^BAD ' "$LOGS/_list.log" >&2
    echo "shot_walk: fix the shot list first (above)" >&2
    exit 1
  fi
  [[ ${#NAMES[@]} -gt 0 ]] || { echo "shot_walk: no shots listed (see ${LOGS#$ROOT/}/_list.log)" >&2; exit 1; }
fi

SUMMARY="$OUT/SUMMARY.txt"
rev="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
git -C "$ROOT" diff --quiet HEAD 2>/dev/null || rev="$rev with local changes"
if [[ "${SHOT_WALK_INNER:-}" == xvfb ]]; then display="Xvfb 1280x720x24"; else display="DISPLAY=${DISPLAY:-none}"; fi
{
  echo "Shot walk of ${LIST#$ROOT/} at $rev"
  echo "$("$GODOT" --version 2>/dev/null | tail -1), --rendering-driver opengl3, --fixed-fps $FPS, $display"
  echo
} > "$SUMMARY"

failed=()
start=$(date +%s)
for name in "${NAMES[@]}"; do
  log="$LOGS/$name.log"
  rm -f "$OUT/$name.png" "$OUT/$name"@*.png
  t0=$(date +%s)
  timeout "$TIMEOUT" "$GODOT" --rendering-driver opengl3 --audio-driver Dummy --fixed-fps "$FPS" \
    --path "$ROOT/project" -s "$WALK" -- "$LIST" "$OUT" --only="$name" > "$log" 2>&1
  code=$?
  secs=$(( $(date +%s) - t0 ))
  clean="$(sed 's/\x1b\[[0-9;]*m//g' "$log")"
  errors="$(grep -E '^(SCRIPT )?ERROR' <<<"$clean" | sort -u)"
  nerr=$( [[ -n "$errors" ]] && wc -l <<<"$errors" || echo 0 )
  note=""
  [[ $nerr -gt 0 ]] && note=" ($nerr distinct engine errors in the log)"
  if [[ $code -eq 0 ]] && grep -q "^SHOT OK $name " <<<"$clean" && [[ -f "$OUT/$name.png" ]]; then
    printf 'ok       %-44s %4ss%s\n' "$name" "$secs" "$note"
    echo "ok    $name.png$note" >> "$SUMMARY"
    sed -n "s/^SNAP \($name@[a-z0-9_]*\) .*/        \1.png/p" <<<"$clean" >> "$SUMMARY"
  else
    why="$(grep -m1 "^SHOT FAIL $name: " <<<"$clean" | sed "s/^SHOT FAIL $name: //")"
    [[ -z "$why" ]] && why="exit $code, no SHOT line"
    [[ $code -eq 124 ]] && why="timed out after ${TIMEOUT}s"
    printf 'FAIL     %-44s %4ss  %s%s\n' "$name" "$secs" "$why" "$note"
    echo "FAIL  $name: $why$note" >> "$SUMMARY"
    failed+=("$name")
  fi
  [[ $nerr -gt 0 ]] && head -3 <<<"$errors" | sed 's/^/        /' | tee -a "$SUMMARY"
done

total=${#NAMES[@]}
saved=$(( total - ${#failed[@]} ))
{ echo; echo "$saved/$total saved"; } >> "$SUMMARY"
echo "== $saved/$total shots saved in $(( $(date +%s) - start ))s to $OUT; logs in ${LOGS#$ROOT/}/"
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "failed: ${failed[*]}"
  exit 1
fi
exit 0
