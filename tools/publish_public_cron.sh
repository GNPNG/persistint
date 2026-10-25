#!/usr/bin/env bash
# SOP-15 (org vault) deployment server, the whole of it: one cron line, one list of repositories, this loop, and the
# handler (publish.py) beside it. Every tick, for each repository in the list: fetch it; work out which
# refs moved since the last successful tick; if any did, check out main and run the handler, which reads
# the checkout's .config/publish.toml and runs each target whose trigger (`on`, default version tags)
# matches a moved ref: filtered publication, mirror replication, or a command such as a site deploy.
# A failed tick is retried on the next one (the ref snapshot advances only on success); a filtered
# publication is force-pushed whole or not at all. Run records: $STATE/runs.jsonl, for whatever runner UI
# or dashboard SOP-15 chooses. The bare clones are full mirrors (every ref, beads data included) and so
# double as the backup of every listed repository: keep $STATE on its own ZFS dataset and snapshot it.
# Credentials live in this user's git credential store inside the container.
#   publish_public_cron.sh LIST_FILE      # one clone URL per line, # comments allowed
set -uo pipefail
LIST="${1:?list file of repository URLs}"
STATE="${STATE_DIR:-$HOME/.local/state/publish_public}"; mkdir -p "$STATE"; export PUBLISH_STATE="$STATE"
HERE="$(cd "$(dirname "$0")" && pwd)"
log() { echo "$(date -u +%FT%TZ) $*" >>"$STATE/publication.log"; }
while IFS= read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  name="$(basename "${url%.git}")"; bare="$STATE/$name.git"; snap="$STATE/$name.refs"
  if [[ -d "$bare" ]]; then git -C "$bare" fetch -q --prune origin || { log "$name fetch failed"; continue; }
  else git clone -q --mirror "$url" "$bare" || { log "$name clone failed"; continue; }; fi
  new="$(git -C "$bare" for-each-ref --format='%(objectname) %(refname)')"
  changed="$(comm -13 <(sort "$snap" 2>/dev/null) <(echo "$new" | sort) | awk '{print $2}')"   # refs new or moved
  [[ -z "$changed" ]] && continue
  co="$(mktemp -d)"
  if git clone -q "$bare" "$co" && [[ -f "$co/.config/publish.toml" ]] && python3 -I "$HERE/publish.py" --repo "$co" --changed $changed >>"$STATE/$name.out" 2>&1; then
    echo "$new" >"$snap"; log "$name ran for: $(echo $changed)"
  elif [[ ! -f "$co/.config/publish.toml" ]]; then echo "$new" >"$snap"; log "$name has no .config/publish.toml; nothing to run"
  else log "$name handler failed (see $name.out); will retry"; fi
  rm -rf "$co"
done <"$LIST"
