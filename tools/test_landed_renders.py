"""Checks that re-running the asset tools leaves landed renders alone (bd up1u).

Usage: python3 -I -B tools/test_landed_renders.py
Prints "ok"/"FAIL" per check and "RESULT: PASS|FAIL (n failures)"; exits 0 on a pass, 1 on a
failure. Run by project/tests/test_landed_renders.gd (tools/run_tests.sh). Standard library and
git only; writes only to a temp folder.

Checked:
  tools/landed_renders.py   keep() is true for the game path of a prompt whose drop exists, false
                            when the drop is missing, and ignores prompts/*.md at the top level
  tools/sync_rendered_assets.py (a copy run in a scratch git repo)
                            a game copy committed after its drop (keyed at landing) is left alone;
                            a drop newer than its game copy is copied; a drop with no game copy yet
                            is copied
  the generators            gen_ui_art.py, gen_brand_art.py, gen_temple_props.py and
                            gen_village_props.py import keep and write nothing past it (they need
                            Pillow, so this is read from their source, not run)
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import landed_renders  # noqa: E402

failures = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global failures
    if ok:
        print(f"ok    {name}")
    else:
        failures += 1
        print(f"FAIL  {name}{': ' + detail if detail else ''}")


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def prompt(root: Path, rel: str, drop: str, game: str) -> None:
    write(root / rel, f"---\nid: x\ntool: Gemini image\ndrop: {drop}\ngame: {game}\n---\n\n## Prompt\n\nA thing.\n")


# --- landed_renders.keep
with tempfile.TemporaryDirectory() as tmp:
    r = Path(tmp)
    prompt(r, "prompts/a/landed.md", "prompts/a/assets/landed.png", "project/assets/landed.png")
    prompt(r, "prompts/a/pending.md", "prompts/a/assets/pending.png", "project/assets/pending.png")
    prompt(r, "prompts/README.md", "prompts/a/assets/landed.png", "project/assets/readme.png")
    write(r / "prompts/a/assets/landed.png", "render")
    check("keep: a landed render's game path", landed_renders.keep(r / "project/assets/landed.png", r))
    check("keep: no drop yet, so not kept", not landed_renders.keep(r / "project/assets/pending.png", r))
    check("keep: prompts/*.md at the top level are not asset prompts",
          not landed_renders.keep(r / "project/assets/readme.png", r))
    check("keep: a path no prompt names", not landed_renders.keep(r / "project/assets/other.png", r))


# --- sync_rendered_assets.py in a scratch repo
def git(repo: Path, *args: str, when: int | None = None) -> None:
    env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t",
               GIT_COMMITTER_EMAIL="t@t")
    if when is not None:
        env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = f"@{when} +0000"
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True, env=env)


def sync(repo: Path) -> str:
    r = subprocess.run([sys.executable, "-I", "-B", str(repo / "tools/sync_rendered_assets.py")],
                       capture_output=True, text=True, cwd=repo)
    return r.stdout + r.stderr


with tempfile.TemporaryDirectory() as tmp:
    repo = Path(tmp)
    for name in ("sync_rendered_assets.py", "audio_levels.py"):
        write(repo / "tools" / name, (ROOT / "tools" / name).read_text(encoding="utf-8"))
    git(repo, "init", "-q")
    prompt(repo, "prompts/p/keyed.md", "prompts/p/assets/keyed.png", "project/assets/keyed.png")
    prompt(repo, "prompts/p/fresh.md", "prompts/p/assets/fresh.png", "project/assets/fresh.png")
    write(repo / "prompts/p/assets/keyed.png", "raw render")
    write(repo / "project/assets/keyed.png", "raw render")
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "land", when=1_000_000)
    write(repo / "project/assets/keyed.png", "keyed and fitted")
    git(repo, "commit", "-q", "-am", "key it", when=1_000_100)
    out = sync(repo)
    check("sync: a game copy keyed after its drop is left alone",
          (repo / "project/assets/keyed.png").read_text() == "keyed and fitted", out.strip())
    write(repo / "prompts/p/assets/fresh.png", "new render")
    sync(repo)
    check("sync: a drop with no game copy is copied",
          (repo / "project/assets/fresh.png").read_text() == "new render")
    write(repo / "prompts/p/assets/keyed.png", "re-delivered render")
    git(repo, "commit", "-q", "-am", "re-deliver", when=1_000_200)
    sync(repo)
    check("sync: a drop newer than its game copy is copied",
          (repo / "project/assets/keyed.png").read_text() == "re-delivered render")


# --- the generators route their writes through keep
for name, unguarded in [("gen_ui_art.py", None), ("gen_brand_art.py", None),
                        ("gen_temple_props.py", '.save(OUT / "'), ("gen_village_props.py", '.save(OUT / "')]:
    src = (ROOT / "tools" / name).read_text(encoding="utf-8")
    check(f"{name} imports keep", "from landed_renders import keep" in src)
    check(f"{name} asks keep before it writes", "if keep(path)" in src or "if not keep(OUT / name)" in src)
    if unguarded:
        check(f"{name} has no write past keep", unguarded not in src)

print(f"RESULT: {'PASS' if failures == 0 else 'FAIL'} ({failures} failures)")
sys.exit(1 if failures else 0)
