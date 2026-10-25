#!/usr/bin/env bash
# SOP-14 publication trigger without a runner: run from cron on a machine that is not the author's
# laptop (srv), every 15 minutes. Fetches the private repository, and when main or the tags moved
# since the last run, regenerates the public repository with tools/publish_public.sh.
#   PRIVATE_URL  private forge clone URL (read access)
#   STATE_FILE   where the last published main commit is kept (default ~/.local/state/publish_public/last)
#   The public repository's token lives in a credential helper or a file readable only by this user;
#   it is never passed on the command line or exported from an interactive session.
set -euo pipefail
PRIVATE_URL="${PRIVATE_URL:?set PRIVATE_URL}"
STATE_FILE="${STATE_FILE:-$HOME/.local/state/publish_public/last}"
WORK="${WORK:-$HOME/.local/state/publish_public/private.git}"
mkdir -p "$(dirname "$STATE_FILE")"
if [[ -d "$WORK" ]]; then git -C "$WORK" fetch -q --prune origin '+refs/heads/main:refs/heads/main' '+refs/tags/*:refs/tags/*'; else git clone -q --bare "$PRIVATE_URL" "$WORK"; fi
now="$(git -C "$WORK" rev-parse main)-$(git -C "$WORK" tag | sort | sha1sum | cut -c1-12)"
[[ -f "$STATE_FILE" && "$(cat "$STATE_FILE")" == "$now" ]] && exit 0
# publish from a working checkout of the bare mirror so the filter lists are the committed ones
CO="$(mktemp -d)"; trap 'rm -rf "$CO"' EXIT
git clone -q "$WORK" "$CO" && (cd "$CO" && tools/publish_public.sh)
echo "$now" >"$STATE_FILE"
echo "$(date -u +%FT%TZ) published $now" >>"$(dirname "$STATE_FILE")/publication.log"
