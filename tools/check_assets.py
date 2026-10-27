#!/usr/bin/env python3
"""Asset conformance gate (bd 4wb; the author's structured-asset standard, 2026-10-23: every
asset, whatever its source, comes from a re-runnable generator or a prompt drop at a stable path,
with consistent import settings; animated things rigged with documented frame layouts; no art
drawn ad hoc in _draw code; Gemini outputs enter only via a prompt's drop:/game:).

Checks, each a failure when broken:
  provenance  every shipped asset has a row in its folder's SOURCES.md and none is "not traced";
              the generated SOURCES.md files are current (tools/gen_sources.py --check)
  gemini      no raw Gemini download (Gemini_Generated_Image_*) anywhere under project/
  paths       every res:// asset path written in a scene, resource, script, data or dialogue
              file exists (paths built at run time, with % or {}, are not checked)
  imports     every texture follows tools/set_texture_imports.py (lossy at or over 300 KB,
              lossless below), and every WAV imports compressed (QOA, compress/mode=2)
  rigs        every *_rig.png is made by a tool whose docstring documents its frame layout
  draw        no script outside scripts/test/ draws in _draw()

    python3 -I tools/check_assets.py        # lists every failure; exit 1 if any
tools/run_tests.sh runs it before the Godot tests.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project"
MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".wav", ".mp3", ".ogg", ".ogv", ".mp4"}
LOSSY_MIN = 300 * 1024  # tools/set_texture_imports.py --min-bytes default
failures = []


def fail(check: str, msg: str) -> None:
    failures.append(f"{check}: {msg}")


def shipped_media():
    for base in ("assets", "audio"):
        for p in sorted((PROJECT / base).rglob("*")):
            if p.is_file() and p.suffix.lower() in MEDIA and "test" not in p.relative_to(PROJECT).parts:
                yield p


def check_provenance(media) -> None:
    r = subprocess.run([sys.executable, "-I", "-B", str(ROOT / "tools/gen_sources.py"), "--check"],
                       cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        fail("provenance", "SOURCES.md out of date; run python3 -I tools/gen_sources.py\n    " + r.stdout.strip().replace("\n", "\n    "))
    tables = {}
    for p in media:
        src = p.parent / "SOURCES.md"
        if not src.exists():
            fail("provenance", f"{p.relative_to(ROOT)}: no SOURCES.md in its folder")
            continue
        text = tables.setdefault(src, src.read_text(encoding="utf-8"))
        row = re.search(rf"^\| `{re.escape(p.name)}` \|([^\n]*)$", text, re.M)
        if row is None:
            fail("provenance", f"{p.relative_to(ROOT)}: no row in {src.relative_to(ROOT)}")
        elif "| not traced |" in row.group(0):
            fail("provenance", f"{p.relative_to(ROOT)}: not traced to a prompt, a voice line or a tool")


def check_gemini() -> None:
    for p in PROJECT.rglob("Gemini_Generated_Image_*"):
        if ".godot" not in p.parts:
            fail("gemini", f"{p.relative_to(ROOT)}: a raw Gemini download; render it through a prompt drop:/game:")


def check_paths() -> None:
    pat = re.compile(r"res://((?:assets|audio)/[^\"'\s)\]}]+)")
    for ext in ("*.tscn", "*.tres", "*.gd", "*.json", "*.dialogue"):
        for f in PROJECT.rglob(ext):
            if ".godot" in f.parts or "test" in f.relative_to(PROJECT).parts or "addons" in f.parts:
                continue
            if f.name == "manifest.json":
                continue  # the voice list names a clip for every line; a line without one is silent by design
            for m in pat.finditer(f.read_text(encoding="utf-8", errors="replace")):
                path = m.group(1).rstrip(".,;:")
                if any(ch in path for ch in "%{}*<") or path.endswith("/"):
                    continue  # built at run time or a folder
                if not (PROJECT / path).exists():
                    fail("paths", f"{f.relative_to(ROOT)}: res://{path} does not exist")


def check_imports(media) -> None:
    for p in media:
        imp = p.with_name(p.name + ".import")
        if p.suffix.lower() in {".svg", ".ogv", ".mp4"}:
            continue
        if not imp.exists():
            fail("imports", f"{p.relative_to(ROOT)}: no .import file (not imported)")
            continue
        text = imp.read_text(encoding="utf-8")
        mode = re.search(r"^compress/mode=(\d+)$", text, re.M)
        if p.suffix.lower() == ".png":
            want = "1" if p.stat().st_size >= LOSSY_MIN else "0"
            if not mode or mode.group(1) != want:
                fail("imports", f"{p.relative_to(ROOT)}: compress/mode={mode.group(1) if mode else '?'}, want {want}; run tools/set_texture_imports.py")
        elif p.suffix.lower() == ".wav" and (not mode or mode.group(1) != "2"):
            fail("imports", f"{p.relative_to(ROOT)}: WAV not imported compressed (compress/mode=2, QOA)")


def check_rigs(media) -> None:
    for p in media:
        if not p.name.endswith("_rig.png"):
            continue
        src = (p.parent / "SOURCES.md").read_text(encoding="utf-8") if (p.parent / "SOURCES.md").exists() else ""
        row = re.search(rf"^\| `{re.escape(p.name)}` \| ([^|]*) \|", src, re.M)
        tools = re.findall(r"`(tools/[^`]+)`", row.group(1)) if row else []
        documented = False
        for t in tools:
            head = (ROOT / t).read_text(errors="replace").split('"""')
            doc = head[1] if len(head) > 2 else ""
            if re.search(r"\bframes?\b", doc, re.I) and re.search(r"\b(rows?|columns?)\b", doc, re.I):
                documented = True
        if not documented:
            fail("rigs", f"{p.relative_to(ROOT)}: its tool ({', '.join(tools) or 'none'}) does not document the frame layout (frames, rows, columns)")


def check_draw() -> None:
    for f in (PROJECT / "scripts").rglob("*.gd"):
        if "test" in f.relative_to(PROJECT / "scripts").parts:
            continue
        if re.search(r"^func _draw\(", f.read_text(encoding="utf-8", errors="replace"), re.M):
            fail("draw", f"{f.relative_to(ROOT)}: draws art in _draw(); move it into a tools/gen_*.py generator")


def main() -> int:
    media = list(shipped_media())
    check_provenance(media)
    check_gemini()
    check_paths()
    check_imports(media)
    check_rigs(media)
    check_draw()
    for f in failures:
        print("FAIL " + f)
    print(f"check_assets: {len(media)} assets, {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
