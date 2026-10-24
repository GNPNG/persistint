#!/usr/bin/env python3
"""Bake the kid-clone voice offline: pitched-up copies of the clone originals' clips and of the
clone vocalizations, so the game plays plain samples (no real-time audio effects).

Reads project/audio/voice/manifest.json and data/ruins.json (clone_children.originals: the
speakers whose clips are clone lines). For each of their clips, and for every clone sound effect
(audio/sfx/groan_*.wav, moan.wav, growl.wav), writes audio/voice/clones/<same file name>.wav:
pitch up by --pitch (default 1.3) with the tempo kept, and a touch of bit-crush grit. Idempotent:
a copy newer than its source is kept. Voice.gd plays the copy when a line goes through the
Clones bus and the copy exists.

    python3 tools/bake_clone_voices.py [--pitch 1.3] [--force]
"""
import argparse
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project"
VOICE = PROJECT / "audio" / "voice"
SFX = PROJECT / "audio" / "sfx"
OUT = VOICE / "clones"


def bake(src: Path, dest: Path, pitch: float) -> None:
    rate = 24000
    af = f"asetrate={rate}*{pitch},aresample={rate},atempo={1 / pitch:.6f},acrusher=bits=10:mix=0.12"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-af", af, "-ar", str(rate),
                    "-ac", "1", str(dest)], check=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pitch", type=float, default=1.3)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    ruins = json.loads((PROJECT / "data" / "ruins.json").read_text(encoding="utf-8"))
    originals = set(ruins.get("clone_children", {}).get("originals", {}).keys())
    manifest = json.loads((VOICE / "manifest.json").read_text(encoding="utf-8"))
    sources = [VOICE / f"{e['key']}.wav" for e in manifest if e.get("speaker") in originals]
    sources += sorted(SFX.glob("groan_*.wav")) + [SFX / "moan.wav", SFX / "growl.wav"]
    OUT.mkdir(parents=True, exist_ok=True)
    done = skipped = missing = 0
    for src in sources:
        if not src.exists():
            missing += 1
            continue
        dest = OUT / src.name
        if dest.exists() and not a.force and dest.stat().st_mtime >= src.stat().st_mtime:
            skipped += 1
            continue
        bake(src, dest, a.pitch)
        done += 1
    print(f"baked {done}, kept {skipped}, {missing} clips not generated yet (speakers: {', '.join(sorted(originals))})")


if __name__ == "__main__":
    main()
