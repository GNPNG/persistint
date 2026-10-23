"""Draw the Florida pony stable art: layered pony parts for PonyDoll and the stable background.

Usage: python3 -I tools/gen_pony_sprites.py
Reads project/data/ponies.json (coat and mane colours, mane styles, accessories) and writes
project/assets/placeholder/pony_*.png and bg_florida_stable.png.

Every pony part shares one 64x52 frame (pony faces right, three-quarter side view) so the parts
stack: body (coat colour; legs, head, face), spots, mane (mane + tail, per style and colour),
accessory, sparkle. Kawaii sticker look from prompts/STYLE.md 4.3: warm-brown outline #8a5a5a,
flat pastel fills with one highlight, dot eyes with a catch-light, pink blush, small smile.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "project/assets/placeholder"
DATA = json.loads((ROOT / "project/data/ponies.json").read_text())
INK = "#8a5a5a"
BLUSH = "#ff9fb8"
K = 4
W, H = 64, 52


def canvas(w=W, h=H):
    im = Image.new("RGBA", (w * K, h * K))
    return im, ImageDraw.Draw(im)


def done(im, name, w=W, h=H):
    im.resize((w, h), Image.LANCZOS).save(OUT / f"{name}.png")


def ell(d, x, y, rx, ry, fill, width=1.0):
    d.ellipse([(x - rx) * K, (y - ry) * K, (x + rx) * K, (y + ry) * K], fill=fill,
              outline=INK if width else None, width=int(width * K))


def mix(hex_a, hex_b, t):
    a = [int(hex_a[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(hex_b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


def sparkle(d, x, y, r, fill="#fff3a8"):
    pts = [(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3), (x, y + r),
           (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)]
    d.polygon([(px * K, py * K) for px, py in pts], fill=fill, outline="#e0b24a", width=K // 2)


def body(coat_id, color):
    im, d = canvas()
    hoof = mix(color, "#8a5a5a", 0.45)
    shade = mix(color, "#8a5a5a", 0.12)
    # far legs first (a touch darker), then the near legs
    for x in (19, 42):
        d.rounded_rectangle([(x - 3) * K, 32 * K, (x + 3) * K, 47 * K], 3 * K, fill=shade, outline=INK, width=K)
        d.rounded_rectangle([(x - 3) * K, 44 * K, (x + 3) * K, 47 * K], 1 * K, fill=hoof)
    ell(d, 31, 29, 18, 11, color)  # barrel
    for x in (14, 36):
        d.rounded_rectangle([(x - 3) * K, 33 * K, (x + 3) * K, 49 * K], 3 * K, fill=color, outline=INK, width=K)
        d.rounded_rectangle([(x - 3) * K, 46 * K, (x + 3) * K, 49 * K], 1 * K, fill=hoof)
    ell(d, 25, 25, 7, 3, mix(color, "#ffffff", 0.55), 0)  # highlight on the back
    ell(d, 44, 21, 6, 9, color)  # neck
    d.polygon([(43 * K, 9 * K), (46 * K, 1 * K), (50 * K, 8 * K)], fill=color, outline=INK, width=K)  # ear
    d.polygon([(45 * K, 8 * K), (46 * K, 4 * K), (48 * K, 8 * K)], fill=BLUSH)
    ell(d, 49, 15, 9, 8.5, color)  # head
    ell(d, 56, 19, 5.5, 4.5, mix(color, "#ffffff", 0.45))  # snout
    ell(d, 51, 13, 1.4, 1.6, INK, 0)  # dot eye + catch-light
    ell(d, 51.4, 12.4, 0.5, 0.5, "#ffffff", 0)
    ell(d, 53.5, 17.5, 2.0, 1.2, BLUSH, 0)  # blush
    ell(d, 58.5, 18, 0.6, 0.6, INK, 0)  # nostril
    d.arc([54.5 * K, 18.5 * K, 58.5 * K, 22 * K], 20, 160, fill=INK, width=K)  # smile
    done(im, f"pony_body_{coat_id}")


def spots():
    im, d = canvas()
    for x, y, r in [(20, 27, 2.4), (27, 32, 2.0), (34, 26, 2.6), (24, 22, 1.6), (40, 31, 1.8), (16, 32, 1.6)]:
        ell(d, x, y, r, r, (255, 255, 255, 170), 0)
    done(im, "pony_spots")


MANE_PATHS = {
    # (x, y, r) lobes along the neck and forelock, then the tail
    "flowing": ([(47, 5, 3.6), (43, 8, 4.0), (40, 13, 4.2), (38, 18, 4.0), (37, 23, 3.4)],
                [(13, 24, 4.0), (10, 29, 4.2), (9, 34, 4.0), (10, 39, 3.4), (12, 43, 2.6)]),
    "braids": ([(47, 5, 2.6), (44, 7, 2.6), (42, 10, 2.6), (40, 13, 2.6), (39, 16, 2.6), (38, 19, 2.6), (37, 22, 2.6)],
               [(13, 24, 3.0), (12, 28, 2.6), (11, 32, 2.6), (11, 36, 2.6), (11, 40, 2.4), (12, 44, 2.2)]),
    "curly": ([(47, 4, 4.4), (42, 8, 4.8), (39, 14, 4.8), (37, 20, 4.4)],
              [(12, 25, 4.6), (9, 31, 4.8), (11, 37, 4.6), (14, 42, 3.6)]),
}


def mane(style, color_id, color):
    im, d = canvas()
    neck, tail = MANE_PATHS[style]
    hi = mix(color, "#ffffff", 0.6)
    for x, y, r in tail + neck:
        ell(d, x, y, r, r, color)
    for x, y, r in (tail + neck)[::2]:
        ell(d, x - r * 0.3, y - r * 0.35, r * 0.35, r * 0.25, hi, 0)
    if style == "braids":  # tiny ties at the braid ends
        for x, y in [(37, 25), (12, 47)]:
            ell(d, x, y, 1.6, 1.2, "#ffffff")
    done(im, f"pony_mane_{style}_{color_id}")


def accessories():
    im, d = canvas()  # bow on the mane by the ear
    for dx in (-3.4, 3.4):
        ell(d, 42 + dx, 4, 3.0, 2.2, "#ff7fae")
    ell(d, 42, 4, 1.5, 1.5, "#ffd1e2")
    done(im, "pony_acc_bow")

    im, d = canvas()  # flower crown over the forelock
    for x, y, c in [(43, 6, "#ff9ad0"), (46, 4, "#ffffff"), (49, 4, "#ffe27a"), (52, 5, "#ff9ad0"), (54, 7, "#b89ae0")]:
        ell(d, x, y, 2.2, 2.2, c)
        ell(d, x, y, 0.8, 0.8, "#ffe27a", 0)
    done(im, "pony_acc_flower_crown")

    im, d = canvas()  # little saddle blanket where a rider sits
    d.rounded_rectangle([22 * K, 18 * K, 38 * K, 28 * K], 3 * K, fill="#7fd4c1", outline=INK, width=K)
    for x in (25, 30, 35):
        ell(d, x, 23, 1.3, 1.3, "#ffffff", 0)
    d.line([22 * K, 26 * K, 38 * K, 26 * K], fill="#ff9ad0", width=K)
    done(im, "pony_acc_blanket")

    im, d = canvas()  # hibiscus behind the ear
    for a in range(5):
        x = 41 + 2.6 * math.cos(a * 1.2566)
        y = 6 + 2.6 * math.sin(a * 1.2566)
        ell(d, x, y, 2.0, 2.0, "#ff6fa8")
    ell(d, 41, 6, 1.1, 1.1, "#ffe27a", 0)
    done(im, "pony_acc_hibiscus")


def shine():
    im, d = canvas()
    for x, y, r in [(8, 14, 3.4), (30, 12, 2.6), (60, 6, 3.0), (24, 44, 2.2), (55, 34, 2.6)]:
        sparkle(d, x, y, r)
    done(im, "pony_sparkle")


def stable_bg():
    w, h = 960, 540
    im = Image.new("RGBA", (w * 2, h * 2), "#c4eab0")
    d = ImageDraw.Draw(im)
    S = 2

    def r(box, fill, rad=0, width=3):
        d.rounded_rectangle([v * S for v in box], rad * S, fill=fill, outline=INK, width=width * S)

    def e(x, y, rx, ry, fill, width=3):
        d.ellipse([(x - rx) * S, (y - ry) * S, (x + rx) * S, (y + ry) * S], fill=fill,
                  outline=INK if width else None, width=width * S)

    d.rectangle([0, 0, w * S, 150 * S], fill="#a9dc92")  # back lawn
    for x in range(30, 960, 120):  # bubbly hedge along the back
        e(x, 40, 52, 34, "#8fce7a")
    # the stable: a big friendly barn with a face
    r((300, 20, 660, 170), "#f4a6a0", 14)
    d.polygon([(280 * S, 40 * S), (480 * S, -40 * S), (680 * S, 40 * S)], fill="#e07a7a", outline=INK, width=3 * S)
    r((430, 90, 530, 170), "#c98f5a", 10)  # big door
    d.line([430 * S, 90 * S, 530 * S, 170 * S], fill=INK, width=2 * S)
    d.line([530 * S, 90 * S, 430 * S, 170 * S], fill=INK, width=2 * S)
    for x in (360, 600):  # windows are the eyes
        r((x - 26, 60, x + 26, 100), "#fff6dc", 10)
        e(x, 82, 8, 9, INK, 0)
        e(x + 3, 78, 3, 3, "#ffffff", 0)
    for x in (330, 630):
        e(x, 122, 14, 8, BLUSH, 0)
    d.arc([462 * S, 52 * S, 498 * S, 76 * S], 20, 160, fill=INK, width=3 * S)  # smile above the door
    # paddock fence
    for y in (190, 520):
        r((40, y - 4, 920, y + 4), "#fff1e6", 3, 2)
    for x in range(40, 921, 80):
        r((x - 5, 176, x + 5, 204), "#fff1e6", 3, 2)
        r((x - 5, 506, x + 5, 534), "#fff1e6", 3, 2)
    # soft dirt patch for the stalls, hay, a trough, flowers
    e(480, 360, 400, 130, "#e9d49b", 0)
    for x, y in [(110, 260), (860, 300), (130, 450)]:
        r((x - 26, y - 16, x + 26, y + 16), "#ffe27a", 8)
        d.line([(x - 20) * S, y * S, (x + 20) * S, y * S], fill="#e0b24a", width=2 * S)
    r((820, 420, 900, 452), "#8fd3e8", 8)
    for x, y, c in [(60, 160, "#ff9ad0"), (250, 150, "#ffffff"), (720, 155, "#ffe27a"), (900, 165, "#ff9ad0")]:
        for dx, dy in ((0, -6), (6, 0), (0, 6), (-6, 0)):
            e(x + dx, y + dy, 5, 5, c, 2)
        e(x, y, 4, 4, "#ffe27a", 2)
    im.resize((w, h), Image.LANCZOS).convert("RGB").save(OUT / "bg_florida_stable.png")


def main():
    for coat_id, info in DATA["genes"]["coat"]["alleles"].items():
        body(coat_id, info["color"])
    for style in DATA["groom"]["mane_style"]:
        for color_id, info in DATA["genes"]["mane"]["alleles"].items():
            mane(style, color_id, info["color"])
    spots()
    accessories()
    shine()
    stable_bg()
    print("Pony art written to", OUT)


if __name__ == "__main__":
    main()
