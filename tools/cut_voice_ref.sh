#!/usr/bin/env bash
# Cut one reference clip the way atwood's refs were cut (voices.json "from"):
# mono, 22050 Hz, highpass 70 Hz, loudnorm I=-20, 16-bit PCM.
# usage: tools/cut_voice_ref.sh SRC.wav START_S END_S OUT.wav
# Two-pass loudnorm (measure, then apply the measured values). On 2026-10-28 the epstein clips
# measured -22.3 to -23.1 LUFS, not -20: the second pass undershoots (bd 9tk5 follow-up).
set -euo pipefail
src=$1; s=$2; e=$3; out=$4
dur=$(awk -v s="$s" -v e="$e" 'BEGIN{printf "%.3f", e-s}')
pre="highpass=f=70"
meas=$(nice -n 19 ionice -c3 ffmpeg -hide_banner -nostats -ss "$s" -t "$dur" -i "$src" -ac 1 -ar 22050 \
  -af "$pre,loudnorm=I=-20:TP=-1.5:LRA=11:print_format=json" -f null - 2>&1 | sed -n '/^{/,/^}/p')
get() { printf '%s\n' "$meas" | sed -n "s/.*\"$1\" : \"\([^\"]*\)\".*/\1/p"; }
ln="loudnorm=I=-20:TP=-1.5:LRA=11:measured_I=$(get input_i):measured_TP=$(get input_tp):measured_LRA=$(get input_lra):measured_thresh=$(get input_thresh):offset=$(get target_offset):linear=true"
nice -n 19 ionice -c3 ffmpeg -hide_banner -loglevel error -y -ss "$s" -t "$dur" -i "$src" -ac 1 \
  -af "$pre,$ln,aresample=22050" -ar 22050 -c:a pcm_s16le "$out"
echo "$out: $s-$e (${dur}s) measured I=$(get input_i) LUFS"
