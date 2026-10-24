"""Draw the Florida stable ponies as layered, rigged sprite sheets for PonyDoll.

Usage: python3 -I tools/gen_pony_sprites.py
Reads project/data/ponies.json (coat and mane colours, mane styles, accessories) and writes
project/assets/florida/pony_<part>.png: pony_body_<coat>, pony_spots, pony_mane_<style>_<colour>,
pony_acc_<accessory>, pony_sparkle.

Every part is a sheet on one shared grid so the parts stack and animate together: frame 64x52
world px, stored at D = 4 texture px per world px (256x208 per frame, sheet 1024x416; pony
faces right, three-quarter side view), 4 columns x 2 rows.
  row 0 idle: 0 rest, 1 breath (body half a pixel lower, tail swishes back), 2 rest,
              3 blink (eyes closed, tail swishes forward)
  row 1 walk: four steps, legs swinging in diagonal pairs, body bobbing on the passing steps
PonyDoll (scripts/florida/pony_doll.gd) stacks the parts as Sprite2D layers (hframes 4,
vframes 2) and one AnimationPlayer drives every layer's frame: idle at 3 fps, walk at 8 fps.
Kawaii sticker look from prompts/STYLE.md 4.3: warm-brown outline #8a5a5a, flat pastel fills
with one highlight, dot eyes with a catch-light, pink blush, small smile. Drawn at 8x world
size and LANCZOS-resized to 4x; deterministic. PonyDoll scales the layers back to 64x52.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "project/assets/florida"
DATA = json.loads((ROOT / "project/data/ponies.json").read_text())
INK = "#8a5a5a"
BLUSH = "#ff9fb8"
K = 8  # drawing scale
D = 4  # texture px per world px
W, H = 64, 52

# (bob, leg swing, tail swing, blink) per frame; row 0 idle, row 1 walk
POSES = [
    [(0.0, 0, 0.0, False), (0.5, 0, -1.0, False), (0.0, 0, 0.0, False), (0.0, 0, 1.0, True)],
    [(0.0, 1, 0.5, False), (-1.0, 0, 0.0, False), (0.0, -1, -0.5, False), (-1.0, 0, 0.0, False)],
]


class Pose:
    bob = 0.0
    legs = 0
    tail = 0.0
    blink = False


P = Pose()


def sheet(name, draw):
    """Render draw(d) once per pose into a 4x2 sheet."""
    out = Image.new("RGBA", (W * D * 4, H * D * 2))
    for r, row in enumerate(POSES):
        for c, (bob, legs, tail, blink) in enumerate(row):
            P.bob, P.legs, P.tail, P.blink = bob, legs, tail, blink
            im = Image.new("RGBA", (W * K, H * K))
            draw(ImageDraw.Draw(im))
            out.alpha_composite(im.resize((W * D, H * D), Image.LANCZOS), (c * W * D, r * H * D))
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / f"{name}.png")


def ell(d, x, y, rx, ry, fill, width=1.0, dy=None):
    """An ellipse on the pony's upper body (moves with the breathing bob)."""
    y += P.bob if dy is None else dy
    d.ellipse([(x - rx) * K, (y - ry) * K, (x + rx) * K, (y + ry) * K], fill=fill,
              outline=INK if width else None, width=int(width * K))


def poly(d, pts, fill, width=1):
    d.polygon([(x * K, (y + P.bob) * K) for x, y in pts], fill=fill, outline=INK if width else None, width=int(width * K))


def mix(hex_a, hex_b, t):
    a = [int(hex_a[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(hex_b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


def sparkle(d, x, y, r, fill="#fff3a8"):
    pts = [(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3), (x, y + r),
           (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)]
    d.polygon([(px * K, (py + P.bob) * K) for px, py in pts], fill=fill, outline="#e0b24a", width=K // 2)


def leg(d, x, top, foot_dx, bottom, fill, hoof):
    """A leg from the barrel down to its hoof; the hoof swings by foot_dx while walking."""
    x0, y0, x1, y1 = x * K, (top + P.bob) * K, (x + foot_dx) * K, bottom * K
    d.line([(x0, y0), (x1, y1)], fill=INK, width=8 * K)
    d.line([(x0, y0 - 2 * K), (x1, y1)], fill=fill, width=6 * K)
    for cx, cy, r, f in ((x1, y1 - K, 4, INK), (x1, y1 - K, 3, fill)):
        d.ellipse([cx - r * K, cy - r * K, cx + r * K, cy + r * K], fill=f)
    d.rounded_rectangle([x1 - 3 * K, y1 - 3 * K, x1 + 3 * K, y1], K, fill=hoof)


def body(color):
    def draw(d):
        hoof = mix(color, INK, 0.45)
        shade = mix(color, INK, 0.12)
        s = P.legs * 2.6
        for x, dx in ((19, s), (42, -s)):  # far legs first, a touch darker
            leg(d, x, 33, dx, 47, shade, hoof)
        ell(d, 31, 29, 18, 11, color)  # barrel
        for x, dx in ((14, -s), (36, s)):
            leg(d, x, 35, dx, 49, color, hoof)
        ell(d, 25, 25, 7, 3, mix(color, "#ffffff", 0.55), 0)  # highlight on the back
        ell(d, 44, 21, 6, 9, color)  # neck
        poly(d, [(43, 9), (46, 1), (50, 8)], color)  # ear
        poly(d, [(45, 8), (46, 4), (48, 8)], BLUSH, 0)
        ell(d, 49, 15, 9, 8.5, color)  # head
        ell(d, 56, 19, 5.5, 4.5, mix(color, "#ffffff", 0.45))  # snout
        if P.blink:
            d.arc([49.4 * K, (12 + P.bob) * K, 52.6 * K, (14.6 + P.bob) * K], 20, 160, fill=INK, width=K)
        else:
            ell(d, 51, 13, 1.4, 1.6, INK, 0)  # dot eye + catch-light
            ell(d, 51.4, 12.4, 0.5, 0.5, "#ffffff", 0)
        ell(d, 53.5, 17.5, 2.0, 1.2, BLUSH, 0)
        ell(d, 58.5, 18, 0.6, 0.6, INK, 0)  # nostril
        d.arc([54.5 * K, (18.5 + P.bob) * K, 58.5 * K, (22 + P.bob) * K], 20, 160, fill=INK, width=K)  # smile
    return draw


def spots(d):
    for x, y, r in [(20, 27, 2.4), (27, 32, 2.0), (34, 26, 2.6), (24, 22, 1.6), (40, 31, 1.8), (16, 32, 1.6)]:
        ell(d, x, y, r, r, (255, 255, 255, 170), 0)


MANE_PATHS = {
    # (x, y, r) lobes along the neck and forelock, then the tail
    "flowing": ([(47, 5, 3.6), (43, 8, 4.0), (40, 13, 4.2), (38, 18, 4.0), (37, 23, 3.4)],
                [(13, 24, 4.0), (10, 29, 4.2), (9, 34, 4.0), (10, 39, 3.4), (12, 43, 2.6)]),
    "braids": ([(47, 5, 2.6), (44, 7, 2.6), (42, 10, 2.6), (40, 13, 2.6), (39, 16, 2.6), (38, 19, 2.6), (37, 22, 2.6)],
               [(13, 24, 3.0), (12, 28, 2.6), (11, 32, 2.6), (11, 36, 2.6), (11, 40, 2.4), (12, 44, 2.2)]),
    "curly": ([(47, 4, 4.4), (42, 8, 4.8), (39, 14, 4.8), (37, 20, 4.4)],
              [(12, 25, 4.6), (9, 31, 4.8), (11, 37, 4.6), (14, 42, 3.6)]),
}


def mane(style, color):
    def draw(d):
        neck, tail = MANE_PATHS[style]
        # the tail swings from its root: lobes further down move further
        tail = [(x + P.tail * 1.6 * i / len(tail), y, r) for i, (x, y, r) in enumerate(tail)]
        hi = mix(color, "#ffffff", 0.6)
        for x, y, r in tail + neck:
            ell(d, x, y, r, r, color)
        for x, y, r in (tail + neck)[::2]:
            ell(d, x - r * 0.3, y - r * 0.35, r * 0.35, r * 0.25, hi, 0)
        if style == "braids":  # tiny ties at the braid ends
            for x, y in [(37, 25), (12 + P.tail * 1.6, 47)]:
                ell(d, x, y, 1.6, 1.2, "#ffffff")
    return draw


def acc_bow(d):  # bow on the mane by the ear
    for dx in (-3.4, 3.4):
        ell(d, 42 + dx, 4, 3.0, 2.2, "#ff7fae")
    ell(d, 42, 4, 1.5, 1.5, "#ffd1e2")


def acc_flower_crown(d):  # flower crown over the forelock
    for x, y, c in [(43, 6, "#ff9ad0"), (46, 4, "#ffffff"), (49, 4, "#ffe27a"), (52, 5, "#ff9ad0"), (54, 7, "#b89ae0")]:
        ell(d, x, y, 2.2, 2.2, c)
        ell(d, x, y, 0.8, 0.8, "#ffe27a", 0)


def acc_blanket(d):  # little saddle blanket where a rider sits
    d.rounded_rectangle([22 * K, (18 + P.bob) * K, 38 * K, (28 + P.bob) * K], 3 * K, fill="#7fd4c1", outline=INK, width=K)
    for x in (25, 30, 35):
        ell(d, x, 23, 1.3, 1.3, "#ffffff", 0)
    d.line([22 * K, (26 + P.bob) * K, 38 * K, (26 + P.bob) * K], fill="#ff9ad0", width=K)


def acc_hibiscus(d):  # hibiscus behind the ear
    for a in range(5):
        ell(d, 41 + 2.6 * math.cos(a * 1.2566), 6 + 2.6 * math.sin(a * 1.2566), 2.0, 2.0, "#ff6fa8")
    ell(d, 41, 6, 1.1, 1.1, "#ffe27a", 0)


ACCESSORIES = {"bow": acc_bow, "flower_crown": acc_flower_crown, "blanket": acc_blanket, "hibiscus": acc_hibiscus}


def shine(d):
    for i, (x, y, r) in enumerate([(8, 14, 3.4), (30, 12, 2.6), (60, 6, 3.0), (24, 44, 2.2), (55, 34, 2.6)]):
        sparkle(d, x, y, r * (0.8 if (i + int(P.blink) + P.legs) % 2 else 1.0))


def main():
    for coat_id, info in DATA["genes"]["coat"]["alleles"].items():
        sheet(f"pony_body_{coat_id}", body(info["color"]))
    for style in DATA["groom"]["mane_style"]:
        for color_id, info in DATA["genes"]["mane"]["alleles"].items():
            sheet(f"pony_mane_{style}_{color_id}", mane(style, info["color"]))
    sheet("pony_spots", spots)
    for acc in DATA["groom"]["accessory"]:
        if acc in ACCESSORIES:
            sheet(f"pony_acc_{acc}", ACCESSORIES[acc])
    sheet("pony_sparkle", shine)
    print("Pony art written to", OUT)


if __name__ == "__main__":
    main()
