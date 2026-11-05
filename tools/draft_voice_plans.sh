#!/bin/sh
# Draft one voice work plan per entry in project/data/voices.json (bead persistint-game-mt29).
# Each plan records what the repo already says about the voice's source and lists the commands
# that would recut the reference and generate clips. Plans are DRAFTS: nothing in them is run
# until the author has reviewed and approved that voice's sources (author rule, 2026-11-04).
# Usage: sh tools/draft_voice_plans.sh   (writes dev/voice-plans/<voice>.md; never overwrites an approved plan)
set -eu
cd "$(dirname "$0")/.."
out=dev/voice-plans
mkdir -p "$out"
jq -r 'to_entries[] | select(.key != "_note") | .key' project/data/voices.json | while IFS= read -r id; do
  slug=$(printf '%s' "$id" | tr ' A-Z' '_a-z')
  f="$out/$slug.md"
  if [ -f "$f" ] && grep -q '^Status: APPROVED' "$f"; then
    echo "skip $f (approved)"; continue
  fi
  v=$(jq -c --arg k "$id" '.[$k]' project/data/voices.json)
  get() { printf '%s' "$v" | jq -r "$1 // \"\""; }
  builtin=$(get .builtin)
  {
    echo "# Voice work plan: $id"
    echo
    echo "Status: DRAFT, awaiting author review (bead persistint-game-mt29)"
    echo
    echo "Nothing below is run until the author approves this plan's sources (author, 2026-11-04:"
    echo "\"every voice should have a scripted work plan that documents user-authorized sources"
    echo "for generating the voice models. These must be reviewed by the user for appropriateness,"
    echo "etc. before the generation is run.\")"
    echo
    if [ -n "$builtin" ]; then
      echo "## Source"
      echo
      echo "XTTS-v2 built-in studio voice \"$builtin\". No recording of a real person is used."
      echo
      echo "Author to confirm: this built-in voice is acceptable for $id."
    else
      echo "## Source as recorded in project/data/voices.json"
      echo
      echo "| Field | Value |"
      echo "|---|---|"
      echo "| Reference file | \`$(get .ref)\` |"
      echo "| Source URL | $(get .source) |"
      echo "| Span | $(get .span) |"
      echo "| Recording | $(get .from) |"
      echo "| Audio captured | $(get .captured) |"
      extra=$(get '.extra_spans | if . then join(", ") else empty end')
      [ -n "$extra" ] && echo "| Extra spans | $extra |"
      echo
      if [ "$(get .source)" = "unknown" ]; then
        echo "Provenance was never recorded (release checklist LP-05). The author must name an"
        echo "authorized source recording and span before this voice is modelled again."
      else
        echo "Author to confirm: this recording and span are authorized and appropriate."
      fi
      echo
      echo "## Recut the reference (after approval)"
      echo
      echo '```sh'
      echo "yt-dlp -x --audio-format wav -o art/voice_refs/src_$slug.%(ext)s '$(get .source)'"
      echo "# cut span $(get .span) to $(get .ref), 22.05 kHz mono"
      echo "ffmpeg -i art/voice_refs/src_$slug.wav -ss <start> -to <end> -ac 1 -ar 22050 $(get .ref)"
      echo '```'
      echo
      echo "Then set \"captured\" in project/data/voices.json to the download date."
    fi
    echo
    echo "## Generate clips (after approval)"
    echo
    echo '```sh'
    echo "python3 tools/generate_voice_clips.py --speaker '$id' --force"
    echo "python3 tools/normalize_voice_clips.py"
    echo "python3 tools/verify_voice_clips.py"
    echo '```'
    echo
    echo "Source-clip QA is the author's; agents run these only once Status reads APPROVED."
  } > "$f"
  echo "wrote $f"
done
