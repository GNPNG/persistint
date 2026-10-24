"""Cut island props (buildings, fences, signs, temple icons) from the canon sheets.

Usage: python3 -I tools/cut_island_props.py
Reads project/data/island_props.json: each prop names a sheet under art/canon, a crop
"WxH+X+Y" in full-resolution pixels, and a background mode:
  white  - clear near-white background (edge-connected, plus large enclosed gaps)
  fuzz   - flood the colour found at the crop corners (tolerance "tol")
  ellipse- keep only the inscribed ellipse (round seals)
Output: project/assets/canon/<name>.png at the sheet's own resolution (trimmed, background
removed, never rescaled). "height" is the prop's display height in world pixels: the map
builder (tools/build_island_maps.gd) scales the sprite to it, so the full-resolution cut is
downsampled smoothly by the GPU (mipmaps) instead of being shrunk here.
Sheets are looked up under art/canon/*/ and dev/art/ (the world-building overview, which is
kept in the git-crypt dev/ tree). A prop whose sheet is missing (a checkout without the
git-crypt key) is skipped and its committed PNG stays.
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
CFG = json.loads((ROOT / "project/data/island_props.json").read_text())
OUT = ROOT / "project/assets/canon"
sheets = {}


def sheet_path(name):
    for pattern in (f"art/canon/*/{name}*", f"dev/art/{name}*"):
        for p in sorted(ROOT.glob(pattern)):
            try:  # a locked git-crypt file is not an image
                Image.open(p).verify()
                return p
            except Exception:
                continue
    return None


def sheet(name):
    if name not in sheets:
        sheets[name] = np.asarray(Image.open(sheet_path(name)).convert("RGB")).astype(int)
    return sheets[name]


def cut(spec):
    rgb = sheet(spec["sheet"])
    size, x, y = spec["crop"].split("+")
    w, h = map(int, size.split("x"))
    rgb = rgb[int(y):int(y) + h, int(x):int(x) + w]
    mode = spec.get("mode", "white")
    if mode == "ellipse":
        yy, xx = np.mgrid[:h, :w]
        keep = ((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2 <= 1
    else:
        if mode == "white":
            bg = rgb.min(axis=2) > spec.get("tol", 232)
        else:
            corners = np.array([rgb[0, 0], rgb[0, -1], rgb[-1, 0], rgb[-1, -1]])
            ref = np.median(corners, axis=0)
            bg = np.abs(rgb - ref).max(axis=2) < spec.get("tol", 28)
        lab, _ = ndimage.label(bg)
        edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
        outside = np.isin(lab, edge[edge > 0])
        keep = ~outside
        lab, n = ndimage.label(keep)
        if n > 1:
            sizes = ndimage.sum(keep, lab, range(1, n + 1))
            keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * 0.08])
        # Enclosed background gaps (between bunting, fence rails) go too; small whites
        # (eyes, highlights) stay.
        if mode == "white":
            gaps, gn = ndimage.label((rgb.min(axis=2) > spec.get("gap_tol", 232)) & keep)
            for i in range(1, gn + 1):
                if (gaps == i).sum() > spec.get("gap", 60):
                    keep &= gaps != i
        keep = ndimage.binary_erosion(keep, iterations=1)
    alpha = ndimage.gaussian_filter(keep.astype(float), 0.7)
    img = Image.fromarray(np.dstack([rgb.astype(np.uint8), (alpha * 255).astype(np.uint8)]), "RGBA")
    return img.crop(img.getchannel("A").point(lambda a: 255 if a > 20 else 0).getbbox())


OUT.mkdir(parents=True, exist_ok=True)
for name, spec in CFG["props"].items():
    if sheet_path(spec["sheet"]) is None:
        print(name, "skipped: sheet", spec["sheet"], "not found (or still encrypted)")
        continue
    im = cut(spec)
    im.save(OUT / f"{name}.png")
    print(name, im.size)
