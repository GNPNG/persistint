"""List every spoken line with its speaker, for generating impersonated voice clips.

Usage: python3 -I tools/export_voice_lines.py
Writes project/audio/voice/manifest.json: [{speaker, text, key, clip}]. Generate each clip
(LLM-based impersonated narration of `speaker` reading `text`) and save it as `clip`;
Voice.speak plays it instead of text-to-speech. key = md5("speaker|text"), matching
Voice.line_key in project/scripts/autoload/voice.gd.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "project"
cast = json.loads((ROOT / "data/cast.json").read_text())
name = lambda cid: cast.get(cid, {}).get("name", cid)
lines = []


def add(speaker, text):
    if speaker and text and text.strip():
        key = hashlib.md5(f"{speaker}|{text}".encode()).hexdigest()
        lines.append({"speaker": speaker, "text": text, "key": key, "clip": f"res://audio/voice/{key}.ogg"})


emcee = json.loads((ROOT / "data/emcee.json").read_text())
for intro in emcee.get("intros", {}).values():
    for t in intro:
        add(name(emcee["emcee"]), t)
hot = json.loads((ROOT / "data/hottest_of_the_hot.json").read_text())
for t in hot.get("verdicts", []):
    add(name(hot["host"]), t)
landing = json.loads((ROOT / "data/landing.json").read_text())
for c in landing.get("commands", []):
    add(landing.get("first_mate", ""), c["text"])
cast_ref = re.compile(r'\{\{Cast\.full\("(\w+)"\)\}\}')
for f in sorted((ROOT / "dialogue").glob("*.dialogue")):
    for raw in f.read_text().splitlines():
        m = re.match(r'\s*(\{\{Cast\.full\("\w+"\)\}\}|[A-Z][^:{]*):\s*(.+)$', raw)
        if m:
            speaker = cast_ref.sub(lambda x: name(x.group(1)), m.group(1))
            add(speaker, cast_ref.sub(lambda x: name(x.group(1)), m.group(2)))
seen, out = set(), []
for l in lines:
    if l["key"] not in seen:
        seen.add(l["key"]); out.append(l)
dest = ROOT / "audio/voice/manifest.json"
dest.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
print(f"{len(out)} lines -> {dest}")
