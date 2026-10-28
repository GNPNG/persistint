#!/usr/bin/env python3
"""Merge voice-review ratings (the JSON the voice_review scene saves; beads persistint-game-rxu)
into dev/voice-ratings/ratings.jsonl and print, per character, what the scores say about the
voice: mean line rating, the overall voice rating, the worst lines, and whether the character is
a re-clone candidate (better source material, a new "interview").

usage: tools/ingest_voice_ratings.py [--jsonl PATH] [--threshold N] FILE.json [FILE.json ...]
       tools/ingest_voice_ratings.py --summary          (report on what is already merged)

Each saved file is {"build", "date", "ratings": [{speaker, clip, text, rating, note}],
"character_overall": {speaker: rating}}. Every rating becomes one JSONL record keyed on
(date, build, speaker, clip, kind); a later file with the same key replaces the record, so a
corrected save wins. dev/ is git-crypt encrypted: the ratings never leave the private side.

tools/ingest_voice_ratings.mjs is its successor (bd dhn2): it reads these files and the voice review
as it is now (a good / sucks verdict per character, a thumb per line: the review's own file, its
Export review, and Settings' Export playtest), into the same JSONL. Records with no 1-10 rating
(the verdicts and thumbs it adds) are left out of this tool's summary.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parents[1]
JSONL = ROOT / "dev/voice-ratings/ratings.jsonl"
MANIFEST = ROOT / "project/audio/voice/manifest.json"
THRESHOLD = 7.0  # below this (mean line or overall) the voice wants better source material


def load_jsonl(path: Path) -> dict[tuple, dict]:
    out: dict[tuple, dict] = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                rec = json.loads(line)
                out[key_of(rec)] = rec
    return out


def key_of(rec: dict) -> tuple:
    return (rec.get("date", ""), rec.get("build", ""), rec.get("speaker", ""), rec.get("clip", ""), rec.get("kind", ""))


def records_from(save: dict) -> list[dict]:
    base = {"date": save.get("date", ""), "build": save.get("build", "")}
    recs = []
    for r in save.get("ratings", []):
        recs.append({**base, "kind": "line", "speaker": r.get("speaker", ""), "clip": r.get("clip", ""),
                     "text": r.get("text", ""), "rating": int(r.get("rating", 0)), "note": r.get("note", "")})
    for speaker, rating in (save.get("character_overall") or {}).items():
        recs.append({**base, "kind": "character", "speaker": speaker, "clip": "", "text": "",
                     "rating": int(rating), "note": ""})
    return recs


def texts() -> dict[str, str]:
    if not MANIFEST.exists():
        return {}
    return {e["key"]: e["text"] for e in json.loads(MANIFEST.read_text(encoding="utf-8"))}


def summary(records: list[dict], threshold: float) -> str:
    records = [r for r in records if isinstance(r.get("rating"), int)]  # not the .mjs's verdicts and thumbs
    by_text = texts()
    lines = defaultdict(list)
    overall = {}
    for r in records:
        if r["kind"] == "line":
            lines[r["speaker"]].append(r)
        elif r["kind"] == "character":
            # the latest save's overall rating wins
            prev = overall.get(r["speaker"])
            if prev is None or (r["date"], r["build"]) >= (prev["date"], prev["build"]):
                overall[r["speaker"]] = r
    speakers = sorted(set(lines) | set(overall))
    if not speakers:
        return "no ratings yet"
    out = ["speaker                  overall  mean  n   verdict"]
    for s in speakers:
        ls = lines.get(s, [])
        m = mean(r["rating"] for r in ls) if ls else None
        o = overall[s]["rating"] if s in overall else None
        low = (o is not None and o < threshold) or (m is not None and m < threshold)
        verdict = "re-clone candidate: better source material" if low else "keep"
        out.append("%-24s %-8s %-5s %-3d %s" % (s, o if o is not None else "-", ("%.1f" % m) if m is not None else "-", len(ls), verdict))
        worst = sorted(ls, key=lambda r: r["rating"])[:3]
        for r in worst:
            if r["rating"] < threshold:
                text = r.get("text") or by_text.get(r["clip"], r["clip"])
                note = (" (%s)" % r["note"]) if r.get("note") else ""
                out.append("    %2d  %s%s" % (r["rating"], text[:90], note))
    return "\n".join(out)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("files", nargs="*", type=Path, help="voice_ratings*.json saved by the review scene")
    ap.add_argument("--jsonl", type=Path, default=JSONL)
    ap.add_argument("--threshold", type=float, default=THRESHOLD)
    ap.add_argument("--summary", action="store_true", help="only report on the merged records")
    a = ap.parse_args(argv)
    merged = load_jsonl(a.jsonl)
    added = 0
    for f in a.files:
        save = json.loads(f.read_text(encoding="utf-8"))
        for rec in records_from(save):
            k = key_of(rec)
            added += k not in merged
            merged[k] = rec
    if a.files:
        a.jsonl.parent.mkdir(parents=True, exist_ok=True)
        with a.jsonl.open("w", encoding="utf-8") as fh:
            for rec in merged.values():
                fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
        where = a.jsonl.relative_to(ROOT) if a.jsonl.is_relative_to(ROOT) else a.jsonl
        print(f"{added} new record(s); {len(merged)} in {where}")
    elif not a.summary:
        ap.print_usage()
        return 2
    print(summary(list(merged.values()), a.threshold))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
