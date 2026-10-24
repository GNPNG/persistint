"""Draw the crafted Florida wearables as paper-doll accessory parts on the canon doll frame.

Usage: python3 -I tools/gen_florida_wearables.py
Inputs: the canon paper-doll body project/assets/canon/body_base.png (cut by
tools/cut_paperdoll.py at the sheet's resolution; it fixes the frame and where the head and
neck sit) and the canon
shells project/assets/florida/shell_*.png (cut from the tide scroll by tools/cut_island_props.py)
for the shell garland.
Outputs (project/assets/florida/, transparent, the same size, frame and origin as every canon
paper-doll part, so PaperDoll stacks them with canon body, dress and hair):
  acc_flower_crown, acc_plumeria_lei, acc_shell_garland, acc_bougainvillea_wreath
  (the "wear" parts of project/data/florida.json recipes).
Shapes are laid out in doll units (the doll is 96 units tall, whatever the cut's pixel size),
drawn at twice the canon cut's resolution in the canon character line colour with flat fills
and one highlight (dev/STYLE.md 4.3, Florida plant colours 4.4), then LANCZOS-resized to
the cut's size. Deterministic.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves tools/ off the path
import florida_draw as fd  # noqa: E402

SS = 2  # supersample over the canon cut's resolution
BODY = fd.canon_sprite("body_base")
PW, PH = BODY.size  # the canon doll frame in pixels
U = PH / 96.0  # pixels per doll unit


def head():
    """Head centre x, top row and chin row of the canon doll body (doll units), from its alpha."""
    a = np.asarray(BODY)[..., 3] > 128
    widths = a.sum(axis=1)
    rows = np.where(widths > 0)[0]
    top = int(rows[0])
    upper = rows[rows < top + 60 * U]
    widest = int(upper[np.argmax(widths[upper])])
    below = np.arange(widest, round(top + 60 * U))
    neck = int(below[np.argmin(widths[below])])
    xs = np.where(a[widest])[0]
    return (xs.min() + xs.max()) / 2 / U, top / U, neck / U


CX, TOP, NECK = head()
HEAD_RX = 26.0  # hair volume round the canon head


def canvas():
    im = Image.new("RGBA", (PW * SS, PH * SS))
    return im, fd.Pen(im, U * SS, fd.CANON_INK)


def arc_points(cx, cy, rx, ry, a0, a1, n):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / (n - 1))),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / (n - 1)))) for i in range(n)]


def leaf(p, x, y, ang, length=4.0):
    rad = math.radians(ang)
    nx, ny = -math.sin(rad), math.cos(rad)
    ex, ey = x + math.cos(rad) * length, y + math.sin(rad) * length
    mx, my = (x + ex) / 2, (y + ey) / 2
    p.poly([(x, y), (mx + nx * 1.5, my + ny * 1.5), (ex, ey), (mx - nx * 1.5, my - ny * 1.5)], "#7fd08a", 0.35)


def flower_crown():
    im, p = canvas()
    cy = TOP + 13
    pts = arc_points(CX, cy, HEAD_RX - 1, 10, 195, 345, 7)
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        leaf(p, (x0 + x1) / 2, (y0 + y1) / 2, math.degrees(math.atan2(y1 - y0, x1 - x0)) - 30)
    for i, (x, y) in enumerate(pts):
        if i % 2:
            p.plumeria(x, y, 3.8, 0.45)
        else:
            p.hibiscus(x, y, 4.3, fd.HIBISCUS if i % 4 == 0 else fd.FLOWER_YELLOW, 0.45)
    return im


def bougainvillea_wreath():
    im, p = canvas()
    cy = TOP + 14
    pts = arc_points(CX, cy, HEAD_RX, 11, 185, 355, 13)
    for i, (x, y) in enumerate(pts):
        leaf(p, x, y, -120 + i * 18, 4.2)
    for i, (x, y) in enumerate(pts[::2]):
        for dx, dy in ((-1.3, 0), (1.3, 0.3), (0, -1.2), (0.2, 1.3)):
            p.ell(x + dx * 1.3, y + dy * 1.3, 2.0, 1.7, fd.BOUG if i % 2 == 0 else "#ff7fb8", 0.35)
        p.ell(x, y, 0.6, 0.6, "#ffffff", 0)
    return im


def plumeria_lei():
    im, p = canvas()
    cy = NECK + 3
    pts = arc_points(CX, cy, 16, 9, 10, 170, 9)
    for i, (x, y) in enumerate(pts):
        leaf(p, x, y + 1.5, 90 + (i - 4) * 12, 3.2)
    for i, (x, y) in enumerate(pts):
        if i % 3 == 1:
            p.hibiscus(x, y, 2.9, fd.HIBISCUS, 0.4)
        else:
            p.plumeria(x, y, 2.8, 0.4)
    return im


def shell_garland():
    im, p = canvas()
    cy = NECK + 2
    string = arc_points(CX, cy, 15, 8, 5, 175, 24)
    p.line(string, "#e9d49b", 0.7)
    shells = [Image.open(fd.OUT / f"shell_{n}.png").convert("RGBA")
              for n in ("scallop", "spiral", "conch")]
    for i, (x, y) in enumerate(arc_points(CX, cy, 15, 8, 20, 160, 7)):
        sh = shells[i % 3]
        h = 6
        w = round(sh.width * h / sh.height)
        k = U * SS
        sm = sh.resize((round(w * k), round(h * k)), Image.LANCZOS)
        im.alpha_composite(sm, (round((x - w / 2) * k), round((y - h / 2 + 1.5) * k)))
    for x, y in arc_points(CX, cy, 15, 8, 30, 150, 6):
        p.ell(x, y, 0.7, 0.7, "#ffd3c2", 0.25)
    return im


def main():
    for name, draw in (("acc_flower_crown", flower_crown), ("acc_plumeria_lei", plumeria_lei),
                       ("acc_shell_garland", shell_garland), ("acc_bougainvillea_wreath", bougainvillea_wreath)):
        fd.save(draw().resize((PW, PH), Image.LANCZOS), name)
        print(name)


if __name__ == "__main__":
    main()
