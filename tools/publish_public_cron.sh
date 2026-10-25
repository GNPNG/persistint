#!/usr/bin/env bash
# SOP-14 publication, the simple form: one cron line on srv, one list of private repositories, no Gitea
# configuration, no runner, no webhook. Every 15 minutes, for each private repository in the list:
# fetch it, and if main or the tags moved since the last publication, run its own tools/publish_public.sh
# (the repository carries its filter lists and its destination in tools/publish_public.{paths,blobs,dest}).
# A failed run is retried on the next tick; nothing is half-published because the script force-pushes a
# complete regenerated copy or nothing. The GitHub token lives in this user's git credential store.
#   publish_public_cron.sh LIST_FILE      # one private clone URL per line, # comments allowed
set -uo pipefail
LIST="${1:?list file of private repository URLs}"
STATE="${STATE_DIR:-$HOME/.local/state/publish_public}"; mkdir -p "$STATE"
log() { echo "$(date -u +%FT%TZ) $*" >>"$STATE/publication.log"; }
while IFS= read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  name="$(basename "${url%.git}")"; bare="$STATE/$name.git"; marker="$STATE/$name.last"
  if [[ -d "$bare" ]]; then git -C "$bare" fetch -q --prune origin '+refs/heads/main:refs/heads/main' '+refs/tags/*:refs/tags/*' || { log "$name fetch failed"; continue; }
  else git clone -q --bare "$url" "$bare" || { log "$name clone failed"; continue; }; fi
  now="$(git -C "$bare" rev-parse main)-$(git -C "$bare" tag | sort | sha1sum | cut -c1-12)"
  [[ -f "$marker" && "$(cat "$marker")" == "$now" ]] && continue
  co="$(mktemp -d)"
  if git clone -q "$bare" "$co" && [[ -x "$co/tools/publish_public.sh" ]] && (cd "$co" && tools/publish_public.sh >>"$STATE/$name.out" 2>&1); then
    echo "$now" >"$marker"; log "$name published $now"
  else log "$name publication failed (see $name.out)"; fi
  rm -rf "$co"
done <"$LIST"
