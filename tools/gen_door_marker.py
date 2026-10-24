"""Draw the doormat-and-arrow marker that every exit door shows (scripts/door.gd).

Usage: python3 -I tools/gen_door_marker.py
Inputs: none (palette hexes from prompts/STYLE.md 4.3-4.4).
Output: project/assets/common/door_marker.png, a sprite sheet of 160x192 frames (40x48 world
px stored at 4x; door.gd shows it at scale 0.25):
  row 0  "open"    8 frames: a pink pill doormat with a white heart, the arrow above it bobbing
                   down and up once over the 8 frames (sin, 3 px)
  row 1  "locked"  the same with a lilac-grey mat and a padlock in place of the heart
The mat is centred at frame (80, 144) in file px (20, 36 world px), which door.gd puts on the
door's origin. Sizes in the code are world px. Kawaii sticker look: warm-brown outline #8a5a5a,
flat fill, white highlight. Drawn at 16x, downscaled with LANCZOS to 4x.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/common/door_marker.png"
INK = "#8a5a5a"
O = 4   # file pixels per world pixel: sprites are stored at 4x their size on the map
K = 16  # drawing pixels per world pixel (4x supersample over the file, LANCZOS down)
W, H, FRAMES = 40, 48, 8


def P(*v):
    return [c * K for c in v]


def heart(d, x, y, r, col):
    d.ellipse(P(x - r, y - r, x, y + r * .2), fill=col)
    d.ellipse(P(x, y - r, x + r, y + r * .2), fill=col)
    d.polygon([((x - r * .97) * K, (y - r * .2) * K), ((x + r * .97) * K, (y - r * .2) * K), (x * K, (y + r * 1.1) * K)], fill=col)


def frame(i, locked):
    im = Image.new("RGBA", (W * K, H * K))
    d = ImageDraw.Draw(im)
    mat, mat_hi = ("#c9c2d6", "#e4dfec") if locked else ("#ffb8d6", "#ffd9e8")
    # Mat: a rounded pill 30x18 with a soft inner rim.
    d.rounded_rectangle(P(5, 27, 35, 45), 9 * K, fill=mat, outline=INK, width=int(1.2 * K))
    d.rounded_rectangle(P(7.5, 29.5, 32.5, 42.5), 7 * K, outline="#ffffff", width=K)
    d.ellipse(P(9, 30.5, 14, 33), fill=mat_hi)
    if locked:
        d.arc(P(17, 30, 23, 37), 180, 360, fill=INK, width=int(1.4 * K))
        d.rounded_rectangle(P(15.5, 33.5, 24.5, 40.5), K, fill="#fff4c4", outline=INK, width=K)
        d.ellipse(P(19, 35.6, 21, 37.6), fill=INK)
    else:
        heart(d, 20, 35.5, 4.4, INK)
        heart(d, 20, 35.6, 3.4, "#ffffff")
    if not locked:
        # Arrow pointing down at the mat; bobs 3 px over the loop.
        y = 9 + math.sin(i / FRAMES * 2 * math.pi) * 3
        pts = [(13, y), (27, y), (20, y + 9)]
        d.polygon([(x * K, yy * K) for x, yy in pts], fill="#ff8cbf", outline=INK, width=int(1.2 * K))
        d.polygon([((x * 0.5 + 20 * 0.5 - 1.5) * K, (yy * 0.5 + (y + 3) * 0.5 - 1.5) * K) for x, yy in pts[:2] + [(20, y + 4)]], fill="#ffc2dc")
    return im


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (W * O * FRAMES, H * O * 2))
    for row, locked in enumerate((False, True)):
        for i in range(FRAMES):
            sheet.paste(frame(i, locked).resize((W * O, H * O), Image.LANCZOS), (i * W * O, row * H * O))
    sheet.save(OUT)
    print(OUT, sheet.size)


if __name__ == "__main__":
    main()
