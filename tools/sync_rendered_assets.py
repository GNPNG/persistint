#!/usr/bin/env python3
"""Copy rendered assets from prompts/**/assets/ to their game paths in project/.

Each prompt file's front matter names `drop:` (where the rendered file is saved) and `game:`
(where the game loads it). .mp4 drops are converted to .ogv (Theora) with ffmpeg, without
sound unless the front matter says `audio: keep` (then the sound is kept as Vorbis); .mp3 drops
are re-encoded at 112 kbps for the game copy and normalized to the music target (tools/audio_levels.py:
-18 LUFS, -1.5 dBTP; the drop keeps the render's bitrate and level). `--force [ext]` redoes game
copies that already exist (all of them, or those with that extension).
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_levels  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
FORCE = "--force" in sys.argv
FORCE_EXT = next((a for a in sys.argv[sys.argv.index("--force") + 1:] if not a.startswith("-")), None) if FORCE else None
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
    forced = FORCE and (FORCE_EXT is None or dest.suffix == "." + FORCE_EXT.lstrip("."))
    if not forced and dest.exists() and dest.stat().st_mtime >= src.stat().st_mtime and (
            dest.suffix != src.suffix or dest.suffix == ".mp3"):
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
        m = audio_levels.normalize(src, dest, audio_levels.MUSIC,
                                   ("-codec:a", "libmp3lame", "-b:a", "112k", "-ar", "44100"))
        print(f"  {src.name}: {m['I']:.1f} LUFS, peak {m['TP']:.1f} dBTP -> {audio_levels.MUSIC['I']:.0f} LUFS")
    else:
        shutil.copyfile(src, dest)
    print("synced", game.group(1))
print(f"{len(missing)} not rendered yet:")
for m in missing:
    print("  ", m)
