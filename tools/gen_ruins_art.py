"""Draw the Ruins of Utopia and the bunker: floor and wall tiles for each room, the props the
rooms' data names by "kind" (data/ruins.json, rooms -> props), the Forbidden Knowledge pickup
icons, a soft glow and a contact shadow.

Usage: python3 -I tools/gen_ruins_art.py
Inputs: none (palette hexes below come from prompts/STYLE.md; every random draw is seeded).
Outputs, all under project/assets/ruins/:
  ruins_tiles.png + ruins_tileset.tres  32x32 tile atlas (layout in tiles()), one texel per
                                        world pixel, painted by scripts/ruins/ruins_decor.gd
  ruins_<kind>.png                      the props data/ruins.json names by "kind"; drawn at
                                        two texels per world pixel, shown at scale 0.5
  ruins_tank.png, ruins_tank_duck.png   animated sheets: 1 row x 4 frames of 88x172 (tank())
  icon_<id>.png                         Forbidden Knowledge pickups, 40x40 (data "icon")
  glow.png, shadow.png, vignette.png    pickup glow, contact shadow, 640x360 screen vignette
Each piece is drawn on a canvas SS times larger and downscaled (LANCZOS). Style: STYLE.md
4.1-4.5 - soft outline (plum #5a4a5e in the bunker, warm brown #8a5a5a on the ship), flat
pastel fills with one highlight, faces on the big machines, cat-in-a-lab-coat stickers on
bunker machines, blue-green gloom with pink/mint accents. The Seal of the O and the tide
chart are canon cuts (assets/canon/prop_seal_o.png, prop_scroll.png), not drawn here.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "project/assets/ruins"
PLUM, BROWN = "#5a4a5e", "#8a5a5a"  # outline colours (STYLE.md 4.1)
INK = PLUM
SS = 8  # supersample: canvas pixels per world pixel
D = 2  # output texels per world pixel for props
BLUSH = "#ff9fb8"
PINK, MINT, SKY, LILAC, BUTTER, CREAM = "#ffb3c8", "#a8e6c8", "#a8d8f0", "#c9b3f0", "#ffe08a", "#fdf6e3"
STEEL, STEEL_D, STEEL_L = "#9fb3c4", "#7d91a6", "#c8d8e4"
FLUID, FLUID_D = "#ff9ebf", "#f07aa0"
GLASS = (200, 236, 245, 110)


class Art:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (int(w * SS), int(h * SS)))
        self.d = ImageDraw.Draw(self.im)

    def p(self, *v):
        return [x * SS for x in v]

    def lw(self, w=0.75):
        return max(1, int(w * SS))

    def rect(self, x0, y0, x1, y1, fill, r=1.5, ink="INK", w=0.75):
        ink = INK if ink == "INK" else ink
        self.d.rounded_rectangle(self.p(x0, y0, x1, y1), r * SS, fill=fill, outline=ink, width=self.lw(w) if ink else 0)

    def ell(self, x0, y0, x1, y1, fill, ink="INK", w=0.75):
        ink = INK if ink == "INK" else ink
        self.d.ellipse(self.p(x0, y0, x1, y1), fill=fill, outline=ink, width=self.lw(w) if ink else 0)

    def circ(self, x, y, r, fill, ink="INK", w=0.75):
        self.ell(x - r, y - r, x + r, y + r, fill, ink, w)

    def line(self, pts, fill="INK", w=0.75):
        fill = INK if fill == "INK" else fill
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=self.lw(w), joint="curve")

    def poly(self, pts, fill, ink="INK", w=0.75):
        ink = INK if ink == "INK" else ink
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill, outline=ink, width=self.lw(w) if ink else 0)

    def arc(self, x0, y0, x1, y1, a0, a1, fill="INK", w=0.75):
        fill = INK if fill == "INK" else fill
        self.d.arc(self.p(x0, y0, x1, y1), a0, a1, fill=fill, width=self.lw(w))

    def face(self, x, y, s=1.0, sleepy=False):
        """Two dot eyes, pink blush, a tiny smile: the house style."""
        for dx in (-2.6, 2.6):
            if sleepy:
                self.arc(x + dx * s - 1 * s, y - 0.6 * s, x + dx * s + 1 * s, y + 0.8 * s, 20, 160, w=0.6 * s)
            else:
                self.circ(x + dx * s, y, 0.85 * s, INK, None)
                self.circ(x + dx * s - 0.3 * s, y - 0.35 * s, 0.28 * s, "#ffffff", None)
        self.arc(x - 1.1 * s, y - 0.2 * s, x + 1.1 * s, y + 1.9 * s, 20, 160, w=0.55 * s)
        for dx in (-4.3, 4.3):
            self.ell(x + dx * s - 1.2 * s, y + 0.9 * s, x + dx * s + 1.2 * s, y + 2.1 * s, BLUSH, None)

    def sparkle(self, x, y, r, fill="#fff3a8", ink="#e0b24a"):
        q = r * 0.32
        self.poly([(x, y - r), (x + q, y - q), (x + r, y), (x + q, y + q), (x, y + r), (x - q, y + q), (x - r, y), (x - q, y - q)], fill, ink, 0.4)

    def heart(self, x, y, r, fill="#ff8fb1", ink="INK"):
        self.circ(x - r * 0.5, y - r * 0.2, r * 0.55, fill, None)
        self.circ(x + r * 0.5, y - r * 0.2, r * 0.55, fill, None)
        self.poly([(x - r * 1.02, y), (x + r * 1.02, y), (x, y + r * 1.05)], fill, None)
        self.circ(x - r * 0.55, y - r * 0.35, r * 0.18, "#ffffff", None)

    def cat_sticker(self, x, y, s=1.0):
        """A small kawaii cat in a lab coat, on a white sticker."""
        self.rect(x - 4 * s, y - 4 * s, x + 4 * s, y + 4.4 * s, "#ffffff", 1.6 * s, "#c9b3c9", 0.4)
        self.poly([(x - 2.6 * s, y - 2.6 * s), (x - 1.6 * s, y - 3.8 * s), (x - 0.8 * s, y - 2.4 * s)], "#ffd9a0", INK, 0.35)
        self.poly([(x + 2.6 * s, y - 2.6 * s), (x + 1.6 * s, y - 3.8 * s), (x + 0.8 * s, y - 2.4 * s)], "#ffd9a0", INK, 0.35)
        self.ell(x - 2.8 * s, y - 3 * s, x + 2.8 * s, y + 1 * s, "#ffd9a0", INK, 0.35)
        self.rect(x - 2.4 * s, y + 0.6 * s, x + 2.4 * s, y + 3.8 * s, "#f6fbff", 0.8 * s, INK, 0.35)
        for dx in (-1, 1):
            self.circ(x + dx * s, y - 1.2 * s, 0.35 * s, INK, None)

    def save(self, name, glow=None):
        out = self.im.resize((int(self.w * D), int(self.h * D)), Image.LANCZOS)
        out.save(OUT / f"{name}.png")


# ---------------------------------------------------------------- tiles

T = 32  # tile size in texels and world pixels
FLOORS = ["deck", "grate", "plate", "concrete", "lab", "carpet"]
WALLS = {  # id: (panel, seam, rivet, accent stripe, cap)
    "hull": ("#5f6e86", "#4d5a6f", "#7c8aa1", "#e9a7b9", "#8494ad"),
    "service": ("#4d5868", "#3f4856", "#677384", "#ff9a9a", "#6a7586"),
    "core": ("#43465c", "#363849", "#5a5d78", "#8d6fa8", "#5d6080"),
    "bunker": ("#55636b", "#45525a", "#6e7d85", "#ffb3c8", "#73828a"),
    "lab": ("#5e7f86", "#4e6c72", "#7aa0a6", "#9fd9c0", "#7fa3a9"),
    "archive": ("#6b6274", "#585063", "#857c90", "#e0b24a", "#887e94"),
}
VOID = "#1b1f2b"


def floor_deck(a, r, alt):
    for i in range(4):
        y = i * 8
        a.d.rectangle(a.p(0, y, 32, y + 8), fill="#8e7f86" if i % 2 else "#968690")
        a.line([(0, y + 7.6), (32, y + 7.6)], "#6f6270", 0.6)
        off = 6 + (i * 11) % 20
        a.line([(off, y), (off, y + 7.6)], "#6f6270", 0.6)
        for x in (off - 2, off + 2):
            a.circ(x, y + 4, 0.45, "#6f6270", None)
    a.ell(20, 3, 25, 5, "#a89aa3", None)
    if alt:  # a dropped streamer
        a.line([(4, 20), (9, 18), (14, 21), (19, 19)], "#ffb3c8", 0.8)


def floor_grate(a, r, alt):
    a.d.rectangle(a.p(0, 0, 32, 32), fill="#55606f")
    for i in range(4):
        for j in range(4):
            a.rect(i * 8 + 1, j * 8 + 1, i * 8 + 7, j * 8 + 7, "#485261", 1, "#3c4552", 0.5)
            a.line([(i * 8 + 2, j * 8 + 2.2), (i * 8 + 6, j * 8 + 2.2)], "#66727f", 0.5)
    if alt:  # a puddle catching the light
        a.ell(9, 13, 23, 20, (168, 216, 240, 120), None)
        a.line([(12, 15), (16, 15)], "#d6f0fb", 0.5)


def floor_plate(a, r, alt):
    a.d.rectangle(a.p(0, 0, 32, 32), fill="#4b4e66")
    a.rect(0.5, 0.5, 31.5, 31.5, "#53566f", 2, "#3d3f55", 0.6)
    for x, y in ((3, 3), (29, 3), (3, 29), (29, 29)):
        a.circ(x, y, 0.8, "#6a6d88", "#3d3f55", 0.3)
    a.line([(8, 16), (24, 16)], "#5d6079", 0.8)
    if alt:  # scuffs where the faithful kneel
        a.arc(6, 18, 18, 26, 200, 300, "#5d6079", 0.6)
        a.arc(15, 6, 26, 13, 210, 320, "#5d6079", 0.5)


def floor_concrete(a, r, alt):
    a.d.rectangle(a.p(0, 0, 32, 32), fill="#5c6a70")
    a.line([(0, 0.3), (32, 0.3)], "#4c585e", 0.6)
    a.line([(0.3, 0), (0.3, 32)], "#4c585e", 0.6)
    for _ in range(5):
        x, y = r.uniform(3, 29), r.uniform(3, 29)
        a.circ(x, y, r.uniform(0.4, 0.9), "#667579", None)
    if alt:  # a hairline crack
        a.line([(6, 8), (11, 12), (10, 17), (16, 22), (20, 21)], "#48545a", 0.5)


def floor_lab(a, r, alt):
    for i in range(2):
        for j in range(2):
            a.d.rectangle(a.p(i * 16, j * 16, i * 16 + 16, j * 16 + 16), fill="#6f9a92" if (i + j) % 2 else "#7aa69c")
            a.line([(i * 16 + 2, j * 16 + 2), (i * 16 + 6, j * 16 + 2)], "#8bb8ad", 0.6)
    for k in (0.3, 16):
        a.line([(0, k), (32, k)], "#5f857e", 0.6)
        a.line([(k, 0), (k, 32)], "#5f857e", 0.6)
    if alt:  # a drain, and a spill of pink tank fluid
        a.circ(8, 24, 2.4, "#5f857e", "#4e6c72", 0.4)
        for dx in (-1, 0, 1):
            a.line([(8 + dx, 22.4), (8 + dx, 25.6)], "#4e6c72", 0.3)
        a.ell(18, 6, 27, 11, (255, 158, 191, 150), None)


def floor_carpet(a, r, alt):
    a.d.rectangle(a.p(0, 0, 32, 32), fill="#c9bba4")
    for x, y in ((8, 8), (24, 24)):
        a.poly([(x, y - 2.4), (x + 2.4, y), (x, y + 2.4), (x - 2.4, y)], "#d6c9b2", None)
    for x, y in ((24, 8), (8, 24)):
        a.circ(x, y, 0.8, "#bcae97", None)
    if alt:  # a worn patch where a chair stood for decades
        a.ell(10, 12, 22, 20, "#c2b39b", None)
        a.ell(12, 13.5, 20, 18.5, "#c9bba4", None)


def wall_tile(a, wid, part):
    base, seam, rivet, stripe, cap = WALLS[wid]
    a.d.rectangle(a.p(0, 0, 32, 32), fill=base)
    a.line([(0.3, 0), (0.3, 32)], seam, 0.7)
    a.line([(16, 0), (16, 32)], seam, 0.4)
    if part == "cap":  # the ceiling's edge: dark above, a pale trim rail below
        a.d.rectangle(a.p(0, 0, 32, 20), fill=VOID)
        a.d.rectangle(a.p(0, 20, 32, 26), fill=cap)
        a.line([(0, 20.4), (32, 20.4)], INK, 0.7)
        a.line([(0, 25.6), (32, 25.6)], seam, 0.7)
        a.line([(0, 22), (32, 22)], "#ffffff", 0.35)
        for x in (4, 12, 20, 28):
            a.circ(x, 23, 0.6, seam, None)
    elif part == "stripe":
        a.d.rectangle(a.p(0, 12, 32, 18), fill=stripe)
        a.line([(0, 12), (32, 12)], seam, 0.5)
        a.line([(0, 18), (32, 18)], seam, 0.5)
        a.line([(0, 13.2), (32, 13.2)], "#ffffff", 0.3)
        for x in (3, 13, 19, 29):
            a.circ(x, 4, 0.55, rivet, None)
            a.circ(x, 27, 0.55, rivet, None)
    elif part == "base":  # skirting board
        for x in (3, 13, 19, 29):
            a.circ(x, 5, 0.55, rivet, None)
        a.d.rectangle(a.p(0, 22, 32, 32), fill=seam)
        a.line([(0, 22), (32, 22)], cap, 0.7)
        a.line([(0, 31.6), (32, 31.6)], INK, 0.7)
    else:
        for y in (4, 28):
            for x in (3, 13, 19, 29):
                a.circ(x, y, 0.55, rivet, None)


def edge_shadow(a):
    """Floor-coloured nothing: a soft shadow strip the skirting casts on the first floor row."""
    for i in range(8):
        a.d.rectangle(a.p(0, i, 32, i + 1), fill=(14, 16, 26, int(110 * (1 - i / 8))))


def tiles():
    """ruins_tiles.png: a 7x6 atlas of 32x32 tiles.
    row 0: floors deck, grate, plate, concrete, lab, carpet; col 6 void
    row 1: the same floors with one detail (streamer, puddle, wax, crack, drain, card); col 6 lip
    row 2: wall caps   hull, service, core, bunker, lab, archive; col 6 floor edge shadow
    row 3: wall panels (same order); col 6 hazard stripes
    row 4: wall panels with the accent stripe
    row 5: wall skirting (bottom wall row)
    """
    sheet = Image.new("RGBA", (7 * T, 6 * T))

    def put(col, row, draw, seed):
        a = Art(T, T)
        draw(a, random.Random(seed))
        sheet.alpha_composite(a.im.resize((T, T), Image.LANCZOS), (col * T, row * T))

    for i, f in enumerate(FLOORS):
        fn = globals()["floor_" + f]
        put(i, 0, lambda a, r, fn=fn: fn(a, r, False), f)
        put(i, 1, lambda a, r, fn=fn: fn(a, r, True), f + "_alt")
    put(6, 0, lambda a, r: a.d.rectangle(a.p(0, 0, 32, 32), fill=VOID), "void")

    def lip(a, r):
        a.d.rectangle(a.p(0, 0, 32, 32), fill=VOID)
        a.d.rectangle(a.p(0, 0, 32, 3), fill="#3a3f52")
        a.line([(0, 3), (32, 3)], INK, 0.6)
    put(6, 1, lip, "lip")
    put(6, 2, lambda a, r: edge_shadow(a), "shadow")

    def hazard(a, r):
        for i in range(-2, 6):
            x = i * 8
            a.poly([(x, 32), (x + 8, 0), (x + 12, 0), (x + 4, 32)], PINK if i % 2 else MINT, None)
    put(6, 3, hazard, "hazard")
    for i, w in enumerate(WALLS):
        for row, part in ((2, "cap"), (3, "panel"), (4, "stripe"), (5, "base")):
            put(i, row, lambda a, r, w=w, part=part: wall_tile(a, w, part), w + part)
    sheet.save(OUT / "ruins_tiles.png")
    tileset()


def tileset():
    """ruins_tileset.tres: one TileSetAtlasSource over ruins_tiles.png, every cell a tile."""
    cells = "\n".join(f"{c}:{r}/0 = 0" for r in range(6) for c in range(7))
    (OUT / "ruins_tileset.tres").write_text(
        '[gd_resource type="TileSet" load_steps=3 format=3]\n\n'
        '[ext_resource type="Texture2D" path="res://assets/ruins/ruins_tiles.png" id="1_tiles"]\n\n'
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_ruins"]\n'
        'texture = ExtResource("1_tiles")\n'
        f"texture_region_size = Vector2i({T}, {T})\n"
        f"{cells}\n\n"
        "[resource]\n"
        f"tile_size = Vector2i({T}, {T})\n"
        'sources/0 = SubResource("TileSetAtlasSource_ruins")\n')


# ---------------------------------------------------------------- shared bits

def glow():
    n = 64
    im = Image.new("RGBA", (n, n))
    px = im.load()
    for y in range(n):
        for x in range(n):
            dist = math.hypot(x - n / 2 + 0.5, y - n / 2 + 0.5) / (n / 2)
            a = max(0.0, 1.0 - dist) ** 2
            px[x, y] = (255, 255, 255, int(255 * a))
    im.save(OUT / "glow.png")


def shadow():
    a = Art(24, 8)
    a.ell(0.5, 0.5, 23.5, 7.5, (40, 30, 50, 110), None)
    a.im = a.im.filter(ImageFilter.GaussianBlur(SS * 0.8))
    a.save("shadow")


def vignette():
    w, h = 640, 360
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
            dist = math.sqrt(dx * dx * 0.8 + dy * dy)
            px[x, y] = (12, 18, 30, int(255 * min(1.0, max(0.0, dist - 0.55) * 1.3) * 0.75))
    im.save(OUT / "vignette.png")


# ---------------------------------------------------------------- clone hall

TANK_FRAMES = 4


def tank_frame(f, duck):
    a = Art(44, 86)
    a.ell(4, 76, 40, 85, (30, 30, 45, 90), None)
    a.rect(4, 70, 40, 82, STEEL, 3)  # base
    a.face(22, 75.5, 0.9)
    a.rect(7, 12, 37, 72, GLASS, 10, "INK", 0.9)  # glass
    a.d.rounded_rectangle(a.p(8, 24, 36, 71), 9 * SS, fill=FLUID)
    a.d.rectangle(a.p(8.5, 24, 35.5, 27), fill="#ffc4d6")
    for x, y, r in ((14, 60, 1.6), (26, 50, 1.2), (19, 40, 1.0), (30, 34, 1.4), (15, 30, 0.8), (24, 64, 1.1)):
        y = 28 + (y - 28 - f * 11) % 40  # bubbles rise a quarter of the way per frame, wrapping
        a.circ(x + (0.8 if f % 2 else 0), y, r, "#fff0f6", "#ffffff", 0.3)
    a.rect(10, 28, 12.6, 66, "#ffc8da", 1.2, None)  # glass sheen
    a.rect(10, 15, 12.6, 23, "#eef9fc", 1.2, None)
    a.rect(3, 4, 41, 15, STEEL_L, 3)  # cap
    a.rect(16, 0.5, 28, 5, STEEL_D, 1.5)
    a.line([(8, 9.5), (36, 9.5)], STEEL_D, 0.6)
    for x in (10, 34):  # status lights, the pink one blinks
        lit = x == 10 or f < 2
        a.circ(x, 9.5, 1.1, ("#9fe0b8" if x == 10 else "#ff9ebf") if lit else "#b9a3ad", "INK", 0.4)
    if duck:
        dy = (0, -0.6, 0, 0.6)[f]
        a.ell(16, 21.5 + dy, 28, 27.5 + dy, "#ffe066")
        a.circ(26, 20 + dy, 3.2, "#ffe066")
        a.poly([(28.5, 20 + dy), (31.5, 20.8 + dy), (28.5, 21.8 + dy)], "#ffa040", "INK", 0.4)
        a.circ(26.4, 19.3 + dy, 0.55, INK, None)
    return a.im.resize((44 * D, 86 * D), Image.LANCZOS)


def tank(name, duck=False):
    """A clone tank, animated: one row of TANK_FRAMES frames, each 88x172 texels (44x86 world
    px at scale 0.5), bubbles rising and the pink light blinking; 6 fps loop."""
    sheet = Image.new("RGBA", (44 * D * TANK_FRAMES, 86 * D))
    for f in range(TANK_FRAMES):
        sheet.alpha_composite(tank_frame(f, duck), (f * 44 * D, 0))
    sheet.save(OUT / f"{name}.png")


def incubator():
    a = Art(66, 52)
    a.ell(3, 45, 63, 51, (30, 30, 45, 80), None)
    a.rect(3, 6, 63, 48, "#eef4f4", 4)
    a.rect(3, 6, 63, 13, "#d8e6e8", 4)
    for i, x in enumerate((8, 36)):
        a.rect(x, 17, x + 22, 40, "#ffcf9a", 3)
        a.rect(x + 2, 19, x + 20, 38, "#ffe2b8", 2, None)
        a.circ(x + 11, 29, 5, "#fff3d8", "#e8b47c", 0.5)
        a.circ(x + 9.5, 27.5, 1.2, "#ffffff", None)
    for x in (12, 18, 24):
        a.circ(x, 9.5, 1.2, ["#9fe0b8", "#ffe08a", "#ff9ebf"][(x // 6) % 3], INK, 0.4)
    a.face(46, 9.5, 0.75)
    a.cat_sticker(57, 43, 0.8)
    a.save("ruins_incubator")


def sequencer():
    a = Art(56, 46)
    a.ell(3, 40, 53, 45, (30, 30, 45, 80), None)
    a.rect(3, 10, 53, 42, "#e9e2d0", 4)
    a.rect(8, 14, 34, 32, "#3d4b5c", 2)
    for i, (h, c) in enumerate(((10, MINT), (6, PINK), (12, SKY), (8, BUTTER), (5, LILAC))):
        a.d.rectangle(a.p(11 + i * 4.6, 30 - h, 13.6 + i * 4.6, 30), fill=c)
    a.face(44, 20, 0.8)
    a.rect(38, 30, 50, 34, "#cfc5ad", 1, INK, 0.4)
    a.rect(14, 3, 30, 11, "#d9d2bf", 2)
    a.cat_sticker(46, 9, 0.85)
    a.save("ruins_sequencer")


def centrifuge():
    a = Art(48, 42)
    a.ell(4, 34, 44, 41, (30, 30, 45, 80), None)
    a.rect(4, 14, 44, 37, "#d9e3ea", 6)
    a.ell(4, 5, 44, 25, "#eef3f7")
    a.ell(10, 9, 38, 21, "#c3d1dc")
    for ang in range(0, 360, 60):
        x = 24 + 9 * math.cos(math.radians(ang))
        y = 15 + 4.2 * math.sin(math.radians(ang))
        a.circ(x, y, 1.6, [PINK, MINT, LILAC][ang // 60 % 3], INK, 0.4)
    a.circ(24, 15, 1.4, STEEL_D, INK, 0.4)
    for r in (17, 19.5):
        a.arc(24 - r, 15 - r * 0.47, 24 + r, 15 + r * 0.47, 200, 250, "#ffffff", 0.7)
        a.arc(24 - r, 15 - r * 0.47, 24 + r, 15 + r * 0.47, 20, 70, "#ffffff", 0.7)
    a.face(24, 29, 0.85)
    a.save("ruins_centrifuge")


def prep_bench():
    a = Art(100, 40)
    a.ell(4, 33, 96, 39, (30, 30, 45, 80), None)
    for x in (8, 88):
        a.rect(x, 18, x + 4, 36, STEEL_D, 1)
    a.rect(2, 10, 98, 21, STEEL_L, 3)
    a.line([(5, 13), (95, 13)], "#ffffff", 0.6)
    a.rect(10, 3, 30, 11, "#ffffff", 2)  # tray
    a.ell(36, 1, 44, 11, (200, 236, 245, 170))  # beaker
    a.d.rounded_rectangle(a.p(37, 6, 43, 10.5), 2 * SS, fill=FLUID)
    a.ell(54, 4, 72, 11, "#ffd0dc")  # folded pink towel
    a.line([(56, 7.4), (70, 7.4)], "#f0a8bf", 0.5)
    a.circ(84, 7, 3.4, "#ffe066")  # a spare duck
    a.poly([(86.8, 6.6), (89.4, 7.2), (86.8, 8)], "#ffa040", INK, 0.3)
    a.circ(85, 6.2, 0.45, INK, None)
    a.save("ruins_prep_bench")


def freezer():
    a = Art(46, 68)
    a.ell(3, 61, 43, 67, (30, 30, 45, 80), None)
    a.rect(3, 3, 43, 64, "#f2f6fb", 5)
    a.line([(3.5, 26), (42.5, 26)], INK, 0.7)
    for y in (12, 40):
        a.rect(36, y, 39, y + 9, STEEL, 1, INK, 0.5)
    for x, y in ((8, 6), (14, 5.4), (30, 6), (36, 5.6)):
        a.circ(x, y, 1.6, "#ffffff", "#c9dff0", 0.3)
    a.face(20, 15, 1.0)
    a.cat_sticker(14, 46, 1.0)
    a.sparkle(30, 50, 2.4, "#ffffff", "#a8d8f0")
    a.save("ruins_freezer")


def cub_basket():
    a = Art(60, 30)
    a.ell(2, 23, 58, 29, (30, 30, 45, 70), None)
    a.ell(2, 4, 58, 18, "#ffd0dc")
    a.ell(6, 6, 54, 15, "#ffe6ee", None)
    a.rect(2, 10, 58, 27, "#e2b98c", 6)
    for x in range(6, 56, 6):
        a.line([(x, 12), (x + 3, 26)], "#c99a6a", 0.5)
    a.line([(4, 18), (56, 18)], "#c99a6a", 0.5)
    a.heart(30, 18.5, 3.2)
    a.heart(14, 7, 2)
    a.sparkle(46, 6, 2.2)
    a.save("ruins_cub_basket")


# ---------------------------------------------------------------- bunker lift

def lift_cage():
    a = Art(80, 100)
    a.ell(3, 92, 77, 99, (20, 20, 35, 100), None)
    a.rect(4, 8, 76, 95, "#2d3644", 3)  # shaft dark
    a.rect(10, 14, 70, 92, "#3b4656", 2, None)
    for x in range(14, 70, 7):
        a.line([(x, 14), (x, 92)], "#77889c", 0.7)
    a.rect(4, 4, 76, 14, STEEL, 2)
    a.rect(4, 88, 76, 96, STEEL_D, 2)
    a.rect(52, 16, 74, 92, None, 1, "#9fb3c4", 0.9)  # open gate, folded aside
    for x in (57, 63, 69):
        a.line([(x, 17), (x, 91)], "#9fb3c4", 0.6)
    a.rect(18, 22, 38, 34, "#fff8ec", 1, INK, 0.5)  # the chart pinned inside
    for i, c in enumerate((PINK, MINT, PINK, "#ff7a9a", MINT)):
        a.d.rectangle(a.p(20 + i * 3.6, 30 - (i % 3 + 1) * 2, 22.6 + i * 3.6, 32), fill=c)
    a.face(40, 9, 0.8)
    # mop bucket holding the gate open
    a.rect(44, 78, 58, 94, "#ffe066", 2)
    a.line([(51, 78), (60, 54)], "#c8956d", 1.0)
    a.ell(45, 76, 57, 80, "#9fd8ff", INK, 0.4)
    a.save("ruins_lift_cage")


def intercom():
    a = Art(38, 42)
    a.rect(3, 3, 35, 39, "#d8dee6", 5)
    a.rect(7, 7, 31, 23, "#bcc6d2", 3)
    for y in range(10, 22, 3):
        a.line([(10, y), (28, y)], "#8d99a8", 0.7)
    a.face(19, 29, 0.85)
    a.circ(29, 34, 1.4, "#ff9ebf", INK, 0.4)
    a.cat_sticker(9, 34, 0.6)
    a.save("ruins_intercom")


def coat_hooks():
    a = Art(84, 50)
    a.rect(2, 2, 82, 7, "#c8956d", 1.5)
    for i, c in enumerate((LILAC, "#ffffff", PINK, LILAC)):
        x = 12 + i * 20
        a.circ(x, 6, 1.4, STEEL, INK, 0.4)
        a.poly([(x - 3, 8), (x + 3, 8), (x + 8, 46), (x - 8, 46)], c)
        a.ell(x - 4, 6, x + 4, 12, c)
        a.line([(x, 12), (x, 44)], INK, 0.4)
        a.circ(x, 20, 0.8, BUTTER, INK, 0.3)
    a.save("ruins_coat_hooks")


def mop_bucket():
    a = Art(30, 34)
    a.ell(2, 28, 28, 33, (30, 30, 45, 80), None)
    a.line([(19, 22), (26, 1)], "#c8956d", 1.1)
    a.poly([(4, 13), (26, 13), (23, 31), (7, 31)], "#ffe066")
    a.ell(4, 10, 26, 16, "#9fd8ff")
    a.ell(12, 10, 22, 14, "#e8f6ff", None)
    a.arc(5, 3, 25, 23, 200, 340, INK, 0.6)
    a.face(15, 22, 0.75)
    a.save("ruins_mop_bucket")


def hazard_band():
    a = Art(104, 26)
    a.rect(1, 1, 103, 25, PINK, 2)
    for i in range(-2, 16):
        x = i * 8
        a.poly([(x, 25), (x + 6, 1), (x + 10, 1), (x + 4, 25)], MINT, None)
    a.rect(1, 1, 103, 25, None, 2)
    a.save("ruins_hazard_band")


# ---------------------------------------------------------------- reliquary core

def server_rack():
    a = Art(52, 86)
    a.ell(3, 79, 49, 85, (20, 20, 35, 100), None)
    a.rect(4, 8, 48, 82, "#3a3f55", 3)
    for i in range(6):
        y = 14 + i * 10
        a.rect(8, y, 44, y + 7, "#4a5069", 1, "#2c3042", 0.5)
        for j, c in enumerate(("#9fe0b8", "#ff9ebf", "#ffe08a")):
            if (i + j) % 2 == 0:
                a.circ(12 + j * 4, y + 3.5, 0.9, c, None)
        a.line([(26, y + 3.5), (40, y + 3.5)], "#2c3042", 0.5)
    a.face(26, 75, 0.8)
    for x in (10, 40):  # candles on top
        a.rect(x - 2, 1.5, x + 2, 9, "#fff8ec", 1, INK, 0.4)
        a.ell(x - 1, -1.5, x + 1, 2.6, "#ffcf6a", None)
    a.line([(18, 8), (22, 12), (26, 8), (30, 12), (34, 8)], PINK, 0.8)  # ribbon
    a.save("ruins_server_rack")


def altar_desk():
    a = Art(90, 52)
    a.ell(3, 45, 87, 51, (20, 20, 35, 100), None)
    a.rect(4, 18, 86, 47, "#5b607c", 3)
    for i, c in enumerate(("#9fe0b8", "#ffe08a", "#ff9ebf", SKY, "#9fe0b8")):
        a.rect(10 + i * 8, 22, 15 + i * 8, 26, c, 1, INK, 0.3)
    a.poly([(4, 14), (86, 14), (80, 36), (10, 36)], "#ffc4d6")  # altar cloth
    a.line([(12, 33), (78, 33)], "#ffe08a", 0.7)
    a.circ(45, 25, 6, "#ff7a9a", INK, 0.6)  # a pink O
    a.circ(45, 25, 3.2, "#ffc4d6", INK, 0.5)
    for x in (16, 22, 68, 74):
        a.rect(x - 1.6, 7, x + 1.6, 15, "#fff8ec", 1, INK, 0.4)
        a.ell(x - 1, 3.8, x + 1, 7.4, "#ffcf6a", None)
    a.face(45, 41, 0.8)
    a.save("ruins_altar_desk")


def candles():
    a = Art(46, 32)
    rr = random.Random(3)
    for i in range(9):
        x = 5 + i * 4.4 + rr.uniform(-1, 1)
        h = rr.uniform(8, 18)
        a.rect(x - 1.8, 30 - h, x + 1.8, 30, "#fff8ec", 1, INK, 0.4)
        a.ell(x - 1.1, 26.4 - h, x + 1.1, 31 - h, "#ffcf6a", None)
        a.ell(x - 0.5, 28 - h, x + 0.5, 30.6 - h, "#fff6c8", None)
    a.ell(1, 27, 45, 32, "#fff1d8", INK, 0.4)  # wax pool
    a.save("ruins_candles")


def floor_hatch():
    a = Art(52, 28)
    a.ell(1, 1, 51, 27, "#6b7085", INK, 0.8)
    a.ell(5, 4, 47, 24, "#555a6e", INK, 0.6)
    for y in (9.5, 14, 18.5):
        a.line([(14, y), (38, y)], "#7c8199", 0.8)
    a.poly([(22, 6.5), (30, 6.5), (26, 10)], "#ff9ebf", None)
    a.poly([(22, 18), (30, 18), (26, 21.5)], "#ff9ebf", None)
    a.save("ruins_floor_hatch")


# ---------------------------------------------------------------- service spine

def pipes(name, stripe=None, w=300):
    a = Art(w, 24)
    for y, c in ((3, "#8d9bb0"), (12, "#a3b0c2")):
        a.rect(0.5, y, w - 0.5, y + 8, c, 3)
        a.line([(2, y + 2.4), (w - 2, y + 2.4)], "#c6d0dd", 0.6)
        if stripe:
            a.d.rectangle(a.p(1, y + 4.6, w - 1, y + 6.2), fill=stripe)
        for x in range(24, w, 48):
            a.rect(x, y - 1, x + 4, y + 9, "#6d7b90", 1, INK, 0.4)
    a.save(name)


def portrait():
    a = Art(44, 52)
    a.rect(1, 1, 43, 51, "#e0b24a", 3)
    a.rect(5, 5, 39, 47, "#cfe6f4", 2)
    a.ell(10, 32, 34, 52, LILAC, None)  # jacket
    a.d.rectangle(a.p(5.5, 44, 38.5, 46.5), fill=LILAC)
    a.ell(12, 10, 32, 34, "#f6d2bd")  # face
    a.d.chord(a.p(10, 6, 34, 26), 180, 360, fill="#ffe08a", outline=INK, width=a.lw(0.6))
    for x in (17.5, 26.5):  # eyes slightly too large and too kind
        a.circ(x, 21, 2.6, INK, None)
        a.circ(x - 0.8, 20, 0.9, "#ffffff", None)
    a.arc(18.5, 23.5, 25.5, 29.5, 20, 160, INK, 0.6)
    for x in (14.5, 29.5):
        a.ell(x - 1.8, 24.5, x + 1.8, 26.5, BLUSH, None)
    for x in range(14, 32, 3):
        a.circ(x, 36, 0.9, "#ffffff", INK, 0.3)  # pearls
    a.save("ruins_portrait")


def towel_trolley():
    a = Art(52, 44)
    a.ell(3, 38, 49, 43, (30, 30, 45, 80), None)
    a.rect(4, 8, 48, 36, "#d5dbe4", 2)
    for y, cols in ((10, (PINK, "#ffffff", MINT)), (22, (SKY, PINK, "#ffffff"))):
        for i, c in enumerate(cols):
            a.rect(7 + i * 13.5, y, 19 + i * 13.5, y + 10, c, 2, INK, 0.5)
            a.line([(8 + i * 13.5, y + 5), (18 + i * 13.5, y + 5)], "#e8dce8", 0.4)
    for x in (8, 44):
        a.circ(x, 38, 2.6, "#6d7b90")
    a.line([(4, 6), (48, 6)], STEEL_D, 1.0)
    a.save("ruins_towel_trolley")


def vending():
    a = Art(48, 74)
    a.ell(3, 67, 45, 73, (20, 20, 35, 100), None)
    a.rect(4, 3, 44, 70, "#ff9ebf", 4)
    a.rect(8, 8, 32, 50, "#cfe6f4", 2)
    for row in range(3):
        y = 12 + row * 12
        a.line([(9, y + 8), (31, y + 8)], "#9fb3c4", 0.6)
        for col in range(3):
            c = [MINT, BUTTER, LILAC, SKY, PINK][(row * 3 + col) % 5]
            a.rect(11 + col * 7, y, 16 + col * 7, y + 7.5, c, 1.2, INK, 0.4)
    a.rect(35, 10, 41, 26, "#ffd0dc", 1, INK, 0.5)
    for y in (13, 17, 21):
        a.circ(38, y, 0.9, "#ffffff", None)
    a.face(24, 58, 0.9)
    # offerings left in front: a flower and a little heart
    for x, c in ((10, "#ffffff"), (38, "#ffd36e")):
        for dx, dy in ((0, -1.6), (1.6, 0), (0, 1.6), (-1.6, 0)):
            a.circ(x + dx, 66 + dy, 1.3, c, INK, 0.3)
        a.circ(x, 66, 1, "#ffe27a", None)
    a.save("ruins_vending")


def crew_sign():
    a = Art(72, 22)
    a.rect(1, 2, 71, 20, "#e9e2d0", 3)
    a.rect(4, 5, 68, 17, "#9e665c", 2, None)
    for i in range(7):  # the old lettering, scratched out
        a.rect(8 + i * 8.4, 8, 13 + i * 8.4, 14, "#f2e6d8", 0.8, None)
    for x in range(6, 66, 5):
        a.line([(x, 6), (x + 6, 16)], "#5a3e3a", 0.6)
    a.heart(66, 4, 2.2)
    a.save("ruins_crew_sign")


# ---------------------------------------------------------------- promenade deck (wreck)

def gift_shop():
    a = Art(124, 86)
    a.ell(3, 79, 121, 85, (20, 20, 35, 100), None)
    a.rect(6, 28, 118, 80, "#e9e2d0", 3)
    a.rect(14, 34, 110, 58, "#5e6a80", 2)  # dark window, sacked
    for i, c in enumerate((PINK, MINT, BUTTER, LILAC)):
        a.rect(18 + i * 22, 52, 32 + i * 22, 58, c, 1, INK, 0.4)  # boxes left behind
    a.poly([(60, 58), (68, 50), (76, 58)], SKY)
    a.rect(14, 62, 110, 76, "#d6c8a8", 2)  # counter
    a.face(62, 68, 1.0)
    # striped awning, scalloped
    a.rect(2, 6, 122, 28, "#ffffff", 3)
    for i in range(10):
        if i % 2 == 0:
            a.d.rectangle(a.p(4 + i * 12, 7, 16 + i * 12, 27), fill=PINK)
    for i in range(10):
        a.ell(2 + i * 12, 22, 14 + i * 12, 32, PINK if i % 2 == 0 else "#ffffff")
    a.rect(2, 6, 122, 28, None, 3)
    # the bunting the Covenant hung on it
    pts = [(4 + i * 10, 2 + (i % 2) * 2) for i in range(13)]
    a.line(pts, INK, 0.4)
    for i in range(12):
        x = 6 + i * 10
        a.poly([(x, 3), (x + 6, 3), (x + 3, 8)], [PINK, MINT, LILAC, BUTTER][i % 4], INK, 0.3)
    a.save("ruins_gift_shop")


def deck_chairs():
    a = Art(76, 40)
    for x0 in (2, 38):
        a.ell(x0, 33, x0 + 34, 39, (30, 30, 45, 70), None)
        a.line([(x0 + 4, 36), (x0 + 10, 20)], "#c8956d", 1.0)
        a.line([(x0 + 30, 36), (x0 + 24, 20)], "#c8956d", 1.0)
        a.poly([(x0 + 4, 6), (x0 + 26, 6), (x0 + 32, 30), (x0 + 6, 30)], "#ffffff")
        for i in range(3):
            xs = x0 + 6 + i * 8
            a.poly([(xs, 6.4), (xs + 4, 6.4), (xs + 5.2 + i * 0.4, 29.6), (xs + 1 + i * 0.4, 29.6)], SKY if x0 == 2 else PINK, None)
        a.poly([(x0 + 4, 6), (x0 + 26, 6), (x0 + 32, 30), (x0 + 6, 30)], None)
    a.save("ruins_deck_chairs")


def ice_swan():
    a = Art(56, 44)
    a.ell(1, 30, 55, 43, (168, 216, 240, 180), INK, 0.6)  # meltwater
    a.ell(8, 32, 40, 39, (220, 244, 255, 160), None)
    a.ell(10, 20, 42, 36, "#e4f4fb")  # body, slumped
    a.line([(36, 26), (40, 14), (36, 6), (31, 7)], "#e4f4fb", 3.6)
    a.line([(36, 26), (40, 14), (36, 6), (31, 7)], INK, 0.5)
    a.circ(32, 7.5, 3, "#e4f4fb")
    a.poly([(29.5, 7), (26, 8.4), (29.5, 9.2)], "#ffd09a", INK, 0.4)
    a.circ(32, 6.8, 0.6, INK, None)
    a.d.chord(a.p(12, 18, 34, 34), 200, 340, fill="#d0ecf8", outline=INK, width=a.lw(0.5))
    for x, y in ((18, 39), (46, 36), (8, 34)):
        a.circ(x, y, 1, "#ffffff", None)
    a.sparkle(46, 18, 2.4, "#ffffff", "#a8d8f0")
    a.save("ruins_ice_swan")


def slots():
    a = Art(84, 70)
    for i, (x0, c) in enumerate(((4, LILAC), (44, PINK))):
        a.ell(x0, 62, x0 + 36, 69, (20, 20, 35, 100), None)
        a.rect(x0, 10 + i * 3, x0 + 34, 66, c, 4)
        a.rect(x0 + 4, 18 + i * 3, x0 + 30, 32 + i * 3, "#fff8ec", 2)
        for j, sym in enumerate(("heart", "cherry", "heart")):
            cx = x0 + 9 + j * 8
            cy = 25 + i * 3
            if sym == "heart":
                a.heart(cx, cy - 0.6, 2.4)
            else:
                a.circ(cx - 1.2, cy + 1, 1.6, "#ff6f8f", INK, 0.3)
                a.circ(cx + 1.4, cy + 1.2, 1.6, "#ff6f8f", INK, 0.3)
                a.line([(cx - 1, cy - 0.4), (cx + 1, cy - 3), (cx + 1.4, cy)], "#6fb85a", 0.4)
        a.rect(x0 + 6, 2 + i * 3, x0 + 28, 11 + i * 3, BUTTER, 3)
        a.line([(x0 + 34, 30 + i * 3), (x0 + 38, 22 + i * 3)], STEEL_D, 0.9)
        a.circ(x0 + 38, 21 + i * 3, 2, "#ff6f8f", INK, 0.4)
        a.face(x0 + 17, 46 + i * 3, 0.85)
    a.save("ruins_slots")


def lifeboat():
    a = Art(116, 56)
    a.ell(4, 46, 112, 55, (20, 20, 35, 100), None)
    a.poly([(4, 20), (112, 20), (102, 46), (16, 46)], "#ff9a6e")
    a.d.rectangle(a.p(10, 30, 106, 34), fill="#ffffff")
    a.poly([(4, 20), (112, 20), (102, 46), (16, 46)], None)
    a.rect(2, 14, 114, 21, "#fff1d8", 3)
    for x in (24, 92):  # life rings on the side
        a.circ(x, 30, 6, "#ffffff", INK, 0.6)
        a.circ(x, 30, 3, "#ff9a6e", INK, 0.5)
        for ang in (45, 135, 225, 315):
            a.d.pieslice(a.p(x - 6, 24, x + 6, 36), ang - 12, ang + 12, fill="#ff7a6e")
        a.circ(x, 30, 3, None, INK, 0.5)
    # the stencil: one stubby 7 on the bow
    a.line([(52, 25), (60, 25), (55, 41)], "#3d4b5c", 1.6)
    a.face(76, 32, 0.9)
    a.line([(20, 14), (30, 4), (86, 4), (96, 14)], "#c8956d", 0.8)  # davit rope
    a.save("ruins_lifeboat")


def buffet():
    a = Art(84, 44)
    a.ell(3, 37, 81, 43, (20, 20, 35, 90), None)
    a.rect(4, 14, 80, 38, "#ffffff", 3)
    for x in range(8, 80, 12):
        a.ell(x - 4, 32, x + 8, 40, "#ffffff", INK, 0.5)
    a.d.rectangle(a.p(4.6, 30, 79.4, 34), fill="#ffffff")
    a.line([(5, 16.5), (79, 16.5)], MINT, 1.2)
    for i, x in enumerate((18, 42, 66)):  # silver domes
        a.d.chord(a.p(x - 9, 2, x + 9, 22), 180, 360, fill=STEEL_L, outline=INK, width=a.lw(0.6))
        a.line([(x - 10, 12), (x + 10, 12)], INK, 0.6)
        a.circ(x, 2.4, 1.4, STEEL, INK, 0.4)
        a.arc(x - 6, 5, x - 1, 10, 180, 260, "#ffffff", 0.6)
    a.face(42, 25, 0.85)
    a.save("ruins_buffet")


# ---------------------------------------------------------------- quiet archive

def binder_shelf(name, seed):
    rr = random.Random(seed)
    a = Art(124, 84)
    a.ell(3, 78, 121, 83, (20, 20, 35, 100), None)
    a.rect(2, 2, 122, 80, "#b58a6a", 3)
    for row in range(3):
        y = 6 + row * 25
        a.rect(6, y, 118, y + 22, "#7d5a48", 1, None)
        x = 7.5
        while x < 112:
            wdt = rr.choice((5, 6, 7))
            h = rr.uniform(15, 20)
            c = rr.choice((PINK, MINT, SKY, LILAC, BUTTER, CREAM, "#ffffff"))
            a.rect(x, y + 22 - h, x + wdt, y + 21.6, c, 0.8, INK, 0.4)
            a.d.rectangle(a.p(x + 1.2, y + 22 - h + 3, x + wdt - 1.2, y + 22 - h + 5), fill="#ffffff")
            x += wdt + 0.6
        a.line([(4, y + 22.5), (120, y + 22.5)], "#9b7458", 1.2)
    a.save(name)


def desk_lamp():
    a = Art(78, 54)
    a.ell(3, 47, 75, 53, (20, 20, 35, 100), None)
    a.rect(4, 22, 74, 48, "#a97e62", 3)
    a.rect(4, 18, 74, 26, "#c49a7a", 3)
    for y in (30, 39):
        a.rect(48, y, 70, y + 7, "#b68c6e", 1, INK, 0.5)
        a.circ(59, y + 3.5, 1, BUTTER, INK, 0.3)
    a.rect(10, 12, 30, 20, "#fff8ec", 1, INK, 0.5)  # an open binder
    a.line([(20, 12), (20, 20)], INK, 0.4)
    for y in (14.5, 17):
        a.line([(12, y), (18, y)], "#c9bba4", 0.4)
        a.line([(22, y), (28, y)], "#c9bba4", 0.4)
    a.line([(56, 18), (52, 8), (58, 2)], STEEL_D, 1.0)  # lamp arm
    a.ell(50, 16, 62, 19.6, STEEL_D)
    a.poly([(54, 0.5), (66, 3), (64, 10), (52, 6)], "#9fe0b8")
    a.ell(57, 6, 63, 10, "#fff6c8", None)
    a.face(39, 36, 0.85)
    a.save("ruins_desk_lamp")


def filing_cabinet():
    a = Art(44, 72)
    a.ell(3, 66, 41, 71, (20, 20, 35, 100), None)
    a.rect(4, 2, 40, 68, "#9fb3c4", 3)
    for i in range(4):
        y = 6 + i * 15.5
        a.rect(7, y, 37, y + 13, "#b8c8d6", 2, INK, 0.5)
        a.rect(17, y + 3, 27, y + 6, "#fff8ec", 0.6, INK, 0.4)
        a.rect(19, y + 8, 25, y + 10, STEEL_D, 1, INK, 0.3)
    a.heart(31, 55, 2)  # BEARS
    a.save("ruins_filing_cabinet")


def stationery():
    a = Art(56, 46)
    a.ell(3, 40, 53, 45, (20, 20, 35, 90), None)
    a.rect(3, 4, 53, 42, "#b58a6a", 3)
    for row, cols in enumerate(((PINK, MINT, BUTTER), (SKY, LILAC, PINK))):
        y = 8 + row * 17
        for i, c in enumerate(cols):
            a.rect(7 + i * 15.5, y, 20 + i * 15.5, y + 13, c, 1.5, INK, 0.5)
            a.rect(9.5 + i * 15.5, y + 3, 17.5 + i * 15.5, y + 6, "#ffffff", 0.6, INK, 0.3)
    a.save("ruins_stationery")


def failed_drawer():
    a = Art(66, 42)
    a.ell(3, 36, 63, 41, (20, 20, 35, 90), None)
    a.rect(4, 14, 62, 38, "#9fb3c4", 3)
    a.rect(8, 6, 58, 24, "#b8c8d6", 2)  # drawer, pulled out
    rr = random.Random(9)
    for i in range(10):  # papers that will not fit
        x = 10 + i * 4.6
        ang = rr.uniform(-0.35, 0.35)
        top = rr.uniform(-1, 4)
        pts = [(x, 10), (x + 6, 10), (x + 6 + ang * 8, top), (x + ang * 8, top)]
        a.poly(pts, "#fff8ec" if i % 3 else "#ffe6ee", INK, 0.35)
    a.rect(26, 15, 40, 20, "#fff8ec", 0.6, INK, 0.4)
    a.rect(29, 28, 37, 31, STEEL_D, 1, INK, 0.3)
    a.save("ruins_failed_drawer")


# ---------------------------------------------------------------- clutter (every room)

def crates():
    """Two supply crates stacked, a third beside them; heart stencils."""
    a = Art(56, 44)
    a.ell(2, 37, 54, 43, (20, 20, 35, 90), None)
    for x0, y0, w, c in ((4, 18, 24, "#e8c49a"), (28, 22, 22, "#d9b48a"), (8, 2, 18, "#f0d2ac")):
        a.rect(x0, y0, x0 + w, y0 + 19 if y0 > 10 else y0 + 17, c, 1.5)
        a.line([(x0 + 1.5, y0 + 4), (x0 + w - 1.5, y0 + 4)], "#c29a70", 0.6)
        a.line([(x0 + 2, y0 + 6), (x0 + w - 2, y0 + 15 if y0 > 10 else y0 + 13)], "#c29a70", 0.6)
        a.heart(x0 + w / 2, y0 + 10 if y0 > 10 else y0 + 9, 2.4, "#ffb3c8")
    a.save("ruins_crates")


def barrel():
    a = Art(28, 38)
    a.ell(2, 32, 26, 37, (20, 20, 35, 90), None)
    a.rect(3, 5, 25, 34, "#a8d8f0", 4)
    for y in (12, 26):
        a.line([(3.5, y), (24.5, y)], "INK", 0.6)
    a.ell(3, 2, 25, 9, "#c8e8f6")
    a.ell(9, 4, 19, 7, "#a8d8f0", "INK", 0.4)
    a.d.rectangle(a.p(6, 15, 10, 23), fill="#e6f5fc")  # highlight
    a.rect(13, 15, 21, 23, "#fff8ec", 1, "INK", 0.4)  # sticker: a heart, not a hazard sign
    a.heart(17, 19, 2)
    a.save("ruins_barrel")


def papers():
    """Loose pages on the floor, painted flat."""
    a = Art(44, 22)
    rr = random.Random(5)
    for i in range(6):
        x, y = rr.uniform(4, 30), rr.uniform(2, 10)
        ang = rr.uniform(-0.5, 0.5)
        w, h = 10, 8
        pts = [(x, y), (x + w, y + ang * 4), (x + w - ang * 3, y + h + ang * 4), (x - ang * 3, y + h)]
        a.poly(pts, "#fff8ec" if i % 3 else "#ffe6ee", "INK", 0.4)
        a.line([(x + 2, y + 3 + ang), (x + 7, y + 3 + ang * 2)], "#d6c8b2", 0.4)
    a.save("ruins_papers")


def cables():
    a = Art(70, 20)
    for k, c in enumerate(("#ffb3c8", "#a8e6c8", "#c9b3f0")):
        pts = [(2 + i * 4, 10 + 5 * math.sin(i * 0.55 + k * 1.7) + k * 2) for i in range(17)]
        a.line(pts, "INK", 2.2)
        a.line(pts, c, 1.3)
    a.save("ruins_cables")


def plant():
    """A potted plant the Covenant tied a ribbon round: life where the ship died."""
    a = Art(30, 44)
    a.ell(4, 38, 26, 43, (20, 20, 35, 90), None)
    for ang, ln in ((-60, 16), (-95, 22), (-125, 17), (-80, 19), (-110, 20)):
        r = math.radians(ang)
        x1, y1 = 15 + math.cos(r) * ln, 26 + math.sin(r) * ln
        a.line([(15, 26), (x1, y1)], "#6fb85a", 0.8)
        a.ell(x1 - 3.4, y1 - 2.2, x1 + 3.4, y1 + 2.2, "#a8e6a0", "INK", 0.5)
    a.poly([(6, 24), (24, 24), (22, 40), (8, 40)], "#ffc9de")
    a.rect(5, 22, 25, 27, "#ffb3c8", 1.2)
    a.poly([(15, 31), (10, 28), (10, 34)], "#c9b3f0", "INK", 0.4)  # the ribbon
    a.poly([(15, 31), (20, 28), (20, 34)], "#c9b3f0", "INK", 0.4)
    a.circ(15, 31, 1.2, "#e0d0fa", "INK", 0.4)
    a.face(15, 36, 0.55)
    a.save("ruins_plant")


def offering():
    """Shells, a flower and a candle left on the floor by the faithful."""
    a = Art(34, 20)
    a.ell(1, 10, 33, 19, (20, 20, 35, 70), None)
    a.rect(14, 2, 18, 13, "#fff8ec", 1, "INK", 0.4)
    a.ell(14.6, -0.6, 17.4, 3.8, "#ffcf6a", None)
    for x, y, c in ((6, 13, "#ffd3c2"), (25, 14, "#fff1d8")):
        a.d.pieslice(a.p(x - 4, y - 4, x + 4, y + 4), 180, 360, fill=c, outline=INK, width=a.lw(0.4))
        for dx in (-2, 0, 2):
            a.line([(x, y), (x + dx, y - 3.2)], "#e0b090", 0.35)
    for dx, dy in ((0, -1.6), (1.6, 0), (0, 1.6), (-1.6, 0)):
        a.circ(11 + dx, 15 + dy, 1.4, "#ff9fc0", "INK", 0.3)
    a.circ(11, 15, 1, "#ffe27a", None)
    a.save("ruins_offering")


def bunting():
    """Pastel bunting strung along a wall."""
    a = Art(120, 20)
    pts = [(1 + i * 6, 3 + 4 * math.sin(math.pi * i / 19)) for i in range(20)]
    a.line(pts, "INK", 0.5)
    for i in range(1, 19, 1):
        x, y = pts[i]
        a.poly([(x - 2.6, y), (x + 2.6, y), (x, y + 7)], [PINK, MINT, LILAC, BUTTER, SKY][i % 5], "INK", 0.35)
    a.save("ruins_bunting")


def porthole():
    a = Art(30, 30)
    a.circ(15, 15, 13.5, "#c8d8e4")
    a.circ(15, 15, 10, "#7fb6d8", "INK", 0.6)
    a.d.chord(a.p(5, 5, 25, 25), 200, 330, fill="#a9ddf2")  # sea, seen through
    a.line([(9, 10), (12, 7)], "#ffffff", 0.9)
    for ang in range(0, 360, 45):
        r = math.radians(ang)
        a.circ(15 + math.cos(r) * 11.8, 15 + math.sin(r) * 11.8, 0.7, STEEL_D, None)
    a.save("ruins_porthole")


def life_ring():
    a = Art(30, 30)
    a.circ(15, 15, 13, "#ffffff")
    for ang in (45, 135, 225, 315):
        a.d.pieslice(a.p(2, 2, 28, 28), ang - 18, ang + 18, fill="#ff9a6e")
    a.circ(15, 15, 13, None)
    a.circ(15, 15, 6.5, (0, 0, 0, 0))
    a.d.ellipse(a.p(8.5, 8.5, 21.5, 21.5), fill=(0, 0, 0, 0))
    a.circ(15, 15, 6.5, None)
    a.arc(4, 4, 26, 26, 200, 250, "#ffffff", 0.7)
    a.save("ruins_life_ring")


def chair_tipped():
    a = Art(40, 24)
    a.ell(2, 17, 38, 23, (20, 20, 35, 80), None)
    a.poly([(3, 15), (30, 6), (37, 13), (10, 21)], "#ffffff")
    for i in range(3):
        a.poly([(6 + i * 9, 14 - i * 3), (10 + i * 9, 12.6 - i * 3), (16 + i * 9, 18.4 - i * 3), (12 + i * 9, 19.8 - i * 3)], PINK, None)
    a.poly([(3, 15), (30, 6), (37, 13), (10, 21)], None)
    a.line([(8, 20), (6, 9)], "#c8956d", 1.0)
    a.line([(33, 11), (30, 3)], "#c8956d", 1.0)
    a.save("ruins_chair_tipped")


def puddle():
    """Spilled tank fluid, pink, painted flat."""
    a = Art(40, 16)
    a.ell(2, 3, 30, 13, "#ff9ebf", "INK", 0.5)
    a.ell(24, 6, 38, 14, "#ff9ebf", "INK", 0.5)
    a.d.ellipse(a.p(2.6, 3.6, 29.4, 12.4), fill="#ff9ebf")
    a.ell(6, 5, 16, 8, "#ffd0dc", None)
    a.circ(31, 9, 1.2, "#ffd0dc", None)
    a.save("ruins_puddle")


def lab_cart():
    a = Art(44, 40)
    a.ell(3, 34, 41, 39, (20, 20, 35, 90), None)
    a.rect(4, 12, 40, 16, STEEL_L, 1.5)
    a.rect(4, 26, 40, 30, STEEL_L, 1.5)
    for x in (6, 38):
        a.line([(x, 14), (x, 34)], STEEL_D, 0.9)
        a.circ(x, 35, 2, "#6d7b90")
    for x, c, h in ((10, FLUID, 8), (17, MINT, 6), (24, SKY, 9), (31, LILAC, 7)):
        a.rect(x - 2.6, 12 - h, x + 2.6, 12, (200, 236, 245, 150), 1, "INK", 0.4)
        a.d.rectangle(a.p(x - 2, 12 - h * 0.55, x + 2, 11.6), fill=c)
    a.rect(10, 20, 32, 26, "#fff8ec", 1, "INK", 0.4)  # a folded towel
    a.cat_sticker(36, 20, 0.6)
    a.save("ruins_lab_cart")


def runner():
    """The pilgrims' rug runner (STYLE.md: #ffb3c8 with #ffe3a8 borders and pale hearts), worn."""
    a = Art(200, 22)
    a.rect(1, 1, 199, 21, "#ffe3a8", 2)
    a.rect(3.5, 3.5, 196.5, 18.5, "#ffb3c8", 1, None)
    for x in range(14, 196, 22):
        a.heart(x, 10.4, 2.6, "#ffd0e0", None)
    for x in range(4, 198, 4):  # fringe
        a.line([(x, 0), (x, 1.2)], "#e0b24a", 0.4)
        a.line([(x, 20.8), (x, 22)], "#e0b24a", 0.4)
    a.ell(120, 5.5, 150, 16.5, "#ffc4d6", None)  # worn where everyone kneels
    a.save("ruins_runner")


def poster():
    """A wall poster: the cat in the lab coat with a thumbs-up, steps as pictures, no words."""
    a = Art(34, 44)
    a.rect(1, 1, 33, 43, "#fff8ec", 1.5)
    a.d.rectangle(a.p(1.6, 1.6, 32.4, 8), fill="#ffb3c8")
    a.cat_sticker(17, 18, 1.4)
    for i, c in enumerate((PINK, MINT, SKY)):
        x = 8 + i * 9
        a.circ(x, 33, 3, c, "INK", 0.4)
        if i < 2:
            a.line([(x + 3.4, 33), (x + 5.6, 33)], "INK", 0.5)
    a.circ(26, 33, 1.2, "#fff0f6", None)
    a.circ(17, 33, 1.4, "#ffe08a", None)
    a.circ(8, 33, 0.7, "#ffffff", None)
    for x in (4, 30):
        a.circ(x, 4, 1, "#ff7a9a", "INK", 0.3)
    a.save("ruins_poster")


# ---------------------------------------------------------------- pickups

def icon(name, draw):
    a = Art(20, 20)
    draw(a)
    a.save(f"icon_{name}")


def icon_book(a, cover=LILAC):
    a.rect(3, 3, 17, 18, cover, 1.5)
    a.d.rectangle(a.p(3.6, 3.6, 5.4, 17.4), fill="#ffffff")
    a.heart(11, 9.5, 2.6)


def icon_paper(a):
    a.poly([(4, 2), (13, 2), (16, 5), (16, 18), (4, 18)], "#fff8ec")
    for y in (7, 10, 13):
        a.line([(6.5, y), (13.5, y)], "#c9bba4", 0.6)
    a.circ(13, 15, 1.4, "#ff9ebf", None)


def icon_thermo(a):
    a.rect(8, 1.5, 12, 15, "#eef6fb", 2)
    a.d.rectangle(a.p(9.3, 7, 10.7, 15), fill="#ff7a9a")
    a.circ(10, 15.5, 3.2, "#ff7a9a")
    for y in (4, 6.5, 9, 11.5):
        a.line([(12, y), (13.6, y)], INK, 0.4)


def icon_calendar(a):
    a.rect(3, 4, 17, 18, "#ffffff", 1.5)
    a.d.rectangle(a.p(3.6, 4.6, 16.4, 8), fill=SKY)
    for i in range(3):
        for j in range(2):
            a.rect(5 + i * 4, 10 + j * 3.8, 7.6 + i * 4, 12.4 + j * 3.8, "#e6e6f0", 0.4, None)
    for x in (7, 13):
        a.rect(x - 0.8, 2, x + 0.8, 6, STEEL_D, 0.6, INK, 0.3)


def icon_chart(a):
    a.rect(3, 3, 17, 17, "#fff8ec", 1.5)
    for i, h in enumerate((4, 7, 10, 6)):
        a.d.rectangle(a.p(5 + i * 3, 15 - h, 7 + i * 3, 15), fill=(PINK, MINT, "#ff7a9a", SKY)[i])


def icon_board(a):
    a.rect(2, 3, 18, 15, "#ffffff", 1.5)
    for x in (6, 10, 14):
        a.line([(x, 5.5), (x, 12.5)], "#c9bba4", 0.5)
    for x, y, c in ((4.4, 7, "#ff7a9a"), (8.4, 9, "#5aa0d0"), (12.4, 7, "#6fb85a"), (16, 10, "#ff7a9a")):
        a.line([(x, y), (x + 1.2, y + 1.2)], c, 0.6)
    a.line([(6, 15), (5, 18.5)], STEEL_D, 0.7)
    a.line([(14, 15), (15, 18.5)], STEEL_D, 0.7)


def icons():
    icon("book", icon_book)
    icon("paper", icon_paper)
    icon("thermometer", icon_thermo)
    icon("calendar", icon_calendar)
    icon("chart", icon_chart)
    icon("board", icon_board)
    icon("ledger", lambda a: icon_book(a, MINT))
    icon("proposal", lambda a: icon_book(a, SKY))
    icon("appendix", lambda a: icon_book(a, PINK))


def bunker():
    tiles()
    tank("ruins_tank")
    tank("ruins_tank_duck", duck=True)
    for draw in (incubator, sequencer, centrifuge, prep_bench, freezer, cub_basket, lift_cage, intercom,
                 coat_hooks, mop_bucket, hazard_band, desk_lamp, filing_cabinet, stationery, failed_drawer):
        draw()
    for name, seed in (("ruins_binders_a", 1), ("ruins_binders_b", 2), ("ruins_binders_c", 3)):
        binder_shelf(name, seed)
    for draw in (puddle, lab_cart, poster):
        draw()
    icons()


def ship():
    for draw in (server_rack, altar_desk, candles, floor_hatch, portrait, towel_trolley, vending, crew_sign,
                 gift_shop, deck_chairs, ice_swan, slots, lifeboat, buffet):
        draw()
    pipes("ruins_pipes")
    pipes("ruins_pipes_striped", "#ff9a9a", 260)
    for draw in (crates, barrel, papers, cables, plant, offering, bunting, porthole, life_ring, chair_tipped, runner):
        draw()


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    glow()
    shadow()
    vignette()
    INK = PLUM  # the bunker: the clone lab's cool plum (STYLE.md 4.1)
    bunker()
    INK = BROWN  # the ship above it: the island's warm brown
    ship()
    print("ruins art done:", len(list(OUT.glob("*.png"))), "files")
