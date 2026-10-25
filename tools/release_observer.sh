#!/usr/bin/env bash
# SOP-15 (org vault) release observer: runs on the LXD host, outside the deployment container, from its own cron line.
# Watches the PUBLIC side (the author 2026-10-25: "an observer script outside of that container could
# actually watch the public repos, eg: Github, and on noticing a successful public release, do an
# 'lxc snapshot' on that container. Meaning that we have a snapshot of the repo of the release.").
# For each public URL in the list: ls-remote its tags; every tag not seen before that matches the pattern
# is a release that reached the public; snapshot the container once per new tag. No credentials needed:
# the repositories watched are public. State: one tags file per repository under $STATE.
#   release_observer.sh LIST_FILE CONTAINER [TAG_GLOB]      # LIST: one public clone URL per line; default glob v*
set -uo pipefail
LIST="${1:?list file of public repository URLs}"; CT="${2:?LXD container name}"; GLOB="${3:-v*}"
STATE="${STATE_DIR:-$HOME/.local/state/release_observer}"; mkdir -p "$STATE"
log() { echo "$(date -u +%FT%TZ) $*" >>"$STATE/observer.log"; }
while IFS= read -r url; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  name="$(basename "${url%.git}")"; seen="$STATE/$name.tags"
  tags="$(git ls-remote --tags --refs "$url" 2>/dev/null | awk '{sub("refs/tags/","",$2); print $2}' | sort)" || { log "$name ls-remote failed"; continue; }
  [[ -z "$tags" ]] && continue
  if [[ ! -f "$seen" ]]; then echo "$tags" >"$seen"; log "$name baseline: $(echo $tags)"; continue; fi
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    case "$tag" in $GLOB) ;; *) continue ;; esac
    snap="release-$name-$tag-$(date -u +%Y%m%dT%H%M%SZ)"
    if lxc snapshot "$CT" "$snap"; then log "$name $tag public: snapshot $CT/$snap"; else log "$name $tag public: snapshot FAILED"; fi
  done < <(comm -13 "$seen" <(echo "$tags"))
  echo "$tags" >"$seen"
done <"$LIST"
