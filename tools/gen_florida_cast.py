"""Draw the Florida people as rigged sprite sheets: the Father, the Daughter and Hannah.

Usage: python3 -I tools/gen_florida_cast.py
Inputs: the canon paper-doll body turnaround (front, side, back) cut at full resolution from the
canon sheet by tools/cut_island_props.py (project/data/florida_canon.json, "bases"). Every
person is that canon body with Florida hair, clothes and props drawn over it at the sheet's
resolution in the canon line (warm-brown outline #8a5a5a, flat fills with one highlight,
dev/STYLE.md 4.3) and the Florida palette (4.4), then supersampled down (LANCZOS).
Outputs (project/assets/florida/; frame sizes in world px, the PNG holds them at
tools/florida_draw.D = 4 texture px per world px, e.g. 32x52 -> 128x208):
  npc_daughter.png / .tres     frame 32x52
  npc_stable_friend.png / .tres frame 32x52   (Hannah, cast id stable_friend)
  npc_father.png / .tres       frame 36x62
  mermaid.png / .tres          frame 36x50   (the aquarium-show mermaids)
Frame layout for the people: rows = facing: 0 front, 1 side (faces right; flip_h for left),
2 back. Columns = idle frames: 0 rest, 1 breath (one pixel lower), 2 rest, 3 blink (back row:
rest). The .tres is a SpriteFrames with idle_front, idle_side, idle_back at 3 fps.
Anchor: the frame's centre (same as the player's paper doll); feet sit on the frame's
bottom pixel row minus one.
These people stand where the scene puts them (they never walk), so idle is their whole rig.
The mermaid is the canon body from the waist up on a drawn tail, seen from the front, the tail
under the pool's water from row 31 down: row 0 idle
(tail sway, 4 frames, 4 fps), row 1 walk (swim: tail kicks and hair streams, 4 frames, 7 fps).
Deterministic: no randomness.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves tools/ off the path
import florida_draw as fd  # noqa: E402
from florida_draw import INK, Pen  # noqa: E402

VIEWS = ("front", "side", "back")


def bases():
    out = {}
    for v in VIEWS:
        im = fd.canon_base(f"body_{v}")
        if v == "side":  # the canon side view faces left; the sheet row faces right
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        out[v] = im
    return out


BASE = bases()
BW = {v: BASE[v].width for v in VIEWS}


def fx(view, x):
    """Side-view coordinates are written for the canon (left-facing) drawing; mirror them."""
    return BW[view] - x if view == "side" else x


class ViewPen(Pen):
    """A Pen in canon-base coordinates for one view (mirrored for the side view)."""

    def __init__(self, im, view, ox, oy):
        super().__init__(im, 1, fd.CANON_INK, ox, oy)
        self.view = view

    def m(self, pts):
        return [(fx(self.view, x), y) for x, y in pts]

    def P(self, pts, fill, width=7, outline=None):
        self.poly(self.m(pts), fill, width, outline)

    def E(self, x, y, rx, ry, fill, width=7, outline=None):
        self.ell(fx(self.view, x), y, rx, ry, fill, width, outline)

    def L(self, pts, fill=None, width=7):
        self.line(self.m(pts), fill, width)

    def A(self, x, y, rx, ry, a0, a1, fill=None, width=7):
        if self.view == "side":
            a0, a1 = 180 - a1, 180 - a0
        self.arc(fx(self.view, x), y, rx, ry, a0, a1, fill, width)


def skin_mask(base):
    a = np.asarray(base).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (a[..., 3] > 100) & (r > 200) & (r - b > 38) & (g < 215)


def limb_layer(base, box, exclude=None):
    """The canon arm (skin and its own outline) inside box, to lay back over the clothes."""
    x0, y0, x1, y1 = box
    sk = skin_mask(base)
    region = np.zeros_like(sk)
    region[y0:y1, x0:x1] = True
    if exclude:
        ex0, ey0, ex1, ey1 = exclude
        region[ey0:ey1, ex0:ex1] = False
    lab, n = ndimage.label(sk & region)
    if n == 0:
        return Image.new("RGBA", base.size)
    sizes = ndimage.sum(sk & region, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 400])
    a = np.asarray(base)
    dark = a[..., :3].max(axis=2) < 170
    grown = ndimage.binary_dilation(keep, iterations=9) & (keep | dark) & region
    out = a.copy()
    out[..., 3] = np.where(grown, a[..., 3], 0)
    return Image.fromarray(out, "RGBA")


def eyes(base, view):
    """Bounding boxes of the canon dot eyes (front: two, side: one, back: none)."""
    if view == "back":
        return []
    a = np.asarray(base).astype(int)
    dark = (a[..., :3].max(axis=2) < 120) & (a[..., 3] > 200)
    region = np.zeros_like(dark)
    region[108:150, 20:BW[view] - 20] = True
    lab, n = ndimage.label(dark & region)
    objs = ndimage.find_objects(lab)
    boxes = sorted(((o[1].start, o[0].start, o[1].stop, o[0].stop) for o in objs
                    if (o[0].stop - o[0].start) > 14), key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))
    return boxes[:2 if view == "front" else 1]


class Person:
    """One person: F source px per output px, frame size, and a draw(view, pen, layer) recipe."""

    name = ""
    F = 10.0
    FW, FH = 32, 52

    def behind(self, p, v):  # drawn before the canon body (pigtails, braids)
        pass

    def clothes(self, p, v):
        pass

    def arms(self, v):
        """Boxes (in canon-base coordinates, before mirroring) of arm parts that sit over clothes."""
        return {"front": [(0, 228, 60, 360), (138, 228, 200, 360)],
                "side": [(60, 228, 140, 345)],
                "back": [(0, 228, 60, 360), (138, 228, 200, 360)]}[v]

    def hair(self, p, v):
        pass

    def front_props(self, p, v):
        pass

    def render(self, v):
        W, H = round(self.FW * self.F), round(self.FH * self.F)
        base = BASE[v]
        ox = (W - base.width) / 2
        oy = H - self.F - base.height
        im = Image.new("RGBA", (W, H))
        p = ViewPen(im, v, ox, oy)
        self.behind(p, v)
        im.alpha_composite(base, (round(ox), round(oy)))
        self.clothes(p, v)
        for box in self.arms(v):
            x0, y0, x1, y1 = box
            if v == "side":
                x0, x1 = BW[v] - x1, BW[v] - x0
            im.alpha_composite(limb_layer(base, (x0, y0, x1, y1)), (round(ox), round(oy)))
        self.sleeves(p, v)
        self.hair(p, v)
        self.front_props(p, v)
        return im, (ox, oy)

    def sleeves(self, p, v):
        pass

    def blink(self, im, v, origin):
        out = im.copy()
        ox, oy = origin
        base = BASE[v]
        skin = base.getpixel((BW[v] // 2 if v == "front" else fx(v, 70), 112))
        p = Pen(out, 1, fd.CANON_INK, ox, oy)
        for x0, y0, x1, y1 in eyes(base, v):
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            p.ell(cx, cy, (x1 - x0) / 2 + 3, (y1 - y0) / 2 + 3, "#%02x%02x%02x" % skin[:3], 0)
            p.arc(cx, cy - 2, (x1 - x0) / 2 + 2, 8, 20, 160, fd.CANON_INK, 6)
        return out

    def sheet(self):
        W, H = round(self.FW * self.F), round(self.FH * self.F)
        rows = []
        for v in VIEWS:
            im, origin = self.render(v)
            breath = Image.new("RGBA", (W, H))
            breath.alpha_composite(im.resize((W, H - round(self.F)), Image.LANCZOS), (0, round(self.F)))
            blink = self.blink(im, v, origin) if v != "back" else im
            rows.append([im, breath, im, blink])
        D = fd.D
        out = Image.new("RGBA", (self.FW * 4 * D, self.FH * 3 * D))
        for r, frames in enumerate(rows):
            for c, fr in enumerate(frames):
                out.alpha_composite(fd.finish(fr, self.FW, self.FH), (c * self.FW * D, r * self.FH * D))
        fd.save(out, self.name)
        fd.write_frames(self.name, self.FW, self.FH,
                        [(f"idle_{v}", r, [0, 1, 2, 3], 3, True) for r, v in enumerate(VIEWS)])
        return out


# ------------------------------------------------------------------ shared clothing shapes

def hair_cap(p, v, fill, hi, bangs=True, cover_back=170):
    """Hair over the canon head: a cap with scalloped bangs (front), a side sweep (side) or the
    whole back of the head (back). Head ellipse is about (98, 94) r (86, 94)."""
    if v == "front":
        cx, cy, rx, ry = 98, 92, 93, 98
        pts = [(cx + rx * np.cos(t), cy + ry * np.sin(t)) for t in np.linspace(np.pi * 0.98, np.pi * 2.02, 40)]
        pts += [(191, 128), (184, 150), (172, 134), (170, 98)]
        if bangs:
            pts += [(160, 64), (146, 84), (130, 60), (113, 86), (98, 58), (82, 86), (66, 60), (50, 84), (36, 64)]
        else:
            pts += [(150, 52), (98, 40), (46, 52)]
        pts += [(26, 98), (24, 134), (12, 150), (5, 128)]
        p.P(pts, fill)
        p.E(64, 30, 26, 11, hi, 0)
        p.L([(118, 20), (110, 44)], fd.mix(fill, INK, 0.35), 4)
    elif v == "side":
        cx, cy, rx, ry = 90, 88, 92, 94
        pts = [(cx + rx * np.cos(t), cy + ry * np.sin(t)) for t in np.linspace(np.pi * 1.12, np.pi * 2.42, 44)]
        pts += [(136, cover_back), (140, 150), (142, 112), (118, 96), (96, 96), (88, 74), (72, 84),
                (60, 62), (44, 76), (30, 58), (12, 74)]
        p.P(pts, fill)
        p.E(70, 26, 26, 11, hi, 0)
    else:
        cx, cy, rx, ry = 100, 92, 94, 98
        pts = [(cx + rx * np.cos(t), cy + ry * np.sin(t)) for t in np.linspace(np.pi * 0.9, np.pi * 2.1, 44)]
        pts += [(192, 140), (178, cover_back), (158, cover_back - 10), (140, cover_back + 4), (120, cover_back - 8),
                (100, cover_back + 6), (80, cover_back - 8), (60, cover_back + 4), (42, cover_back - 10),
                (22, cover_back), (8, 140)]
        p.P(pts, fill)
        p.E(70, 34, 28, 12, hi, 0)
        p.L([(100, 4), (100, 60)], fd.mix(fill, INK, 0.35), 4)


def sun_hat(p, v, straw, band, flower=None, tails=False):
    """A wide straw sun hat with a ribbon band."""
    dark = fd.mix(straw, INK, 0.25)
    if v == "front":
        p.E(98, 34, 132, 30, straw)
        p.P([(24, 36), (34, -12), (64, -36), (98, -42), (132, -36), (162, -12), (172, 36)], straw)
        p.P([(26, 18), (170, 18), (172, 38), (24, 38)], band, 5)
        p.L([(40, 52), (156, 52)], dark, 3)
        p.E(70, -14, 18, 8, fd.mix(straw, "#ffffff", 0.5), 0)
        if flower:
            p.hibiscus(fx(v, 146), 26, 18, flower, 4)
    elif v == "side":
        p.P([(22, 30), (32, -16), (62, -40), (100, -44), (136, -32), (158, -6), (164, 30)], straw)
        p.P([(24, 12), (164, 12), (166, 32), (22, 32)], band, 5)
        p.E(92, 34, 140, 16, straw)
        p.L([(-30, 36), (210, 36)], dark, 3)
        p.E(66, -16, 18, 8, fd.mix(straw, "#ffffff", 0.5), 0)
        if flower:
            p.hibiscus(fx(v, 140), 20, 16, flower, 4)
        if tails:
            p.P([(160, 20), (196, 70), (184, 80), (152, 32)], band, 4)
    else:
        p.E(100, 34, 132, 30, straw)
        p.P([(26, 36), (36, -12), (66, -36), (100, -42), (134, -36), (164, -12), (174, 36)], straw)
        p.P([(28, 18), (172, 18), (174, 38), (26, 38)], band, 5)
        if tails:
            p.P([(96, 30), (78, 92), (92, 96), (102, 40)], band, 4)
            p.P([(104, 30), (122, 92), (108, 96), (98, 40)], band, 4)
            p.E(100, 30, 12, 9, band, 4)


def a_dress(p, v, fill, hem=388, flare=34, scallop=None):
    """Sleeveless sundress over the canon tank top, A-line from the waist."""
    if v == "front":
        top = [(62, 216), (78, 204), (90, 214), (106, 214), (118, 204), (136, 216)]
        pts = top + [(142, 288), (142 + flare, hem)] + _hem(142 + flare, 56 - flare, hem, scallop) + [(56 - flare, hem), (56, 288)]
    elif v == "side":
        pts = [(56, 208), (86, 214), (118, 204), (126, 230), (128, 288), (148, hem)] + _hem(148, 26, hem, scallop) + [(26, hem), (46, 288), (44, 236)]
    else:
        top = [(62, 210), (100, 220), (136, 210)]
        pts = top + [(142, 288), (142 + flare, hem)] + _hem(142 + flare, 56 - flare, hem, scallop) + [(56 - flare, hem), (56, 288)]
    p.P(pts, fill)


def _hem(x_right, x_left, y, scallop):
    if not scallop:
        return []
    n = 7
    out = []
    for i in range(n + 1):
        x = x_right + (x_left - x_right) * i / n
        out.append((x, y + (scallop if i % 2 else 0)))
    return out


# ------------------------------------------------------------------ the people

class Daughter(Person):
    """The Daughter: brown pigtails with pink ties, a straw sun hat with a pink ribbon and a
    hibiscus, a butter-yellow sundress with plumeria print, and her stone bucket."""
    name = "npc_daughter"
    HAIR = fd.HAIR_BROWN
    HI = fd.mix(fd.HAIR_BROWN, "#ffffff", 0.3)
    DRESS = "#ffe08a"

    def behind(self, p, v):
        if v == "front":
            for x, s in ((6, -1), (190, 1)):
                p.P([(x, 128), (x + 22 * s, 150), (x + 30 * s, 196), (x + 18 * s, 238), (x + 2 * s, 222), (x - 6 * s, 180)], self.HAIR)
                p.L([(x + 10 * s, 160), (x + 18 * s, 210)], fd.mix(self.HAIR, INK, 0.35), 4)
        elif v == "side":
            p.P([(150, 122), (176, 146), (190, 196), (178, 240), (160, 226), (148, 180)], self.HAIR)
            p.L([(166, 160), (174, 214)], fd.mix(self.HAIR, INK, 0.35), 4)
        else:
            for x, s in ((8, -1), (192, 1)):
                p.P([(x, 128), (x + 22 * s, 150), (x + 30 * s, 196), (x + 18 * s, 238), (x + 2 * s, 222), (x - 6 * s, 180)], self.HAIR)

    def clothes(self, p, v):
        a_dress(p, v, self.DRESS, scallop=8)
        dark = fd.mix(self.DRESS, INK, 0.2)
        if v != "side":
            p.L([(60, 290), (138, 290)], dark, 4)
            for x, y in ((40, 360), (84, 320), (124, 352), (156, 368), (98, 372), (70, 254), (124, 246)):
                p.plumeria(fx(v, x), y, 11, 3)
        else:
            p.L([(46, 290), (128, 290)], dark, 4)
            for x, y in ((60, 340), (110, 360), (88, 250)):
                p.plumeria(fx(v, x), y, 11, 3)
        if v == "back":
            p.E(100, 290, 16, 11, "#ff9ad0", 4)
            p.P([(96, 292), (80, 330), (94, 334)], "#ff9ad0", 4)
            p.P([(104, 292), (120, 330), (106, 334)], "#ff9ad0", 4)

    def hair(self, p, v):
        hair_cap(p, v, self.HAIR, self.HI)
        tie = "#ff9ad0"
        if v == "front":
            p.E(16, 146, 10, 10, tie, 4)
            p.E(180, 146, 10, 10, tie, 4)
        elif v == "side":
            p.E(150, 136, 10, 10, tie, 4)
        else:
            p.E(18, 146, 10, 10, tie, 4)
            p.E(182, 146, 10, 10, tie, 4)
        sun_hat(p, v, "#f6d98c", "#ff9ad0", flower=fd.HIBISCUS if v != "back" else None, tails=True)

    def front_props(self, p, v):
        if v == "back":
            return
        # her stone bucket, in the hand on the viewer's right (front) / the near hand (side)
        x, y = (168, 352) if v == "front" else (100, 336)
        p.A(x, y, 20, 18, 180, 360, None, 5)
        p.P([(x - 24, y), (x + 24, y), (x + 18, y + 40), (x - 18, y + 40)], fd.TURQ)
        p.E(x, y, 24, 7, fd.mix(fd.TURQ, INK, 0.25))
        for dx, c in ((-10, "#d8d4dc"), (2, "#c8c0cc"), (12, "#e4e0e8")):
            p.E(x + dx, y - 3, 8, 6, c, 3)
        p.L([(x + 6, y - 6), (x + 14, y - 4)], "#ffffff", 2)  # the lucky white stripe
        p.E(x - 12, y + 18, 4, 9, fd.mix(fd.TURQ, "#ffffff", 0.5), 0)


class Hannah(Person):
    """Hannah, the Daughter's friend at the stable: golden braids with pink bows, a turquoise
    pinafore over a white tee, and a pink pony brush."""
    name = "npc_stable_friend"
    HAIR = "#f2c96a"
    HI = fd.mix("#f2c96a", "#ffffff", 0.5)
    DRESS = fd.TURQ

    def behind(self, p, v):
        dark = fd.mix(self.HAIR, INK, 0.3)
        if v == "front":
            for x, s in ((14, -1), (182, 1)):
                for i in range(4):
                    y = 140 + i * 32
                    p.E(x + 6 * s, y, 18, 19, self.HAIR, 5)
                    p.L([(x + 6 * s - 8, y - 6), (x + 6 * s + 8, y + 6)], dark, 3)
        elif v == "side":
            for i in range(4):
                y = 140 + i * 32
                p.E(156, y, 18, 19, self.HAIR, 5)
                p.L([(148, y - 6), (164, y + 6)], dark, 3)
        else:
            for x, s in ((16, -1), (184, 1)):
                for i in range(4):
                    y = 140 + i * 32
                    p.E(x + 6 * s, y, 18, 19, self.HAIR, 5)
                    p.L([(x + 6 * s - 8, y - 6), (x + 6 * s + 8, y + 6)], dark, 3)

    def clothes(self, p, v):
        tee = "#ffffff"
        # white tee: little sleeves are added in sleeves(); the body shows at the collar
        if v == "front":
            p.P([(62, 214), (80, 202), (118, 202), (136, 214), (140, 260), (58, 260)], tee)
            a_dress(p, v, self.DRESS, hem=376, flare=26)
            p.P([(70, 226), (128, 226), (132, 290), (66, 290)], self.DRESS)  # bib
            p.L([(70, 228), (66, 206)], self.DRESS, 9)
            p.L([(128, 228), (132, 206)], self.DRESS, 9)
            for x in (78, 120):
                p.E(x, 236, 6, 6, "#ffe08a", 3)
            p.E(99, 262, 14, 11, fd.mix(self.DRESS, "#ffffff", 0.35), 4)  # pocket
            p.heart(99, 262, 7, fd.HEART, 2)
        elif v == "side":
            p.P([(54, 206), (90, 212), (118, 204), (126, 250), (48, 250)], tee)
            a_dress(p, v, self.DRESS, hem=376, flare=26)
        else:
            p.P([(62, 208), (100, 216), (136, 208), (140, 250), (58, 250)], tee)
            a_dress(p, v, self.DRESS, hem=376, flare=26)
            p.L([(66, 214), (130, 290)], self.DRESS, 10)
            p.L([(132, 214), (68, 290)], self.DRESS, 10)
            p.L([(66, 214), (130, 290)], INK, 2)
        p.L([(60 if v != "side" else 48, 296), (140 if v != "side" else 128, 296)], fd.mix(self.DRESS, INK, 0.25), 4)

    def sleeves(self, p, v):
        tee = "#ffffff"
        if v == "side":
            p.P([(76, 206), (120, 204), (128, 250), (82, 254)], tee)
        else:
            for x, s in ((44, 1), (154, -1)):
                p.P([(x + 18 * s, 206), (x - 4 * s, 222), (x - 14 * s, 256), (x + 14 * s, 260)], tee)

    def hair(self, p, v):
        hair_cap(p, v, self.HAIR, self.HI, bangs=True)
        band = "#ff9ad0"
        if v == "front":
            p.A(98, 92, 92, 96, 205, 335, band, 12)
            for x in (8, 188):
                p.E(x, 268, 12, 8, band, 4)
        elif v == "side":
            p.A(90, 88, 90, 92, 200, 330, band, 12)
            p.E(156, 268, 12, 8, band, 4)
        else:
            for x in (10, 190):
                p.E(x, 268, 12, 8, band, 4)

    def front_props(self, p, v):
        if v == "back":
            return
        x, y = (172, 340) if v == "front" else (96, 326)
        p.rect(fx(v, x) - 18, y - 6, fx(v, x) + 18, y + 10, "#ff9ad0", 6, 5)
        for i in range(5):
            xx = fx(v, x) - 13 + i * 6.5
            p.line([(xx, y - 6), (xx, y - 18)], "#fff1b8", 4)
        p.rect(fx(v, x) - 18, y - 6, fx(v, x) + 18, y + 10, "#ff9ad0", 6, 5)
        p.ell(fx(v, x) - 8, y - 1, 5, 3, "#ffffff", 0)


class Father(Person):
    """The Father: a fisherman, more or less. Straw hat with a turquoise band, short dark hair,
    a coral hibiscus shirt and khaki shorts. Taller than the children: the canon body drawn
    at a larger scale."""
    name = "npc_father"
    F = 8.2
    FW, FH = 36, 62
    HAIR = fd.HAIR_DARK
    SHIRT = fd.CORAL
    SHORTS = "#d9c49a"

    def clothes(self, p, v):
        dark = fd.mix(self.SHIRT, INK, 0.3)
        if v == "front":
            p.P([(54, 300), (146, 300), (152, 372), (104, 372), (100, 356), (96, 372), (48, 372)], self.SHORTS)
            p.L([(100, 304), (100, 352)], fd.mix(self.SHORTS, INK, 0.3), 4)
            p.P([(58, 212), (82, 200), (100, 228), (118, 200), (142, 212), (148, 318), (52, 318)], self.SHIRT)
            p.P([(82, 200), (100, 228), (90, 240), (74, 210)], fd.mix(self.SHIRT, "#ffffff", 0.25), 4)
            p.P([(118, 200), (100, 228), (110, 240), (126, 210)], fd.mix(self.SHIRT, "#ffffff", 0.25), 4)
            p.L([(100, 230), (100, 316)], dark, 3)
            for y in (252, 280, 306):
                p.E(104, y, 4, 4, "#ffffff", 2)
            for x, y in ((70, 262), (130, 250), (82, 300), (128, 296), (66, 228)):
                p.hibiscus(x, y, 11, "#ffffff", 3)
        elif v == "side":
            p.P([(42, 300), (128, 300), (124, 372), (48, 372)], self.SHORTS)
            p.P([(52, 210), (90, 202), (118, 204), (128, 250), (128, 318), (40, 318), (42, 250)], self.SHIRT)
            p.P([(58, 204), (86, 206), (70, 230)], fd.mix(self.SHIRT, "#ffffff", 0.25), 4)
            for x, y in ((54, 270), (100, 300), (60, 236)):
                p.hibiscus(fx(v, x), y, 11, "#ffffff", 3)
        else:
            p.P([(54, 300), (146, 300), (152, 372), (104, 372), (100, 356), (96, 372), (48, 372)], self.SHORTS)
            p.P([(58, 210), (100, 200), (142, 210), (148, 318), (52, 318)], self.SHIRT)
            p.P([(76, 200), (124, 200), (118, 214), (82, 214)], fd.mix(self.SHIRT, "#ffffff", 0.25), 4)
            for x, y in ((70, 250), (130, 262), (100, 296), (100, 236), (66, 300)):
                p.hibiscus(x, y, 11, "#ffffff", 3)

    def sleeves(self, p, v):
        if v == "side":
            p.P([(74, 206), (120, 204), (130, 262), (78, 266)], self.SHIRT)
            p.hibiscus(fx(v, 102), 236, 10, "#ffffff", 3)
        else:
            for x, s in ((44, 1), (154, -1)):
                p.P([(x + 20 * s, 204), (x - 4 * s, 220), (x - 18 * s, 264), (x + 16 * s, 270)], self.SHIRT)
                p.hibiscus(x, 240, 9, "#ffffff", 3)

    def hair(self, p, v):
        hi = fd.mix(self.HAIR, "#ffffff", 0.3)
        if v == "front":
            p.P([(8, 110), (12, 60), (40, 22), (98, 6), (156, 22), (186, 60), (190, 110), (176, 118),
                 (170, 78), (146, 62), (120, 74), (96, 60), (70, 76), (40, 70), (26, 84), (22, 118)], self.HAIR)
        elif v == "side":
            p.P([(16, 70), (40, 22), (98, 4), (160, 30), (182, 80), (176, 140), (150, 168), (138, 150),
                 (140, 110), (114, 96), (98, 96), (90, 70), (60, 74), (36, 60)], self.HAIR)
        else:
            p.P([(8, 110), (12, 60), (40, 22), (100, 6), (160, 22), (190, 60), (192, 120), (176, 160),
                 (100, 172), (24, 160), (8, 120)], self.HAIR)
        p.E(fx(v, 80), 24, 20, 8, hi, 0)
        sun_hat(p, v, "#efd08a", fd.TURQ)


MER_HAIR = "#c9a8f0"
MER_TAIL = fd.TURQ
MER_FIN = "#9fe3d6"


def mermaid_frame(sway, kick, stream):
    """sway: tail bend (-1..1); kick: fin spread; stream: hair drift (0..1)."""
    F, FW, FH = 10.0, 36, 50
    W, H = round(FW * F), round(FH * F)
    base = BASE["front"]
    torso = base.crop((0, 0, base.width, 300))
    ox, oy = (W - base.width) / 2, 30
    im = Image.new("RGBA", (W, H))
    p = ViewPen(im, "front", ox, oy)
    hair_dk = fd.mix(MER_HAIR, fd.CANON_INK, 0.3)
    # long hair behind, streaming back and out
    for s in (-1, 1):
        x0 = 98 + s * 80
        wave = [(x0, 110), (x0 + s * (26 + stream * 14), 170), (x0 + s * (10 + stream * 20), 240),
                (x0 + s * (30 + stream * 24), 300), (x0 + s * (4 + stream * 10), 330), (x0 - s * 30, 250), (x0 - s * 26, 150)]
        p.P(wave, MER_HAIR)
        p.L([(x0 + s * 6, 160), (x0 + s * (8 + stream * 10), 240), (x0 + s * (14 + stream * 12), 300)], hair_dk, 5)
    # tail: from the hips down, bending with the sway, fin at the end
    pts_l, pts_r = [], []
    for i in range(13):
        t = i / 12
        cx = 98 + math.sin(t * math.pi * 0.9) * sway * 34 * t
        half = 54 * (1 - t) ** 0.8 + 12
        y = 280 + t * 150
        pts_l.append((cx - half, y))
        pts_r.append((cx + half, y))
    tip_x, tip_y = (pts_l[-1][0] + pts_r[-1][0]) / 2, pts_l[-1][1]
    spread = 46 + kick * 22
    fin = [(tip_x, tip_y - 8), (tip_x + spread, tip_y + 30 + kick * 10), (tip_x + spread * 0.55, tip_y + 46),
           (tip_x, tip_y + 26), (tip_x - spread * 0.55, tip_y + 46), (tip_x - spread, tip_y + 30 - kick * 10)]
    p.P(fin, MER_FIN)
    p.L([(tip_x, tip_y + 4), (tip_x + spread * 0.6, tip_y + 34)], fd.mix(MER_FIN, fd.CANON_INK, 0.25), 4)
    p.L([(tip_x, tip_y + 4), (tip_x - spread * 0.6, tip_y + 34)], fd.mix(MER_FIN, fd.CANON_INK, 0.25), 4)
    im.alpha_composite(torso, (round(ox), round(oy)))
    p.P(pts_l + list(reversed(pts_r)), MER_TAIL)
    scale = fd.mix(MER_TAIL, "#ffffff", 0.35)
    for i in range(2, 11, 2):
        a, b = pts_l[i], pts_r[i]
        for k in range(1, 4):
            x = a[0] + (b[0] - a[0]) * k / 4
            p.A(x, a[1] - 4, 10, 8, 20, 160, scale, 4)
    p.E(70, 320, 10, 30, fd.alpha("#ffffff", 0x70), 0)
    # scalloped waistband where tail meets skin, and a shell top
    p.L([(46, 286), (150, 286)], fd.mix(MER_TAIL, fd.CANON_INK, 0.3), 9)
    # skin over the canon tank top (the canon body's own skin tone)
    p.P([(56, 210), (142, 210), (146, 284), (52, 284)], "#f9cfb9", 0)
    for x in (76, 120):
        p.P([(x - 24, 254), (x - 20, 222), (x, 212), (x + 20, 222), (x + 24, 254)], "#ffb3c8")
        for dx in (-12, 0, 12):
            p.L([(x, 252), (x + dx, 222)], fd.mix("#ffb3c8", fd.CANON_INK, 0.25), 3)
    for box in ((0, 228, 60, 300), (138, 228, 200, 300)):
        im.alpha_composite(limb_layer(base, box), (round(ox), round(oy)))
    # hair over the head: centre part, front locks over the shoulders, a shell clip
    hair_cap(p, "front", MER_HAIR, fd.mix(MER_HAIR, "#ffffff", 0.45), bangs=False)
    for s in (-1, 1):
        x0 = 98 + s * 84
        p.P([(x0, 100), (x0 + s * 14, 150), (x0 - s * 4, 214), (x0 + s * 8, 262), (x0 - s * 18, 236), (x0 - s * 20, 150)], MER_HAIR)
    p.E(150, 50, 13, 12, "#ffe08a", 5)
    p.L([(150, 42), (150, 60)], fd.mix("#ffe08a", fd.CANON_INK, 0.3), 3)
    return in_water(fd.finish(im, FW, FH), 31)


def in_water(img, waterline, tint="#58b8dc"):
    """Below the waterline the tail shows through the pool water: blended toward its blue,
    fading in over three rows (waterline and rows in world px)."""
    px = img.load()
    t = fd.rgb(tint)
    for y in range(waterline * fd.D, img.height):
        k = min(1.0, (y - waterline * fd.D + 1) / (3 * fd.D)) * 0.45
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (round(r + (t[0] - r) * k), round(g + (t[1] - g) * k), round(b + (t[2] - b) * k), a)
    return img


def mermaid():
    rows = [[mermaid_frame(0.2, 0.0, 0.2), mermaid_frame(0.45, 0.3, 0.3), mermaid_frame(0.2, 0.0, 0.2), mermaid_frame(-0.1, 0.2, 0.1)],
            [mermaid_frame(-0.6, 0.0, 0.6), mermaid_frame(0.1, 1.0, 1.0), mermaid_frame(0.7, 0.2, 0.7), mermaid_frame(0.1, 0.8, 0.9)]]
    D = fd.D
    out = Image.new("RGBA", (36 * 4 * D, 50 * 2 * D))
    for r, frames in enumerate(rows):
        for c, fr in enumerate(frames):
            out.alpha_composite(fr, (c * 36 * D, r * 50 * D))
    fd.save(out, "mermaid")
    fd.write_frames("mermaid", 36, 50, [("idle", 0, [0, 1, 2, 3], 4, True), ("walk", 1, [0, 1, 2, 3], 7, True)])
    return out


def main():
    print("mermaid", mermaid().size)
    for cls in (Daughter, Hannah, Father):
        out = cls().sheet()
        print(cls.name, out.size)


if __name__ == "__main__":
    main()
