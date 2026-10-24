"""Draw the failed clone children of the bunker's clone hall and the polar bear cub batch as
rigged sprite sheets, plus the kawaii gore bits a cub's pounce leaves behind.

The clones are small, pale-green, shambling and kawaii (prompts/STYLE.md, "The clone children"):
one sheet per original (every batch of an original shares the same little face), told apart by
hair and gown; stitches, a goo drip and one X eye on every one of them. The cubs are not
zombies: fluffy, round, healthy.

Usage: python3 -I tools/gen_clone_children.py
Inputs: none (palette from prompts/STYLE.md; nothing random).
Outputs (project/assets/ruins/, the paths scripts/ruins/*.gd load; generated stand-ins, not canon cuts):
  clone_<original>.png   originals are cast ids in data/cast.json. Sheet of 192x272 frames
                         (24x34 world px at scale 1/8, feet on the bottom edge):
                           rows    0 front (walking down), 1 side (facing right; flip for
                                   left), 2 back (walking up)
                           columns 0-1 idle (breathing), 2-5 walk (the shamble)
                           row 3 front, the floss: columns 0-5, arms swinging side to side
                                   together with the hips swinging the other way
                           row 4 front, the dab: columns 0-2 (wind-up, the dab with one arm
                                   bent across the face and the other straight up and out,
                                   the hold)
                         (the dances: author 2026-10-24, "make the zombies floss sometimes...
                         Also dabbing"; a dancing clone is what the cubs pounce on)
  clone_polar_bear.png   sheet of 192x176 frames (24x22 world px at scale 1/8, feet on the
                         bottom edge):
                           rows 0 front, 1 side (facing right), 2 back: columns 0-1 idle,
                                2-5 walk (a toddle)
                           row 3 front with a pink muzzle: 0-1 idle, 2-3 chomp
                           row 4 asleep, pink muzzle: 0-1 breathing
  gore_bone.png 96x48, gore_chunk.png 80x80, gore_puddle.png 256x112 (eight texels per
                         world px; clone_lab.gd shows them at scale 0.1875)
  gore_drop.png 48x64    a splatter droplet, the particle texture of the pounce's spray
                         (clone_lab.gd fits it to a world size)
  gore_puff.png 80x72    a pale mint dust puff, the particle texture of an eaten clone's
                         poof (zombie_child.gd fits it to a world size)
Each frame is drawn SS times larger and downscaled (LANCZOS).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/ruins"
INK = "#5a4a5e"  # the clone lab's plum outline (STYLE.md 4.1)
SKIN = "#c9ecc4"
SKIN_D = "#b2dbad"
GOO = "#8fe07a"
BLUSH = "#ff9fb8"
MOUTH = "#7a4a5a"
FUR, FUR_D, EAR = "#fbfbff", "#e6e3f0", "#ffc4d4"
SMEAR = "#ff7a9a"
SS = 16  # canvas pixels per world unit while drawing
D = 8  # output texels per world unit (the game shows them at 1/8)
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
STEP = [(1.4, 0.0), (0.4, 0.4), (0.0, 1.4), (0.4, 0.4)]  # (left, right) foot lift per walk frame


def tint(hex_, k):
    """hex_ mixed toward white by k (0..1): the one flat highlight of the sticker style."""
    r, g, b = (int(hex_[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(round(c + (255 - c) * k) for c in (r, g, b))


def shade(hex_, k):
    r, g, b = (int(hex_[i:i + 2], 16) for i in (1, 3, 5))
    return "#%02x%02x%02x" % tuple(round(c * (1 - k)) for c in (r, g, b))


def gown_shape(gx, top, hem, half_top, half_hem):
    """An A-line gown: narrow at the shoulders, flaring to a softly rounded hem."""
    pts = [(gx - half_top, top + 1.2), (gx - half_top + 1.2, top), (gx + half_top - 1.2, top), (gx + half_top, top + 1.2)]
    pts += [(gx + half_hem, hem - 1.4)]
    for k in range(9):  # the hem's gentle curve, right to left
        t = k / 8
        pts.append((gx + half_hem * (1 - 2 * t), hem - 1.4 + 1.6 * math.sin(math.pi * t)))
    pts += [(gx - half_hem, hem - 1.4)]
    return pts


def clone_frame(kind, gown, view, f=None, breath=0):
    p = Pen(CW, CH)
    bob = (0.5 if f in (1, 3) else 0.0) + (0.35 if breath else 0.0)
    gx = 12 + {0: -0.5, 2: 0.5}.get(f, 0.0)  # the lurch
    p.ell(5.5, 31.8, 18.5, 34, (40, 30, 50, 70), None)  # contact shadow
    ll, rl = (0.0, 0.0) if f is None else STEP[f]
    if view == "side":  # little legs and round toes pointing ahead
        stride = {0: 2.0, 2: -2.0}.get(f, 0.0)
        for dx, lift, fill in ((-stride, ll, SKIN_D), (stride, rl, SKIN)):
            p.rect(gx - 1.3 + dx, 26.8 - lift, gx + 1.3 + dx, 32.6 - lift, fill, 1.0)
            p.ell(gx - 1.5 + dx, 31.0 - lift, gx + 2.6 + dx, 33.2 - lift, fill)
    else:
        for x, lift in ((gx - 2.6, ll), (gx + 2.6, rl)):
            p.rect(x - 1.35, 26.8 - lift, x + 1.35, 32.4 - lift, SKIN, 1.0)
            p.ell(x - 1.9, 31.0 - lift, x + 1.9, 33.3 - lift, SKIN)
    top = 16.6 + bob
    hem = 29.0 + bob * 0.3
    hi = tint(gown, 0.45)
    if view == "side":
        for y, fill in ((top + 1.6, SKIN_D),):  # the far arm, straight ahead
            p.rect(gx + 0.5, y, gx + 10.6, y + 2.2, fill, 1.1)
        p.poly(gown_shape(gx - 0.3, top, hem, 3.8, 5.6), gown)
        p.poly([(gx - 2.6, top + 2.2), (gx - 1.8, top + 1.2), (gx - 1.8, hem - 2.4), (gx - 2.9, hem - 2.6)], hi, None)
        p.line([(gx - 3.6, top + 6.2), (gx + 3.6, top + 6.2)], w=0.45)  # stitched seam
        for x in (gx - 2.2, gx, gx + 2.2):
            p.line([(x, top + 5.4), (x, top + 7.0)], w=0.4)
        p.rect(gx - 1.6, top + 2.6, gx + 4.0, top + 5.0, gown, 1.1)  # near sleeve
        p.rect(gx + 2.6, top + 3.0, gx + 10.8, top + 5.0, SKIN, 1.0)  # near arm, straight ahead
        p.circ(gx + 10.6, top + 4.0, 1.5, SKIN)
    elif view == "front":
        p.poly(gown_shape(gx, top, hem, 4.4, 6.6), gown)
        p.poly([(gx - 4.0, top + 2.2), (gx - 2.9, top + 1.4), (gx - 3.9, hem - 2.0), (gx - 5.2, hem - 2.2)], hi, None)
        p.line([(gx - 1.6, top + 0.2), (gx, top + 1.8), (gx + 1.6, top + 0.2)], w=0.45)  # collar
        p.line([(gx - 4.4, top + 6.6), (gx + 4.4, top + 6.6)], w=0.45)
        for x in (gx - 2.4, gx, gx + 2.4):
            p.line([(x, top + 5.8), (x, top + 7.4)], w=0.4)
        for sx in (-1, 1):  # puffed sleeves, both arms reaching out at you (foreshortened)
            reach = 0.6 if (f == 0 and sx == 1) or (f == 2 and sx == -1) else 0.0
            p.ell(gx + sx * 4.6 - 2.0, top + 0.6, gx + sx * 4.6 + 2.0, top + 4.6, gown)
            p.ell(gx + sx * 3.6 - 1.7, top + 2.8 - reach, gx + sx * 3.6 + 1.7, top + 5.8 - reach, SKIN_D)
            p.circ(gx + sx * 3.4, top + 4.4 - reach, 1.9, SKIN)
    else:  # back: the gown's ties, the arms out ahead of it
        for sx in (-1, 1):
            p.rect(gx + sx * 4.9 - 1.4, top + 1.2, gx + sx * 4.9 + 1.4, top + 4.4, SKIN_D, 1.0)
        p.poly(gown_shape(gx, top, hem, 4.4, 6.6), gown)
        p.poly([(gx - 4.0, top + 2.2), (gx - 2.9, top + 1.4), (gx - 3.9, hem - 2.0), (gx - 5.2, hem - 2.2)], hi, None)
        p.line([(gx, top + 1), (gx, hem - 0.6)], w=0.45)
        for y in (top + 3, top + 7):
            p.line([(gx - 1.6, y - 0.7), (gx, y), (gx + 1.6, y - 0.7)], w=0.45)
    head(p, kind, view, gx, bob)
    return p.frame()


def head(p, kind, view, gx, bob):
    hy = 9.6 + bob
    hair, hair_d = HAIR[kind]
    if view == "side":
        p.circ(gx - 3.4, hy + 1.4, 1.6, SKIN_D, INK, 0.45)  # ear, behind the hair line
    p.ell(gx - (7.6 if view == "side" else 8.6), hy - 8.2, gx + 8.6, hy + 8.0, SKIN)
    if view == "back":
        back_hair(p, kind, gx, hy, hair, hair_d)
        return
    if view == "front":
        # one sleepy dot eye with a catch-light, one X eye, blush, a tiny round groaning mouth
        p.ell(gx - 4.6, hy + 0.2, gx - 2.4, hy + 2.8, INK, None)
        p.circ(gx - 3.9, hy + 0.9, 0.42, "#ffffff", None)
        p.line([(gx + 2.3, hy + 0.1), (gx + 4.7, hy + 2.5)], w=0.65)
        p.line([(gx + 4.7, hy + 0.1), (gx + 2.3, hy + 2.5)], w=0.65)
        for x in (gx - 5.6, gx + 5.6):
            p.ell(x - 1.6, hy + 3.0, x + 1.6, hy + 4.4, BLUSH, None)
        p.ell(gx - 1.0, hy + 3.6, gx + 1.0, hy + 5.5, MOUTH, None)
        p.line([(gx - 5.6, hy - 3.2), (gx - 1.8, hy - 4.2)], w=0.45)  # forehead stitches
        for x in (gx - 4.6, gx - 3.2):
            p.line([(x, hy - 4.6), (x + 0.2, hy - 2.8)], w=0.4)
        p.rect(gx + 1.6, hy + 5.2, gx + 2.8, hy + 9.0, GOO, 0.6, None)  # goo drip off the chin
        p.circ(gx + 2.2, hy + 9.0, 0.95, GOO, None)
        p.circ(gx + 1.9, hy + 8.7, 0.3, tint(GOO, 0.6), None)
        front_hair(p, kind, gx, hy, hair, hair_d)
    else:
        p.ell(gx + 2.6, hy + 0.2, gx + 4.6, hy + 2.8, INK, None)
        p.circ(gx + 3.2, hy + 0.9, 0.42, "#ffffff", None)
        p.ell(gx + 1.0, hy + 3.0, gx + 4.0, hy + 4.4, BLUSH, None)
        p.ell(gx + 6.2, hy + 3.6, gx + 7.8, hy + 5.4, MOUTH, None)
        p.line([(gx - 0.6, hy - 4.0), (gx + 3.4, hy - 4.6)], w=0.45)
        p.line([(gx + 1.4, hy - 5.2), (gx + 1.6, hy - 3.4)], w=0.4)
        p.rect(gx + 5.4, hy + 5.0, gx + 6.6, hy + 8.8, GOO, 0.6, None)
        p.circ(gx + 6.0, hy + 8.8, 0.95, GOO, None)
        side_hair(p, kind, gx, hy, hair, hair_d)


def shine(p, x0, y0, x1, y1, a0, a1, hair):
    """The one highlight on the hair: a short pale arc."""
    p.arc(x0 + 1.4, y0 + 1.4, x1 - 0.4, y1 - 0.4, a0, a1, tint(hair, 0.65), 0.8)


def front_hair(p, kind, gx, hy, hair, hair_d):
    if kind == "epstein":  # grey, swept back off the forehead in a soft wave
        p.poly([(gx - 8.7, hy - 0.6), (gx - 8.6, hy - 4.6), (gx - 6.4, hy - 8.0), (gx - 2.0, hy - 9.4), (gx + 3.0, hy - 9.4),
                (gx + 7.0, hy - 7.6), (gx + 8.8, hy - 4.0), (gx + 8.7, hy - 0.6), (gx + 7.6, hy - 2.4), (gx + 5.4, hy - 5.2),
                (gx + 1.0, hy - 5.8), (gx - 3.2, hy - 5.0), (gx - 6.6, hy - 3.4)], hair)
        for dx in (-3.4, 0.4, 4.0):
            p.arc(gx + dx - 2.6, hy - 9.0, gx + dx + 2.6, hy - 4.8, 200, 300, hair_d, 0.5)
        shine(p, gx - 7.0, hy - 8.8, gx - 1.0, hy - 3.2, 200, 250, hair)
    elif kind == "bill_clinton":  # white, puffy, a round red nose
        for dx, dy, r in ((-6.2, -3.6, 3.2), (-3.2, -6.8, 3.6), (1.0, -7.8, 3.8), (5.0, -6.4, 3.4), (7.0, -3.2, 2.8)):
            p.circ(gx + dx, hy + dy, r, hair)
        for dx, dy in ((-3.2, -6.8), (1.0, -7.8), (5.0, -6.4)):  # the puffs' inner curls
            p.arc(gx + dx - 1.6, hy + dy - 0.4, gx + dx + 1.6, hy + dy + 2.4, 200, 340, hair_d, 0.45)
        shine(p, gx - 5.0, hy - 10.2, gx + 0.4, hy - 5.6, 200, 260, hair)
        p.circ(gx, hy + 2.2, 1.35, "#f2a0a0", INK, 0.45)
        p.circ(gx - 0.4, hy + 1.8, 0.4, "#ffffff", None)
    elif kind == "hillary_clinton":  # blonde chin-length bob with a swept fringe
        for sx in (-1, 1):
            p.poly([(gx + sx * 8.9, hy - 3.6), (gx + sx * 9.4, hy + 3.6), (gx + sx * 8.6, hy + 6.6), (gx + sx * 6.2, hy + 6.4),
                    (gx + sx * 6.6, hy + 2.6), (gx + sx * 6.4, hy - 1.6)], hair)
        p.poly([(gx - 8.9, hy - 1.6), (gx - 8.6, hy - 5.4), (gx - 6.0, hy - 8.6), (gx - 1.0, hy - 9.6), (gx + 4.0, hy - 9.0),
                (gx + 7.6, hy - 6.6), (gx + 8.9, hy - 1.6), (gx + 6.4, hy - 3.6), (gx + 2.6, hy - 4.4), (gx - 2.0, hy - 4.0),
                (gx - 5.4, hy - 2.6)], hair)
        p.line([(gx - 2.4, hy - 8.8), (gx + 3.6, hy - 4.8)], hair_d, 0.5)
        shine(p, gx - 7.6, hy - 9.0, gx - 0.6, hy - 2.6, 200, 250, hair)
    else:  # bill_gates: brown side-parted bowl and big round glasses
        p.poly([(gx - 8.7, hy - 0.4), (gx - 8.6, hy - 5.0), (gx - 6.0, hy - 8.4), (gx - 1.0, hy - 9.6), (gx + 4.0, hy - 9.0),
                (gx + 7.6, hy - 6.6), (gx + 8.8, hy - 2.6), (gx + 8.7, hy - 0.4), (gx + 7.4, hy - 3.0), (gx + 3.0, hy - 4.2),
                (gx - 1.6, hy - 4.0), (gx - 2.4, hy - 6.6), (gx - 3.6, hy - 3.6), (gx - 6.8, hy - 2.6)], hair)
        p.line([(gx - 2.4, hy - 9.4), (gx - 2.4, hy - 6.4)], hair_d, 0.5)
        shine(p, gx + 0.6, hy - 9.2, gx + 7.0, hy - 3.6, 240, 300, hair)
        for x in (gx - 3.5, gx + 3.5):
            p.circ(x, hy + 1.5, 2.6, None, INK, 0.5)
        p.line([(gx - 0.9, hy + 1.2), (gx + 0.9, hy + 1.2)], INK, 0.45)


def side_hair(p, kind, gx, hy, hair, hair_d):
    if kind == "epstein":
        p.poly([(gx - 7.6, hy + 2.4), (gx - 8.0, hy - 3.0), (gx - 6.0, hy - 7.4), (gx - 1.0, hy - 9.4), (gx + 4.0, hy - 9.0),
                (gx + 7.4, hy - 6.4), (gx + 6.0, hy - 5.2), (gx + 2.0, hy - 5.6), (gx - 2.0, hy - 4.4), (gx - 4.6, hy - 1.0),
                (gx - 5.4, hy + 2.4)], hair)
        p.arc(gx - 4.0, hy - 8.6, gx + 4.0, hy - 3.0, 190, 280, hair_d, 0.5)
        shine(p, gx - 3.0, hy - 9.0, gx + 3.6, hy - 4.0, 220, 280, hair)
    elif kind == "bill_clinton":
        for dx, dy, r in ((-4.8, -3.2, 3.4), (-1.2, -6.8, 3.6), (3.2, -7.2, 3.4), (6.2, -5.0, 2.6), (-5.6, 1.6, 2.8)):
            p.circ(gx + dx, hy + dy, r, hair)
        shine(p, gx - 3.6, hy - 10.2, gx + 1.6, hy - 5.6, 200, 270, hair)
        p.circ(gx + 8.4, hy + 2.2, 1.35, "#f2a0a0", INK, 0.45)
    elif kind == "hillary_clinton":
        p.poly([(gx - 8.2, hy + 6.4), (gx - 8.8, hy - 2.0), (gx - 6.6, hy - 7.6), (gx - 1.0, hy - 9.6), (gx + 4.4, hy - 9.0),
                (gx + 8.0, hy - 6.2), (gx + 8.6, hy - 2.6), (gx + 5.0, hy - 4.6), (gx + 0.6, hy - 4.6), (gx - 2.6, hy - 2.0),
                (gx - 2.4, hy + 6.2)], hair)
        p.line([(gx - 0.4, hy - 8.4), (gx + 4.8, hy - 5.4)], hair_d, 0.5)
        shine(p, gx - 4.6, hy - 9.0, gx + 2.2, hy - 3.0, 210, 270, hair)
    else:
        p.poly([(gx - 7.6, hy + 2.0), (gx - 8.0, hy - 3.6), (gx - 6.0, hy - 7.8), (gx - 1.0, hy - 9.6), (gx + 4.4, hy - 9.0),
                (gx + 8.0, hy - 6.0), (gx + 7.6, hy - 3.6), (gx + 3.4, hy - 4.4), (gx - 1.6, hy - 4.0), (gx - 4.4, hy - 1.0),
                (gx - 5.2, hy + 2.0)], hair)
        shine(p, gx - 3.0, hy - 9.2, gx + 3.6, hy - 4.0, 220, 280, hair)
        p.circ(gx + 4.0, hy + 1.5, 2.6, None, INK, 0.5)
        p.line([(gx + 1.4, hy + 1.2), (gx - 2.8, hy + 0.4)], INK, 0.45)


def back_hair(p, kind, gx, hy, hair, hair_d):
    if kind == "bill_clinton":
        for dx, dy, r in ((-5.4, -3.6, 3.6), (0, -6.6, 4.0), (5.4, -3.6, 3.6), (-3.8, 1.6, 3.4), (3.8, 1.6, 3.4), (0, -1.0, 3.8)):
            p.circ(gx + dx, hy + dy, r, hair)
        shine(p, gx - 4.2, hy - 10.4, gx + 1.8, hy - 5.0, 200, 260, hair)
        return
    bottom = {"epstein": 3.4, "hillary_clinton": 6.8, "bill_gates": 2.6}[kind]
    if kind != "hillary_clinton":  # the ears peep out, except under a bob
        for sx in (-1, 1):
            p.circ(gx + sx * 8.4, hy + 1.8, 1.4, SKIN_D, INK, 0.45)
    r = 8.8  # one outline: the crown's dome, straight sides, a softly rounded nape
    pts = [(gx + r * math.cos(math.radians(a)), hy - 0.4 + r * math.sin(math.radians(a))) for a in range(180, 361, 10)]
    pts += [(gx + r, hy + bottom - 1.6)]
    pts += [(gx + r * (1 - 2 * k / 8), hy + bottom - 1.6 + 1.6 * math.sin(math.pi * k / 8)) for k in range(9)]
    p.poly(pts, hair)
    p.line([(gx, hy - 8.2), (gx - 0.6, hy + bottom - 1.4)], hair_d, 0.5)
    shine(p, gx - 6.6, hy - 7.6, gx - 0.6, hy - 1.6, 200, 250, hair)


def arm(p, pts, fill=SKIN):
    """An arm as a thick rounded stroke with the plum outline, a round hand at its end."""
    p.line(pts, INK, 3.2)
    p.circ(pts[-1][0], pts[-1][1], 2.05, INK, None)
    p.line(pts, fill, 2.0)
    p.circ(pts[-1][0], pts[-1][1], 1.5, fill, None)


def dance_frame(kind, gown, move, k):
    """Front view, the clone dancing: move "floss" frame k (0-5) or "dab" frame k (0-2)."""
    p = Pen(CW, CH)
    if move == "floss":
        s = math.sin(2 * math.pi * k / 6)      # the arms' swing, -1..1
        hip = -1.1 * s                          # the hips go the other way
        bob = 0.4 if k % 3 == 0 else 0.0        # a little dip as the arms pass the body
    else:
        s, hip = 0.0, 0.0
        bob = (0.0, 0.6, 0.4)[k]
    gx = 12.0
    p.ell(5.5, 31.8, 18.5, 34, (40, 30, 50, 70), None)  # contact shadow
    for x in (gx - 2.6, gx + 2.6):  # feet planted
        p.rect(x - 1.35, 26.8, x + 1.35, 32.4, SKIN, 1.0)
        p.ell(x - 1.9, 31.0, x + 1.9, 33.3, SKIN)
    top = 16.6 + bob
    hem = 29.0 + bob * 0.3
    bx = gx + hip  # the body (gown and head) swings with the hips
    hi = tint(gown, 0.45)
    p.poly(gown_shape(bx, top, hem, 4.4, 6.6), gown)
    p.poly([(bx - 4.0, top + 2.2), (bx - 2.9, top + 1.4), (bx - 3.9, hem - 2.0), (bx - 5.2, hem - 2.2)], hi, None)
    p.line([(bx - 1.6, top + 0.2), (bx, top + 1.8), (bx + 1.6, top + 0.2)], w=0.45)  # collar
    p.line([(bx - 4.4, top + 6.6), (bx + 4.4, top + 6.6)], w=0.45)  # stitched seam
    for x in (bx - 2.4, bx, bx + 2.4):
        p.line([(x, top + 5.8), (x, top + 7.4)], w=0.4)
    for sx in (-1, 1):  # puffed sleeves at the shoulders
        p.ell(bx + sx * 4.6 - 2.0, top + 0.6, bx + sx * 4.6 + 2.0, top + 4.6, gown)
    if move == "floss":
        # both arms straight, swinging together past the hips; the far arm a shade darker
        for sx, fill in ((-1, SKIN_D), (1, SKIN)):
            sh = (bx + sx * 4.6, top + 2.6)
            hand = (gx + s * 7.6 + sx * 1.3, top + 8.6 - abs(s) * 1.2)
            arm(p, [sh, hand], fill)
        head(p, kind, "front", bx, bob)
    else:
        hy = 9.6 + bob
        if k == 0:  # wind-up: both arms out to the right, low
            head(p, kind, "front", bx, bob)
            for sx, fill in ((-1, SKIN_D), (1, SKIN)):
                arm(p, [(bx + sx * 4.6, top + 2.6), (bx + 5.5 + sx * 2.4, top + 7.0)], fill)
        else:  # the dab: the far arm straight up and out beside the head, the near arm bent across the face
            arm(p, [(bx - 5.0, top + 2.2), (bx - 10.4, hy - 6.8)], SKIN_D)
            head(p, kind, "front", bx, bob)
            arm(p, [(bx + 4.6, top + 2.6), (bx + 0.4, hy + 3.4), (bx - 5.0, hy - 1.6)], SKIN)
    return p.frame()


def clone(kind, gown):
    frames = {}
    for r, view in enumerate(("front", "side", "back")):
        for c in range(2):
            frames[(r, c)] = clone_frame(kind, gown, view, None, c)
        for f in range(4):
            frames[(r, 2 + f)] = clone_frame(kind, gown, view, f)
    for k in range(6):
        frames[(3, k)] = dance_frame(kind, gown, "floss", k)
    for k in range(3):
        frames[(4, k)] = dance_frame(kind, gown, "dab", k)
    sheet(frames, 6, 5, CW, CH).save(OUT / f"clone_{kind}.png")


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
    p = Pen(6, 8)  # a splatter droplet: the pounce's spray (clone_lab.gd particles)
    tip, cx, cy, r = (3, 0.5), 3, 5.2, 2.3
    p.circ(cx, cy, r + 0.45, INK, None)  # outline: the same teardrop, a little larger
    p.poly([(tip[0], tip[1] - 0.2), (cx - r - 0.4, cy - 0.2), (cx + r + 0.4, cy - 0.2)], INK, None)
    p.circ(cx, cy, r, "#ff8fa8", None)
    p.poly([(tip[0], tip[1] + 0.55), (cx - r + 0.05, cy - 0.1), (cx + r - 0.05, cy - 0.1)], "#ff8fa8", None)
    p.ell(cx - 1.5, cy - 1.6, cx - 0.3, cy + 0.2, "#ffd0dc", None)  # the one highlight
    p.frame().save(OUT / "gore_drop.png")
    p = Pen(10, 9)  # a pale mint puff of clone dust: where an eaten clone stood (zombie_child.gd)
    lobes = ((3.2, 4.8, 2.4), (5.4, 3.4, 2.8), (7.2, 5.0, 2.2), (5.0, 5.6, 2.2))
    for x, y, r in lobes:
        p.circ(x, y, r + 0.45, INK, None)
    for x, y, r in lobes:
        p.circ(x, y, r, "#e6f7e2", None)
    p.ell(3.9, 1.8, 5.6, 3.0, "#ffffff", None)  # the one highlight
    p.frame().save(OUT / "gore_puff.png")


if __name__ == "__main__":
    cubs()
    gore()
    for kind, gown in ORIGINALS:
        clone(kind, gown)
    print("clone children done")
