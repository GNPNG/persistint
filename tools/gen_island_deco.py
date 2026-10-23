"""Draw the kawaii island decoration (bubbly trees, flower clumps, hearts, sparkles) and put
cute faces on the canon signs.

Usage: python3 -I tools/gen_island_deco.py   (run after tools/cut_island_props.py)
Writes project/assets/canon/deco_*.png; prop_sign_a/b get a face painted on the board.
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/canon"
INK = "#8a5a5a"
K = 4


def canvas(w, h):
    im = Image.new("RGBA", (w * K, h * K))
    return im, ImageDraw.Draw(im)


def done(im, w, h, name):
    im.resize((w, h), Image.LANCZOS).save(OUT / f"{name}.png")


def circle(d, x, y, r, fill, width=2):
    d.ellipse([(x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K], fill=fill, outline=INK, width=width * K // 2)


def face(d, x, y, s=1.0):
    for dx in (-3.2, 3.2):
        circle(d, x + dx * s, y, 1.1 * s, INK, 0)
    d.arc([(x - 1.6 * s) * K, (y - 0.4 * s) * K, (x + 1.6 * s) * K, (y + 3 * s) * K], 20, 160, fill=INK, width=K)
    for dx in (-5.4, 5.4):
        d.ellipse([(x + dx * s - 1.5 * s) * K, (y + 1.2 * s) * K, (x + dx * s + 1.5 * s) * K, (y + 3 * s) * K], fill="#ff9fb8")


def tree(name, canopy, trunk="#c8956d", cheeks=True):
    w, h = 40, 52
    im, d = canvas(w, h)
    d.rounded_rectangle([17 * K, 30 * K, 23 * K, 49 * K], 3 * K, fill=trunk, outline=INK, width=K)
    for x, y, r in [(12, 24, 9), (28, 24, 9), (20, 14, 11), (20, 26, 11)]:
        circle(d, x, y, r, canopy)
    if cheeks:
        face(d, 20, 24)
    for x, y in [(30, 8), (8, 12)]:
        d.polygon([(x * K, (y - 3) * K), ((x + 1) * K, (y - 1) * K), ((x + 3) * K, y * K), ((x + 1) * K, (y + 1) * K), (x * K, (y + 3) * K),
                   ((x - 1) * K, (y + 1) * K), ((x - 3) * K, y * K), ((x - 1) * K, (y - 1) * K)], fill="#ffffff")
    done(im, w, h, name)


def flowers():
    w, h = 36, 22
    im, d = canvas(w, h)
    for x, y, c in [(8, 13, "#ff9fc0"), (18, 8, "#ffffff"), (28, 14, "#ffd36e")]:
        d.line([x * K, (y + 2) * K, x * K, 20 * K], fill="#6fb85a", width=K)
        for dx, dy in ((0, -3), (3, 0), (0, 3), (-3, 0)):
            circle(d, x + dx, y + dy, 2.6, c, 1)
        circle(d, x, y, 2.2, "#ffe27a", 1)
    done(im, w, h, "deco_flowers")


def sparkle_heart():
    im, d = canvas(14, 14)
    for cx, cy in ((4.5, 5), (9.5, 5)):
        d.ellipse([(cx - 4) * K, (cy - 4) * K, (cx + 3.2) * K, (cy + 3) * K], fill="#ff8fb1", outline=INK, width=K // 2)
    d.polygon([(1.2 * K, 6.5 * K), (12.8 * K, 6.5 * K), (7 * K, 13 * K)], fill="#ff8fb1")
    d.ellipse([3.5 * K, 3 * K, 5.5 * K, 4.6 * K], fill="#ffffff")
    done(im, 14, 14, "deco_heart")
    im, d = canvas(14, 14)
    d.polygon([(7 * K, 0), (8.6 * K, 5.4 * K), (14 * K, 7 * K), (8.6 * K, 8.6 * K), (7 * K, 14 * K), (5.4 * K, 8.6 * K), (0, 7 * K), (5.4 * K, 5.4 * K)],
              fill="#fff3a8", outline="#e0b24a", width=K // 2)
    done(im, 14, 14, "deco_sparkle")


def sign_faces():
    for n in ("prop_sign_a", "prop_sign_b"):
        im = Image.open(OUT / f"{n}.png").convert("RGBA")
        big = im.resize((im.width * K, im.height * K), Image.LANCZOS)
        d = ImageDraw.Draw(big)
        # The boards sit in the upper ~55% of each cut; paint the face on the middle of the board.
        cx, cy = im.width * 0.5, im.height * 0.27
        face(d, cx, cy, im.width / 36)
        im2 = big.resize(im.size, Image.LANCZOS)
        im2.save(OUT / f"{n}.png")


tree("deco_tree_a", "#a8e6a0")
tree("deco_tree_b", "#ffc9de")
tree("deco_tree_c", "#c9b8f2")
flowers()
sparkle_heart()
sign_faces()
print("deco done")
