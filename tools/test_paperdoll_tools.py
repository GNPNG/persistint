"""Checks for the paper-doll tools (bd lg5w.1): tools/cut_paperdoll.py on small synthetic sheets, and
the slots the cutter, tools/gen_player_rig.py, project/data/outfits.json and PaperDoll agree on.

Usage: python3 -I -B tools/test_paperdoll_tools.py
Prints "ok"/"FAIL" per check and "RESULT: PASS|FAIL (n failures)"; exits 0 on a pass, 1 on a
failure, 2 when numpy, scipy or Pillow is missing (tools/requirements-art.txt; nothing checked).
Run by project/tests/test_paperdoll_tools.gd (tools/run_tests.sh). Writes only to a temp folder.

The synthetic sheets (white background, warm fills and outlines, as the keyed Gemini sheets are):
  canon     the body (head top y 40, soles y 290), a wig with a face opening, a dress, an
            accessory and a top drawn at the body's own torso height
  wardrobe  the reference doll at half the body's size (head top y 20, soles y 145) and, beside
            her at her heights, a top, a bottom, a pair of shoes, a hat and a bottom too wide for
            the frame
Checked: every part lands on the frame (body_base.png's size); a top, a bottom and shoes from the
wardrobe sheet take the doll's scale (x2) and stand where they would on her, centred on the body
(the wardrobe top where the canon top is); a hat sits at its anchor; the wide bottom is clipped
with a warning; the canon parts come out the same with and without the wardrobe sheet in the
parts file (the frame is the canon parts'); --sheet cuts one sheet the same as a full run and
writes nothing else; bad sheet names fail. Slots: the cutter's SLOTS are PaperDoll.LAYERS,
outfits.json has every slot but the body and each option's prefix is its slot, and
gen_player_rig.view_rule narrows tops, bottoms and shoes like the dress and hats like the head.
"""
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
FILL = (240, 196, 200)
INK = (138, 90, 90)
failures = 0


def check(ok, what):
    global failures
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        failures += 1


def near(a, b, slack):
    return abs(float(a) - float(b)) <= slack


def doll(draw, ox, oy, k):
    """The body shape (head top at oy, soles at oy + 250 k), drawn at scale k from (ox, oy)."""
    def box(x0, y0, x1, y1):
        return [ox + x0 * k, oy + y0 * k, ox + x1 * k, oy + y1 * k]
    draw.ellipse(box(0, 0, 100, 100), fill=FILL, outline=INK, width=2)
    draw.rectangle(box(40, 96, 60, 118), fill=FILL, outline=INK, width=2)
    draw.rectangle(box(20, 118, 80, 190), fill=FILL, outline=INK, width=2)
    draw.rectangle(box(25, 190, 45, 250), fill=FILL, outline=INK, width=2)
    draw.rectangle(box(55, 190, 75, 250), fill=FILL, outline=INK, width=2)


def sheets(tmp):
    from PIL import Image, ImageDraw
    canon = Image.new("RGB", (900, 400), "white")
    d = ImageDraw.Draw(canon)
    doll(d, 40, 40, 1.0)
    d.ellipse([200, 30, 330, 160], fill=FILL, outline=INK, width=2)  # a wig
    d.ellipse([235, 70, 295, 140], fill="white", outline=INK, width=2)  # its face opening
    d.rectangle([380, 150, 460, 290], fill=FILL, outline=INK, width=2)  # a dress
    d.ellipse([520, 40, 560, 70], fill=FILL, outline=INK, width=2)  # an accessory
    d.rectangle([600, 158, 660, 230], fill=FILL, outline=INK, width=2)  # a top at the torso's height
    canon.save(tmp / "canon.png")
    ward = Image.new("RGB", (720, 300), "white")
    d = ImageDraw.Draw(ward)
    doll(d, 20, 20, 0.5)  # the reference doll: head top y 20, soles y 145
    d.rectangle([150, 79, 180, 115], fill=FILL, outline=INK, width=2)  # top: torso 118-190 at 0.5
    d.rectangle([250, 115, 280, 140], fill=FILL, outline=INK, width=2)  # bottom: from the hip down
    d.rectangle([350, 138, 360, 145], fill=FILL, outline=INK, width=2)  # shoes, soles on the baseline
    d.rectangle([366, 138, 376, 145], fill=FILL, outline=INK, width=2)
    d.ellipse([450, 20, 500, 40], fill=FILL, outline=INK, width=2)  # a hat
    d.rectangle([520, 115, 690, 140], fill=FILL, outline=INK, width=2)  # a bottom wider than the frame
    ward.save(tmp / "wardrobe_white.png")
    canon_parts = {
        "body_base": {"crop": "140x270+20+30"},
        "hair_test": {"crop": "150x150+190+20"},
        "dress_test": {"crop": "100x160+370+140"},
        "acc_test": {"crop": "60x50+510+30", "anchor": [0, 20], "scale": 1.0},
        "top_canon": {"crop": "80x90+590+150"},
    }
    ward_parts = {
        "top_test": {"sheet": "wardrobe", "crop": "50x50+140+70"},
        "bottom_test": {"sheet": "wardrobe", "crop": "50x40+240+108"},
        "shoes_test": {"sheet": "wardrobe", "crop": "40x20+343+132"},
        "hat_test": {"sheet": "wardrobe", "crop": "70x34+440+13", "anchor": [0, 30], "scale": 2.0},
        "bottom_wide": {"sheet": "wardrobe", "crop": "190x40+510+108"},
    }
    full = {"sheets": {"wardrobe": {"path": str(tmp / "wardrobe_white.png"), "doll": "70x140+10+10"}},
            "parts": {**canon_parts, **ward_parts}}
    (tmp / "parts.json").write_text(json.dumps(full))
    (tmp / "legacy.json").write_text(json.dumps({"parts": canon_parts}))
    return list(canon_parts), list(ward_parts)


def run(*args):
    return subprocess.run([sys.executable, "-I", "-B", str(TOOLS / "cut_paperdoll.py"), *map(str, args)],
                          capture_output=True, text=True)


def alpha(path, level=0):
    """The PNG's mask: alpha over `level` (128 for measuring: a LANCZOS upscale rings faintly
    a few px beyond an edge)."""
    import numpy as np
    from PIL import Image
    return np.asarray(Image.open(path).convert("RGBA"))[:, :, 3] > level


def box(mask):
    import numpy as np
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max(), ys.max()


def same(a, b):
    import numpy as np
    from PIL import Image
    return np.array_equal(np.asarray(Image.open(a).convert("RGBA")), np.asarray(Image.open(b).convert("RGBA")))


def check_cutter(tmp, cp):
    canon, ward = sheets(tmp)
    a = run(tmp / "canon.png", "--parts", tmp / "parts.json", "--out", tmp / "A")
    check(a.returncode == 0, f"a full run cuts both sheets (exit {a.returncode}: {a.stderr.strip()[-300:]})")
    if a.returncode != 0:
        return
    from PIL import Image
    size = Image.open(tmp / "A/body_base.png").size
    sizes = {n: Image.open(tmp / f"A/{n}.png").size for n in canon + ward}
    check(all(s == size for s in sizes.values()), f"every part is on the {size} frame ({sizes})")
    lm = cp.landmarks(alpha(tmp / "A/body_base.png"), {})
    top, feet, cx = lm["top"], lm["feet"], lm["body_cx"]
    check(near(feet - top, 250, 1), f"the body stands 250 px on the frame (top {top}, feet {feet})")

    x0, y0, x1, y1 = box(alpha(tmp / "A/top_canon.png", 128))
    check(near((x0 + x1) / 2, cx, 1.5) and near(y0, top + 118, 2), f"a canon top stands at the body's torso (top y {y0}, want {top + 118})")
    canon_top_y = y0
    x0, y0, x1, y1 = box(alpha(tmp / "A/top_test.png", 128))
    check(near((x0 + x1) / 2, cx, 1.5), f"the wardrobe top is centred on the body ({(x0 + x1) / 2} vs {cx})")
    check(near(y0, canon_top_y, 3), f"the wardrobe top stands where the canon one does (y {y0} vs {canon_top_y})")
    check(near(y1 - y0, 73, 4), f"the wardrobe top takes the doll's scale, x2 (height {y1 - y0}, want about 73)")
    x0, y0, x1, y1 = box(alpha(tmp / "A/bottom_test.png", 128))
    check(near(y0, top + 190, 3) and near((x0 + x1) / 2, cx, 1.5), f"the bottom starts at the hip line (y {y0}, want {top + 190})")
    x0, y0, x1, y1 = box(alpha(tmp / "A/shoes_test.png", 128))
    check(near(y1, feet, 3) and near((x0 + x1) / 2, cx, 1.5), f"the shoes stand on the body's soles (y {y1}, want {feet})")
    x0, y0, x1, y1 = box(alpha(tmp / "A/hat_test.png", 128))
    check(near((x0 + x1) / 2, lm["head_cx"], 1.5) and near((y0 + y1) / 2, top + 30, 1.5),
          f"the hat sits at its anchor ({(x0 + x1) / 2}, {(y0 + y1) / 2}; want {lm['head_cx']}, {top + 30})")
    check("bottom_wide" in a.stderr and "fall off" in a.stderr, f"a part too wide for the frame is clipped with a warning ({a.stderr.strip()[-200:]})")
    check(alpha(tmp / "A/bottom_wide.png").any(), "and what fits of it is kept")
    hair = alpha(tmp / "A/hair_test.png")
    check(hair.any() and not hair[lm["chin"] - 5, int(lm["head_cx"])], "the wig's face opening is clear over the face")

    b = run(tmp / "canon.png", "--parts", tmp / "legacy.json", "--out", tmp / "B")
    check(b.returncode == 0 and all(same(tmp / f"A/{n}.png", tmp / f"B/{n}.png") for n in canon),
          "the canon parts are the same with or without the wardrobe sheet (today's CLI: SHEET only)")

    (tmp / "C").mkdir()
    shutil.copy(tmp / "A/body_base.png", tmp / "C/body_base.png")
    c = run("--sheet", "wardrobe", "--parts", tmp / "parts.json", "--out", tmp / "C")
    written = sorted(p.stem for p in (tmp / "C").glob("*.png"))
    check(c.returncode == 0 and written == sorted(ward + ["body_base"]),
          f"--sheet wardrobe writes that sheet's parts and nothing else ({written}; {c.stderr.strip()[-200:]})")
    check(c.returncode == 0 and all(same(tmp / f"A/{n}.png", tmp / f"C/{n}.png") for n in ward),
          "--sheet wardrobe cuts them as the full run does")

    check(run("--sheet", "nosuch", "--parts", tmp / "parts.json", "--out", tmp / "D").returncode != 0, "an unknown --sheet fails")
    bad = json.loads((tmp / "parts.json").read_text())
    bad["parts"]["top_lost"] = {"sheet": "lost", "crop": "10x10+0+0"}
    (tmp / "bad.json").write_text(json.dumps(bad))
    check(run(tmp / "canon.png", "--parts", tmp / "bad.json", "--out", tmp / "E").returncode != 0, "a part on an unlisted sheet fails")
    nodoll = json.loads((tmp / "parts.json").read_text())
    del nodoll["sheets"]["wardrobe"]["doll"]
    (tmp / "nodoll.json").write_text(json.dumps(nodoll))
    check(run(tmp / "canon.png", "--parts", tmp / "nodoll.json", "--out", tmp / "F").returncode != 0,
          "a top on a sheet without its reference doll fails")


def check_slots(cp):
    import gen_player_rig
    gd = (ROOT / "project/scripts/systems/paper_doll.gd").read_text()
    m = re.search(r"const LAYERS: Array\[String\] = \[([^\]]*)\]", gd)
    layers = re.findall(r'"([a-z_]+)"', m.group(1)) if m else []
    check(set(cp.SLOTS.values()) == set(layers) and len(cp.SLOTS) == len(layers),
          f"the cutter has a rule for every PaperDoll slot ({layers} vs {sorted(cp.SLOTS.values())})")
    outfits = json.loads((ROOT / "project/data/outfits.json").read_text())
    check(set(outfits) == set(layers) - {"body"}, f"outfits.json lists every slot but the body ({sorted(outfits)})")
    wrong = [f"{slot}:{p}" for slot, items in outfits.items() for p in items
             if p != "none" and cp.SLOTS.get(p.split("_")[0]) != slot]
    check(not wrong, f"every option's prefix is its slot ({wrong})")
    parts = json.loads((ROOT / "project/data/paperdoll_parts.json").read_text())
    unknown = [n for n in parts["parts"] if n.split("_")[0] not in cp.SLOTS]
    check(not unknown, f"every cut part's prefix has a slot ({unknown})")
    rules = {k: gen_player_rig.view_rule(k) for k in cp.SLOTS}
    check(rules == {"body": "body", "shoes": "torso", "bottom": "torso", "top": "torso", "dress": "torso",
                    "hair": "hair", "hat": "head", "acc": "head"}, f"the rig derives each slot's views ({rules})")


def main():
    try:
        import numpy  # noqa: F401
        import PIL  # noqa: F401
        import scipy  # noqa: F401
    except ImportError as e:
        print(f"SKIP: {e.name} not installed (python3 -m pip install -r tools/requirements-art.txt)")
        return 2
    sys.path.insert(0, str(TOOLS))  # -I leaves tools/ off the path
    sys.dont_write_bytecode = True  # no tools/__pycache__ from the imports below
    import cut_paperdoll as cp
    with tempfile.TemporaryDirectory(prefix="paperdoll-") as d:
        check_cutter(Path(d), cp)
    check_slots(cp)
    print(f"RESULT: {'PASS' if failures == 0 else 'FAIL'} ({failures} failures)")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
