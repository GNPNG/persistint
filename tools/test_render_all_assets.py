"""Checks for the render queue (bd e8e8): tools/render_all_assets.py takes each prompt's aspect from
its front matter, else from the ratio the prompt text states, else from its Notes, else 16:9.

Usage: python3 -I -B tools/test_render_all_assets.py
Prints "ok"/"FAIL" per check and "RESULT: PASS|FAIL (n failures)"; exits 0 on a pass, 1 on a
failure. Run by project/tests/test_render_all_assets.gd (tools/run_tests.sh). Writes only to a temp
folder; needs nothing beyond the standard library.
"""
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import render_all_assets as raa  # noqa: E402

failures = 0


def check(name: str, got, want) -> None:
    global failures
    if got == want:
        print(f"ok    {name}")
    else:
        failures += 1
        print(f"FAIL  {name}: got {got!r}, want {want!r}")


def prompt_file(folder: Path, name: str, front: str, prompt: str, notes: str | None) -> Path:
    text = f"---\nid: {name}\ntool: Gemini image\ndrop: prompts/x/assets/{name}.png\n{front}---\n\n# {name}\n\n"
    text += f"## Prompt\n\n{prompt}\n"
    if notes is not None:
        text += f"\n## Notes\n\n{notes}\n"
    path = folder / f"{name}.md"
    path.write_text(text, encoding="utf-8")
    return path


with tempfile.TemporaryDirectory() as tmp:
    d = Path(tmp)
    raa.ROOT = d  # the parser names each file relative to the repo root; here, the temp folder
    cases = [
        ("front matter wins", "aspect: 9:16\n", "A sparkle. 1:1 square.", "Strip of 4:3 frames.", "9:16"),
        ("the prompt's ratio before Notes", "", "A sparkle. 1:1 square.", "Strip of 4:3 frames.", "1:1"),
        ("the prompt's first ratio", "", "A plinth, 21:9 wide, in a 16:9 sheet.", None, "21:9"),
        ("Notes when the prompt states none", "", "A sparkle.", "Render at 3:2.", "3:2"),
        ("16:9 when nothing states one", "", "A sparkle.", "No ratio here.", "16:9"),
        ("16:9 with no Notes", "", "A sparkle.", None, "16:9"),
    ]
    for i, (name, front, prompt, notes, want) in enumerate(cases):
        parsed = raa.parse_prompt_file(prompt_file(d, f"case{i}", front, prompt, notes))
        check(name, parsed and parsed["aspect"], want)
    raa.ROOT = ROOT

# The real prompts that showed the bug and one that was already right.
for rel, want in [("prompts/image/levels/temple/temple_twinkle.md", "1:1"),
                  ("prompts/image/levels/temple/temple_plinth.md", "21:9"),
                  ("prompts/image/levels/temple/temple_tiles_sheet.md", "16:9")]:
    parsed = raa.parse_prompt_file(ROOT / rel)
    check(f"{rel} is {want}", parsed and parsed["aspect"], want)

print(f"RESULT: {'PASS' if failures == 0 else 'FAIL'} ({failures} failures)")
sys.exit(1 if failures else 0)
