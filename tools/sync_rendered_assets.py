#!/usr/bin/env python3
"""Copy rendered assets from prompts/**/assets/ to their game paths in project/.

Each prompt file's front matter names `drop:` (where the rendered file is saved) and `game:`
(where the game loads it). .mp4 drops are converted to .ogv (Theora) with ffmpeg, without
sound unless the front matter says `audio: keep` (then the sound is kept as Vorbis); .mp3 drops
are re-encoded at 112 kbps for the game copy (the drop keeps the render's bitrate).
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
    if dest.exists() and dest.stat().st_mtime >= src.stat().st_mtime and dest.suffix != src.suffix or (
            dest.exists() and dest.suffix == ".mp3" and dest.stat().st_mtime >= src.stat().st_mtime):
        # Already converted from this drop: re-encoding would only churn the committed file.
        continue
    if src.suffix == ".mp4" and dest.suffix == ".ogv":
        keep_audio = re.search(r"^audio: keep$", text, re.M) is not None
        audio = ["-c:a", "libvorbis", "-q:a", "5"] if keep_audio else ["-an"]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-c:v", "libtheora",
                        "-q:v", "7", *audio, str(dest)], check=True)
    elif src.suffix == ".mp3" and dest.suffix == ".mp3":
        # The drop keeps the render's own bitrate; the game copy is re-encoded for the web build
        # (112 kbps joint stereo: ten tracks were 40 MB of a 103 MB index.pck).
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-codec:a", "libmp3lame",
                        "-b:a", "112k", "-ar", "44100", str(dest)], check=True)
    else:
        shutil.copyfile(src, dest)
    print("synced", game.group(1))
print(f"{len(missing)} not rendered yet:")
for m in missing:
    print("  ", m)
