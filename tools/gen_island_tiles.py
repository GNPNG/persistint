"""Draw the island tile atlas (32 px map cells, stored at 128 px): village ground, coast, and the temple interior.

Usage: python3 -I tools/gen_island_tiles.py
Inputs: none (palette hexes from prompts/STYLE.md 4.3-4.4; every tile seeds its RNG with the
crc32 of its name, so the output is the same on every run).
Outputs:
  project/assets/tiles/island_tiles.png   the atlas
  project/assets/tiles/island_tiles.json  {name: [col, row]} read by tools/build_island_maps.gd

Atlas layout (cell = 32x32 world px = 128x128 atlas px; index "cell" and "cell_px"), COLS = 32
cells wide (4096 px), filled in this order, a new row where noted:
  walkable ground, one cell per name in WALK ("tiles"[name])            -> new row
  the same cells again as blocked ground, props stand on them ("blocked"[name]), then the
  solid-only tiles in SOLID ("tiles"[name]); the builder gives both a full collision square
                                                                          -> new row
  animation strips: each ANIM tile has ANIM_FRAMES cells in one row, frame 0 first; the
  builder registers them as TileSet tile animations (solid, like the blocked cells)
  edge sets: 16 dual-grid overlay cells per set, never split across rows ("edges"[set] is
  mask 0's cell, mask m is m cells to its right), column offset = corner mask
         (bit 1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right set where that corner's
         cell is "inside": shallows or land for "shallows", land for "shore", grass for
         "grass_edge", path for "path_edge", paving for "paving_edge"). An overlay TileMapLayer
         sits half a cell up-left of the ground, so each overlay cell's corners are the
         centres of four ground cells; it rounds the reef line, the coast (sand rim, wet line,
         foam), the grass borders (soft bulge with a clover-green edge), the footpaths where they
         cross sand (trodden rim) and the paved terraces (curb band). Mask 0 and 15 are empty.
All cell positions are written to the index ([col, row]); nothing else hard-codes them.
Multi-cell pieces (rug, dais, doorway, stairs) are drawn whole at supersample and sliced into
cells named <piece>_<col>_<row>; their cells only line up when placed together.

The canon sheets carry no tiles, so these are drawn in the canon sticker look: flat pastel
fills, one light highlight edge, soft warm-brown outline #8a5a5a, candy shapes (hearts,
four-point sparkles). Drawn at 16x (K) and downscaled with LANCZOS to the 4x atlas (O); the
map builder scales the tile layers by 0.25, so every size in the drawing code is world px.
"""
import json
import random
import zlib
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "project/assets/tiles/island_tiles.png"
INDEX = ROOT / "project/assets/tiles/island_tiles.json"
S = 32          # cell size in world pixels (the map grid)
O = 4           # file pixels per world pixel: the atlas is drawn at 4x the on-map size
C = S * O       # cell size in atlas pixels (128)
K = 16          # drawing pixels per world pixel (supersample 4x over the atlas, LANCZOS down)
INK = "#8a5a5a"
OUTLINE = K // 2 * 3 // 2
ANIM_FRAMES = 4

# Multi-cell pieces: name -> (cols, rows); walkable unless listed in SOLID_PIECES.
PIECES = {
    "pool": (2, 2),       # a garden pool with a white rim and a float ring (solid)
    "rug": (2, 2),        # runner body, repeats every 2 rows
    "rug_top": (2, 1),    # fringed end toward the dais
    "rug_bot": (2, 1),    # fringed end toward the door
    "dais": (4, 3),       # raised blush platform with two steps
    "door_s": (2, 1),     # opening in the south wall (temple exit)
    "stairs_w": (1, 2),   # steps down through the west wall (to the Ruins)
}


def piece_cells(name):
    w, h = PIECES[name]
    return [f"{name}_{x}_{y}" for y in range(h) for x in range(w)]


SOLID_PIECES = ["pool"]
WALK = ["grass_a", "grass_b", "grass_flower", "path", "sand", "soil", "sprouts", "plaza",
        "floor", "floor_b", "floor_alt", "floor_n", "floor_nb"]
for _p in PIECES:
    if _p not in SOLID_PIECES:
        WALK += piece_cells(_p)
SOLID = [c for _p in SOLID_PIECES for c in piece_cells(_p)] + ["wall", "wall_cap", "hedge", "rock", "stripe", "gold_cap",
         "wall_base", "wall_l", "wall_r", "wall_s", "wall_sl", "wall_sr"]
ANIM = ["water", "foam"]
EDGES = ["shallows", "shore", "grass_edge", "path_edge", "paving_edge"]


def canvas(w=1, h=1):
    im = Image.new("RGBA", (w * S * K, h * S * K))
    return im, ImageDraw.Draw(im)


def P(*v):
    """Cell units -> supersampled pixels."""
    return [c * K for c in v]


def mix(a, b, t):
    a = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


def blob(d, x, y, r, fill, ink=INK):
    d.ellipse(P(x - r, y - r, x + r, y + r), fill=fill, outline=ink, width=OUTLINE)


def flower(d, x, y, petal, r=2.4):
    for dx, dy in ((0, -r), (r, 0), (0, r), (-r, 0)):
        blob(d, x + dx, y + dy, r * 0.75, petal)
    blob(d, x, y, r * 0.7, "#ffe27a")


def clover(d, x, y, col, ink="#79b45f"):
    for dx, dy in ((-1.6, 0), (1.6, 0), (0, -1.6)):
        d.ellipse(P(x + dx - 1.7, y + dy - 1.7, x + dx + 1.7, y + dy + 1.7), fill=col, outline=ink, width=K // 2)


def sparkle(d, x, y, r, col="#ffffff", ink=None):
    pts = [(x, y - r), (x + r * .3, y - r * .3), (x + r, y), (x + r * .3, y + r * .3),
           (x, y + r), (x - r * .3, y + r * .3), (x - r, y), (x - r * .3, y - r * .3)]
    d.polygon([(px * K, py * K) for px, py in pts], fill=col, outline=ink)


def heart(d, x, y, r, col="#ff8fb1", ink=None):
    if ink:
        heart(d, x, y + 0.2, r + 0.8, ink)
    d.ellipse(P(x - r, y - r, x, y + r * .2), fill=col)
    d.ellipse(P(x, y - r, x + r, y + r * .2), fill=col)
    d.polygon([((x - r * .97) * K, (y - r * .2) * K), ((x + r * .97) * K, (y - r * .2) * K), (x * K, (y + r * 1.1) * K)], fill=col)


def hline(d, x0, x1, y, col, w=1.0):
    d.rectangle(P(x0, y, x1, y + w), fill=col)


def vline(d, x, y0, y1, col, w=1.0):
    d.rectangle(P(x, y0, x + w, y1), fill=col)


# ---------------- temple stone ----------------

CREAM, CREAM_HI, CREAM_LO, CREAM_VEIN = "#fff6e2", "#fffaee", "#f3e2c4", "#f8ecd8"
BLUSH, BLUSH_HI, BLUSH_LO, BLUSH_VEIN = "#ffe6ee", "#ffeff4", "#f6ccd9", "#fbdde6"
GROUT = "#efd9c4"
GOLD, GOLD_HI, GOLD_LO = "#ffe3a8", "#fff4c4", "#e0b24a"


def slab(d, x0, y0, w, h, base, hi, lo, vein, r):
    """One polished marble slab: flat fill, a darker lower-right bevel, a light upper-left bevel,
    one soft diagonal sheen (the canon's single highlight) and a faint wandering vein."""
    d.rectangle(P(x0, y0, x0 + w, y0 + h), fill=lo)
    d.rectangle(P(x0, y0, x0 + w - 0.9, y0 + h - 0.9), fill=hi)
    d.rectangle(P(x0 + 0.7, y0 + 0.7, x0 + w - 0.9, y0 + h - 0.9), fill=base)
    # Sheen: a soft diagonal band across the upper-left half.
    d.polygon([tuple(P(x0 + 3, y0 + 13)), tuple(P(x0 + 13, y0 + 3)), tuple(P(x0 + 17, y0 + 3)),
               tuple(P(x0 + 3, y0 + 17))], fill=hi)
    d.polygon([tuple(P(x0 + 3, y0 + 19.5)), tuple(P(x0 + 19.5, y0 + 3)), tuple(P(x0 + 20.6, y0 + 3)),
               tuple(P(x0 + 3, y0 + 20.6))], fill=hi)
    # A vein that wanders diagonally across the slab.
    px, py = x0 + 4 + r.random() * (w - 14), y0 + 3
    pts = []
    while py < y0 + h - 3 and px < x0 + w - 3:
        pts.append((px * K, py * K))
        px += r.uniform(1.0, 3.2)
        py += r.uniform(1.6, 3.4)
    if len(pts) > 2:
        d.line(pts, fill=vein, width=K // 3, joint="curve")


def temple_floor(d, r, blush=False, glint=False):
    """One 32 px marble slab of the temple's cream and blush checkerboard (STYLE.md 6.1).

    The map builder alternates "floor" (cream) and "floor_b" (blush) by cell parity, so the
    checker has one slab per cell. Every corner carries a quarter of a small gold diamond inlay,
    so where four slabs meet a whole diamond shows."""
    if blush:
        slab(d, 0, 0, S, S, BLUSH, BLUSH_HI, BLUSH_LO, BLUSH_VEIN, r)
    else:
        slab(d, 0, 0, S, S, CREAM, CREAM_HI, CREAM_LO, CREAM_VEIN, r)
    # Grout: half a world pixel on each side, so neighbouring tiles join into one joint.
    hline(d, 0, S, 0, GROUT, 0.5)
    hline(d, 0, S, S - 0.5, GROUT, 0.5)
    vline(d, 0, 0, S, GROUT, 0.5)
    vline(d, S - 0.5, 0, S, GROUT, 0.5)
    for cx in (0, S):
        for cy in (0, S):
            rr = 3.6
            d.polygon([((cx) * K, (cy - rr) * K), ((cx + rr) * K, cy * K), (cx * K, (cy + rr) * K),
                       ((cx - rr) * K, cy * K)], fill=GOLD_LO)
            rr = 2.7
            d.polygon([((cx) * K, (cy - rr) * K), ((cx + rr) * K, cy * K), (cx * K, (cy + rr) * K),
                       ((cx - rr) * K, cy * K)], fill=GOLD)
            d.polygon([((cx - 0.9) * K, (cy - 1.1) * K), ((cx) * K, (cy - 2.0) * K), ((cx + 0.6) * K, (cy - 1.4) * K)], fill=GOLD_HI)
    if glint:
        sparkle(d, 10, 9, 2.4, "#ffffff")


def wall_face(d, r):
    """North wall face: soft cream ashlar, 16x8 blocks, staggered, each with a light top edge."""
    d.rectangle(P(0, 0, S, S), fill="#e6d2b8")
    for row in range(4):
        y = row * 8
        off = 0 if row % 2 == 0 else -8
        for x in range(off, S, 16):
            tone = r.choice(["#f4e6d2", "#f1e2cd", "#f6eadb"])
            d.rounded_rectangle(P(x + 0.5, y + 0.5, x + 15.5, y + 7.5), K, fill=tone)
            hline(d, max(x + 1.5, 0), min(x + 14.5, S), y + 0.8, "#fbf4ea", 0.8)


def draw_wall(name, r):
    im, d = canvas()
    if name == "wall":
        wall_face(d, r)
    elif name == "wall_cap":
        # Top of the high wall: cap stone, a gold band, a pink scalloped frieze under it.
        wall_face(d, r)
        d.rectangle(P(0, 0, S, 14), fill="#fbf3e6")
        hline(d, 0, S, 0, "#fffaf2", 3)
        hline(d, 0, S, 13, "#d9c3a5", 1.2)
        hline(d, 0, S, 14.2, GOLD, 2.2)
        for x in range(0, S + 1, 8):
            d.pieslice(P(x - 4, 12.4, x + 4, 20.4), 0, 180, fill="#ffc9da", outline="#f4a9c0", width=K // 2)
        for x in range(4, S, 8):
            blob(d, x, 18.6, 0.6, "#fff6f9", "#fff6f9")
    elif name == "wall_base":
        # Foot of the wall face: blush wainscot panels under a gold rail, then a baseboard.
        wall_face(d, r)
        d.rectangle(P(0, 10, S, 28), fill="#ffd9e4")
        hline(d, 0, S, 9, GOLD_HI, 1.4)
        hline(d, 0, S, 10.4, GOLD_LO, 1)
        for x in (2, 18):
            d.rounded_rectangle(P(x, 13.5, x + 12, 25), 2 * K, fill="#ffe6ee", outline="#f2b8ca", width=K // 2)
            heart(d, x + 6, 18.5, 2.2, "#ffc2d4")
        d.rectangle(P(0, 28, S, S), fill="#e9cfb1")
        hline(d, 0, S, 28, "#c9a888", 0.8)
    else:
        # Wall tops seen from above: pale cap stones, a gold trim and a shade on the room side.
        cap, joint, shade = "#f8efe0", "#ecdfc8", "#ecd9bf"
        d.rectangle(P(0, 0, S, S), fill=cap)
        if name in ("wall_l", "wall_r"):
            for y in range(0, S, 16):
                hline(d, 0, S, y, joint, 0.8)
        else:
            for x in range(0, S, 16):
                vline(d, x, 0, S, joint, 0.8)
        if name == "wall_l":
            d.rectangle(P(27, 0, S, S), fill=shade)
            vline(d, 24.5, 0, S, GOLD, 2)
            vline(d, 26.5, 0, S, "#d9c3a5", 0.8)
        elif name == "wall_r":
            d.rectangle(P(0, 0, 5, S), fill=shade)
            vline(d, 5.5, 0, S, GOLD, 2)
            vline(d, 4.7, 0, S, "#d9c3a5", 0.8)
        elif name == "wall_s":
            d.rectangle(P(0, 0, S, 5), fill=shade)
            hline(d, 0, S, 5.5, GOLD, 2)
            hline(d, 0, S, 4.7, "#d9c3a5", 0.8)
        elif name == "wall_sl":
            d.rectangle(P(27, 0, S, 5), fill=shade)
            vline(d, 24.5, 0, 7.5, GOLD, 2)
            hline(d, 24.5, S, 5.5, GOLD, 2)
        elif name == "wall_sr":
            d.rectangle(P(0, 0, 5, 5), fill=shade)
            vline(d, 5.5, 0, 7.5, GOLD, 2)
            hline(d, 0, 7.5, 5.5, GOLD, 2)
    return im


# ---------------- pieces ----------------

RUG, RUG_LO, RUG_HI = "#ffb3c8", "#f59ab5", "#ffd0dd"


def rug_body(d, h, top=False, bot=False):
    """Runner two cells wide: gold borders on the outer edges only, fringe at the ends."""
    w = 2 * S
    y0 = 6 if top else 0
    y1 = h - 6 if bot else h
    d.rectangle(P(3, y0, w - 3, y1), fill=RUG)
    for x in (3, w - 6):
        d.rectangle(P(x, y0, x + 3, y1), fill=GOLD)
    vline(d, 2.4, y0, y1, GOLD_LO, 0.8)
    vline(d, w - 3.2, y0, y1, GOLD_LO, 0.8)
    vline(d, 6, y0, y1, RUG_LO, 0.8)
    vline(d, w - 6.8, y0, y1, RUG_LO, 0.8)
    if top or bot:
        yb = y0 if top else y1 - 3
        d.rectangle(P(2.4, yb, w - 2.4, yb + 3), fill=GOLD)
        hline(d, 6, w - 6, yb + 3 if top else yb - 0.8, RUG_LO, 0.8)
        fy = y0 - 5 if top else y1
        for x in range(5, w - 5, 3):  # fringe tassels
            d.rounded_rectangle(P(x, fy, x + 1.6, fy + 5), K // 2, fill="#fff1d6", outline=GOLD_LO, width=K // 3)
    return y0, y1


def draw_piece(name, r):
    cw, ch = PIECES[name]
    im, d = canvas(cw, ch)
    W, H = cw * S, ch * S
    if name == "pool":
        d.rectangle(P(0, 0, W, H), fill="#fff0cf")  # set into the sandy path
        d.rounded_rectangle(P(1, 1, W - 1, H - 1), 9 * K, fill="#fbf3f7", outline=INK, width=OUTLINE)
        d.rounded_rectangle(P(6, 6, W - 6, H - 6), 6 * K, fill="#8fd0ee", outline="#e9d3df", width=K)
        d.rounded_rectangle(P(8, 8, W - 8, H - 8), 5 * K, fill="#a9ddf2")
        for x, y in ((14, 16), (34, 40), (40, 18)):
            d.arc(P(x, y, x + 9, y + 5), 200, 340, fill="#ffffff", width=K)
        d.ellipse(P(3.5, 3, 12, 6), fill="#ffffff")
        # Float ring.
        d.ellipse(P(30, 26, 48, 44), fill="#ff9fc0", outline=INK, width=OUTLINE)
        d.ellipse(P(35, 31, 43, 39), fill="#a9ddf2", outline=INK, width=K)
        for a0 in (20, 110, 200, 290):
            d.arc(P(31, 27, 47, 43), a0, a0 + 35, fill="#ffffff", width=int(2.2 * K))
    elif name == "rug":
        floor_under(im, cw, ch, PIECE_PARITY[name])
        d = ImageDraw.Draw(im)
        rug_body(d, H)
        for y in (16, 48):
            heart(d, 32, y, 5.0, "#fff4f8", RUG_LO)
        for y in (0, 32, 64):
            for x in (12, 52):
                blob(d, x, y, 1.2, RUG_HI, RUG_HI)
    elif name in ("rug_top", "rug_bot"):
        # The ends sit on the temple floor (or paving); the floor shows through the fringe.
        floor_under(im, cw, ch, PIECE_PARITY[name])
        d = ImageDraw.Draw(im)
        y0, y1 = rug_body(d, H, top=name == "rug_top", bot=name == "rug_bot")
        sparkle(d, 32, (y0 + y1) / 2, 4.2, "#fff4f8")
        for x in (12, 52):
            blob(d, x, (y0 + y1) / 2, 1.2, RUG_HI, RUG_HI)
    elif name == "dais":
        floor_under(im, cw, ch, PIECE_PARITY[name])
        d = ImageDraw.Draw(im)
        # Raised blush platform (rows 0-1) with a gold lip, two cream steps in front (row 2).
        d.rounded_rectangle(P(1, 1, W - 1, 62), 3 * K, fill="#ffd3e0", outline=INK, width=OUTLINE)
        d.rounded_rectangle(P(4, 4, W - 4, 51), 2 * K, fill="#ffe3ec", outline="#f2b8ca", width=K // 2)
        d.ellipse(P(W / 2 - 14, 12, W / 2 + 14, 44), outline=GOLD_LO, width=K * 2)
        d.ellipse(P(W / 2 - 12.5, 13.5, W / 2 + 12.5, 42.5), outline=GOLD, width=K)
        heart(d, W / 2, 27, 5.5, "#ffb3c8", RUG_LO)
        for sx in (14, W - 14):
            sparkle(d, sx, 16, 3.0, "#fff3a8", GOLD_LO)
            sparkle(d, sx, 40, 2.0, "#ffffff")
        hline(d, 2, W - 2, 52, GOLD, 2.5)
        hline(d, 2, W - 2, 54.5, GOLD_LO, 0.8)
        d.rectangle(P(2, 55.3, W - 2, 61), fill="#f7c0d1")
        d.rounded_rectangle(P(4, 61, W - 4, 79), 2 * K, fill="#fbefe0", outline=INK, width=OUTLINE)
        hline(d, 6, W - 6, 62.5, "#fffaf2", 1.2)
        d.rounded_rectangle(P(8, 77, W - 8, H - 2), 2 * K, fill="#fff6e8", outline=INK, width=OUTLINE)
        hline(d, 10, W - 10, 78.5, "#fffdf8", 1.2)
    elif name == "door_s":
        # Gap in the south wall: floor runs through to a gold threshold, wall ends either side.
        floor_under(im, cw, ch, PIECE_PARITY[name])
        d = ImageDraw.Draw(im)
        d.rectangle(P(0, 22, W, H), fill=GOLD)
        hline(d, 0, W, 22, GOLD_LO, 1)
        hline(d, 0, W, 23.5, GOLD_HI, 1.2)
        for x in range(8, W - 4, 12):
            heart(d, x, 27.5, 1.6, "#ffc2d4")
        for x0, x1 in ((0, 3), (W - 3, W)):
            d.rectangle(P(x0, 0, x1, H), fill="#f8efe0")
        vline(d, 3, 0, H, GOLD, 1.5)
        vline(d, W - 4.5, 0, H, GOLD, 1.5)
    elif name == "stairs_w":
        # Steps going down westward through the wall: lilac stone, darker with depth.
        d.rectangle(P(0, 0, W, H), fill="#f8efe0")
        tones = ["#9d90b6", "#aea2c8", "#c0b6d6", "#d3cbe4", "#e6e0f1"]
        x = 0.0
        for i, t in enumerate(tones):
            w = 5.0 if i < 4 else 12.0
            d.rectangle(P(x, 7, x + w, H - 7), fill=t)
            vline(d, x + w - 1, 7, H - 7, mix(t, "#ffffff", 0.45), 1)
            x += w
        hline(d, 0, W, 5, GOLD, 2)
        hline(d, 0, W, H - 7, GOLD, 2)
        hline(d, 0, W, 7, "#7f7398", 0.8)
    return im


# Checker parity of each piece's top-left cell where the temple map places it (the builder
# asserts these): 1 = that cell is a blush slab. The rug body repeats every two rows.
PIECE_PARITY = {"rug": 0, "rug_top": 1, "rug_bot": 0, "dais": 1, "door_s": 1, "stairs_w": 1, "pool": 0}


def floor_under(im, cw, ch, parity=0):
    """Paint temple floor under a piece, seeded per piece cell so it matches every run."""
    for y in range(ch):
        for x in range(cw):
            sub, sd = canvas()
            temple_floor(sd, random.Random(x * 31 + y), blush=(x + y + parity) % 2 == 1)
            im.paste(sub, (x * S * K, y * S * K))


def draw(name):
    im, d = canvas()
    full = P(0, 0, S, S)
    r = random.Random(zlib.crc32(name.encode()))
    if name.startswith("grass"):
        d.rectangle(full, fill="#c5ecaa")
        for _ in range(4):
            clover(d, r.randint(5, S - 6), r.randint(6, S - 5), "#a6dc8a")
        if name == "grass_b":
            for _ in range(5):
                x, y = r.randint(3, S - 4), r.randint(3, S - 4)
                d.ellipse(P(x, y, x + 3, y + 1.5), fill="#d6f5bf")
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
            d.rounded_rectangle(P(3, y - 3, S - 3, y + 1.5), 2 * K, fill="#c99468", outline="#a8714a", width=K // 2)
        if name == "sprouts":
            for x in (8, 16, 24):
                for y in (6, 16, 26):
                    d.ellipse(P(x - 3, y - 1.5, x + 0.5, y + 1.5), fill="#9be07c", outline="#5fa84a", width=K // 2)
                    d.ellipse(P(x - .5, y - 3.5, x + 3, y - .5), fill="#b4ee95", outline="#5fa84a", width=K // 2)
    elif name == "plaza":
        # Outdoor paving: rounded blush cobbles of a few sizes in soft joints. The stones are
        # laid on a 3x3 jittered lattice that wraps at the tile edge, so the paving tiles.
        d.rectangle(full, fill="#ead6e1")
        tones = ["#f7eaf1", "#f4e4ee", "#f9eff5", "#f2e1eb"]
        for gy in range(3):
            for gx in range(3):
                cx = gx * S / 3 + S / 6 + r.uniform(-1.6, 1.6)
                cy = gy * S / 3 + S / 6 + r.uniform(-1.6, 1.6)
                rx, ry = r.uniform(3.6, 5.0), r.uniform(3.4, 4.8)
                col = r.choice(tones)
                for ox in (-S, 0, S):
                    for oy in (-S, 0, S):
                        x, y = cx + ox, cy + oy
                        d.rounded_rectangle(P(x - rx, y - ry, x + rx, y + ry), 2.4 * K, fill=col)
                        d.line(P(x - rx + 1.8, y - ry + 0.9, x + rx - 1.8, y - ry + 0.9), fill="#fdf7fa", width=K // 2)
    elif name in ("floor", "floor_b", "floor_alt", "floor_n", "floor_nb"):
        temple_floor(d, r, blush=name in ("floor_b", "floor_nb"), glint=name == "floor_alt")
        if name in ("floor_n", "floor_nb"):  # soft shadow under the north wall
            sh = Image.new("RGBA", im.size)
            sd = ImageDraw.Draw(sh)
            for i in range(8):
                sd.rectangle(P(0, i, S, i + 1), fill=(138, 90, 90, int(60 * (1 - i / 8))))
            im = Image.alpha_composite(im, sh)
    elif name.startswith("wall"):
        im = draw_wall(name, r)
    elif name == "hedge":
        d.rectangle(full, fill="#c5ecaa")
        for x, y in [(9, 11), (22, 10), (15, 21), (25, 24), (7, 25)]:
            blob(d, x, y, 7, "#95d37c", "#5fa84a")
        sparkle(d, 16, 10, 2.2, "#ffffff")
    elif name == "stripe":
        d.rectangle(full, fill="#ffffff")
        for x in range(0, S, 8):
            d.rectangle(P(x, 0, x + 4, S), fill="#a8d4f5")
        d.line(P(0, S - 1, S, S - 1), fill="#7fb3dc", width=K)
    elif name == "gold_cap":
        d.rectangle(full, fill="#ffe59a")
        d.rectangle(P(0, 0, S, 5), fill="#fff4c4")
        d.line(P(0, 5, S, 5), fill="#e0b24a", width=K)
        for x in range(4, S, 8):
            d.line(P(x, 6, x, S), fill="#efc86a", width=K // 2)
    elif name == "rock":
        d.rectangle(full, fill="#c5ecaa")
        d.rounded_rectangle(P(3, 8, S - 3, S - 3), 8 * K, fill="#e1dcef", outline=INK, width=OUTLINE)
        d.ellipse(P(9, 11, 17, 16), fill="#f5f2fb")
        blob(d, 12, 20, .7, INK, INK)
        blob(d, 20, 20, .7, INK, INK)
    return im.resize((C, C), Image.LANCZOS)


def water(name, frame):
    """Sea ("water") or shallows ("foam") cell, frame 0-3: wave arcs drift right 2 px a frame
    (wrapping, so the cells still tile) and the sparkle swells and fades."""
    im, d = canvas()
    deep = name == "water"
    d.rectangle(P(0, 0, S, S), fill="#a9ddf2" if deep else "#c6eefb")
    r = random.Random(zlib.crc32(name.encode()))
    arcs = [(r.uniform(0, S), r.uniform(3, S - 6)) for _ in range(3)]
    for x, y in arcs:
        x = (x + frame * 2) % S
        for ox in (-S, 0, S):
            d.arc(P(x + ox, y, x + ox + 8, y + 5), 200, 340, fill="#ffffff" if deep else "#f2fbff", width=K)
    sx, sy = r.uniform(6, S - 6), r.uniform(6, S - 6)
    rad = [1.2, 2.2, 1.6, 0.0][frame]
    if rad:
        sparkle(d, sx, sy, rad, "#ffffff")
    return im.resize((C, C), Image.LANCZOS)


def edge(name, mask):
    """Dual-grid overlay cell for corner mask (see module docstring).

    f is the bilinear blend of the corner flags over the cell, plus a wobble that is zero on
    the cell's sides so neighbouring cells meet. Inside = f > 0.25: that region always covers
    the inside corners' quarters, so the overlay only ever paints over "outside" cells.
    Computed per drawing pixel with numpy, then downscaled like every other tile."""
    import numpy as np
    W = S * K
    c = [(mask >> i) & 1 for i in range(4)]  # tl, tr, bl, br
    if mask in (0, 15):
        return Image.new("RGBA", (C, C))
    rng = random.Random(mask * 7 + len(name))
    ph = rng.uniform(0, 6.28)

    def f(u, v):
        b = (c[0] * (1 - u) * (1 - v) + c[1] * u * (1 - v) + c[2] * (1 - u) * v + c[3] * u * v)
        return b + 0.06 * np.sin(np.pi * u) * np.sin(np.pi * v) * np.sin(ph + 5 * (u + v))

    T = 0.25
    v, u = (np.mgrid[0:W, 0:W] + 0.5) / W
    val = f(u, v)
    e = 1.0 / W
    g = np.hypot(f(u + e, v) - f(u - e, v), f(u, v + e) - f(u, v - e)) / (2 * e)
    g[g == 0] = 1.0
    dist = (val - T) / g * S  # signed distance to the edge in world pixels, + inside
    qi = (u >= 0.5).astype(int) + 2 * (v >= 0.5).astype(int)
    q = np.array(c)[qi].astype(bool)  # this quarter's own cell is inside
    out = np.zeros((W, W, 4), np.uint8)

    def paint(sel, col):
        out[sel & (out[..., 3] == 0)] = col

    if name == "shallows":
        paint((dist >= 0) & (dist < 0.9), (224, 246, 255, 255))     # light line along the reef
        paint((dist >= 0.9) & ~q, (198, 238, 251, 255))             # shallow water over deep
    elif name == "shore":
        paint((dist >= 0) & (dist < 1.3), (233, 196, 140, 255))     # wet line
        paint((dist >= 1.3) & ~q, (255, 233, 184, 255))             # beach sand over water
        paint((dist >= -2.6) & (dist < 0), (255, 255, 255, 235))    # foam
        paint((dist >= -4.2) & (dist < -2.6), (226, 247, 255, 200))  # wash
    elif name == "path_edge":
        paint((dist >= 0) & (dist < 0.8), (236, 210, 165, 255))     # trodden rim
        paint((dist >= 0.8) & ~q, (255, 240, 207, 255))             # path over the sand
    elif name == "paving_edge":
        paint((dist >= 0) & (dist < 1.0), (214, 184, 200, 255))     # curb shadow
        paint((dist >= 1.0) & (dist < 2.4), (249, 238, 244, 255))   # curb stone
        paint((dist >= 2.4) & ~q, (234, 214, 225, 255))             # joint band
    else:
        paint((dist >= 0) & (dist < 1.0), (121, 180, 95, 255))      # clover-green edge
        paint((dist >= 1.0) & (dist < 2.2), (166, 220, 138, 255))
        paint((dist >= 2.2) & ~q, (197, 236, 170, 255))             # grass over the neighbour
    return Image.fromarray(out, "RGBA").resize((C, C), Image.LANCZOS)


def cells():
    """name -> 32x32 image, for every single tile and every piece cell."""
    out = {}
    for name, (cw, ch) in PIECES.items():
        big = draw_piece(name, random.Random(zlib.crc32(name.encode()))).resize((cw * C, ch * C), Image.LANCZOS)
        for y in range(ch):
            for x in range(cw):
                out[f"{name}_{x}_{y}"] = big.crop((x * C, y * C, (x + 1) * C, (y + 1) * C))
    for n in WALK + SOLID:
        if n not in out:
            out[n] = draw(n)
    return out


COLS = 32  # atlas width in cells: 4096 px, inside WebGL's common 4096 texture limit


def main():
    tiles = cells()
    slots = []  # (name, image) in atlas order; a new row starts where a strip must not wrap

    def row_break():
        while len(slots) % COLS:
            slots.append((None, None))

    index, blocked = {}, {}
    for n in WALK:
        index[n] = len(slots)
        slots.append((n, tiles[n]))
    row_break()
    for n in WALK:
        blocked[n] = len(slots)
        slots.append((n, tiles[n]))
    for n in SOLID:
        index[n] = len(slots)
        slots.append((n, tiles[n]))
    row_break()
    for n in ANIM:
        index[n] = len(slots)
        for f in range(ANIM_FRAMES):
            slots.append((n, water(n, f)))
        row_break()
    edges = {}
    for n in EDGES:
        if len(slots) % COLS + 16 > COLS:
            row_break()
        edges[n] = len(slots)
        for m in range(16):
            slots.append((n, edge(n, m)))
    row_break()
    rows = len(slots) // COLS
    atlas = Image.new("RGBA", (C * COLS, C * rows))
    for i, (_n, im) in enumerate(slots):
        if im is not None:
            atlas.paste(im, ((i % COLS) * C, (i // COLS) * C))
    cell = lambda i: [i % COLS, i // COLS]
    atlas.save(OUT)
    INDEX.write_text(json.dumps({
        "cell": S, "cell_px": C, "walk": WALK, "solid": SOLID, "anim": ANIM,
        "anim_frames": ANIM_FRAMES,
        "tiles": {n: cell(i) for n, i in index.items()},
        "blocked": {n: cell(i) for n, i in blocked.items()},
        "edges": {n: cell(i) for n, i in edges.items()}}, indent=1) + "\n")
    print(OUT, atlas.size)


if __name__ == "__main__":
    main()
