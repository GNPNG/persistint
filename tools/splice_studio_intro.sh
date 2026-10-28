#!/usr/bin/env bash
# Rebuild the G|P|G studio intro from the author's Veo render with its glitch cut out (bd r1hp).
#
# The Veo render (prompts/video/ui/assets/studio_intro.veo-original.mp4, 1280x720, 24 fps, 168
# frames, 7.0 s, AAC 48 kHz stereo) plays the ball's flight off the mint paddle twice: a second
# ball leaves the paddle at frame 67 (0-based) and retraces the first ball's path exactly 8 frames
# behind it, so frames 67-69 (2.792-2.917 s) show two balls and from frame 70 the ball jumps back
# to where it was at frame 62. The cut, film-editor style, whole frames only:
#   picture  drop frames 62-69 (2.583-2.917 s): frame 61 cuts straight to frame 70, where the second
#            ball is one step (25 px) on from the first ball at frame 61, so the ball flies on
#            unbroken and the hearts' jump falls inside the hit's burst. 8 frames, 0.333 s.
#   sound    0.333 s out between the two hits, so the pink hit and the letters stay on their
#            picture. The music is a 0.25 s pulse of chord stabs (high and low in turn, so the
#            pattern repeats every 0.5 s), and a plain 0.333 s cut would trip the beat; instead
#            cut exactly one repeat, 3.200 s to 3.700 s (in the gaps before two low stabs, inside
#            the same held bass note and 1.5 kHz tone, phase-matched to the sample; 20 ms linear
#            crossfade), and give 0.167 s back as silence in the rest before the sting's downbeat
#            (at 3.978 s, where the sound is at -68 dB; 3 ms fades), which grows from about 0.08 s
#            to 0.25 s, one beat. The mint hit at 2.58 s is untouched; from the downbeat on, sound
#            and picture are exactly 8 frames earlier than in the render.
#            (Dropping 4 more single frames in the flight back, to match a plain 0.5 s cut, was
#            tried: the ball hitches 4 times in 0.4 s, where the eye follows it.)
# Result: 160 frames, 6.667 s of picture, 6.685 s of sound.
#
# Outputs (the same encoders as tools/sync_rendered_assets.py for the game file):
#   prompts/video/ui/assets/studio_intro.mp4     1280x720 H.264 CRF 16, AAC 192 kb/s: the fixed
#                                                drop that sync_rendered_assets.py converts
#   prompts/video/ui/assets/studio_intro.2x.mp4  2560x1440 (lanczos 2x) H.264 CRF 17: master
#   project/assets/video/studio_intro.ogv        1280x720 Theora -q:v 7, Vorbis -q:a 5: the game's
#
# Usage: tools/splice_studio_intro.sh [--work DIR]   (DIR keeps the edited WAV; default a temp dir)
# Run it under `nice -n 19 ionice -c3` on a laptop. Needs ffmpeg with libx264, libtheora, libvorbis.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SRC=prompts/video/ui/assets/studio_intro.veo-original.mp4
SRC_SHA256=7d3fabe99b4e876f03f26419b8628fc9a57e1ad0a690bd414023d93ef3ef68cb
OUT_MP4=prompts/video/ui/assets/studio_intro.mp4
OUT_2X=prompts/video/ui/assets/studio_intro.2x.mp4
OUT_OGV=project/assets/video/studio_intro.ogv

WORK=""
while (($#)); do
  case "$1" in
    --work) WORK="$2"; shift 2 ;;
    -h|--help) sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "$0"; exit 0 ;;
    *) echo "splice_studio_intro: unknown option $1" >&2; exit 2 ;;
  esac
done
if [[ -z $WORK ]]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
fi
mkdir -p "$WORK"

[[ -f $SRC ]] || { echo "splice_studio_intro: $SRC missing (git lfs pull --include=$SRC)" >&2; exit 1; }
echo "$SRC_SHA256  $SRC" | sha256sum -c --quiet - \
  || { echo "splice_studio_intro: $SRC is not the Veo render this cut was made for" >&2; exit 1; }

# Picture: whole frames out, the rest renumbered at 24 fps.
DROP='between(n,62,69)'
PICTURE="select='not($DROP)',setpts=N/(24*TB)"

# Sound, in samples at 48 kHz: [0, 153600) + crossfade + [177598, 190944) + 7998 of silence +
# [190944, end). 153600 = 3.200 s, 177598 = 3.69996 s (the best phase match within 6 ms of
# 3.700 s); each side carries half the 960-sample (20 ms) crossfade, so 23998 samples go there.
# 190944 = 3.978 s, in the rest before the downbeat; 7998 come back, so 16000 go in all, exactly
# the 8 frames the picture loses.
SOUND='[0:a]atrim=end_sample=154080,asetpts=PTS-STARTPTS[a0];'
SOUND+='[0:a]atrim=start_sample=177118:end_sample=190944,asetpts=PTS-STARTPTS,'
SOUND+='afade=t=out:ss=13682:ns=144,apad=pad_len=7998[a1];'
SOUND+='[0:a]atrim=start_sample=190944,asetpts=PTS-STARTPTS,afade=t=in:ss=0:ns=144[a2];'
SOUND+='[a0][a1]acrossfade=ns=960:c1=tri:c2=tri[a01];[a01][a2]concat=n=2:v=0:a=1[a]'
ffmpeg -hide_banner -loglevel error -y -i "$SRC" -filter_complex "$SOUND" -map '[a]' \
  -c:a pcm_s16le "$WORK/sound.wav"

TAGS=(-color_range tv -colorspace smpte170m -color_primaries bt709 -color_trc iec61966-2-1)
ffmpeg -hide_banner -loglevel error -y -i "$SRC" -i "$WORK/sound.wav" -map 0:v:0 -map 1:a:0 \
  -vf "$PICTURE" -r 24 -c:v libx264 -preset slow -tune animation -crf 16 -pix_fmt yuv420p "${TAGS[@]}" \
  -c:a aac -b:a 192k -movflags +faststart "$OUT_MP4"
ffmpeg -hide_banner -loglevel error -y -i "$SRC" -i "$WORK/sound.wav" -map 0:v:0 -map 1:a:0 \
  -vf "$PICTURE,scale=2560:1440:flags=lanczos+accurate_rnd+full_chroma_int" -r 24 \
  -c:v libx264 -preset slow -tune animation -crf 17 -pix_fmt yuv420p "${TAGS[@]}" \
  -c:a aac -b:a 192k -movflags +faststart "$OUT_2X"
ffmpeg -hide_banner -loglevel error -y -i "$SRC" -i "$WORK/sound.wav" -map 0:v:0 -map 1:a:0 \
  -vf "$PICTURE" -r 24 -c:v libtheora -q:v 7 -pix_fmt yuv420p -c:a libvorbis -q:a 5 "$OUT_OGV"

for f in "$OUT_MP4" "$OUT_2X" "$OUT_OGV"; do
  printf '%s: %s B, %s\n' "$f" "$(wc -c <"$f")" "$(ffprobe -v error -select_streams v:0 -count_packets \
    -show_entries stream=width,height,nb_read_packets:format=duration -of csv=p=0 "$f" | paste -sd' ')"
done
