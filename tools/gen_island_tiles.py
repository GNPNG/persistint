"""Draw the island tile atlas (32 px cells) in the canon sheets' palette.

Usage: python3 -I tools/gen_island_tiles.py
Row 0 holds walkable ground (cols 0-10). Row 1 repeats those cells as blocked ground (props
sit on them) and adds the solid-only tiles (cols 11-16). The canon sheets carry no tiles,
so these are flat pastel cells with the same brown outline colour as the canon art.
"""
import random
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/tiles/island_tiles.png"
S, K = 32, 4  # cell size, supersample
INK = "#7a5a4a"
random.seed(7)

WALK = ["grass_a", "grass_b", "grass_flower", "path", "sand", "soil", "sprouts", "plaza", "floor", "floor_alt", "rug"]
SOLID = ["water", "foam", "wall", "wall_cap", "hedge", "rock"]


def cell():
    im = Image.new("RGBA", (S * K, S * K))
    return im, ImageDraw.Draw(im)


def tufts(d, col, n, seed):
    r = random.Random(seed)
    for _ in range(n):
        x, y = r.randint(5, S - 6) * K, r.randint(6, S - 4) * K
        for dx in (-2, 0, 2):
            d.line([x + dx * K // 2, y, x + dx * K, y - 3 * K], fill=col, width=K // 2 * 1)


def draw(name):
    im, d = cell()
    full = [0, 0, S * K, S * K]
    if name.startswith("grass"):
        d.rectangle(full, fill="#b9dc8c")
        tufts(d, "#8fbd69", 3, zlib.crc32(name.encode()) % 99)
        if name == "grass_b":
            for _ in range(5):
                x, y = random.randint(3, S - 3) * K, random.randint(3, S - 3) * K
                d.ellipse([x, y, x + 2 * K, y + K], fill="#c9e79c")
        if name == "grass_flower":
            for x, y, c in [(8, 9, "#ffb3c8"), (21, 18, "#fff2a6"), (12, 25, "#ffb3c8")]:
                d.ellipse([(x - 2) * K, (y - 2) * K, (x + 2) * K, (y + 2) * K], fill=c, outline=INK, width=K // 3)
                d.ellipse([(x - 1) * K // 1, (y - 1) * K, (x + 1) * K, (y + 1) * K], fill="#ffd98a")
    elif name == "path":
        d.rectangle(full, fill="#f3e4b8")
        for _ in range(7):
            x, y = random.randint(3, S - 5) * K, random.randint(3, S - 5) * K
            d.ellipse([x, y, x + 3 * K, y + 2 * K], fill="#e3cf9b")
    elif name == "sand":
        d.rectangle(full, fill="#f6e2a8")
        for _ in range(9):
            x, y = random.randint(2, S - 3) * K, random.randint(2, S - 3) * K
            d.ellipse([x, y, x + K, y + K], fill="#e7cb8b")
    elif name in ("soil", "sprouts"):
        d.rectangle(full, fill="#c39a74")
        for y in (8, 18, 28):
            d.rounded_rectangle([3 * K, (y - 3) * K, (S - 3) * K, (y + 1) * K], K, fill="#a97c58")
        if name == "sprouts":
            for x in (8, 16, 24):
                for y in (6, 16, 26):
                    d.ellipse([(x - 3) * K, (y - 2) * K, (x + 1) * K, (y + 1) * K], fill="#8fcf72", outline=INK, width=K // 3)
                    d.ellipse([(x - 1) * K, (y - 4) * K, (x + 3) * K, (y - 1) * K], fill="#a8df86", outline=INK, width=K // 3)
    elif name == "plaza":
        d.rectangle(full, fill="#ece3ea")
        for x in (0, 16):
            for y in (0, 16):
                d.rounded_rectangle([(x + 1) * K, (y + 1) * K, (x + 15) * K, (y + 15) * K], 2 * K, outline="#cdbfc9", width=K // 2)
    elif name in ("floor", "floor_alt"):
        d.rectangle(full, fill="#f7eedc" if name == "floor" else "#f7dfe3")
        d.rectangle(full, outline="#e4d6bd" if name == "floor" else "#e8c3cc", width=K // 2)
        d.ellipse([13 * K, 13 * K, 19 * K, 19 * K], outline="#e4d6bd" if name == "floor" else "#e8c3cc", width=K // 2)
    elif name == "rug":
        d.rectangle(full, fill="#f4a9bd")
        d.rectangle([0, 0, 3 * K, S * K], fill="#ffd9a0")
        d.rectangle([(S - 3) * K, 0, S * K, S * K], fill="#ffd9a0")
        for y in (6, 16, 26):
            d.polygon([(16 * K, (y - 3) * K), (19 * K, y * K), (16 * K, (y + 3) * K), (13 * K, y * K)], fill="#fff2f6")
    elif name in ("water", "foam"):
        d.rectangle(full, fill="#9fd6ea" if name == "water" else "#bfe7f2")
        for x, y in [(6, 9), (20, 22), (18, 6)]:
            d.arc([x * K, y * K, (x + 8) * K, (y + 5) * K], 200, 340, fill="#e9f8fc", width=K)
        if name == "foam":
            for x in range(0, S, 8):
                d.ellipse([x * K, (S - 5) * K, (x + 8) * K, (S + 3) * K], fill="#ffffff")
    elif name == "wall":
        d.rectangle(full, fill="#dccfba")
        for y in range(0, S, 8):
            d.line([0, y * K, S * K, y * K], fill="#b9a98f", width=K // 2)
            off = 0 if (y // 8) % 2 == 0 else 8
            for x in range(off, S, 16):
                d.line([x * K, y * K, x * K, (y + 8) * K], fill="#b9a98f", width=K // 2)
    elif name == "wall_cap":
        d.rectangle(full, fill="#efe6d5")
        d.rectangle([0, 0, S * K, 6 * K], fill="#f9f3e6")
        d.line([0, 6 * K, S * K, 6 * K], fill="#b9a98f", width=K)
        d.rectangle([0, (S - 2) * K, S * K, S * K], fill="#d3c5ad")
    elif name == "hedge":
        d.rectangle(full, fill="#b9dc8c")
        for x, y in [(8, 10), (20, 9), (14, 20), (24, 22), (7, 24)]:
            d.ellipse([(x - 8) * K, (y - 7) * K, (x + 8) * K, (y + 7) * K], fill="#86bf6c", outline="#5f9a52", width=K // 2)
    elif name == "rock":
        d.rectangle(full, fill="#b9dc8c")
        d.rounded_rectangle([3 * K, 8 * K, (S - 3) * K, (S - 3) * K], 6 * K, fill="#cfc8d6", outline=INK, width=K // 2)
        d.ellipse([9 * K, 11 * K, 17 * K, 16 * K], fill="#e6e1ec")
    return im.resize((S, S), Image.LANCZOS)


atlas = Image.new("RGBA", (S * 17, S * 2))
for i, n in enumerate(WALK):
    c = draw(n)
    atlas.paste(c, (i * S, 0))
    atlas.paste(c, (i * S, S))
for i, n in enumerate(SOLID):
    atlas.paste(draw(n), ((len(WALK) + i) * S, S))
atlas.save(OUT)
print(OUT, atlas.size)
