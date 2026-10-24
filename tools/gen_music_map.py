#!/usr/bin/env python3
"""Write the track tables of project/data/music.json from the audio prompts' front matter.

Every prompt under prompts/audio/music/ becomes a loop track and every prompt under
prompts/audio/stingers/ a one-shot stinger: `id:` is the track id, `game:` (minus the leading
`project/`) is the res:// path the Music autoload loads — the same path
tools/sync_rendered_assets.py copies the rendered file to. The hand-written parts of music.json
(scenes, chapter_end_stingers, events, ...) are kept as they are.

Run after adding or renaming a music prompt:  python3 tools/gen_music_map.py
--check exits non-zero instead of writing when music.json is out of date.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "project" / "data" / "music.json"


def table(folder: str) -> dict:
    out = {}
    for prompt in sorted((ROOT / "prompts" / "audio" / folder).rglob("*.md")):
        text = prompt.read_text()
        pid = re.search(r"^id: (.*)$", text, re.M)
        game = re.search(r"^game: (.*)$", text, re.M)
        if not (pid and game):
            continue
        path = game.group(1).strip()
        if not path.startswith("project/"):
            sys.exit(f"{prompt}: game path is not under project/: {path}")
        out[pid.group(1).strip()] = "res://" + path[len("project/"):]
    return out


def main() -> None:
    data = json.loads(DATA.read_text()) if DATA.exists() else {}
    data["tracks"] = table("music")
    data["stingers"] = table("stingers")
    text = json.dumps(data, indent="\t", ensure_ascii=False) + "\n"
    if "--check" in sys.argv:
        if not DATA.exists() or DATA.read_text() != text:
            sys.exit("project/data/music.json is out of date: run python3 tools/gen_music_map.py")
        print("music.json is up to date")
        return
    DATA.write_text(text)
    print(f"wrote {DATA.relative_to(ROOT)}: {len(data['tracks'])} tracks, {len(data['stingers'])} stingers")


main()
