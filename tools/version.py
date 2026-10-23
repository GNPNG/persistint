#!/usr/bin/env python3
"""Single source of truth for the PERSISTINT version: the VERSION file at the repo root.

Usage (python3 -I tools/version.py ...):
  show                      print the current version
  bump major|minor|patch    increment VERSION, stamp it everywhere, add a CHANGELOG.md heading
  set X.Y.Z                 set VERSION to X.Y.Z, stamp it everywhere
  stamp                     write VERSION into every place listed below (idempotent)
  check                     exit 1 if any place disagrees with VERSION (used by tools/deploy_site.sh)

Places stamped:
  project/project.godot         application/config/version (shown on the main menu)
  README.md                     the "**Status: vX.Y.Z" line
  site/public/*.html            every element with data-version, e.g. <span data-version>v0.1.0</span>
Tag the release commit vX.Y.Z (git tag -a vX.Y.Z) after bumping.
"""
import datetime
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "VERSION"
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def current() -> str:
    v = VERSION_FILE.read_text().strip()
    if not SEMVER.match(v):
        sys.exit(f"VERSION is not X.Y.Z: {v!r}")
    return v


def _godot(text: str, v: str) -> str:
    line = f'config/version="{v}"'
    if re.search(r'^config/version=".*"$', text, re.M):
        return re.sub(r'^config/version=".*"$', line, text, flags=re.M)
    return re.sub(r"^(\[application\]\n)", r"\1\n" + line + "\n", text, count=1, flags=re.M)


def _readme(text: str, v: str) -> str:
    return re.sub(r"(\*\*Status: )v\d+\.\d+\.\d+", rf"\g<1>v{v}", text)


def _html(text: str, v: str) -> str:
    return re.sub(r"(<(\w+)[^>]*\bdata-version\b[^>]*>)[^<]*(</\2>)", rf"\g<1>v{v}\g<3>", text)


def targets():
    yield ROOT / "project/project.godot", _godot
    yield ROOT / "README.md", _readme
    for p in sorted((ROOT / "site/public").glob("*.html")):
        yield p, _html


def stamp(v: str, write: bool) -> list:
    stale = []
    for path, fn in targets():
        if not path.exists():
            continue
        old = path.read_text(encoding="utf-8")
        new = fn(old, v)
        if new != old:
            stale.append(str(path.relative_to(ROOT)))
            if write:
                path.write_text(new, encoding="utf-8")
    return stale


def changelog(v: str) -> None:
    p = ROOT / "CHANGELOG.md"
    text = p.read_text(encoding="utf-8") if p.exists() else "# Changelog\n\n"
    head = f"## v{v} — {datetime.date.today().isoformat()}"
    if head.split(" — ")[0] not in text:
        text = text.replace("# Changelog\n\n", f"# Changelog\n\n{head}\n\n- \n\n", 1)
        p.write_text(text, encoding="utf-8")


def main(argv: list) -> None:
    cmd = argv[0] if argv else "show"
    if cmd == "show":
        print(current())
    elif cmd in ("bump", "set"):
        if len(argv) < 2:
            sys.exit(__doc__)
        if cmd == "set":
            if not SEMVER.match(argv[1]):
                sys.exit("set needs X.Y.Z")
            v = argv[1]
        else:
            major, minor, patch = map(int, SEMVER.match(current()).groups())
            part = argv[1]
            if part == "major":
                v = f"{major + 1}.0.0"
            elif part == "minor":
                v = f"{major}.{minor + 1}.0"
            elif part == "patch":
                v = f"{major}.{minor}.{patch + 1}"
            else:
                sys.exit("bump needs major, minor or patch")
        VERSION_FILE.write_text(v + "\n")
        changed = stamp(v, write=True)
        changelog(v)
        print(f"v{v}; stamped: {', '.join(changed) or 'nothing to change'}; tag with: git tag -a v{v} -m v{v}")
    elif cmd == "stamp":
        v = current()
        print(", ".join(stamp(v, write=True)) or "already up to date")
    elif cmd == "check":
        v = current()
        stale = stamp(v, write=False)
        if stale:
            sys.exit(f"version {v} not stamped in: {', '.join(stale)} (run python3 -I tools/version.py stamp)")
        print(f"version v{v} consistent")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
