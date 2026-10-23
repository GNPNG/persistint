#!/usr/bin/env python3
"""Mechanical pre-flight check for the asset prompts in prompts/ (see prompts/STYLE.md, sections 11-12).

Checks every leaf prompt file (all prompts/**/*.md except STYLE.md and README.md):
  - front matter: id (= file name), tool (matches the type folder), drop (= <prompt dir>/assets/<id>.<ext>),
    game (under project/, extension matching the drop); ids, drops and game paths unique
  - the assets/ folder beside the prompt exists and holds .gitkeep
  - `## Prompt` and `## Notes` sections present
  - image/video: the compiled preamble (sticker-illustration look, never-black outlines, anti-stair-step
    guard, faces on buildings/trees/props/ship/bunker) and the negative prompt are present; no text asked
    for (only title_screen carries the PERSISTINT logo); no hex colour codes; no real-person names
  - music: the compiled music preamble, the loop or stinger clause and the loudness spec are present
  - vocabulary and lore bans in every leaf file
Exits non-zero on any failure.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROMPTS = ROOT / "prompts"

TOOLS = {"audio": ("Gemini Lyria", "mp3"), "image": ("Gemini image", "png"), "video": ("Gemini Veo", "mp4")}
GAME_EXT = {"mp3": "mp3", "png": "png", "mp4": "ogv"}

# Marker phrases taken from the STYLE.md section 11 preambles and the 4.12 negative prompt.
VISUAL_MARKERS = {
    "preamble (sticker-illustration look)": "clean sticker-illustration",
    "outline rule (never black)": "never black",
    "anti-stair-step guard": "no harsh pixel stair-steps",
    "faces on everything": "on buildings, trees, props, the ship and the bunker",
    "negative prompt": "no harsh pixel stair-stepping",
    "negative prompt (real-person likeness)": "no real-person likeness",
}
MUSIC_MARKERS = {
    "music preamble": "Instrumental video-game music for a kawaii game",
    "loudness spec": "LUFS",
    "spec line": "Spec: instrumental only",
}
LOGO_ASSETS = {"title_screen"}
ALLCAPS_OK = {"VHS"}

# Vocabulary rules (STYLE 1.1) and lore corrections from the prompt audit.
BANNED = [
    (r"\blayers?\b", "use 'area' or 'world' for game spaces"),
    (r"\bguard-?rails?\b", "say 'rule' or 'limit'"),
    (r"\bidyll(ic)?\b|\bparadise\b", "Florida is 'tropical'"),
    (r"\bGilead\b|\bhandmaids?\b|\bOrwell(ian)?\b|\bHunger Games\b|\bBrave New World\b", "no other dystopian fiction"),
    (r"\bzombies?\b", "say 'clone children'"),
    (r"\bcolony\b", "say 'retro sci-fi bunker'"),
    (r"\bcottages?\b", "island homes are bunker-shaped"),
    (r"\bwhite robes?\b", "Initiates wear sailor uniforms; Priestesses lavender robes"),
    (r"\bgreen tanks?\b", "the clone tanks hold pink fluid"),
]
HEX = re.compile(r"#[0-9a-fA-F]{3,8}\b")

# Real people whose names must not reach image/video generators (STYLE 1.2, 7.5).
REAL_IDS = ["chelsea", "tyra", "kate", "silverman", "oprah", "epstein", "bill_clinton", "hillary_clinton", "bill_gates"]
REAL_EXTRA = ["Margaret Atwood", "Gloria Steinem", "Kate McCue", "Ellen"]


def real_name_tokens():
    cast = json.loads((ROOT / "project/data/cast.json").read_text())
    names = []
    for cid in REAL_IDS:
        entry = cast.get(cid)
        if entry:
            names += [entry["name"], entry["short"]]
    names += REAL_EXTRA
    tokens = set()
    for n in names:
        for t in n.split():
            if len(t) >= 3:
                tokens.add(t)
    return sorted(tokens)


def front_matter(text):
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None
    fm = {}
    for line in m.group(1).splitlines():
        k, _, v = line.partition(":")
        fm[k.strip()] = v.strip()
    return fm


def section(text, name):
    m = re.search(rf"^## {name}\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    return m.group(1).strip() if m else None


def main():
    names = real_name_tokens()
    name_re = re.compile(r"\b(" + "|".join(re.escape(n) for n in names) + r")\b")
    fails = []
    seen = {"id": {}, "drop": {}, "game": {}}
    files = sorted(p for p in PROMPTS.rglob("*.md") if p.parent != PROMPTS)
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text()

        def fail(msg):
            fails.append(f"{rel}: {msg}")

        if "\r" in text:
            fail("CRLF line endings")
        kind = path.relative_to(PROMPTS).parts[0]
        if kind not in TOOLS:
            fail(f"unknown type folder '{kind}'")
            continue
        tool, ext = TOOLS[kind]
        fm = front_matter(text)
        if fm is None:
            fail("missing front matter")
            continue
        for key in ("id", "tool", "drop", "game"):
            if not fm.get(key):
                fail(f"front matter lacks '{key}'")
        aid = fm.get("id", "")
        if aid != path.stem:
            fail(f"id '{aid}' != file name '{path.stem}'")
        if fm.get("tool") != tool:
            fail(f"tool '{fm.get('tool')}' should be '{tool}'")
        want_drop = f"{path.parent.relative_to(ROOT).as_posix()}/assets/{path.stem}.{ext}"
        if fm.get("drop") != want_drop:
            fail(f"drop '{fm.get('drop')}' should be '{want_drop}'")
        game = fm.get("game", "")
        if not game.startswith("project/") or not game.endswith(f"/{path.stem}.{GAME_EXT[ext]}"):
            fail(f"game '{game}' should be project/.../{path.stem}.{GAME_EXT[ext]}")
        for key in ("id", "drop", "game"):
            v = fm.get(key)
            if v in seen[key]:
                fail(f"duplicate {key} '{v}' (also in {seen[key][v]})")
            seen[key][v] = rel
        if not (path.parent / "assets" / ".gitkeep").is_file():
            fail("assets/.gitkeep missing beside the prompt")
        if not re.search(rf"^# {re.escape(path.stem)}$", text, re.M):
            fail("heading '# <id>' missing")
        prompt = section(text, "Prompt")
        if not prompt:
            fail("'## Prompt' section missing or empty")
            prompt = ""
        if section(text, "Notes") is None:
            fail("'## Notes' section missing")

        for pattern, why in BANNED:
            for m in re.finditer(pattern, text, re.I):
                fail(f"banned word '{m.group(0)}' ({why})")

        if kind in ("image", "video"):
            for label, marker in VISUAL_MARKERS.items():
                if marker not in prompt:
                    fail(f"{label} missing (marker: '{marker}')")
            for m in HEX.finditer(text):
                fail(f"hex colour '{m.group(0)}' in a visual prompt (use natural-language colours)")
            for m in name_re.finditer(text):
                fail(f"real name '{m.group(0)}' in an image/video prompt (describe role, hair, costume)")
            caps = {w for w in re.findall(r"\b[A-Z]{3,}\b", prompt)} - ALLCAPS_OK
            if aid in LOGO_ASSETS:
                caps.discard("PERSISTINT")
                if "PERSISTINT" not in prompt or "no other text" not in prompt.lower() and "other than" not in prompt:
                    fail("title logo prompt must ask for PERSISTINT and forbid any other text")
            elif "no text" not in prompt.lower():
                fail("visual prompt must say 'no text'")
            for w in sorted(caps):
                fail(f"lettering '{w}' requested in a visual asset (no text except the title logo)")
        else:
            for label, marker in MUSIC_MARKERS.items():
                if marker not in prompt:
                    fail(f"{label} missing (marker: '{marker}')")
            if "seamless loop" not in prompt and "non-looping cue" not in prompt:
                fail("loop clause missing ('seamless loop' or 'non-looping cue')")

    for f in fails:
        print("FAIL", f)
    print(f"{len(files)} prompt files checked, {len(fails)} failures")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
