"""Draw the kawaii island greenery: bubbly trees and flower clumps.

Usage: python3 -I tools/gen_island_deco.py
Inputs:  none (palette hexes from prompts/STYLE.md: outline #8a5a5a, mint / blush / lilac
         canopies, cream highlights; drawing is fully deterministic, no randomness).
Outputs: project/assets/canon/deco_tree_a.png, deco_tree_b.png, deco_tree_c.png (160x208)
         project/assets/canon/deco_flowers.png (144x88)
The hearts and sparkles are canon cuts (tools/cut_island_props.py), not drawn here; the
canon sheets have no trees or flower clumps, so these are drawn in the canon sticker look:
warm-brown outline, flat pastel fills, one soft highlight per shape, rosy cheeks.

Resolution: each sprite is designed on a grid of world pixels (tree 40x52, flowers 36x22),
drawn at 16x and downscaled with LANCZOS to OUT_SCALE (4x) of its world size; the map
builder (tools/build_island_maps.gd) shows it at its world size, so the GPU downsamples it
smoothly with mipmaps. The paths stay under assets/canon/ because other areas load them there.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/canon"
INK = "#8a5a5a"
OUT_SCALE = 4   # file pixels per world pixel
K = 16          # supersample: drawing pixels per world pixel


def canvas(w, h):
    im = Image.new("RGBA", (w * K, h * K))
    return im, ImageDraw.Draw(im)


def done(im, w, h, name):
    im.resize((w * OUT_SCALE, h * OUT_SCALE), Image.LANCZOS).save(OUT / f"{name}.png")


def circle(d, x, y, r, fill, width=1.0):
    d.ellipse([(x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K], fill=fill,
              outline=INK if width else None, width=round(width * K))


def blend(a, b, t):
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def face(d, x, y):
    for dx in (-3.0, 3.0):
        circle(d, x + dx, y, 1.0, INK, 0)
        circle(d, x + dx + 0.35, y - 0.35, 0.33, "#ffffff", 0)
    d.arc([(x - 1.4) * K, (y - 0.2) * K, (x + 1.4) * K, (y + 2.4) * K], 20, 160, fill=INK, width=round(0.7 * K))
    for dx in (-5.0, 5.0):
        d.ellipse([(x + dx - 1.5) * K, (y + 1.1) * K, (x + dx + 1.5) * K, (y + 2.7) * K], fill="#ff9fb8")


def sparkle(d, x, y, r, fill="#ffffff"):
    pts = []
    for i in range(8):
        rr = r if i % 2 == 0 else r * 0.32
        ang = i * math.pi / 4
        pts.append(((x + rr * math.sin(ang)) * K, (y - rr * math.cos(ang)) * K))
    d.polygon(pts, fill=fill)


def tree(name, canopy):
    w, h = 40, 52
    im, d = canvas(w, h)
    # Soft ground shadow, then the trunk with a highlight stripe.
    d.ellipse([9 * K, 46.5 * K, 31 * K, 51 * K], fill=(138, 90, 90, 60))
    d.rounded_rectangle([16.5 * K, 29 * K, 23.5 * K, 49 * K], round(3 * K), fill="#c8956d", outline=INK, width=K)
    d.rounded_rectangle([18 * K, 32 * K, 19.4 * K, 46 * K], round(0.7 * K), fill="#e3b892")
    # Canopy: four overlapping puffs; outlines first, fills on top so inner seams vanish.
    puffs = [(11.5, 25, 9), (28.5, 25, 9), (20, 13.5, 11), (20, 26, 11)]
    for x, y, r in puffs:
        circle(d, x, y, r + 1.0, INK, 0)
    shade = blend(canopy, INK, 0.12)
    for x, y, r in puffs:
        circle(d, x, y, r, shade, 0)
    for x, y, r in puffs:
        circle(d, x, y - 1.2, r - 0.8, canopy, 0)
    # One soft highlight on the crown puff.
    hl = blend(canopy, "#ffffff", 0.55)
    d.ellipse([12.5 * K, 5.5 * K, 20 * K, 10.5 * K], fill=hl)
    circle(d, 23, 7.2, 1.1, hl, 0)
    face(d, 20, 24)
    sparkle(d, 31.5, 8, 2.6)
    sparkle(d, 7.5, 15, 2.0)
    done(im, w, h, name)


def leaf(d, x, y, side):
    """A pointed leaf from the stem at (x, y), leaning out to one side."""
    pts = []
    for i in range(25):
        t = i / 24
        a = t * math.pi * 2
        lx = 2.6 * (1 - math.cos(a)) / 2 * 2  # 0..5.2 along the leaf
        ly = 1.25 * math.sin(a)
        ang = -0.55
        rx = lx * math.cos(ang) - ly * math.sin(ang)
        ry = lx * math.sin(ang) + ly * math.cos(ang)
        pts.append(((x + side * rx) * K, (y + ry) * K))
    d.polygon(pts, fill="#8fd18a", outline=INK, width=round(0.6 * K))


def flowers():
    w, h = 36, 22
    im, d = canvas(w, h)
    d.ellipse([3 * K, 18 * K, 33 * K, 21.6 * K], fill=(138, 90, 90, 50))
    for x, side in ((8, -1), (8, 1), (18, -1), (18, 1), (28, -1), (28, 1)):  # leaves on the stems
        leaf(d, x, 17.6 - (1.2 if side > 0 else 0), side)
    petals = ((0, -2.8), (2.8, 0), (0, 2.8), (-2.8, 0), (2, -2), (2, 2), (-2, 2), (-2, -2))
    for x, y, c in [(8, 11.5, "#ffb3cb"), (18, 7, "#ffffff"), (28, 12.5, "#ffd98a")]:
        d.line([x * K, (y + 2) * K, x * K, 18.5 * K], fill="#6fb85a", width=round(1.1 * K))
        for dx, dy in petals:
            circle(d, x + dx * 0.95, y + dy * 0.95, 2.3, INK, 0)
        for dx, dy in petals:
            circle(d, x + dx * 0.95, y + dy * 0.95, 1.65, c, 0)
        circle(d, x, y, 1.9, "#ffe27a", 0.6)
        circle(d, x - 0.6, y - 0.7, 0.55, "#fff7d1", 0)
    done(im, w, h, "deco_flowers")


tree("deco_tree_a", "#a8e6a0")
tree("deco_tree_b", "#ffc9de")
tree("deco_tree_c", "#c9b8f2")
flowers()
print("deco done")
