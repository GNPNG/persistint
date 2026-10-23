"""Cut aligned paper-doll layers from the Gemini paper-doll sheet.

Usage: python3 -I tools/cut_paperdoll.py <sheet.jpg>

Reads project/data/paperdoll_parts.json. Every layer is placed on one shared canvas so
the game can stack them at one origin:
  - body: placed as drawn.
  - dress: drawn on the same baseline as the body; centered on the body, feet on feet.
  - hair: the face opening is measured, scaled to the body's face width, centered on the
    head and its bottom set on the chin.
  - accessory: scaled by "scale" and placed at "anchor" relative to the head.
White background and hair face openings become transparent.
Layers keep the sheet's resolution (the shared canvas is about 540x790 px): no downscale, so
the doll stays smooth illustration. Code scales it to its display size (player.gd fits it to
48 world px tall; PaperDoll fits its rect).
Outputs: project/assets/canon/<part>.png for every part in the data file.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
CFG = json.loads((ROOT / "project/data/paperdoll_parts.json").read_text())
OUT = ROOT / "project/assets/canon"
WHITE = CFG.get("white_threshold", 232)

sheet = np.asarray(Image.open(sys.argv[1]).convert("RGB"))


def cut(spec):
    """Crop WxH+X+Y; return RGBA with outside white cleared, plus the enclosed-white mask."""
    size, x, y = spec.split("+")
    w, h = map(int, size.split("x"))
    x, y = int(x), int(y)
    rgb = sheet[y:y + h, x:x + w]
    white = rgb.min(axis=2) > WHITE
    lab, _ = ndimage.label(white)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    outside = np.isin(lab, edge[edge > 0])
    outside = ndimage.binary_dilation(outside, iterations=1) & (rgb.min(axis=2) > WHITE - 40) | outside
    # Keep the drawing itself; drop small neighbours that fall inside the crop box.
    lab, n = ndimage.label(~outside)
    if n > 1:
        sizes = ndimage.sum(~outside, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * 0.1]
        outside |= ~np.isin(lab, keep)
    rgba = np.dstack([rgb, np.where(outside, 0, 255).astype(np.uint8)])
    enclosed = white & ~outside
    return rgba, enclosed


def largest(mask):
    lab, n = ndimage.label(mask)
    if n == 0:
        return None
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    return lab == (int(np.argmax(sizes)) + 1)


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max(), ys.max()


# Body landmarks.
body, _ = cut(CFG["parts"]["body_base"]["crop"])
solid = body[:, :, 3] > 0
widths = solid.sum(axis=1)
rows = np.arange(len(widths))
top = rows[widths > 0][0]
feet = rows[widths > 0][-1]
# Chin: the narrowest row of the neck, below the head's widest point.
head_rows = rows[top:top + int((feet - top) * 0.6)]
neck = head_rows[np.argmax(widths[head_rows])] + np.argmin(widths[head_rows[np.argmax(widths[head_rows]):]])
chin = neck - CFG.get("chin_above_neck", 8)
face_row = top + int((chin - top) * 0.6)
xs = np.where(solid[face_row])[0]
head_cx = (xs.min() + xs.max()) / 2
face_w = widths[top + int((chin - top) * 0.45)] * CFG.get("face_fill", 0.86)
body_cx = head_cx

layers = {}
for name, part in CFG["parts"].items():
    rgba, enclosed = cut(part["crop"])
    kind = name.split("_")[0]
    scale, ox, oy = 1.0, 0.0, 0.0
    if kind == "body":
        pass
    elif kind == "dress":
        # Fit from just above the neck down to the feet, centered on the body.
        bx0, by0, bx1, by1 = bbox(rgba[:, :, 3] > 0)
        collar = neck - part.get("collar", CFG.get("collar", 14))
        scale = (feet - collar) / (by1 - by0)
        ox = body_cx - (bx0 + bx1) / 2 * scale
        oy = collar - by0 * scale
    elif kind == "hair":
        hole = largest(enclosed)
        rgba[hole, 3] = 0
        hx0, hy0, hx1, hy1 = bbox(hole)
        scale = face_w / (hx1 - hx0)
        ox = head_cx - (hx0 + hx1) / 2 * scale
        oy = chin - hy1 * scale
    elif kind == "acc":
        scale = part.get("scale", 1.0)
        ax, ay = part["anchor"]
        bx0, by0, bx1, by1 = bbox(rgba[:, :, 3] > 0)
        ox = head_cx + ax - (bx0 + bx1) / 2 * scale
        oy = top + ay - (by0 + by1) / 2 * scale
    img = Image.fromarray(rgba, "RGBA")
    if scale != 1.0:
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    layers[name] = (img, round(ox), round(oy))

# One canvas that holds every layer.
x0 = min(ox for _, ox, _ in layers.values())
y0 = min(oy for _, _, oy in layers.values())
x1 = max(ox + im.width for im, ox, _ in layers.values())
y1 = max(oy + im.height for im, _, oy in layers.values())
OUT.mkdir(parents=True, exist_ok=True)
for name, (img, ox, oy) in layers.items():
    canvas = Image.new("RGBA", (x1 - x0, y1 - y0))
    canvas.alpha_composite(img, (ox - x0, oy - y0))
    canvas.save(OUT / f"{name}.png")
    print(name, canvas.size)
