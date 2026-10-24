#!/usr/bin/env python3
"""Bring every committed voice clip (project/audio/voice/**/*.wav, baked clone copies included) to the voice level: -16 LUFS
integrated, true peak -1 dBTP (tools/audio_levels.py). Idempotent: a clip already within
tolerance is left alone; the others are rewritten in place with a static gain and a limiter.
New clips get this at generation (tools/generate_voice_clips.py); this is for the ones made
before, and for a target change.

    python3 tools/normalize_voice_clips.py [--check]   # --check only reports, exit 1 if any is off
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_levels  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CLIPS = ROOT / "project" / "audio" / "voice"


def main() -> int:
    check = "--check" in sys.argv
    off = fixed = 0
    for wav in sorted(CLIPS.rglob("*.wav")):
        m = audio_levels.measure(wav)
        if audio_levels.in_range(m, audio_levels.VOICE):
            continue
        off += 1
        if check:
            print(f"off: {wav.name}  {m['I']} LUFS  {m['TP']} dBTP")
            continue
        audio_levels.normalize(wav, wav, audio_levels.VOICE, ("-codec:a", "pcm_s16le"))
        after = audio_levels.measure(wav)
        fixed += 1
        print(f"{wav.name}: {m['I']:.1f} -> {after['I']:.1f} LUFS, peak {m['TP']:.1f} -> {after['TP']:.1f} dBTP")
    print(f"{off} clip(s) off target, {fixed} rewritten")
    return 1 if (check and off) else 0


if __name__ == "__main__":
    sys.exit(main())
