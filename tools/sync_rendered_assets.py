#!/usr/bin/env python3
"""Copy rendered assets from prompts/**/assets/ to their game paths in project/.

Each prompt file's front matter names `drop:` (where the rendered file is saved) and `game:`
(where the game loads it). .mp4 drops are converted to .ogv (Theora) with ffmpeg.
"""
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
missing = []
for prompt in sorted((ROOT / "prompts").rglob("*.md")):
    if prompt.parent == ROOT / "prompts":  # STYLE.md and README.md are not asset prompts
        continue
    text = prompt.read_text()
    drop = re.search(r"^drop: (.*)$", text, re.M)
    game = re.search(r"^game: (.*)$", text, re.M)
    if not (drop and game):
        continue
    src, dest = ROOT / drop.group(1), ROOT / game.group(1)
    if not src.exists():
        missing.append(drop.group(1))
        continue
    dest.parent.mkdir(parents=True, exist_ok=True)
    if src.suffix == ".mp4" and dest.suffix == ".ogv":
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-c:v", "libtheora",
                        "-q:v", "7", "-an", str(dest)], check=True)
    else:
        shutil.copyfile(src, dest)
    print("synced", game.group(1))
print(f"{len(missing)} not rendered yet:")
for m in missing:
    print("  ", m)
