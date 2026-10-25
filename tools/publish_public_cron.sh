#!/usr/bin/env bash
# SOP-15 deployment server, the whole of it: one cron line, one list of repositories, this script.
# Every tick, for each repository in the list: fetch it; if any ref moved since the last run, check it
# out and run the handler, publish.py beside this script, which reads the checkout's .config/publish.toml (filtered
# publication, mirror replication, or a command such as a site deploy). The run records (runs.jsonl) feed whatever runner UI or dashboard SOP-15 chooses.
# A failed run is retried on the next tick; a filtered publication is force-pushed whole or not at all.
# Credentials live in this user's git credential store inside the deployment container (SOP-15).
#   publish_public_cron.sh LIST_FILE      # one clone URL per line, # comments allowed
set -uo pipefail
LIST="${1:?list file of repository URLs}"
STATE="${STATE_DIR:-$HOME/.local/state/publish_public}"; mkdir -p "$STATE/www"; export PUBLISH_STATE="$STATE"
HERE="$(cd "$(dirname "$0")" && pwd)"
log() { echo "$(date -u +%FT%TZ) $*" >>"$STATE/publication.log"; }
while IFS= read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  name="$(basename "${url%.git}")"; bare="$STATE/$name.git"; marker="$STATE/$name.last"
  if [[ -d "$bare" ]]; then git -C "$bare" fetch -q --prune origin '+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*' || { log "$name fetch failed"; continue; }
  else git clone -q --bare "$url" "$bare" || { log "$name clone failed"; continue; }; fi
  now="$(git -C "$bare" for-each-ref --format='%(objectname) %(refname)' | sha1sum | cut -c1-16)"
  [[ -f "$marker" && "$(cat "$marker")" == "$now" ]] && continue
  co="$(mktemp -d)"
  if git clone -q "$bare" "$co" && [[ -f "$co/.config/publish.toml" ]] && python3 -I "$HERE/publish.py" --repo "$co" >>"$STATE/$name.out" 2>&1; then
    echo "$now" >"$marker"; log "$name pipelines ran $now"
  else log "$name pipeline failed (see $name.out and the status page)"; fi
  rm -rf "$co"
done <"$LIST"
