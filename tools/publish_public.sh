#!/usr/bin/env bash
# SOP-14 publication: regenerate the public repository as a filtered copy of the private history and
# force-push it. The private forge is never rewritten; the public repository is disposable.
#
#   tools/publish_public.sh [--dry-run] [--dest URL]
#
# Filter list: tools/publish_public.paths (one path or glob per line, removed from every commit), plus
# tools/publish_public.blobs (blob ids to strip, for material that moved between paths). Branches
# published: main and tags only, unless PUBLISH_REFS is set.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${DEST:-$( [[ -s "$(dirname "$0")/publish_public.dest" ]] && head -n1 "$(dirname "$0")/publish_public.dest" || echo https://github.com/GNPNG/persistint.git )}"; DRY=0
for a in "$@"; do case "$a" in --dry-run) DRY=1 ;; --dest=*) DEST="${a#--dest=}" ;; esac; done
command -v git-filter-repo >/dev/null 2>&1 || git filter-repo --version >/dev/null 2>&1 || { echo "git-filter-repo missing" >&2; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "== fresh mirror of the private repository"
git clone -q --mirror --no-local "$ROOT" "$WORK/pub.git"
cd "$WORK/pub.git"
ARGS=()
if [[ -s "$ROOT/tools/publish_public.paths" ]]; then
  while IFS= read -r p; do [[ -z "$p" || "$p" == \#* ]] && continue; ARGS+=(--path-glob "$p"); done < "$ROOT/tools/publish_public.paths"
  ARGS+=(--invert-paths)
fi
[[ -s "$ROOT/tools/publish_public.blobs" ]] && ARGS+=(--strip-blobs-with-ids "$ROOT/tools/publish_public.blobs")
if [[ ${#ARGS[@]} -gt 0 ]]; then
  echo "== filtering: ${ARGS[*]}"
  git filter-repo --force "${ARGS[@]}" >/dev/null
fi
echo "== check: no private path survives"
for p in $(grep -vE '^\s*(#|$)' "$ROOT/tools/publish_public.paths" 2>/dev/null || true); do
  if git log --all --format=%h -- "$p" | grep -q .; then echo "private path still present: $p" >&2; exit 2; fi
done
REFS="${PUBLISH_REFS:-refs/heads/main:refs/heads/main refs/tags/*:refs/tags/*}"
echo "== publish to $DEST: $REFS"
if [[ $DRY = 1 ]]; then git for-each-ref --format='%(refname) %(objectname:short)' refs/heads/main refs/tags; echo "(dry run, nothing pushed)"; exit 0; fi
# shellcheck disable=SC2086
git -c credential.helper='!gh auth git-credential' push --force --prune "$DEST" $REFS
echo "published $(git rev-parse --short refs/heads/main) to $DEST"
