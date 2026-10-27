#!/usr/bin/env python3
"""Draw the floating HUD stickers: the settings gear, the wardrobe's clothes hanger and the
journal's book (scripts/ui/gear_button.gd, scripts/ui/sticker_button.gd).

Usage: python3 -I tools/gen_hud_stickers.py
Inputs: none (the gear's cream / plum / blush, as the settings screen uses them).
Outputs: project/assets/ui/hud/<name>.png and <name>_pressed.png for gear, hanger and book:
64x64 px, shown 32 viewport px (stored at 2x for the 1280x720 window). Pressed swaps the cream
face for blush. Drawn at 8x the file size and downscaled with LANCZOS. Deterministic.
"""
from pathlib import Path

from PIL import Image, ImageDraw

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


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in (("gear", gear), ("hanger", hanger), ("book", book)):
        for suffix, face in (("", FACE), ("_pressed", BLUSH)):
            img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            draw(ImageDraw.Draw(img), face)
            img.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / f"{name}{suffix}.png", optimize=True)
            print(f"wrote {OUT.relative_to(OUT.parents[2])}/{name}{suffix}.png")


if __name__ == "__main__":
    main()
