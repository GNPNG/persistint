"""Generate impersonated voice clips for every spoken line (beads persistint-game-zkk).

Usage:
  python3 -I tools/export_voice_lines.py          # refresh project/audio/voice/manifest.json
  python3 -I tools/generate_voice_clips.py [--speaker NAME] [--force]

Each speaker's voice is set in project/data/voices.json (keyed by cast id): a reference
recording of the real person ("ref", 6-30 s of clean speech) or one of XTTS-v2's built-in
studio voices ("builtin") for characters who aren't real people. Clips are synthesized with Coqui XTTS-v2 (an LLM-based TTS: a GPT-style model
that speaks text in the reference speaker's voice) and written to project/audio/voice/<key>.wav,
which Voice.speak plays instead of system text-to-speech. Lines whose speaker has no reference
recording are skipped. Requires: pip install coqui-tts (uses CUDA when available).
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "project/audio/voice/manifest.json"
CAST = ROOT / "project/data/cast.json"
VOICES = ROOT / "project/data/voices.json"
OUT = ROOT / "project/audio/voice"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--speaker", action="append", help="only this speaker (repeatable)")
    ap.add_argument("--key", action="append", help="only this clip key (repeatable; e.g. to redo a flagged clip)")
    ap.add_argument("--force", action="store_true", help="regenerate existing clips")
    args = ap.parse_args()

    lines = json.loads(MANIFEST.read_text())
    cast = json.loads(CAST.read_text())
    voices = json.loads(VOICES.read_text())
    by_name = {v["name"]: voices.get(cid) for cid, v in cast.items() if isinstance(v, dict) and "name" in v}
    by_name.update({k: v for k, v in voices.items() if not k.startswith("_") and k not in cast})

    def voice_for(speaker):
        v = by_name.get(speaker) or voices.get(speaker) or {}
        if "ref" in v and (ROOT / v["ref"]).exists():
            return {"speaker_wav": str(ROOT / v["ref"])}
        if "builtin" in v:
            return {"speaker": v["builtin"]}
        return None

    todo = []
    for line in lines:
        if args.speaker and line["speaker"] not in args.speaker:
            continue
        if args.key and line["key"] not in args.key:
            continue
        clip = OUT / f"{line['key']}.wav"
        voice = voice_for(line["speaker"])
        if voice is None or (clip.exists() and not args.force):
            continue
        todo.append((line, voice, clip))
    missing = sorted({l["speaker"] for l in lines if voice_for(l["speaker"]) is None})
    if missing:
        print("no voice yet (skipped):", ", ".join(missing))
    if not todo:
        print("nothing to generate")
        return

    import torch
    from TTS.api import TTS

    device = "cuda" if torch.cuda.is_available() else "cpu"
    tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to(device)
    for line, voice, clip in todo:
        tts.tts_to_file(text=line["text"], language="en", file_path=str(clip), **voice)
        print(f"{line['speaker']}: {line['text'][:60]} -> {clip.name}")


if __name__ == "__main__":
    main()
