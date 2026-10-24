#!/usr/bin/env python3
"""Audio levels gate: every music track, voice clip and sound effect measured against its target
(tools/audio_levels.py), plus the bus layout. Readings are cached in docs/AUDIO_LEVELS.json by
file hash, so a run only measures files that changed; `--all` measures everything again (do that
on each minor release: sops/10-audio-levels.md). `--check` exits 1 when anything is out of range
or a bus gain has drifted; tools/deploy_site.sh runs it before every export.

    python3 tools/audio_report.py [--check] [--all] [--quiet]
"""
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_levels  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REPORT = ROOT / "docs" / "AUDIO_LEVELS.json"
FOLDERS = ["project/audio/music", "project/audio/voice", "project/audio/sfx"]
BUSES = {"Music": "Master", "Voice": "Master", "Clones": "Voice", "SFX": "Master"}


def sha1(path: Path) -> str:
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def bus_problems() -> list:
    text = (ROOT / "project" / "default_bus_layout.tres").read_text(encoding="utf-8")
    names = dict(re.findall(r'bus/(\d+)/name = &"([^"]+)"', text))
    sends = dict(re.findall(r'bus/(\d+)/send = &"([^"]+)"', text))
    vols = dict(re.findall(r"bus/(\d+)/volume_db = (-?[\d.]+)", text))
    out = []
    by_name = {v: k for k, v in names.items()}
    for bus, send in BUSES.items():
        if bus not in by_name:
            out.append(f"bus {bus} is missing")
            continue
        i = by_name[bus]
        if sends.get(i) != send:
            out.append(f"bus {bus} sends to {sends.get(i)}, not {send}")
        if abs(float(vols.get(i, "0"))) > 0.01:
            out.append(f"bus {bus} is at {vols.get(i)} dB, not 0 (levels live in the assets; sliders scale the buses)")
    return out


def main() -> int:
    check = "--check" in sys.argv
    measure_all = "--all" in sys.argv
    quiet = "--quiet" in sys.argv
    if not audio_levels.have_ffmpeg():
        print("audio_report: ffmpeg is not installed; nothing measured")
        return 2
    cache = {}
    if REPORT.exists():
        cache = json.loads(REPORT.read_text(encoding="utf-8")).get("files", {})
    report, flagged, measured = {}, [], 0
    for folder in FOLDERS:
        for path in sorted((ROOT / folder).rglob("*")):
            if path.suffix.lower() not in (".mp3", ".wav", ".ogg"):
                continue
            rel = path.relative_to(ROOT).as_posix()
            digest = sha1(path)
            entry = cache.get(rel)
            if measure_all or not entry or entry.get("sha1") != digest:
                m = audio_levels.measure(path)
                entry = {"sha1": digest, **m}
                measured += 1
            report[rel] = entry
            target = audio_levels.target_for(path)
            ok = audio_levels.in_range(entry, target)
            if not ok:
                flagged.append(rel)
            if not quiet:
                lvl = audio_levels.level_of(entry, target)
                want = audio_levels.wanted(target)
                kind = "mean" if "mean" in target else ("M" if "M" in target else "I")
                lvl_s = f"{lvl:6.1f}" if lvl is not None else "   n/a"
                tp_s = f"{entry['TP']:5.1f}" if entry.get("TP") is not None else "  n/a"
                print(f"{'ok ' if ok else 'OFF'} {kind:4s} {lvl_s} (target {want:+.0f}+/-{target['tol']})  TP {tp_s} (<= {target['TP']})  {rel}")
    problems = bus_problems()
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps({"_note": "Written by tools/audio_report.py; readings per file, cached by sha1.",
                                  "files": report}, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"audio_report: {len(report)} files, {measured} measured now, {len(flagged)} out of range, "
          f"{len(problems)} bus problem(s)")
    for p in problems:
        print("  bus:", p)
    for f in flagged:
        print("  off:", f)
    return 1 if (check and (flagged or problems)) else 0


if __name__ == "__main__":
    sys.exit(main())
