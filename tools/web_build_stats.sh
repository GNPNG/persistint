#!/usr/bin/env bash
# Write build-stats.json into a web export folder: the build id and how much a browser downloads
# to start the game (PW-04 download-size warning). Run at build time, right after the Web export,
# by tools/build_all.sh and tools/deploy_site.sh; the play page reads load_mb from the file.
#
# Usage: tools/web_build_stats.sh <web export folder> [build id]
#   Counts every file except *.import and build-stats.json itself. When both <file> and
#   <file>.gz exist, only the .gz counts (the server sends the gzipped copy).
set -euo pipefail
dir="${1:?usage: tools/web_build_stats.sh <web export folder> [build id]}"
build="${2:-}"
[[ -d "$dir" ]] || { echo "web_build_stats: no folder $dir" >&2; exit 1; }
bytes=0
while IFS= read -r -d '' f; do
  case "$f" in *.import|*/build-stats.json) continue ;; esac
  [[ "$f" != *.gz && -f "$f.gz" ]] && continue
  bytes=$((bytes + $(stat -c %s "$f")))
done < <(find "$dir" -type f -print0)
mb=$(( (bytes + 524288) / 1048576 ))
printf '{"build": "%s", "load_bytes": %d, "load_mb": %d, "measured_at": "%s"}\n' \
  "$build" "$bytes" "$mb" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$dir/build-stats.json"
echo "web_build_stats: $dir: about $mb MB to load"
