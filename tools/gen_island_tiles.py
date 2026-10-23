"""Draw the island tile atlas (32 px cells) in the canon sheets' palette.

Usage: python3 -I tools/gen_island_tiles.py
Row 0 holds walkable ground (cols 0-10). Row 1 repeats those cells as blocked ground (props
sit on them) and adds the solid-only tiles (cols 11-16). The canon sheets carry no tiles,
so these are flat pastel cells with the rounded candy shapes with the canon sheets' brown outline colour.
"""
import random
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/tiles/island_tiles.png"
S, K = 32, 4  # cell size, supersample
random.seed(7)

WALK = ["grass_a", "grass_b", "grass_flower", "path", "sand", "soil", "sprouts", "plaza", "floor", "floor_alt", "rug"]
SOLID = ["water", "foam", "wall", "wall_cap", "hedge", "rock", "stripe", "gold_cap"]


def cell():
    im = Image.new("RGBA", (S * K, S * K))
    return im, ImageDraw.Draw(im)


INK = "#8a5a5a"
OUTLINE = K // 2 * 3 // 2


def blob(d, x, y, r, fill, ink=INK):
    d.ellipse([(x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K], fill=fill, outline=ink, width=OUTLINE)


def flower(d, x, y, petal, r=2.4):
    for dx, dy in ((0, -r), (r, 0), (0, r), (-r, 0)):
        blob(d, x + dx, y + dy, r * 0.75, petal)
    blob(d, x, y, r * 0.7, "#ffe27a")


def clover(d, x, y, col, ink="#79b45f"):
    for dx, dy in ((-1.6, 0), (1.6, 0), (0, -1.6)):
        d.ellipse([(x + dx - 1.7) * K, (y + dy - 1.7) * K, (x + dx + 1.7) * K, (y + dy + 1.7) * K], fill=col, outline=ink, width=K // 2)


def sparkle(d, x, y, r, col="#ffffff", ink=None):
    d.polygon([(x * K, (y - r) * K), ((x + r * .3) * K, (y - r * .3) * K), ((x + r) * K, y * K), ((x + r * .3) * K, (y + r * .3) * K),
               (x * K, (y + r) * K), ((x - r * .3) * K, (y + r * .3) * K), ((x - r) * K, y * K), ((x - r * .3) * K, (y - r * .3) * K)],
              fill=col, outline=ink)


def heart(d, x, y, r, col="#ff8fb1"):
    d.ellipse([(x - r) * K, (y - r) * K, x * K, (y + r * .2) * K], fill=col)
    d.ellipse([x * K, (y - r) * K, (x + r) * K, (y + r * .2) * K], fill=col)
    d.polygon([((x - r) * K, (y - r * .25) * K), ((x + r) * K, (y - r * .25) * K), (x * K, (y + r * 1.1) * K)], fill=col)


def draw(name):
    im, d = cell()
    full = [0, 0, S * K, S * K]
    r = random.Random(zlib.crc32(name.encode()))
    if name.startswith("grass"):
        d.rectangle(full, fill="#c5ecaa")
        for _ in range(4):
            clover(d, r.randint(5, S - 6), r.randint(6, S - 5), "#a6dc8a")
        if name == "grass_b":
            for _ in range(5):
                x, y = r.randint(3, S - 4), r.randint(3, S - 4)
                d.ellipse([x * K, y * K, (x + 3) * K, (y + 1.5) * K], fill="#d6f5bf")
        if name == "grass_flower":
            flower(d, 9, 10, "#ffb8d1")
            flower(d, 22, 21, "#ffffff", 2.2)
            sparkle(d, 24, 8, 2.4, "#fff6b0", "#e8c85a")
    elif name == "path":
        d.rectangle(full, fill="#fff0cf")
        for _ in range(6):
            blob(d, r.randint(5, S - 6), r.randint(5, S - 6), 1.9, "#ffe2b0", "#d9b98a")
    elif name == "sand":
        d.rectangle(full, fill="#ffe9b8")
        for _ in range(6):
            x, y = r.randint(3, S - 4), r.randint(3, S - 4)
            blob(d, x, y, 1.0, "#ffd3c2", "#e0a899")
        sparkle(d, 22, 10, 2.0, "#ffffff")
    elif name in ("soil", "sprouts"):
        d.rectangle(full, fill="#e0b48f")
        for y in (8, 18, 28):
            d.rounded_rectangle([3 * K, (y - 3) * K, (S - 3) * K, (y + 1.5) * K], 2 * K, fill="#c99468", outline="#a8714a", width=K // 2)
        if name == "sprouts":
            for x in (8, 16, 24):
                for y in (6, 16, 26):
                    d.ellipse([(x - 3) * K, (y - 1.5) * K, (x + 0.5) * K, (y + 1.5) * K], fill="#9be07c", outline="#5fa84a", width=K // 2)
                    d.ellipse([(x - .5) * K, (y - 3.5) * K, (x + 3) * K, (y - .5) * K], fill="#b4ee95", outline="#5fa84a", width=K // 2)
    elif name == "plaza":
        d.rectangle(full, fill="#f6e9f2")
        for x in (0, 16):
            for y in (0, 16):
                d.rounded_rectangle([(x + 1) * K, (y + 1) * K, (x + 15) * K, (y + 15) * K], 4 * K, fill="#fbf2f8", outline="#e1c6d8", width=K)
        heart(d, 8, 8, 2.2, "#ffd0e0")
        heart(d, 24, 24, 2.2, "#d9e9ff")
    elif name in ("floor", "floor_alt"):
        base, line = ("#fff6e2", "#f0d9b4") if name == "floor" else ("#ffe6ee", "#f4bfd1")
        d.rectangle(full, fill=base)
        d.rounded_rectangle([1 * K, 1 * K, (S - 1) * K, (S - 1) * K], 5 * K, outline=line, width=K)
        sparkle(d, 16, 16, 3.2, "#ffffff", line)
    elif name == "rug":
        d.rectangle(full, fill="#ffb3c8")
        d.rectangle([0, 0, 3 * K, S * K], fill="#ffe3a8")
        d.rectangle([(S - 3) * K, 0, S * K, S * K], fill="#ffe3a8")
        for y in (8, 24):
            heart(d, 16, y, 4, "#fff4f8")
    elif name in ("water", "foam"):
        d.rectangle(full, fill="#a9ddf2" if name == "water" else "#c6eefb")
        for x, y in [(6, 9), (20, 22), (18, 6)]:
            d.arc([x * K, y * K, (x + 8) * K, (y + 5) * K], 200, 340, fill="#ffffff", width=K)
        sparkle(d, 25, 12, 2.2, "#ffffff")
        if name == "foam":
            for x in range(0, S, 8):
                d.ellipse([x * K, (S - 5) * K, (x + 8) * K, (S + 3) * K], fill="#ffffff", outline="#d9f3fb", width=K // 2)
    elif name == "wall":
        d.rectangle(full, fill="#f1e2cd")
        for y in range(0, S, 8):
            d.line([0, y * K, S * K, y * K], fill="#d9c3a5", width=K // 2)
            off = 0 if (y // 8) % 2 == 0 else 8
            for x in range(off, S, 16):
                d.line([x * K, y * K, x * K, (y + 8) * K], fill="#d9c3a5", width=K // 2)
    elif name == "wall_cap":
        d.rectangle(full, fill="#f8efe0")
        d.rectangle([0, 0, S * K, 6 * K], fill="#fffaf0")
        d.line([0, 6 * K, S * K, 6 * K], fill="#d9c3a5", width=K)
        d.rectangle([0, (S - 2) * K, S * K, S * K], fill="#e6d6bd")
    elif name == "hedge":
        d.rectangle(full, fill="#c5ecaa")
        for x, y in [(9, 11), (22, 10), (15, 21), (25, 24), (7, 25)]:
            blob(d, x, y, 7, "#95d37c", "#5fa84a")
        sparkle(d, 16, 10, 2.2, "#ffffff")
    elif name == "stripe":
        d.rectangle(full, fill="#ffffff")
        for x in range(0, S, 8):
            d.rectangle([x * K, 0, (x + 4) * K, S * K], fill="#a8d4f5")
        d.line([0, (S - 1) * K, S * K, (S - 1) * K], fill="#7fb3dc", width=K)
    elif name == "gold_cap":
        d.rectangle(full, fill="#ffe59a")
        d.rectangle([0, 0, S * K, 5 * K], fill="#fff4c4")
        d.line([0, 5 * K, S * K, 5 * K], fill="#e0b24a", width=K)
        for x in range(4, S, 8):
            d.line([x * K, 6 * K, x * K, S * K], fill="#efc86a", width=K // 2)
    elif name == "rock":
        d.rectangle(full, fill="#c5ecaa")
        d.rounded_rectangle([3 * K, 8 * K, (S - 3) * K, (S - 3) * K], 8 * K, fill="#e1dcef", outline=INK, width=OUTLINE)
        d.ellipse([9 * K, 11 * K, 17 * K, 16 * K], fill="#f5f2fb")
        blob(d, 12, 20, .7, "#8a5a5a", "#8a5a5a")
        blob(d, 20, 20, .7, "#8a5a5a", "#8a5a5a")
    return im.resize((S, S), Image.LANCZOS)


atlas = Image.new("RGBA", (S * (len(WALK) + len(SOLID)), S * 2))
for i, n in enumerate(WALK):
    c = draw(n)
    atlas.paste(c, (i * S, 0))
    atlas.paste(c, (i * S, S))
for i, n in enumerate(SOLID):
    atlas.paste(draw(n), ((len(WALK) + i) * S, S))
atlas.save(OUT)
print(OUT, atlas.size)
