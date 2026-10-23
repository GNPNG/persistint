"""Draw the failed clone children of the bunker's clone hall and the polar bear cub batch as
rigged sprite sheets, plus the kawaii gore bits a cub's pounce leaves behind.

The clones are small, pale-green, shambling and kawaii (prompts/STYLE.md, "The clone children"):
one sheet per original (every batch of an original shares the same little face), told apart by
hair and gown; stitches, a goo drip and one X eye on every one of them. The cubs are not
zombies: fluffy, round, healthy.

Usage: python3 -I tools/gen_clone_children.py
Inputs: none (palette from prompts/STYLE.md; nothing random).
Outputs (project/assets/canon/, the paths scripts/ruins/*.gd load):
  clone_<original>.png   originals are cast ids in data/cast.json. Sheet of 48x68 frames
                         (24x34 world px at scale 0.5, feet on the bottom edge):
                           rows    0 front (walking down), 1 side (facing right; flip for
                                   left), 2 back (walking up)
                           columns 0-1 idle (breathing), 2-5 walk (the shamble)
  clone_polar_bear.png   sheet of 48x44 frames (24x22 world px at scale 0.5, feet on the
                         bottom edge):
                           rows 0 front, 1 side (facing right), 2 back: columns 0-1 idle,
                                2-5 walk (a toddle)
                           row 3 front with a pink muzzle: 0-1 idle, 2-3 chomp
                           row 4 asleep, pink muzzle: 0-1 breathing
  gore_bone.png 24x12, gore_chunk.png 20x20, gore_puddle.png 64x28 (two texels per world px;
                         clone_lab.gd shows them at scale 0.75)
Each frame is drawn SS times larger and downscaled (LANCZOS).
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/canon"
INK = "#5a4a5e"  # the clone lab's plum outline (STYLE.md 4.1)
SKIN = "#c9ecc4"
SKIN_D = "#b2dbad"
GOO = "#8fe07a"
BLUSH = "#ff9fb8"
MOUTH = "#7a4a5a"
FUR, FUR_D, EAR = "#fbfbff", "#e6e3f0", "#ffc4d4"
SMEAR = "#ff7a9a"
SS = 8  # canvas pixels per world unit while drawing
D = 2  # output texels per world unit
ORIGINALS = (("epstein", "#ffb3c8"), ("bill_clinton", "#a8d8f0"), ("hillary_clinton", "#c9b3f0"), ("bill_gates", "#ffe08a"))
HAIR = {"epstein": ("#b7b4bd", "#8f8c96"), "bill_clinton": ("#f4f1ee", "#d9d4d0"),
        "hillary_clinton": ("#f2d48a", "#dcb86a"), "bill_gates": ("#9a7458", "#7d5a42")}


class Pen:
    """Drawing in world units on a supersampled canvas."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w * SS, h * SS))
        self.d = ImageDraw.Draw(self.im)

    def lw(self, w):
        return max(1, round(w * SS))

    def ell(self, x0, y0, x1, y1, fill, ink=INK, w=0.6):
        self.d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=fill, outline=ink, width=self.lw(w) if ink else 0)

    def circ(self, x, y, r, fill, ink=INK, w=0.6):
        self.ell(x - r, y - r, x + r, y + r, fill, ink, w)

    def rect(self, x0, y0, x1, y1, fill, r=1.0, ink=INK, w=0.6):
        self.d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS, y1 * SS], r * SS, fill=fill, outline=ink, width=self.lw(w) if ink else 0)

    def poly(self, pts, fill, ink=INK, w=0.6):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=fill, outline=ink, width=self.lw(w) if ink else 0)

    def line(self, pts, fill=INK, w=0.5):
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=fill, width=self.lw(w), joint="curve")

    def arc(self, x0, y0, x1, y1, a0, a1, fill=INK, w=0.5):
        self.d.arc([x0 * SS, y0 * SS, x1 * SS, y1 * SS], a0, a1, fill=fill, width=self.lw(w))

    def chord(self, x0, y0, x1, y1, a0, a1, fill, ink=INK, w=0.6):
        self.d.chord([x0 * SS, y0 * SS, x1 * SS, y1 * SS], a0, a1, fill=fill, outline=ink, width=self.lw(w))

    def frame(self):
        return self.im.resize((self.w * D, self.h * D), Image.LANCZOS)


def sheet(frames, cols, rows, fw, fh):
    """frames: {(row, col): Image} -> one sheet of cols x rows cells of fw x fh world units."""
    out = Image.new("RGBA", (cols * fw * D, rows * fh * D))
    for (r, c), im in frames.items():
        out.alpha_composite(im, (c * fw * D, r * fh * D))
    return out


# ---------------------------------------------------------------- clone children

CW, CH = 24, 34  # frame in world units
STEP = [(1.6, 0.0), (0.4, 0.4), (0.0, 1.6), (0.4, 0.4)]  # (left, right) foot lift per walk frame


def clone_frame(kind, gown, view, f=None, breath=0):
    p = Pen(CW, CH)
    bob = (0.6 if f in (1, 3) else 0.0) + (0.4 if breath else 0.0)
    gx = 12 + {0: -0.5, 2: 0.5}.get(f, 0.0)  # the lurch
    p.ell(5, 31.6, 19, 34, (40, 30, 50, 70), None)  # contact shadow
    ll, rl = (0.0, 0.0) if f is None else STEP[f]
    if view == "side":
        stride = {0: 2.2, 2: -2.2}.get(f, 0.0)
        for dx, lift, shade in ((-stride, ll, SKIN_D), (stride, rl, SKIN)):
            p.rect(gx - 1.4 + dx, 26.5 - lift, gx + 1.4 + dx, 33.2 - lift, shade, 0.9)
    else:
        for x, lift in ((gx - 3.2, ll), (gx + 0.6, rl)):
            p.rect(x, 26.5 - lift, x + 2.6, 33.2 - lift, SKIN, 0.9)
    top = 17 + bob
    hem = 28.4 + bob * 0.3
    if view == "side":
        p.rect(gx - 4.6, top, gx + 4.2, hem, gown, 2.6)
        p.line([(gx - 3.4, top + 5.5), (gx + 3, top + 5.5)])  # stitched seam
        for x in (gx - 2, gx, gx + 2):
            p.line([(x, top + 4.8), (x, top + 6.2)], w=0.4)
        for y, shade in ((top + 1.4, SKIN_D), (top + 3.0, SKIN)):  # both arms straight forward
            p.rect(gx + 1, y, gx + 10.4, y + 2.0, shade, 1.0)
    elif view == "front":
        p.rect(gx - 5.4, top, gx + 5.4, hem, gown, 3)
        p.line([(gx - 3.6, top + 5.6), (gx + 3.6, top + 5.6)])
        for x in (gx - 2, gx, gx + 2):
            p.line([(x, top + 4.9), (x, top + 6.3)], w=0.4)
        for sx in (-1, 1):  # short sleeves, and two hands held out at you
            p.rect(gx + sx * 5.6 - 1.6, top + 1, gx + sx * 5.6 + 1.6, top + 5.4, gown, 1.2)
            reach = 0.5 if (f == 0 and sx == 1) or (f == 2 and sx == -1) else 0.0
            p.circ(gx + sx * 3.4, top + 4.6 - reach, 1.7, SKIN)
    else:  # back: the gown's ties, the arms out ahead of it
        for sx in (-1, 1):
            p.rect(gx + sx * 4.8 - 1.4, top + 1, gx + sx * 4.8 + 1.4, top + 4.8, SKIN_D, 1.0)
        p.rect(gx - 5.4, top, gx + 5.4, hem, gown, 3)
        p.line([(gx, top + 1), (gx, hem - 0.4)], w=0.45)
        for y in (top + 3, top + 7):
            p.line([(gx - 1.6, y - 0.6), (gx, y), (gx + 1.6, y - 0.6)], w=0.45)
    head(p, kind, view, gx, bob)
    return p.frame()


def head(p, kind, view, gx, bob):
    hy = 9.4 + bob
    hair, hair_d = HAIR[kind]
    p.ell(gx - (7.2 if view == "side" else 8.2), hy - 8, gx + 8.2, hy + 7.6, SKIN)
    if view == "back":
        back_hair(p, kind, gx, hy, hair, hair_d)
        return
    if view == "front":
        # one sleepy dot eye, one X eye, blush, a tiny round groaning mouth
        p.circ(gx - 3.4, hy + 0.6, 1.0, INK, None)
        p.circ(gx - 3.7, hy + 0.2, 0.32, "#ffffff", None)
        p.line([(gx + 2.3, hy - 0.4), (gx + 4.5, hy + 1.6)], w=0.6)
        p.line([(gx + 4.5, hy - 0.4), (gx + 2.3, hy + 1.6)], w=0.6)
        for x in (gx - 5.4, gx + 5.4):
            p.ell(x - 1.5, hy + 2.2, x + 1.5, hy + 3.5, BLUSH, None)
        p.ell(gx - 1.1, hy + 3.0, gx + 1.1, hy + 5.0, MOUTH, None)
        p.line([(gx - 5.2, hy - 4.4), (gx - 1.6, hy - 5.4)], w=0.45)  # forehead stitches
        for x in (gx - 4.2, gx - 2.8):
            p.line([(x, hy - 5.8), (x + 0.2, hy - 4.0)], w=0.4)
        p.rect(gx + 1.8, hy + 4.4, gx + 3.0, hy + 8.4, GOO, 0.6, None)  # goo drip off the chin
        p.circ(gx + 2.4, hy + 8.4, 0.95, GOO, None)
        front_hair(p, kind, gx, hy, hair, hair_d)
    else:
        p.circ(gx + 3.6, hy + 0.4, 1.0, INK, None)
        p.circ(gx + 3.3, hy, 0.32, "#ffffff", None)
        p.ell(gx + 1.2, hy + 2.2, gx + 4.0, hy + 3.5, BLUSH, None)
        p.ell(gx + 6.0, hy + 3.0, gx + 7.6, hy + 4.8, MOUTH, None)
        p.line([(gx - 1, hy - 5.4), (gx + 3, hy - 5.8)], w=0.45)
        p.line([(gx + 1, hy - 6.4), (gx + 1.2, hy - 4.8)], w=0.4)
        p.rect(gx + 5.6, hy + 4.4, gx + 6.8, hy + 8.2, GOO, 0.6, None)
        p.circ(gx + 6.2, hy + 8.2, 0.95, GOO, None)
        p.circ(gx - 3.6, hy + 1.2, 1.4, SKIN_D, INK, 0.45)  # ear
        side_hair(p, kind, gx, hy, hair, hair_d)


def front_hair(p, kind, gx, hy, hair, hair_d):
    if kind == "epstein":  # grey, swept back
        p.chord(gx - 8.2, hy - 8.2, gx + 8.2, hy + 2.4, 180, 360, hair)
        for dx in (-3, 0, 3):
            p.line([(gx + dx - 1.4, hy - 6), (gx + dx + 1.2, hy - 4.2)], hair_d, 0.5)
    elif kind == "bill_clinton":  # white, puffy, a round red nose
        for dx, dy in ((-5.2, -4.4), (0, -6.6), (5.2, -4.4)):
            p.circ(gx + dx, hy + dy, 3.6, hair)
        p.circ(gx, hy + 1.8, 1.2, "#f2a0a0", INK, 0.4)
    elif kind == "hillary_clinton":  # blonde bob
        p.chord(gx - 8.8, hy - 8.6, gx + 8.8, hy + 3.4, 180, 360, hair)
        for sx in (-1, 1):
            p.rect(gx + sx * 7.4 - 2, hy - 2.6, gx + sx * 7.4 + 2, hy + 5.6, hair, 1.6)
        p.line([(gx - 2, hy - 7.6), (gx + 4, hy - 4.6)], hair_d, 0.5)
    else:  # bill_gates: side part and big round glasses
        p.chord(gx - 8.2, hy - 8.2, gx + 8.2, hy + 1.6, 180, 360, hair)
        p.line([(gx - 2.2, hy - 8), (gx - 3.2, hy - 3.6)], INK, 0.45)
        for x in (gx - 3.4, gx + 3.4):
            p.circ(x, hy + 0.6, 2.5, None, INK, 0.5)
        p.line([(gx - 0.9, hy + 0.4), (gx + 0.9, hy + 0.4)], INK, 0.45)


def side_hair(p, kind, gx, hy, hair, hair_d):
    if kind == "epstein":
        p.chord(gx - 7.4, hy - 8.2, gx + 8.2, hy + 4, 180, 330, hair)
        p.line([(gx + 1, hy - 6.6), (gx - 4, hy - 4.8)], hair_d, 0.5)
    elif kind == "bill_clinton":
        for dx, dy in ((-4.4, -3.4), (0.6, -6.6), (4.6, -5.2), (-5.2, 1)):
            p.circ(gx + dx, hy + dy, 3.4, hair)
        p.circ(gx + 7.8, hy + 1.6, 1.2, "#f2a0a0", INK, 0.4)
    elif kind == "hillary_clinton":
        p.chord(gx - 7.8, hy - 8.6, gx + 8.6, hy + 3.4, 180, 340, hair)
        p.rect(gx - 7.8, hy - 3, gx - 1.8, hy + 5.6, hair, 2)
    else:
        p.chord(gx - 7.4, hy - 8.2, gx + 8.2, hy + 2, 180, 340, hair)
        p.circ(gx + 4.2, hy + 0.6, 2.5, None, INK, 0.5)
        p.line([(gx + 1.7, hy + 0.2), (gx - 2.8, hy - 0.4)], INK, 0.45)


def back_hair(p, kind, gx, hy, hair, hair_d):
    if kind == "bill_clinton":
        for dx, dy in ((-5, -3.6), (0, -6), (5, -3.6), (-3.6, 1.4), (3.6, 1.4)):
            p.circ(gx + dx, hy + dy, 3.8, hair)
        return
    bottom = {"epstein": 3.6, "hillary_clinton": 6.2, "bill_gates": 2.8}[kind]
    p.chord(gx - 8.2, hy - 8.2, gx + 8.2, hy + bottom * 2 - 0.2, 180, 360, hair)
    p.rect(gx - 8.1, hy - 0.6, gx + 8.1, hy + bottom, hair, 3.2)
    p.line([(gx, hy - 7.6), (gx - 0.6, hy + bottom - 1.2)], hair_d, 0.5)
    if kind != "hillary_clinton":  # the ears peep out, except under a bob
        for sx in (-1, 1):
            p.circ(gx + sx * 8.2, hy + 1.6, 1.3, SKIN_D, INK, 0.45)


def clone(kind, gown):
    frames = {}
    for r, view in enumerate(("front", "side", "back")):
        for c in range(2):
            frames[(r, c)] = clone_frame(kind, gown, view, None, c)
        for f in range(4):
            frames[(r, 2 + f)] = clone_frame(kind, gown, view, f)
    sheet(frames, 6, 3, CW, CH).save(OUT / f"clone_{kind}.png")


# ---------------------------------------------------------------- polar bear cubs

BW, BH = 24, 22


def cub_asleep(p, breath):
    rise = 0.5 if breath else 0.0
    p.ell(2.5, 9.5 - rise, 21.5, 20.5, FUR)
    p.ell(4, 13, 9, 17, FUR_D, INK, 0.45)  # a paw tucked in
    p.ell(9, 7.5 - rise, 20, 17 - rise, FUR)  # head resting on it
    for x in (9.6, 16.8):
        p.ell(x, 6 - rise, x + 3.6, 9.6 - rise, FUR)
        p.ell(x + 1, 7 - rise, x + 2.6, 8.6 - rise, EAR, None)
    p.ell(12.6, 12.4 - rise, 17, 16 - rise, FUR_D, None)
    for x, y, r in ((13.4, 14.8, 1.2), (15.8, 15.2, 1.0)):
        p.circ(x, y - rise, r, SMEAR, None)
    p.circ(14.8, 12.8 - rise, 0.8, INK, None)
    for x in (11.6, 16.6):
        p.arc(x - 1.2, 10.6 - rise, x + 1.2, 12.4 - rise, 20, 160, INK, 0.5)
    p.ell(10, 12.6 - rise, 12, 13.6 - rise, BLUSH, None)


def cub_side(p, f, bob):
    stride = {0: 1.6, 2: -1.6}.get(f, 0.0)
    for x, dx, shade in ((6, -stride, FUR_D), (14.5, stride, FUR_D), (7.5, stride, FUR), (16, -stride, FUR)):
        p.ell(x + dx, 15.5, x + dx + 3.6, 20.6, shade)
    p.ell(2.5, 8.5 + bob, 18.5, 18.5 + bob, FUR)  # body
    p.circ(2.8, 12 + bob, 1.6, FUR)  # tail nub
    p.ell(10.5, 3 + bob, 22, 14 + bob, FUR)  # head
    p.ell(12, 1.6 + bob, 15.6, 5.4 + bob, FUR)  # ear
    p.ell(13, 2.6 + bob, 14.6, 4.4 + bob, EAR, None)
    p.ell(17.6, 7.6 + bob, 23.2, 12.2 + bob, FUR_D)  # snout
    p.circ(22.4, 8.8 + bob, 0.8, INK, None)
    p.circ(16.4, 6.8 + bob, 0.9, INK, None)
    p.circ(16.1, 6.5 + bob, 0.3, "#ffffff", None)
    p.ell(13.4, 8.6 + bob, 15.8, 9.8 + bob, BLUSH, None)


def cub_frame(view, f=None, breath=0, smeared=False, asleep=False, chomp=False):
    p = Pen(BW, BH)
    bob = (0.5 if f in (1, 3) else 0.0) + (0.35 if breath else 0.0)
    p.ell(4, 19.4, 20, 21.8, (40, 30, 50, 60), None)  # contact shadow
    if asleep:
        cub_asleep(p, breath)
        return p.frame()
    if view == "side":
        cub_side(p, f, bob)
        return p.frame()
    ll, rl = (0.0, 0.0) if f is None else [(1.0, 0.0), (0.3, 0.3), (0.0, 1.0), (0.3, 0.3)][f]
    for x, lift in ((5, ll), (14, rl)):  # stubby feet
        p.ell(x, 15.6 - lift, x + 5, 20.8 - lift, FUR)
    p.ell(3, 8.6 + bob, 21, 19.6 + bob, FUR)  # round body
    if view == "back":
        p.circ(12, 17.6 + bob, 1.6, FUR)  # tail
        for x in (3.6, 15.4):
            p.ell(x, 0.8 + bob, x + 5, 5.8 + bob, FUR)
        p.ell(4, 1.8 + bob, 20, 14.8 + bob, FUR)
        p.arc(7, 9 + bob, 17, 14 + bob, 20, 160, FUR_D, 0.5)
        return p.frame()
    for x in (3.6, 15.4):  # ears
        p.ell(x, 0.8 + bob, x + 5, 5.8 + bob, FUR)
        p.ell(x + 1.4, 2.2 + bob, x + 3.6, 4.4 + bob, EAR, None)
    p.ell(4, 1.8 + bob, 20, 14.8 + bob, FUR)  # head
    p.ell(9, 8.6 + bob, 15, 13.8 + bob, FUR_D, None)  # muzzle
    p.circ(12, 9.8 + bob, 1.0, INK, None)  # nose
    if chomp:
        p.ell(10.2, 11 + bob, 13.8, 14.4 + bob, MOUTH, INK, 0.4)
        p.ell(10.9, 12.6 + bob, 13.1, 14.0 + bob, "#ff9eb5", None)
    else:
        p.arc(10.4, 10.4 + bob, 12, 12.4 + bob, 20, 160, INK, 0.45)
        p.arc(12, 10.4 + bob, 13.6, 12.4 + bob, 20, 160, INK, 0.45)
    if smeared:
        for x, y, r in ((9.4, 12.8, 1.5), (14.4, 13.0, 1.3), (12, 14.4, 1.1), (15.6, 11.4, 0.7)):
            p.circ(x, y + bob, r, SMEAR, None)
    for x in (8.2, 15.8):
        p.circ(x, 7.6 + bob, 1.2, INK, None)
        p.circ(x - 0.4, 7.2 + bob, 0.4, "#ffffff", None)
    for x in (5.8, 18.2):
        p.ell(x - 1.5, 9.4 + bob, x + 1.5, 11 + bob, BLUSH, None)
    return p.frame()


def cubs():
    frames = {}
    for r, view in enumerate(("front", "side", "back")):
        for c in range(2):
            frames[(r, c)] = cub_frame(view, None, c)
        for f in range(4):
            frames[(r, 2 + f)] = cub_frame(view, f)
    for c in range(2):
        frames[(3, c)] = cub_frame("front", None, c, smeared=True)
        frames[(3, 2 + c)] = cub_frame("front", None, c, smeared=True, chomp=c == 0)
        frames[(4, c)] = cub_frame("front", None, c, smeared=True, asleep=True)
    sheet(frames, 6, 5, BW, BH).save(OUT / "clone_polar_bear.png")


# ---------------------------------------------------------------- gore

def gore():
    p = Pen(12, 6)  # a little cartoon bone
    for x in (2.2, 9.8):
        for y in (1.8, 4.2):
            p.circ(x, y, 1.6, "#fff8ec", INK, 0.5)
    p.rect(2.5, 2, 9.5, 4, "#fff8ec", 0.5, INK, 0.5)
    p.frame().save(OUT / "gore_bone.png")
    p = Pen(10, 10)  # a pink chunk with a worried face and a sweat drop
    p.ell(0.5, 2, 9.5, 9.5, "#ff8fa8", INK, 0.5)
    p.ell(2, 3, 5, 4.6, "#ffc0cf", None)
    for x in (3.4, 6.6):
        p.circ(x, 5.6, 0.6, INK, None)
    p.arc(3.8, 6.8, 6.2, 8.6, 200, 340, INK, 0.45)
    p.poly([(8.6, 0.4), (9.8, 2.6), (7.4, 2.6)], "#9fd8ff", None)
    p.circ(8.6, 2.7, 1.2, "#9fd8ff", None)
    p.frame().save(OUT / "gore_chunk.png")
    p = Pen(32, 14)  # a pastel puddle with a heart outline
    for x0, y0, x1, y1 in ((1, 3, 22, 13), (12, 1, 31, 12), (6, 6, 28, 13.5)):
        p.ell(x0, y0, x1, y1, "#e8547a", None)
    hx, hy = 16, 7.6
    heart = [(hx, hy + 3.4), (hx - 4, hy), (hx - 4, hy - 1.6), (hx - 2.6, hy - 3), (hx - 1, hy - 3), (hx, hy - 1.8),
             (hx + 1, hy - 3), (hx + 2.6, hy - 3), (hx + 4, hy - 1.6), (hx + 4, hy), (hx, hy + 3.4)]
    p.line(heart, "#ffd0dc", 0.7)
    p.frame().save(OUT / "gore_puddle.png")


if __name__ == "__main__":
    cubs()
    gore()
    for kind, gown in ORIGINALS:
        clone(kind, gown)
    print("clone children done")
