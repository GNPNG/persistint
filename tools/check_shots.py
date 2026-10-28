#!/usr/bin/env python3
"""Check a shot list (tools/shots/*.json, in the format project/scripts/test/shot_walk.gd describes)
against the tree before tools/shot_walk.sh renders it, so a typo fails here and not partway through a walk.

Checks every shot:
  - its keys, and a unique name of the form <area>-<scene>-<state> (a-z, 0-9, _)
  - the scene exists; a spawn is a node of the scene
  - every step's kind and keys; every node it names: a node of the scene (from the .tscn; a deeper
    path into nodes made at run time is noted, not checked), /root/<an autoload>/..., or
    group:<a group something joins>
  - every method a step calls is a func of that node's script or a script it extends (or, for a
    node whose script can't be told from the .tscn, of some script in the project)
  - dialogue files and their ~ titles, and the dialogue of an NPC a step interacts with
  - a speaker or text a dialogue step waits for appears in a .dialogue file or data/*.json
  - set_static: the script has that static var; press, hold, release: the input action is in
    project.godot; snap: a step after the scene opens, its `as` in a-z, 0-9 and _, once a shot
Exits non-zero on any failure. No packages needed (python3 -I).

Usage: python3 tools/check_shots.py <shots.json> [...]
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "project"
NAME_RE = re.compile(r"^[a-z0-9_]+(-[a-z0-9_]+){2,}$")
SNAP_RE = re.compile(r"^[a-z0-9_]+$")
SHOT_KEYS = {"name", "scene", "note", "flags", "spawn", "before", "steps", "settle", "typing"}
STEP_KEYS = {
    "wait": {"frames"},
    "flags": {"set"},
    "call": {"node", "method", "args"},
    "interact": {"node"},
    "set": {"node", "prop", "value"},
    "set_static": {"script", "prop", "value"},
    "player_to": {"node", "pos", "offset"},
    "camera": {"zoom", "center"},
    "dialogue": {"file", "title"},
    "dialogue_text": {"text", "title"},
    "dialogue_next": {"count"},
    "dialogue_until": {"speaker", "contains", "responses", "max"},
    "dialogue_choose": {"index", "contains"},
    "press": {"action"},
    "hold": {"action"},
    "release": {"action"},
    "snap": {"as"},
}
NODE_KEYS = {"call", "interact", "set", "player_to"}

_text_cache: dict = {}
_files: dict = {}


def text(path: Path) -> str:
    if path not in _text_cache:
        _text_cache[path] = path.read_text(encoding="utf-8") if path.is_file() else ""
    return _text_cache[path]


def res(path: str) -> Path:
    return PROJECT / path[len("res://"):] if path.startswith("res://") else PROJECT / "__not_res__"


def autoloads() -> dict:
    out, on = {}, False
    for line in text(PROJECT / "project.godot").splitlines():
        if line.startswith("["):
            on = line.strip() == "[autoload]"
        elif on and "=" in line:
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip().strip('"').lstrip("*")
    return out


def input_actions() -> set:
    out, on = set(), False
    for line in text(PROJECT / "project.godot").splitlines():
        if line.startswith("["):
            on = line.strip() == "[input]"
        elif on and re.match(r"^[A-Za-z_][\w]*=\{", line):
            out.add(line.split("=", 1)[0])
    return out


def scene_nodes(scene: Path) -> dict:
    """Node path (from the scene root, "." for the root) -> {"script": res path or "", "instance":
    res path or ""} for every node the .tscn lists."""
    src = text(scene)
    ext = {}  # ext_resource id -> res:// path
    for line in re.findall(r"^\[ext_resource [^\n]*\]$", src, re.M):
        attrs = dict(re.findall(r'(\w+)="([^"]*)"', line))
        if "id" in attrs and "path" in attrs:
            ext[attrs["id"]] = attrs["path"]
    nodes, current = {}, None
    for line in src.splitlines():
        m = re.match(r'\[node name="([^"]+)"(.*)\]$', line)
        if m:
            name, rest = m.group(1), m.group(2)
            parent = re.search(r'parent="([^"]*)"', rest)
            if parent is None:
                current = "."
            elif parent.group(1) == ".":
                current = name
            else:
                current = parent.group(1) + "/" + name
            inst = re.search(r'instance=ExtResource\("([^"]+)"\)', rest)
            nodes[current] = {"script": "", "instance": ext.get(inst.group(1), "") if inst else ""}
            continue
        if line.startswith("[") and current is not None and not line.startswith("[node"):
            current = None
        sm = re.match(r'script = ExtResource\("([^"]+)"\)', line)
        if sm and current is not None:
            nodes[current]["script"] = ext.get(sm.group(1), "")
        for key in ("dialogue_path", "dialogue_title"):
            km = re.match(rf'{key} = "([^"]*)"', line)
            if km and current is not None:
                nodes[current][key] = km.group(1)
    return nodes


def node_script(scene: Path, node: str, depth: int = 0) -> str:
    """The res:// script of a node (its own, or the root script of the scene it instances)."""
    info = scene_nodes(scene).get(node)
    if info is None or depth > 5:
        return ""
    if info["script"]:
        return info["script"]
    if info["instance"].endswith(".tscn"):
        return node_script(res(info["instance"]), ".", depth + 1)
    return ""


def node_prop(scene: Path, node: str, key: str, default: str = "") -> str:
    """A property the .tscn sets on a node, else the one its instanced scene's root sets."""
    info = scene_nodes(scene).get(node, {})
    if key in info:
        return info[key]
    if info.get("instance", "").endswith(".tscn"):
        return node_prop(res(info["instance"]), ".", key, default)
    return default


def project_files(suffix: str) -> list:
    """Every project file with this suffix, outside the .godot/ import cache (walked once)."""
    if not _files:
        for dirpath, dirnames, filenames in os.walk(PROJECT):
            dirnames[:] = [d for d in dirnames if d != ".godot"]
            for f in filenames:
                _files.setdefault(Path(f).suffix, []).append(Path(dirpath) / f)
    return _files.get(suffix, [])


def class_names() -> dict:
    out = {}
    for gd in project_files(".gd"):
        m = re.search(r"^class_name\s+(\w+)", text(gd), re.M)
        if m:
            out[m.group(1)] = "res://" + gd.relative_to(PROJECT).as_posix()
    return out


def script_has(script: str, pattern: str, classes: dict, depth: int = 0) -> bool:
    src = text(res(script))
    if not src or depth > 8:
        return False
    if re.search(pattern, src, re.M):
        return True
    m = re.search(r'^extends\s+(?:"([^"]+)"|(\w+))', src, re.M)
    if not m:
        return False
    base = m.group(1) or classes.get(m.group(2), "")
    return bool(base) and script_has(base, pattern, classes, depth + 1)


def anywhere(pattern: str, suffixes: tuple, data_only: bool = False) -> bool:
    """Whether some project file with one of these suffixes (only those in data/ with data_only)
    matches the pattern."""
    for suffix in suffixes:
        for f in project_files(suffix):
            if data_only and f.parent != PROJECT / "data":
                continue
            if re.search(pattern, text(f), re.M):
                return True
    return False


def check(list_path: Path) -> tuple:
    fails, notes = [], []
    try:
        spec = json.loads(list_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return [f"{list_path}: not a readable JSON shot list ({e})"], notes
    if not isinstance(spec, dict) or not isinstance(spec.get("shots"), list):
        return [f'{list_path}: not a shot list (a JSON object with a "shots" array)'], notes
    loads, actions, classes = autoloads(), input_actions(), class_names()
    names = set()
    for i, shot in enumerate(spec["shots"]):
        if not isinstance(shot, dict):
            fails.append(f"shot {i + 1}: not a JSON object")
            continue
        name = shot.get("name", f"shot {i + 1}")

        def fail(msg: str) -> None:
            fails.append(f"{name}: {msg}")

        if not isinstance(shot.get("name"), str) or not NAME_RE.match(shot["name"]):
            fail("the name is not <area>-<scene>-<state> in a-z, 0-9 and _")
        if name in names:
            fail("the name is used twice")
        names.add(name)
        for k in set(shot) - SHOT_KEYS:
            fail(f"unknown key {k}")
        scene = res(str(shot.get("scene", "")))
        if not str(shot.get("scene", "")).endswith(".tscn") or not scene.is_file():
            fail(f"no scene {shot.get('scene')}")
            continue
        nodes = scene_nodes(scene)
        if "spawn" in shot and shot["spawn"] not in nodes:
            fail(f"no spawn marker {shot['spawn']} in {shot['scene']}")
        dialogues = []  # the dialogue files the shot opens, for speaker/text checks

        def node_ok(path: str, in_scene: bool) -> str:
            """Checks a node reference; returns its script ("" if unknown)."""
            if path.startswith("group:"):
                g = path[len("group:"):]
                if not (anywhere(rf'add_to_group\(\s*&?"{re.escape(g)}"', (".gd",))
                        or anywhere(rf'groups=\[[^\]]*"{re.escape(g)}"', (".tscn",))):
                    fail(f"nothing joins group {g}")
                return ""
            if path.startswith("/root/"):
                parts = path[len("/root/"):].split("/")
                if parts[0] not in loads:
                    fail(f"{parts[0]} is not an autoload")
                    return ""
                if len(parts) > 1:
                    notes.append(f"{name}: {path} is made at run time (only /root/{parts[0]} checked)")
                    return ""
                return loads[parts[0]]
            if not in_scene:
                fail(f"{path}: a before step runs with no scene open; use /root/...")
                return ""
            if path in ("", "."):
                return node_script(scene, ".")
            if path in nodes:
                return node_script(scene, path)
            first = path.split("/")[0]
            if first in nodes:
                notes.append(f"{name}: {path} is made at run time (only {first} checked)")
                return ""
            fail(f"no node {path} in {shot['scene']}")
            return ""

        def method_ok(script: str, method: str, node: str) -> None:
            pat = rf"^(static\s+)?func\s+{re.escape(method)}\s*\("
            if script:
                if not script_has(script, pat, classes):
                    fail(f"{node} ({script}) has no func {method}")
            elif not anywhere(pat, (".gd",)):
                fail(f"no script in the project has func {method} (for {node})")

        snaps: set = set()
        for key in ("before", "steps"):
            steps = shot.get(key, [])
            if not isinstance(steps, list):
                fail(f"{key} is not a list")
                continue
            for j, step in enumerate(steps):
                where = f"{key}[{j}]"
                if not isinstance(step, dict) or step.get("do") not in STEP_KEYS:
                    fail(f"{where}: unknown step {step!r}")
                    continue
                kind = step["do"]
                for k in set(step) - STEP_KEYS[kind] - {"do"}:
                    fail(f"{where} ({kind}): unknown key {k}")
                in_scene = key == "steps"
                if kind in NODE_KEYS and ("node" in step or kind != "player_to"):
                    node = str(step.get("node", ""))
                    script = node_ok(node, in_scene)
                    if kind == "call":
                        method_ok(script, str(step.get("method", "")), node)
                    elif kind == "interact":
                        method_ok(script, "interact", node)
                        dpath = node_prop(scene, node, "dialogue_path") if node in nodes else ""
                        if dpath:
                            title = node_prop(scene, node, "dialogue_title", "start")
                            dialogues.append(dpath)
                            if not re.search(rf"^~ {re.escape(title)}\s*$", text(res(dpath)), re.M):
                                fail(f"{where}: {node}'s dialogue {dpath} has no ~ {title}")
                    elif kind == "set" and script and not script_has(
                            script, rf"^(@\w+(\(.*\))?\s+)*var\s+{re.escape(str(step.get('prop')))}\b", classes):
                        notes.append(f"{name}: {where} sets {step.get('prop')} (not a var of {script}; engine property?)")
                if kind == "player_to" and "node" not in step and "pos" not in step:
                    fail(f"{where}: player_to needs node or pos")
                if kind == "camera":
                    c = step.get("center")
                    if isinstance(c, str) and c != "map":
                        node_ok(c, in_scene)
                    z = step.get("zoom")
                    if z is not None and z != "fit" and not isinstance(z, (int, float)):
                        fail(f"{where}: zoom is a number or \"fit\"")
                if kind == "dialogue":
                    f, title = str(step.get("file", "")), str(step.get("title", "start"))
                    if not res(f).is_file():
                        fail(f"{where}: no dialogue {f}")
                    elif not re.search(rf"^~ {re.escape(title)}\s*$", text(res(f)), re.M):
                        fail(f"{where}: {f} has no ~ {title}")
                    dialogues.append(f)
                if kind == "set_static":
                    s = str(step.get("script", ""))
                    if not re.search(rf"^static\s+var\s+{re.escape(str(step.get('prop')))}\b", text(res(s)), re.M):
                        fail(f"{where}: {s} has no static var {step.get('prop')}")
                if kind in ("press", "hold", "release") and step.get("action") not in actions:
                    fail(f"{where}: no input action {step.get('action')} in project.godot")
                if kind == "snap":
                    label = step.get("as")
                    if not in_scene:
                        fail(f"{where}: a snap is a step after the scene opens (steps, not before)")
                    elif not isinstance(label, str) or not SNAP_RE.match(label):
                        fail(f"{where}: snap as {label!r} is not a-z, 0-9 and _")
                    elif label in snaps:
                        fail(f"{where}: snap as {label!r} is used twice in the shot")
                    else:
                        snaps.add(label)
                if kind in ("dialogue_until", "dialogue_choose"):
                    for k in ("speaker", "contains"):
                        if k not in step:
                            continue
                        want = re.escape(str(step[k]))
                        pat = rf"^\s*{want}:" if k == "speaker" else want
                        found = (any(re.search(pat, text(res(d)), re.M) for d in dialogues)
                                 or anywhere(pat, (".dialogue",))
                                 or anywhere(want if k == "contains" else rf'"{want}"', (".json",), True))
                        if not found:
                            fail(f"{where}: {k} {step[k]!r} is in no dialogue or data file")
    return fails, notes


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    total_fails = 0
    for arg in sys.argv[1:]:
        p = Path(arg)
        fails, notes = check(p)
        for n in notes:
            print(f"NOTE {n}")
        for f in fails:
            print(f"FAIL {f}")
        count = 0
        try:
            count = len(json.loads(p.read_text(encoding="utf-8")).get("shots", []))
        except (OSError, ValueError, AttributeError):
            pass
        print(f"check_shots: {p}: {count} shots, {len(fails)} problems, {len(notes)} notes")
        total_fails += len(fails)
    return 1 if total_fails else 0


if __name__ == "__main__":
    sys.exit(main())
