#!/usr/bin/env bash
# Move one repository from the archive-tier Gitea (NAS) to the development tier (srv), history,
# branches, tags and the beads data ref included. Run from any workstation with push rights to both.
#
#   ./migrate-repo.sh https://gitea.old/org/repo.git https://forge.new/org/repo.git
#
# The destination repo must exist (create it in the UI, with tea, or through the MCP server; the
# forge also has ENABLE_PUSH_CREATE_ORG, so a push to a new name under an existing org creates it).
set -euo pipefail
SRC="${1:?source clone URL}"; DST="${2:?destination clone URL}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo "== mirror clone of $SRC"
git clone --quiet --mirror "$SRC" "$TMP/repo.git"
cd "$TMP/repo.git"
# refs/dolt/* (beads) and refs/notes/* travel with --mirror; show what goes across
echo "refs: $(git for-each-ref --format='%(refname)' | wc -l) ($(git for-each-ref --format='%(refname)' refs/dolt | wc -l) dolt, $(git for-each-ref --format='%(refname)' refs/tags | wc -l) tags)"
echo "== push --mirror to $DST"
git -c http.version=HTTP/1.1 -c http.postBuffer=524288000 push --mirror "$DST"
echo "== verify"
diff <(git ls-remote "$SRC" | sort) <(git ls-remote "$DST" | sort) && echo "identical ref lists" || echo "ref lists differ (see above)"
cat <<NEXT

Next, in each checkout of this repository:
  git remote set-url origin $DST
  git remote -v
Beads (its Dolt remote follows the git remote):
  bd remote list            # see the current dolt remote
  bd remote set origin $DST  # or the bd equivalent in this version; then: bd sync
Mirrors on the new forge (Settings > Repository > Mirror settings):
  push mirror to $SRC (backup tier), interval 2h, sync on commit off
  push mirror to GitHub (public), interval 2h, sync on commit off; remove the same mirror from $SRC
Tools: tea login add for the new forge; the Gitea MCP server's URL and token; the GitHub token re-entered once.
NEXT
