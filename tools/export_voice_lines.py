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
short = lambda cid: cast.get(cid, {}).get("short", name(cid))
lines = []
# Celebrity clones speak their original's quotes (data/quotes/<file>.json), keyed by cast id.
QUOTE_SPEAKERS = {"epstein": "epstein", "bill_clinton": "bill_clinton", "hillary": "hillary_clinton", "bill_gates": "bill_gates"}


def add(speaker, text):
    if speaker and text and text.strip() and "{{" not in speaker + text:
        key = hashlib.md5(f"{speaker}|{text}".encode()).hexdigest()
        lines.append({"speaker": speaker, "text": text, "key": key, "clip": f"res://audio/voice/{key}.wav"})


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
barks = json.loads((ROOT / "data/barks.json").read_text())
for npc_id, entries in barks.items():
    for e in entries if isinstance(entries, list) else []:
        add(name(npc_id), e.get("text", ""))
cast_ref = re.compile(r'\{\{Cast\.(full|short)\("(\w+)"\)\}\}')
resolve = lambda s: cast_ref.sub(lambda x: (name if x.group(1) == "full" else short)(x.group(2)), s)
for f in sorted((ROOT / "dialogue").glob("*.dialogue")):
    for raw in f.read_text().splitlines():
        m = re.match(r'\s*(\{\{Cast\.full\("\w+"\)\}\}|[A-Z][^:{]*):\s*(.+)$', raw)
        if m:
            add(resolve(m.group(1)), resolve(m.group(2)))
for stem, cid in QUOTE_SPEAKERS.items():
    for q in json.loads((ROOT / f"data/quotes/{stem}.json").read_text()).get("quotes", []):
        add(cid, q["text"])
seen, out = set(), []
for l in lines:
    if l["key"] not in seen:
        seen.add(l["key"]); out.append(l)
dest = ROOT / "audio/voice/manifest.json"
dest.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
print(f"{len(out)} lines -> {dest}")
