#!/usr/bin/env python3
"""Draw the floating HUD stickers: the settings gear, the wardrobe's clothes hanger, the
journal's book, the zoom magnifier, the help mark and the map (scripts/ui/gear_button.gd,
sticker_button.gd), and the two paper-cutout shadow figures that show the zoom level beside the
magnifier (scripts/map.gd).

Usage: python3 -I tools/gen_hud_stickers.py
Inputs: none (the gear's cream / plum / blush, as the settings screen uses them).
Outputs: project/assets/ui/hud/<name>.png and <name>_pressed.png for gear, hanger, book, zoom_in,
zoom_out (a magnifier with + or -), help (a question mark) and map (a folded paper map with a
heart pin): 64x64 px, shown 32 viewport px (stored at 2x for the 1280x720 window). Pressed swaps
the cream face for blush. And figure_near.png / figure_far.png, 32x48 px shown 16x24: a girl in
braids and a long gown cut from plum paper, white paper edge, soft shadow, big for the normal
view and small for the view one level out, both standing on the same baseline (author
2026-10-24, bd ctw: "little cutout paper shadow, but like shadowed, and it's smaller or
bigger"). Drawn at 8x the file size and downscaled with LANCZOS. Deterministic.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "project/assets/ui/hud"
FACE = (253, 246, 227, 255)     # cream  #fdf6e3
OUTLINE = (89, 56, 89, 255)     # plum   #593859
BLUSH = (252, 231, 239, 255)    # blush  #fce7ef
SIZE = 64                       # file px (32 viewport px at 2x)
K = 8                           # supersample
S = SIZE * K


def px(v: float) -> float:
    """Viewport px (the 32 px sticker) to drawing px."""
    return v * 2 * K


def gear(d: ImageDraw.ImageDraw, face) -> None:
    import math
    c, r, teeth = S / 2, px(32 * 0.36), 8
    pts = []
    for i in range(teeth * 2):
        a = math.tau * i / (teeth * 2)
        rad = r * (1.25 if i % 2 == 0 else 0.95)
        pts.append((c + math.cos(a) * rad, c + math.sin(a) * rad))
    d.polygon(pts, fill=face, outline=OUTLINE, width=int(px(2)))
    h = r * 0.4
    d.ellipse([c - h, c - h, c + h, c + h], fill=BLUSH, outline=OUTLINE, width=int(px(2)))


def card(d: ImageDraw.ImageDraw, face) -> None:
    m = px(2)
    d.rounded_rectangle([m, m, S - m, S - m], radius=px(4), fill=face, outline=OUTLINE, width=int(px(2)))


def hanger(d: ImageDraw.ImageDraw, face) -> None:
    card(d, face)
    c = S / 2
    w = int(px(2))
    # hook: an arc over the neck
    d.arc([c - px(3), c - px(11), c + px(3), c - px(5)], start=180, end=360 + 90, fill=OUTLINE, width=w)
    neck, left, right = (c, c - px(5)), (c - px(10), c + px(5)), (c + px(10), c + px(5))
    d.line([neck, left, right, neck], fill=OUTLINE, width=w, joint="curve")


def book(d: ImageDraw.ImageDraw, face) -> None:
    card(d, face)
    c = S / 2
    w = int(px(2))
    x0, y0, x1, y1 = c - px(8), c - px(10), c + px(8), c + px(10)
    d.rectangle([x0, y0, x1, y1], fill=BLUSH, outline=OUTLINE, width=w)
    d.line([(x0 + px(4), y0), (x0 + px(4), y1)], fill=OUTLINE, width=w)
    d.line([(x0 + px(7), y0 + px(6)), (x1 - px(3), y0 + px(6))], fill=OUTLINE, width=int(px(1.5)))


def magnifier(d: ImageDraw.ImageDraw, face, sign: str) -> None:
    card(d, face)
    c = S / 2
    w = int(px(2))
    r = px(6)
    cx, cy = c - px(2), c - px(2)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BLUSH, outline=OUTLINE, width=w)
    d.line([(cx + r * 0.7, cy + r * 0.7), (c + px(9), c + px(9))], fill=OUTLINE, width=int(px(3)))
    d.line([(cx - px(3), cy), (cx + px(3), cy)], fill=OUTLINE, width=w)
    if sign == "+":
        d.line([(cx, cy - px(3)), (cx, cy + px(3))], fill=OUTLINE, width=w)


def zoom_in(d: ImageDraw.ImageDraw, face) -> None:
    magnifier(d, face, "+")


def zoom_out(d: ImageDraw.ImageDraw, face) -> None:
    magnifier(d, face, "-")


def help_mark(d: ImageDraw.ImageDraw, face) -> None:
    card(d, face)
    c = S / 2
    w = int(px(2.5))
    d.arc([c - px(5), c - px(10), c + px(5), c], start=180, end=420, fill=OUTLINE, width=w)
    d.line([(c + px(2.5), c - px(1.5)), (c, c + px(1)), (c, c + px(3.5))], fill=OUTLINE, width=w, joint="curve")
    d.ellipse([c - px(1.5), c + px(6), c + px(1.5), c + px(9)], fill=OUTLINE)


def map_sheet(d: ImageDraw.ImageDraw, face) -> None:
    """A map folded in three (blush, face, blush panels, zigzag), a path across it and a heart pin."""
    card(d, face)
    c = S / 2
    w = int(px(2))
    x0, x1, y0, y1 = c - px(10), c + px(10), c - px(7), c + px(8)
    xs = [x0 + (x1 - x0) * i / 3 for i in range(4)]
    tilt = px(1.5)  # the folds zigzag: panels 1 and 3 sit a little lower
    for i in range(3):
        dy = tilt if i % 2 == 0 else 0
        d.polygon([(xs[i], y0 + dy), (xs[i + 1], y0 + tilt - dy), (xs[i + 1], y1 + tilt - dy), (xs[i], y1 + dy)],
                  fill=BLUSH if i % 2 == 0 else face, outline=OUTLINE, width=w)
    # a dotted path from the bottom left to the pin
    for i in range(4):
        t = i / 4
        r = px(0.8)
        x, y = x0 + px(3) + (px(10)) * t, y1 - px(2) - px(6) * t
        d.ellipse([x - r, y - r, x + r, y + r], fill=OUTLINE)
    heart(d, (c + px(4), c - px(3)), px(4.5), (255, 140, 191, 255))


def heart(d: ImageDraw.ImageDraw, at, size: float, fill) -> None:
    """A heart centred at `at`, `size` drawing px from its centre to its widest side."""
    import math
    pts = []
    for i in range(48):
        t = math.tau * i / 48
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((at[0] + x / 16 * size, at[1] + (y + 2) / 16 * size))
    d.polygon(pts, fill=fill, outline=OUTLINE, width=int(px(1.5)))


FIG_W, FIG_H = 32, 48           # file px of a figure (16x24 viewport px)
FIG_INK = (89, 56, 89, 255)     # the plum of the HUD, cut out as a shadow


def figure(height: float) -> Image.Image:
    """The paper-doll girl as a plum paper shadow `height` viewport px tall, feet on the bottom."""
    W, H = FIG_W * K, FIG_H * K
    u = height * 2 * K / 24  # one unit of the 24-unit-tall figure, in drawing px
    cx, foot = W / 2, H - px(2.5)

    def shape(d: ImageDraw.ImageDraw, fill, grow: float) -> None:
        g = grow
        top = foot - 24 * u
        d.ellipse([cx - 3.6 * u - g, top - g, cx + 3.6 * u + g, top + 7.2 * u + g], fill=fill)  # head
        for side in (-1, 1):  # braids sticking out either side
            bx, by = cx + side * 4.4 * u, top + 5.4 * u
            d.ellipse([bx - 1.5 * u - g, by - 1.5 * u - g, bx + 1.5 * u + g, by + 1.5 * u + g], fill=fill)
        d.rectangle([cx - 0.9 * u - g, top + 6.5 * u - g, cx + 0.9 * u + g, top + 9 * u + g], fill=fill)  # neck
        d.polygon([(cx - 3 * u - g, top + 8.6 * u - g), (cx + 3 * u + g, top + 8.6 * u - g),  # the gown
                   (cx + 6.4 * u + g, foot - 2.2 * u + g), (cx - 6.4 * u - g, foot - 2.2 * u + g)], fill=fill)
        for side in (-1, 1):
            sx = cx + side * 3.2 * u  # puffed sleeve, arm and hand
            d.ellipse([sx - 1.7 * u - g, top + 8.2 * u - g, sx + 1.7 * u + g, top + 11.4 * u + g], fill=fill)
            hx, hy = cx + side * 6.6 * u, top + 14.6 * u
            d.line([(sx + side * 0.6 * u, top + 10 * u), (hx, hy)], fill=fill, width=int(1.5 * u + 2 * g))
            d.ellipse([hx - 1 * u - g, hy - 1 * u - g, hx + 1 * u + g, hy + 1 * u + g], fill=fill)
            lx = cx + side * 1.8 * u  # a leg and a foot under the hem
            d.rectangle([lx - 0.7 * u - g, foot - 2.6 * u - g, lx + 0.7 * u + g, foot - 0.8 * u + g], fill=fill)
            d.ellipse([lx - 1.2 * u - g + side * 0.4 * u, foot - 1.6 * u - g, lx + 1.2 * u + g + side * 0.4 * u, foot + g], fill=fill)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shape(ImageDraw.Draw(shadow), (89, 56, 89, 90), px(1.2))
    shadow = shadow.filter(ImageFilter.GaussianBlur(px(1.2)))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.alpha_composite(shadow, (int(px(1)), int(px(1))))
    d = ImageDraw.Draw(img)
    shape(d, (255, 255, 255, 255), px(1.2))  # the white paper edge
    shape(d, FIG_INK, 0)
    top = foot - 24 * u
    for side in (-1, 1):  # everything has a face (STYLE 4.1): two cream dot eyes
        ex, ey, r = cx + side * 1.4 * u, top + 3.8 * u, 0.55 * u
        d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=FACE)
    return img.resize((FIG_W, FIG_H), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in (("gear", gear), ("hanger", hanger), ("book", book), ("zoom_in", zoom_in),
                       ("zoom_out", zoom_out), ("help", help_mark), ("map", map_sheet)):
        for suffix, face in (("", FACE), ("_pressed", BLUSH)):
            img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            draw(ImageDraw.Draw(img), face)
            img.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{name}{suffix}.png", optimize=True)
            print(f"wrote {OUT.relative_to(OUT.parents[2])}/{name}{suffix}.png")
    for name, height in (("figure_near", 19.0), ("figure_far", 11.0)):
        figure(height).save(OUT / f"{name}.png", optimize=True)
        print(f"wrote {OUT.relative_to(OUT.parents[2])}/{name}.png")


if __name__ == "__main__":
    main()
