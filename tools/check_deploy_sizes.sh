#!/usr/bin/env bash
# Check a web build or site directory against the hosts' size limits (release checklist BD-06,
# sops/09-game-release-checklist.md). Lists every file over a limit and exits non-zero, so a
# deploy stops before the host rejects the upload. tools/deploy_site.sh runs it on site/public
# (the Cloudflare static assets, after the gzip/parts step) and on the Godot export (what an
# itch.io HTML5 upload would carry).
#
# Usage: tools/check_deploy_sizes.sh [--cloudflare=DIR] [--itch=DIR]
#   --cloudflare=DIR  every file in DIR is a Cloudflare Pages / Workers static asset:
#                     at most 25 MiB per file and 20,000 files (Free plan).
#   --itch=DIR        DIR is the content of an itch.io HTML5 zip (index.html at the top):
#                     at most 200 MB per file, 1,000 files, 500 MB in all once extracted,
#                     and 240 characters per file name including its path.
#
# Limits (bytes are exact; sizes come from `wc -c`, so a sparse file counts at its full length):
#   Cloudflare Pages, "File size" and "Files": "The maximum file size for a single Cloudflare
#     Pages site asset is 25 MiB."; "up to 20,000 files on the Free plan" (100,000 on paid plans).
#     https://developers.cloudflare.com/pages/platform/limits/ (read 2026-10-27)
#   Cloudflare Workers static assets (host_type workers): the same 25 MiB per file and 20,000
#     files per Worker version on Free (100,000 on Paid).
#     https://developers.cloudflare.com/workers/platform/limits/ (read 2026-10-27)
#   itch.io HTML5: "The size any single extracted file should not be greater than 200MB.";
#     "not more than 1,000 individual files after extraction"; "The size of all the extracted
#     content should not be greater than 500MB."; "The maximum length of a file name including
#     path should not be greater than 240 characters long." The page writes MB; read here as
#     10^6 bytes, the smaller reading. It gives no limit for the zip itself.
#     https://itch.io/docs/creators/html5 (read 2026-10-27)
set -euo pipefail

usage() { sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "$0"; }
die() { printf 'check_deploy_sizes: %s\n' "$*" >&2; exit 1; }

CF_MAX_FILE_BYTES=26214400        # 25 MiB
CF_MAX_FILES=20000                # Free plan
ITCH_MAX_FILE_BYTES=200000000     # 200 MB
ITCH_MAX_FILES=1000
ITCH_MAX_TOTAL_BYTES=500000000    # 500 MB
ITCH_MAX_PATH_CHARS=240

CF_DIR="" ITCH_DIR=""
(($#)) || { usage >&2; exit 2; }
for arg in "$@"; do
  case "$arg" in
    --cloudflare=*) CF_DIR="${arg#--cloudflare=}" ;;
    --itch=*) ITCH_DIR="${arg#--itch=}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $arg (see --help)" ;;
  esac
done

human() { awk -v b="$1" 'BEGIN { printf "%.2f MiB", b / 1048576 }'; }

# check HOST DIR MAX_FILE_BYTES MAX_FILES MAX_TOTAL_BYTES MAX_PATH_CHARS (0 = no limit)
# Prints the totals and every offending file; returns 1 if anything is over.
check() {
  local host="$1" dir="${2%/}" max_file="$3" max_files="$4" max_total="$5" max_path="$6"
  local p rel bytes files=0 total=0 largest=0 largest_name="" fail=0
  local over_size=() over_path=()
  [[ -d "$dir" ]] || die "$host: no such directory: $dir"
  while IFS= read -r -d '' p; do
    rel="${p#"$dir"/}"
    bytes=$(($(wc -c <"$p")))
    files=$((files + 1))
    total=$((total + bytes))
    if ((bytes > largest)); then largest=$bytes largest_name="$rel"; fi
    if ((bytes > max_file)); then
      over_size+=("$(printf '%12s B  %11s  %s' "$bytes" "$(human "$bytes")" "$rel")")
    fi
    if ((max_path && ${#rel} > max_path)); then
      over_path+=("$(printf '%5s chars  %s' "${#rel}" "$rel")")
    fi
  done < <(find "$dir" -type f -print0 | sort -z)

  printf '  %s: %s files, %s B (%s) in all; largest %s (%s B)\n' \
    "$host" "$files" "$total" "$(human "$total")" "${largest_name:-none}" "$largest"
  if ((${#over_size[@]})); then
    printf '  %s: OVER the per-file limit of %s B (%s):\n' "$host" "$max_file" "$(human "$max_file")" >&2
    printf '    %s\n' "${over_size[@]}" >&2
    fail=1
  fi
  if ((files > max_files)); then
    printf '  %s: OVER the file-count limit: %s files, limit %s\n' "$host" "$files" "$max_files" >&2
    fail=1
  fi
  if ((max_total && total > max_total)); then
    printf '  %s: OVER the total size limit: %s B (%s), limit %s B (%s)\n' \
      "$host" "$total" "$(human "$total")" "$max_total" "$(human "$max_total")" >&2
    fail=1
  fi
  if ((${#over_path[@]})); then
    printf '  %s: OVER the path-length limit of %s characters:\n' "$host" "$max_path" >&2
    printf '    %s\n' "${over_path[@]}" >&2
    fail=1
  fi
  return "$fail"
}

status=0
if [[ -n "$CF_DIR" ]]; then
  check cloudflare "$CF_DIR" "$CF_MAX_FILE_BYTES" "$CF_MAX_FILES" 0 0 || status=1
fi
if [[ -n "$ITCH_DIR" ]]; then
  check itch.io "$ITCH_DIR" "$ITCH_MAX_FILE_BYTES" "$ITCH_MAX_FILES" "$ITCH_MAX_TOTAL_BYTES" "$ITCH_MAX_PATH_CHARS" || status=1
fi
((status == 0)) || die "size check failed (limits and sources: tools/check_deploy_sizes.sh --help)"
echo "  size check OK"
