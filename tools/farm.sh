#!/usr/bin/env bash
# Run a pre-compute job (a bake, an encode, a render) at low priority, one job at a time per
# machine, with its output logged (bd 5d8: "don't run them all at once on my laptop ... run it on
# other machines"). Jobs run on this machine, or over SSH on a farm host that has its own clone.
#
# Usage: tools/farm.sh [--host HOST] [--repo PATH] [--name NAME] -- COMMAND [ARGS ...]
#   --host HOST   run on HOST over ssh (default: here). The host needs a clone of this repo
#                 (--repo, default ~/repos/persistint-game-unified) and the job's tools.
#   --name NAME   log name (default: the command's basename)
#   COMMAND runs from the repo root under nice -n 19 and ionice -c 3 (idle class, where
#   available), holding .cache/farm/lock, so a second job waits for the first instead of
#   competing with it. The log is .cache/farm/<UTC time>-<name>.log (gitignored); the exit
#   status is the job's.
#
# Examples:
#   tools/farm.sh -- env PAPER_OUT=.cache/tiers/s2 PAPER_MAX_SCALE=2 tools/bake_paper.sh all
#   tools/farm.sh --host srv -- tools/run_tests.sh --no-import
#
# Run long jobs from a clone nobody switches branches in while they run: a checkout under a
# running bash script (bake_paper.sh) can make bash read shifted lines.
set -uo pipefail

HOST="" REPO='~/repos/persistint-game-unified' NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "farm: unknown option $1 (put the command after --)" >&2; exit 2 ;;
  esac
done
[[ $# -gt 0 ]] || { echo "farm: no command (tools/farm.sh -h)" >&2; exit 2; }

if [[ -n $HOST ]]; then
  # Re-run this script on the host, from its own clone, with the same command.
  q=$(printf '%q ' "$@")
  exec ssh -o BatchMode=yes "$HOST" "cd $REPO && tools/farm.sh ${NAME:+--name $(printf '%q' "$NAME")} -- $q"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p .cache/farm
NAME="${NAME:-$(basename "$1")}"
LOG=".cache/farm/$(date -u +%Y%m%dT%H%M%SZ)-${NAME//[^A-Za-z0-9._-]/_}.log"
IONICE=()
command -v ionice >/dev/null && IONICE=(ionice -c 3)

echo "farm: $(hostname) waiting for the lock, log $LOG"
exec 9>.cache/farm/lock
flock 9
start=$(date +%s)
{
  echo "# $(date -u +%FT%TZ) on $(hostname): $*"
  nice -n 19 "${IONICE[@]}" "$@"
} > "$LOG" 2>&1
code=$?
echo "# exit $code after $(( $(date +%s) - start ))s" >> "$LOG"
echo "farm: $NAME exit $code after $(( $(date +%s) - start ))s ($LOG)"
exit $code
