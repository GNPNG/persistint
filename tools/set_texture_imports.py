#!/usr/bin/env python3
"""Lossy import for the big textures, so the web build stays small.

Every PNG under project/assets at or over --min-bytes (default 300 KB) gets compress/mode=1
(Lossy: WebP) at compress/lossy_quality (default 0.9) in its .import file; smaller ones stay
lossless (mode 0). Godot 4's modes: 0 Lossless, 1 Lossy, 2 VRAM Compressed (several GPU formats
per texture: it made the web build bigger, not smaller), 3 VRAM Uncompressed, 4 Basis Universal. Run `godot --headless --path project --import` afterwards. Idempotent.

    python3 tools/set_texture_imports.py [--min-bytes N] [--quality Q] [--dry-run]
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "project" / "assets"


def set_option(text: str, key: str, value: str) -> str:
    pat = re.compile(rf"^{re.escape(key)}=.*$", re.M)
    if pat.search(text):
        return pat.sub(f"{key}={value}", text)
    # No such line yet: add it to the [params] section.
    return text.replace("[params]\n", f"[params]\n\n{key}={value}\n", 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--min-bytes", type=int, default=300 * 1024)
    ap.add_argument("--quality", type=float, default=0.9)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    changed = 0
    for png in sorted(ASSETS.rglob("*.png")):
        imp = png.with_suffix(".png.import")
        if not imp.exists():
            continue
        text = imp.read_text(encoding="utf-8")
        big = png.stat().st_size >= a.min_bytes
        new = set_option(text, "compress/mode", "1" if big else "0")
        if big:
            new = set_option(new, "compress/lossy_quality", f"{a.quality:g}")
        if new != text:
            changed += 1
            print(("would set" if a.dry_run else "set"), "lossy" if big else "lossless", png.relative_to(ROOT))
            if not a.dry_run:
                imp.write_text(new, encoding="utf-8")
    print(f"{changed} import files changed")


if __name__ == "__main__":
    main()
