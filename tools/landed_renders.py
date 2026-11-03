"""Which game files hold a landed render, so the asset generators leave them alone (bd up1u).

Each prompt file (prompts/**/<id>.md) names `drop:` (where its render is saved) and `game:` (where
the game loads it). Once the drop exists the render has landed, and the game file is that render,
often keyed, fitted or resized by hand at landing. A generator that drew a stand-in at that game
path (gen_ui_art.py, gen_brand_art.py, gen_temple_props.py, gen_village_props.py) must not draw
over it, so each asks keep(path) before it writes:

  sys.path.insert(0, str(Path(__file__).resolve().parent))
  from landed_renders import keep
  if not keep(path):
      im.save(path)

(The generators run with python3 -I, which leaves the script's folder off sys.path; hence the
insert, as in sync_rendered_assets.py.)
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DROP_RE = re.compile(r"^drop: (.*)$", re.M)
GAME_RE = re.compile(r"^game: (.*)$", re.M)
_landed: dict[Path, dict[Path, str]] = {}


def landed_game_paths(root: Path = ROOT) -> dict[Path, str]:
    """Each game path (resolved) whose prompt's drop exists, mapped to that drop (repo-relative)."""
    out = {}
    for prompt in sorted((root / "prompts").rglob("*.md")):
        if prompt.parent == root / "prompts":  # STYLE.md, README.md, QUEUE.md are not asset prompts
            continue
        text = prompt.read_text(encoding="utf-8")
        drop, game = DROP_RE.search(text), GAME_RE.search(text)
        if drop and game and (root / drop.group(1).strip()).exists():
            out[(root / game.group(1).strip()).resolve()] = drop.group(1).strip()
    return out


def keep(path, root: Path = ROOT) -> bool:
    """True, and says so, when path holds a landed render that the caller must not overwrite."""
    if root not in _landed:
        _landed[root] = landed_game_paths(root)
    path = Path(path).resolve()
    drop = _landed[root].get(path)
    if drop:
        print(f"{path.relative_to(root.resolve())} kept: its render has landed ({drop})")
    return drop is not None
