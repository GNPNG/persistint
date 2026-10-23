"""Generate impersonated voice clips for every spoken line (beads persistint-game-zkk).

Usage:
  python3 -I tools/export_voice_lines.py          # refresh project/audio/voice/manifest.json
  python3 -I tools/generate_voice_clips.py [--speaker NAME] [--force]

Each speaker's voice comes from a reference recording: art/voice_refs/<speaker>.wav, where
<speaker> is the name as it appears in the manifest (e.g. "Chelsea Clinton.wav"). 6-30 s of clean
speech works best. Clips are synthesized with Coqui XTTS-v2 (an LLM-based TTS: a GPT-style model
that speaks text in the reference speaker's voice) and written to project/audio/voice/<key>.wav,
which Voice.speak plays instead of system text-to-speech. Lines whose speaker has no reference
recording are skipped. Requires: pip install coqui-tts (uses CUDA when available).
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "project/audio/voice/manifest.json"
REFS = ROOT / "art/voice_refs"
OUT = ROOT / "project/audio/voice"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--speaker", help="only this speaker")
    ap.add_argument("--force", action="store_true", help="regenerate existing clips")
    args = ap.parse_args()

    lines = json.loads(MANIFEST.read_text())
    todo = []
    for line in lines:
        if args.speaker and line["speaker"] != args.speaker:
            continue
        ref = REFS / f"{line['speaker']}.wav"
        clip = OUT / f"{line['key']}.wav"
        if not ref.exists():
            continue
        if clip.exists() and not args.force:
            continue
        todo.append((line, ref, clip))
    missing = sorted({l["speaker"] for l in lines if not (REFS / f"{l['speaker']}.wav").exists()})
    if missing:
        print("no reference recording (skipped):", ", ".join(missing))
    if not todo:
        print("nothing to generate")
        return

    import torch
    from TTS.api import TTS

    device = "cuda" if torch.cuda.is_available() else "cpu"
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
    for line, ref, clip in todo:
        tts.tts_to_file(text=line["text"], speaker_wav=str(ref), language="en", file_path=str(clip))
        print(f"{line['speaker']}: {line['text'][:60]} -> {clip.name}")


if __name__ == "__main__":
    main()
