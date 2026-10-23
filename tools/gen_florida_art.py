"""Draw the tropical Florida Keys art: the beach, garden (the house and its yard) and aquarium
backgrounds, the Father, the Daughter, Hannah, the critters, the mermaid and the garden props.

Usage: python3 -I tools/gen_florida_art.py
Writes project/assets/placeholder/ (the same file names the scenes already load):
bg_florida_beach.png, bg_florida_garden.png, bg_florida_aquarium.png, npc_father.png,
npc_daughter.png, npc_stable_friend.png, crab.png, gull.png, dolphin.png, mermaid.png,
shell.png, seed_bag.png, craft_bench.png, plot_empty.png, plot_growing.png, plot_ready.png.

People are built from the canon art so they match the rest of the cast: the Daughter, Hannah
and the mermaid are the canon paper-doll body (assets/canon/body_base.png) with a canon hair
part, recoloured, and Florida clothes drawn on top; the Father is the canon man
(npc_drone_front.png) in a coral hibiscus shirt and a straw hat. Everything else is drawn in the
kawaii sticker look of prompts/STYLE.md 4.3 (warm-brown outline #8a5a5a, flat fills with one
highlight, dot eyes with a catch-light, pink blush) in the Florida palette of 4.4: sea blue,
turquoise, foam, coral, hibiscus, bougainvillea, key lime, mango, plumeria, coconut.
Florida is the most saturated world and nothing in it is wrong.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "project/assets/placeholder"
CANON = ROOT / "project/assets/canon"
INK = "#8a5a5a"
BLUSH = "#ff9fb8"
K = 4

SEA = "#80b0d0"
TURQ = "#70d0c0"
FOAM = "#e0f0f0"
CORAL = "#f08060"
HIBISCUS = "#ff9ad0"
BOUG = "#e0408a"
LIME = "#d8f07a"
MANGO = "#ffb347"
PLUMERIA = "#fff1b8"
COCONUT = "#b08a5a"
LEAF = "#7cc46a"
LEAF_DK = "#5aa85a"
SAND = "#f6e2b0"
SAND_DK = "#ead09a"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


class Pen:
    """Draws at S times the output size; every coordinate is given in output pixels."""

    def __init__(self, im, s):
        self.im, self.s, self._d = im, s, ImageDraw.Draw(im)
        self._overlay = None

    @property
    def d(self):
        return self._overlay[1] if self._overlay else self._d

    def _begin(self, fill):
        """Translucent fills (shadows, glare, bubbles) are drawn on an overlay and blended."""
        alpha = None
        if isinstance(fill, str) and len(fill) == 9:
            alpha = int(fill[7:], 16)
        elif isinstance(fill, tuple) and len(fill) == 4:
            alpha = fill[3]
        if alpha is not None and alpha < 255 and self.im.mode == "RGBA":
            ov = Image.new("RGBA", self.im.size)
            self._overlay = (ov, ImageDraw.Draw(ov))
        return self

    def _end(self):
        if self._overlay:
            self.im.alpha_composite(self._overlay[0])
            self._overlay = None

    def _w(self, width):
        return max(1, round(width * self.s)) if width else 0

    def ell(self, x, y, rx, ry, fill, width=1.0, outline=INK):
        s = self.s
        self._begin(fill).d.ellipse([(x - rx) * s, (y - ry) * s, (x + rx) * s, (y + ry) * s], fill=fill,
                                    outline=outline if width else None, width=self._w(width))
        self._end()

    def rect(self, x0, y0, x1, y1, fill, rad=0, width=1.0, outline=INK):
        s = self.s
        self._begin(fill).d.rounded_rectangle([x0 * s, y0 * s, x1 * s, y1 * s], rad * s, fill=fill,
                                              outline=outline if width else None, width=self._w(width))
        self._end()

    def poly(self, pts, fill, width=1.0, outline=INK):
        self._begin(fill).d.polygon([(x * self.s, y * self.s) for x, y in pts], fill=fill,
                                    outline=outline if width else None, width=self._w(width))
        self._end()

    def line(self, pts, fill=INK, width=1.0):
        self._begin(fill).d.line([(x * self.s, y * self.s) for x, y in pts], fill=fill, width=self._w(width), joint="curve")
        self._end()

    def arc(self, x0, y0, x1, y1, a0, a1, fill=INK, width=1.0):
        s = self.s
        self.d.arc([x0 * s, y0 * s, x1 * s, y1 * s], a0, a1, fill=fill, width=self._w(width))

    def chord(self, x0, y0, x1, y1, a0, a1, fill, width=1.0):
        s = self.s
        self.d.chord([x0 * s, y0 * s, x1 * s, y1 * s], a0, a1, fill=fill, outline=INK, width=self._w(width))

    def face(self, x, y, sc=1.0):
        for dx in (-3.2, 3.2):
            self.ell(x + dx * sc, y, 1.1 * sc, 1.2 * sc, INK, 0)
            self.ell(x + dx * sc + 0.35 * sc, y - 0.45 * sc, 0.4 * sc, 0.4 * sc, "#ffffff", 0)
        self.arc(x - 1.5 * sc, y - 0.2 * sc, x + 1.5 * sc, y + 2.6 * sc, 20, 160, INK, 0.7 * sc)
        for dx in (-5.3, 5.3):
            self.ell(x + dx * sc, y + 2 * sc, 1.5 * sc, 0.9 * sc, BLUSH, 0)

    def sparkle(self, x, y, r, fill="#ffffff", outline=None):
        pts = [(x, y - r), (x + r * 0.28, y - r * 0.28), (x + r, y), (x + r * 0.28, y + r * 0.28), (x, y + r),
               (x - r * 0.28, y + r * 0.28), (x - r, y), (x - r * 0.28, y - r * 0.28)]
        self.poly(pts, fill, 0.5 if outline else 0, outline or INK)

    def hibiscus(self, x, y, r, color=HIBISCUS):
        for a in range(5):
            ang = a * 2 * math.pi / 5 - math.pi / 2
            self.ell(x + r * 0.62 * math.cos(ang), y + r * 0.62 * math.sin(ang), r * 0.55, r * 0.55, color, 0.8)
        self.ell(x, y, r * 0.28, r * 0.28, "#ffe27a", 0)

    def plumeria(self, x, y, r):
        for a in range(5):
            ang = a * 2 * math.pi / 5
            self.ell(x + r * 0.55 * math.cos(ang), y + r * 0.55 * math.sin(ang), r * 0.5, r * 0.38, "#ffffff", 0.6)
        self.ell(x, y, r * 0.3, r * 0.3, "#ffd36e", 0)


def canvas(w, h, s=K, bg=(0, 0, 0, 0)):
    im = Image.new("RGBA", (w * s, h * s), bg)
    return im, Pen(im, s)


def save(im, w, h, name, rgb_only=False):
    out = im.resize((w, h), Image.LANCZOS)
    if rgb_only:
        out = out.convert("RGB")
    out.save(OUT / f"{name}.png")
    return out


# ---------------------------------------------------------------- people

def canon(name):
    return Image.open(CANON / f"{name}.png").convert("RGBA")


def recolor(part, target, keep_dark=True):
    """Recolour a canon part to `target`, keeping its shading (relative luminance) and line art."""
    src = part.load()
    out = part.copy()
    dst = out.load()
    tr, tg, tb = rgb(target)
    lums = [(0.3 * r + 0.59 * g + 0.11 * b) / 255 for r, g, b, a in part.getdata() if a > 200]
    fills = [v for v in lums if v >= 0.33] or [0.5]
    mean = sum(fills) / len(fills)
    for y in range(part.height):
        for x in range(part.width):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            if keep_dark and lum < 0.33:  # outline: warm it slightly, keep it dark
                dst[x, y] = (int(r * 0.9 + 20), int(g * 0.8), int(b * 0.8), a)
                continue
            f = max(0.6, min(1.35, 1 + (lum / mean - 1) * 1.2))
            dst[x, y] = (min(255, int(tr * f)), min(255, int(tg * f)), min(255, int(tb * f)), a)
    return out


def doll(hair, hair_color, clothes, extras_front=None):
    """Canon body + recoloured canon hair + drawn clothes, on the 91x96 paper-doll frame."""
    base = Image.new("RGBA", (91 * K, 96 * K))
    body = canon("body_base").resize((91 * K, 96 * K), Image.LANCZOS)
    base.alpha_composite(body)
    p = Pen(base, K)
    clothes(p)
    h = recolor(canon(hair), hair_color).resize((91 * K, 96 * K), Image.LANCZOS)
    base.alpha_composite(h)
    if extras_front:
        extras_front(Pen(base, K))
    return base


def finish_person(big, height, name):
    """Trim to the drawn figure and scale so it stands `height` px tall (feet at the bottom)."""
    box = big.getbbox()
    fig = big.crop(box)
    w = max(1, round(fig.width * height / fig.height))
    out = fig.resize((w, height), Image.LANCZOS)
    out.save(OUT / f"{name}.png")
    return out


def sun_hat(p, color, band, cx=46, top=1):
    p.ell(cx, top + 12, 31, 7, color, 1.4)
    p.chord(cx - 17, top, cx + 17, top + 24, 180, 360, color, 1.4)
    p.line([(cx - 16, top + 10), (cx + 16, top + 10)], band, 3)
    p.arc(cx - 26, top + 7, cx + 26, top + 17, 10, 170, mix(color, INK, 0.25), 0.8)


def sundress(p, color, trim, flowers=None):
    # straps, bodice, a flared skirt to the knee
    for x in (40, 52):
        p.line([(x, 51), (x, 56)], color, 2.4)
    p.poly([(36, 56), (56, 56), (59, 66), (67, 82), (25, 82), (33, 66)], color, 1.2)
    p.line([(26, 80), (66, 80)], trim, 2)
    p.line([(35, 64), (57, 64)], mix(color, INK, 0.2), 1)
    if flowers:
        for fx, fy in flowers:
            p.hibiscus(fx, fy, 3.2, "#ffffff" if color != "#ffffff" else HIBISCUS)


def daughter():
    def clothes(p):
        sundress(p, "#ffd36e", "#ffffff", [(38, 72), (52, 75), (45, 69)])

    def front(p):
        sun_hat(p, PLUMERIA, HIBISCUS)
        p.hibiscus(62, 11, 4.5)
        # her stone bucket (two hundred stones, keeps fifty)
        p.poly([(64, 66), (78, 66), (76, 80), (66, 80)], "#70d0c0", 1.2)
        p.arc(64, 58, 78, 74, 180, 360, INK, 1.2)
        for sx, sy in ((68, 66), (72, 65), (75, 67)):
            p.ell(sx, sy, 2, 1.4, "#c8c0b8", 0.6)
        p.line([(70.5, 65), (73.5, 65)], "#ffffff", 0.7)
        p.line([(65, 72), (77, 72)], "#ffffff", 1.2)

    big = doll("hair_pigtails", "#a8703e", clothes, front)
    return finish_person(big, 40, "npc_daughter")


def hannah():
    def clothes(p):
        sundress(p, TURQ, "#ffffff", [(40, 74), (53, 71)])

    def front(p):
        sun_hat(p, "#fff6dc", BOUG)
        # the pink pony brush in her hand
        p.rect(66, 62, 82, 69, HIBISCUS, 2.5, 1.2)
        for bx in range(68, 81, 3):
            p.line([(bx, 69), (bx, 72)], "#fff1e6", 1.2)

    big = doll("hair_braids", "#f2c45a", clothes, front)
    return finish_person(big, 40, "npc_stable_friend")


def mermaid():
    def clothes(p):
        # shell top
        for x in (40, 52):
            p.ell(x, 59, 5, 4, "#ffb0c8", 1)
            p.line([(x - 3, 57), (x, 62), (x + 3, 57)], "#ff86a8", 0.6)

    def front(p):
        # a turquoise tail in place of the legs, curling to a fin
        p.poly([(31, 66), (61, 66), (60, 78), (54, 88), (50, 92), (42, 92), (36, 86), (32, 76)], TURQ, 1.3)
        for i, y in enumerate((72, 78, 84)):
            for x in range(36 + i * 2, 58 - i * 2, 6):
                p.arc(x - 3, y - 3, x + 3, y + 3, 10, 170, mix(TURQ, INK, 0.25), 0.7)
        p.poly([(46, 90), (30, 96), (36, 89), (46, 88), (56, 89), (62, 96)], "#a8e8dc", 1.2)
        p.hibiscus(31, 22, 5, "#c8a0f0")
        for bx, by, r in ((74, 30, 3), (79, 20, 2), (72, 14, 1.6)):
            p.ell(bx, by, r, r, "#e8fbff", 0.6, "#80b0d0")

    big = doll("hair_braids", "#b898ec", clothes, None)
    # hide the legs under the tail: clear everything below the hips first
    px = big.load()
    for y in range(75 * K, 96 * K):
        for x in range(91 * K):
            px[x, y] = (0, 0, 0, 0)
    front(Pen(big, K))
    return finish_person(big, 40, "mermaid")


def father():
    """The canon man in a coral hibiscus shirt, rolled khaki trousers and a straw fishing hat,
    holding a flat skipping stone."""
    src = canon("npc_drone_front")
    S = 8
    big = src.resize((src.width * S, src.height * S), Image.NEAREST)
    px = big.load()
    w, h = big.size
    for y in range(int(19 * S), int(34 * S)):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            # the beige work shirt: light, low-saturation pixels
            if r > 140 and r - b < 60 and g > 120:
                lum = (r + g + b) / 765
                c = rgb(CORAL)
                f = 0.75 + (lum - 0.62) * 1.6
                px[x, y] = (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)), a)
    for y in range(int(33 * S), h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            if 100 < r < 200 and r - b < 80 and r > g:  # brown work trousers -> khaki
                lum = (r + g + b) / 765
                c = rgb("#e6cf98")
                f = 0.7 + (lum - 0.38) * 1.4
                px[x, y] = (min(255, int(c[0] * f)), min(255, int(c[1] * f)), min(255, int(c[2] * f)), a)
    p = Pen(big, S)
    for fx, fy in ((7.5, 24), (14.5, 27), (10.5, 30.5), (16, 22.5)):  # hibiscus print
        for a in range(5):
            ang = a * 2 * math.pi / 5
            p.ell(fx + 0.9 * math.cos(ang), fy + 0.9 * math.sin(ang), 0.7, 0.7, "#fff1e6", 0)
        p.ell(fx, fy, 0.35, 0.35, "#ffd36e", 0)
    # straw fishing hat
    p.ell(11, 6.2, 11.5, 2.4, "#f2d58a", 0.4)
    p.chord(4.6, 0.2, 17.4, 11.6, 180, 360, "#f2d58a", 0.4)
    p.line([(4.9, 5.0), (17.1, 5.0)], "#70d0c0", 1.0)
    p.arc(2, 4.2, 20, 8.2, 15, 165, "#c9a85a", 0.25)
    # flat grey skipping stone in his hand
    p.ell(20.2, 32, 1.8, 1.1, "#c8c0b8", 0.35)
    p.line([(19, 31.8), (21.4, 31.8)], "#ffffff", 0.3)
    canvas_big = Image.new("RGBA", (26 * S, 50 * S))
    canvas_big.alpha_composite(big, (2 * S, 2 * S))
    res = canvas_big.resize((26, 50), Image.LANCZOS)
    res = res.crop(res.getbbox())
    res.save(OUT / "npc_father.png")
    return res


# ---------------------------------------------------------------- critters and props

def crab():
    im, p = canvas(22, 16)
    for side in (-1, 1):
        for i in range(3):
            x0 = 11 + side * (4 + i * 1.6)
            p.line([(x0, 10), (x0 + side * 3, 13.5 + i * 0.3)], INK, 1.3)
            p.line([(x0, 10), (x0 + side * 3, 13.5 + i * 0.3)], CORAL, 0.6)
        p.line([(11 + side * 5, 8), (11 + side * 8, 5)], INK, 1.4)
        p.ell(11 + side * 8.6, 4, 2.4, 2.2, CORAL, 0.7)
        p.line([(11 + side * 8.6, 3), (11 + side * 10.5, 2)], INK, 0.6)
        p.line([(11 + side * 2.2, 6.5), (11 + side * 2.6, 3.5)], INK, 0.7)
        p.ell(11 + side * 2.6, 3, 1.2, 1.2, "#ffffff", 0.6)
        p.ell(11 + side * 2.6, 3.1, 0.55, 0.6, INK, 0)
    p.ell(11, 9, 6.5, 4.4, CORAL, 0.8)
    p.ell(9.2, 7.4, 2, 0.9, "#ffb49a", 0)
    p.arc(9.5, 8.6, 12.5, 11, 20, 160, INK, 0.5)
    for dx in (-3.6, 3.6):
        p.ell(11 + dx, 10.2, 1.1, 0.6, BLUSH, 0)
    save(im, 22, 16, "crab")


def gull():
    im, p = canvas(22, 20)
    p.line([(9, 15), (9, 19)], "#ffb347", 0.8)
    p.line([(12, 15), (12, 19)], "#ffb347", 0.8)
    p.ell(10.5, 12, 6.5, 4.6, "#ffffff", 0.8)
    p.poly([(4.5, 10), (12, 9.5), (14, 13), (6, 14)], "#c9d6e0", 0.7)
    p.poly([(3, 11), (5.5, 10.5), (5, 13.5)], "#8a98a8", 0.6)
    p.ell(15, 7, 4, 3.8, "#ffffff", 0.8)
    p.poly([(18.4, 6.6), (21.8, 7.6), (18.4, 8.8)], "#ffb347", 0.6)
    p.ell(16.2, 6.3, 0.75, 0.85, INK, 0)
    p.ell(16.4, 6.0, 0.28, 0.28, "#ffffff", 0)
    p.ell(16.6, 8.6, 1.1, 0.6, BLUSH, 0)
    save(im, 22, 20, "gull")


def dolphin():
    """A round bottlenose dolphin mid-leap: curved back, short beak, big smile."""
    im, p = canvas(44, 26)
    p.poly([(6, 9), (1, 3.5), (3, 9.5), (1, 15), (6, 11.5)], "#7aa8d8", 0.8)  # tail flukes
    body = []
    for i in range(0, 181, 10):  # a curved, plump body arcing over the water
        t = math.radians(i)
        body.append((6 + 30 * (1 - math.cos(t)) / 2 * 1.0 + 0.0, 10.5 - 6.5 * math.sin(t)))
    lower = [(36, 16.5), (30, 19.5), (20, 19.5), (11, 15.5), (6, 11.5)]
    p.poly(body + [(38, 9), (43, 11.5), (42.5, 13), (37.5, 14)] + lower, "#8cc4ec", 1)
    p.poly([(12, 15.2), (20, 18.2), (30, 18.2), (36.5, 14.6), (31, 15.6), (20, 15.8)], "#eaf6ff", 0)
    p.poly([(18, 5.2), (21, 0.8), (25.5, 4.2)], "#7aa8d8", 0.8)  # dorsal fin
    p.poly([(24, 17.5), (21.5, 23.5), (28.5, 18.5)], "#7aa8d8", 0.8)  # flipper
    p.ell(32.6, 9.4, 1.15, 1.25, INK, 0)
    p.ell(33.0, 8.9, 0.42, 0.42, "#ffffff", 0)
    p.arc(35, 9.8, 42.6, 14.2, 20, 160, INK, 0.6)
    p.ell(34.0, 12.2, 1.5, 0.85, BLUSH, 0)
    p.ell(18, 6.8, 5, 1.1, "#c4e4fa", 0)
    for x, y, r in ((40, 3, 1.2), (37, 1.5, 0.8)):
        p.ell(x, y, r, r, "#e8fbff", 0.5, "#80b0d0")
    save(im, 44, 26, "dolphin")


def shell():
    im, p = canvas(14, 13)
    p.poly([(7, 1), (13, 5.5), (11.5, 10.5), (7, 12), (2.5, 10.5), (1, 5.5)], "#ffd2dc", 0.8)
    for x in (3.5, 5.3, 7, 8.7, 10.5):
        p.line([(7, 11.2), (x, 3.2 + abs(x - 7) * 0.5)], "#f7a0b8", 0.55)
    p.rect(5, 10.5, 9, 12.6, "#ffc0cf", 0.8, 0.6)
    p.ell(5, 4.6, 1, 0.7, "#ffffff", 0)
    save(im, 14, 13, "shell")


def seed_bag():
    im, p = canvas(22, 26)
    p.poly([(4, 7), (18, 7), (20, 23), (11, 25), (2, 23)], "#f2d58a", 1)
    p.poly([(5, 4), (17, 4), (18, 8), (4, 8)], "#e0b860", 1)
    p.line([(4.5, 8.4), (17.5, 8.4)], BOUG, 1.4)
    p.ell(11, 16, 5.5, 5.5, "#fff6dc", 0.8)
    p.hibiscus(11, 16, 4)
    p.line([(11, 4), (9, 0.8)], LEAF_DK, 0.9)
    p.ell(8.6, 1.4, 1.6, 1, LEAF, 0.5)
    for sx, sy in ((5, 21), (16.5, 20), (14, 23)):
        p.ell(sx, sy, 0.7, 0.5, "#b08a5a", 0)
    save(im, 22, 26, "seed_bag")


def craft_bench():
    im, p = canvas(44, 32)
    for x in (6, 38):
        p.rect(x - 2, 14, x + 2, 31, "#c98f5a", 1, 0.9)
    p.rect(3, 20, 41, 23, "#d9a26a", 1, 0.8)
    p.rect(1, 10, 43, 16, "#e8b47c", 2, 1)
    p.line([(4, 12), (40, 12)], "#f6cf9c", 0.8)
    # what's on the bench: a jar of shells, flowers, a lime and a mango, string for garlands
    p.rect(7, 2, 14, 11, "#dff6f6", 1.5, 0.8)
    p.ell(9.4, 8, 1.6, 1.2, "#ffd2dc", 0.4)
    p.ell(11.6, 6, 1.4, 1, "#ffe0b0", 0.4)
    p.hibiscus(19, 8, 3.2)
    p.plumeria(25, 9, 2.8)
    p.ell(31, 9, 2.4, 2.2, LIME, 0.7)
    p.ell(36.5, 8.6, 3, 2.6, MANGO, 0.7)
    p.ell(35.6, 7.6, 0.9, 0.6, "#fff0c8", 0)
    p.line([(13, 14), (22, 14.6), (30, 13.8)], BOUG, 0.6)
    p.ell(22, 26, 5.5, 4, "#fff1e6", 0.8)  # a basket of crafts underneath
    p.hibiscus(20, 24.5, 2.2)
    p.ell(24.4, 25, 1.4, 1, "#ffd2dc", 0.4)
    save(im, 44, 32, "craft_bench")


def plots():
    def base():
        im, p = canvas(34, 26)
        p.rect(1, 6, 33, 25, "#c98f5a", 3, 1)
        p.rect(3, 8, 31, 22.5, "#8a5e3c", 2.5, 0)
        for y in (11, 15, 19):
            p.line([(5, y), (29, y)], "#9e6f48", 1)
            p.line([(5, y + 0.9), (29, y + 0.9)], "#764e30", 0.5)
        return im, p

    im, p = base()
    for x, y in ((8, 13), (17, 17), (25, 12)):
        p.ell(x, y, 0.8, 0.6, "#c9a070", 0)
    save(im, 34, 26, "plot_empty")
    im, p = base()
    for x in (10, 17, 24):
        p.line([(x, 17), (x, 12)], LEAF_DK, 1)
        p.ell(x - 2.2, 11, 2.4, 1.3, LEAF, 0.6)
        p.ell(x + 2.2, 10.4, 2.4, 1.3, LEAF, 0.6)
    save(im, 34, 26, "plot_growing")
    im, p = base()
    for x in (17, 9, 25):
        p.line([(x, 18), (x, 8)], LEAF_DK, 1.2)
        p.ell(x - 3, 13, 3, 1.5, LEAF, 0.6)
        p.ell(x + 3, 12, 3, 1.5, LEAF, 0.6)
    p.hibiscus(9, 6, 4)
    p.hibiscus(25, 6, 4, BOUG)
    p.hibiscus(17, 4.5, 4.4, MANGO)
    p.sparkle(30, 2.5, 2.2, "#fff3a8", "#e0b24a")
    save(im, 34, 26, "plot_ready")


# ---------------------------------------------------------------- shared scenery

BG_S = 2  # backgrounds are drawn at 2x and scaled down to 960x540


def palm(p, x, y, lean=1, height=120, scale=1.0):
    """A friendly palm: bumpy coconut-brown trunk, a crown of leaves, three coconuts."""
    hgt = height * scale
    top = (x + 22 * lean * scale, y - hgt)
    p.ell(x, y + 2, 20 * scale, 6 * scale, "#00000022", 0)
    n = int(10 * scale) + 4
    for i in range(n):
        t = i / (n - 1)
        cx = x + 22 * lean * scale * t * t
        cy = y - hgt * t
        rr = (9 - 3 * t) * scale
        p.ell(cx, cy, rr, 7 * scale, COCONUT if i % 2 else "#c09a68", 1.5)
    for ang in (-175, -140, -105, -75, -40, -5, 155, 25):
        a = math.radians(ang)
        tip = (top[0] + 60 * scale * math.cos(a), top[1] + 34 * scale * math.sin(a) + 20 * scale)
        mid = (top[0] + 28 * scale * math.cos(a), top[1] + 16 * scale * math.sin(a) - 6 * scale)
        side = (-math.sin(a) * 15 * scale, math.cos(a) * 10 * scale)
        col = LEAF if ang % 2 else LEAF_DK
        p.poly([top, (mid[0] + side[0], mid[1] + side[1]), tip, (mid[0] - side[0], mid[1] - side[1])], col, 1.5)
        p.line([top, mid, tip], mix(col, INK, 0.3), 1)
    for dx, dy in ((-6, 6), (5, 7), (0, 12)):
        p.ell(top[0] + dx * scale, top[1] + dy * scale, 5 * scale, 5 * scale, "#9a6a3a", 1.5)


def bush(p, x, y, r, flower=HIBISCUS, n=3, seed=0):
    rnd = random.Random(seed)
    p.ell(x, y + r * 0.5, r * 1.3, r * 0.35, "#00000018", 0)
    for dx, dy, rr in ((-r * 0.6, 0, r * 0.7), (r * 0.6, 0, r * 0.7), (0, -r * 0.35, r * 0.8)):
        p.ell(x + dx, y + dy, rr, rr * 0.85, LEAF, 1.5)
    p.ell(x - r * 0.3, y - r * 0.55, r * 0.3, r * 0.15, "#a8e090", 0)
    for i in range(n):
        p.hibiscus(x + rnd.uniform(-r, r) * 0.9, y + rnd.uniform(-r * 0.8, r * 0.2), max(4, r * 0.28), flower)


def sand_texture(p, rnd, x0, y0, x1, y1, n):
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        c = rnd.choice([SAND_DK, "#fff4d6", "#e8c890", "#f0d8a8"])
        p.ell(x, y, rnd.uniform(0.8, 1.8), rnd.uniform(0.6, 1.2), c, 0)


def gradient(im, y0, y1, top, bottom, s):
    d = ImageDraw.Draw(im)
    for y in range(int(y0 * s), int(y1 * s)):
        t = (y - y0 * s) / max(1, (y1 - y0) * s)
        d.line([(0, y), (im.width, y)], fill=mix(top, bottom, t))


def wave_edge(p, y, amp, period, x0, x1, fill, phase=0.0):
    pts = [(x0, -10)]
    x = x0
    while x <= x1:
        pts.append((x, y + amp * math.sin((x / period) * 2 * math.pi + phase)))
        x += 4
    pts.append((x1, -10))
    p.poly(pts, fill, 0)


# ---------------------------------------------------------------- beach

def beach_bg():
    """Shoreline seen from above: turquoise sea across the top (the dolphins swim at y 70-180),
    a foam line, then warm sand where everyone walks (nav from y 230). Paths and props mark the
    doors: the garden arbour (x 120), the stable path (x 300), the aquarium pavilion (x 840) and
    the little jetty with the boat back to the island (x 480, y 380)."""
    w, h = 960, 540
    rnd = random.Random(7)
    im = Image.new("RGBA", (w * BG_S, h * BG_S), SAND)
    p = Pen(im, BG_S)
    sand_texture(p, rnd, 0, 200, w, h, 2600)
    # wet sand, foam and sea
    wave_edge(p, 214, 6, 160, 0, w, "#e4cf9c")
    wave_edge(p, 205, 6, 160, 0, w, "#ffffff", 0.4)
    sea = Image.new("RGBA", im.size)
    gradient(sea, 0, 205, "#3fa8c8", "#70d8c8", BG_S)
    mask = Image.new("L", im.size, 0)
    mp = Pen(mask, BG_S)
    wave_edge(mp, 200, 6, 160, 0, w, 255, 0.4)
    im.paste(sea, (0, 0), mask)
    # shallows band and foam ripples
    for i, (y, a) in enumerate(((186, 5), (164, 4), (140, 4), (110, 3), (78, 3), (44, 3))):
        pts = []
        for x in range(-10, w + 10, 6):
            pts.append((x, y + a * math.sin(x / (70 + i * 15) * 2 * math.pi + i)))
        col = "#ffffff" if i == 0 else mix("#bff4ee", "#7fd0dc", i / 6)
        for j in range(0, len(pts) - 1, 1):
            if (j // (6 + i)) % 3 != 2:
                p.line([pts[j], pts[j + 1]], col, 2.5 if i == 0 else 1.6)
    for _ in range(70):  # sun glitter
        x, y = rnd.uniform(0, w), rnd.uniform(10, 190)
        p.sparkle(x, y, rnd.uniform(2, 4.5), "#ffffff")
    # coral and rocks in the shallows
    for x, y in ((60, 150), (420, 175), (705, 168)):
        p.ell(x, y, 16, 7, "#5ab8c0", 0)
        p.ell(x - 6, y - 2, 6, 4, "#ff9a8a", 0.8)
        p.ell(x + 6, y, 5, 3.5, "#c8a0f0", 0.8)
    # mangroves along the left edge ("out past the mangroves")
    for mx, my in ((-8, 196), (40, 212)):
        for k in range(-3, 4):
            p.arc(mx + k * 7 - 10, my - 12, mx + k * 7 + 10, my + 14, 200, 340, "#8a6a48", 2)
        p.ell(mx, my - 20, 34, 18, "#4fa060", 1.5)
        p.ell(mx + 20, my - 30, 22, 14, LEAF, 1.5)

    # aquarium pavilion, top right: pastel walls, dolphin-blue dome, a door on the sand
    ax, ay = 840, 236
    p.ell(ax, ay + 6, 92, 14, "#00000020", 0)
    p.rect(ax - 80, ay - 80, ax + 80, ay, "#e8f8f8", 10, 2)
    p.chord(ax - 70, ay - 140, ax + 70, ay - 30, 180, 360, "#7ab8e0", 2)
    for k in range(-2, 3):
        p.arc(ax - 70 + 70 - 14 + k * 26, ay - 135, ax - 70 + 70 + 14 + k * 26, ay - 30, 200, 340, "#9fd0ee", 1.5)
    p.rect(ax - 80, ay - 86, ax + 80, ay - 76, TURQ, 4, 2)
    for wx in (ax - 52, ax + 52):  # porthole windows with a fish each
        p.ell(wx, ay - 46, 15, 15, "#bfeaf6", 2)
        p.ell(wx, ay - 46, 11, 11, "#8fd3e8", 0)
        p.poly([(wx - 6, ay - 46), (wx + 2, ay - 50), (wx + 6, ay - 46), (wx + 2, ay - 42)], MANGO, 0.8)
        p.poly([(wx - 6, ay - 46), (wx - 10, ay - 50), (wx - 10, ay - 42)], MANGO, 0.8)
    p.rect(ax - 18, ay - 50, ax + 18, ay, "#5aa8c8", 8, 2)
    p.line([(ax, ay - 48), (ax, ay)], INK, 1)
    p.chord(ax - 26, ay - 112, ax + 26, ay - 78, 180, 360, "#ffffff", 1.5)  # dolphin emblem
    p.poly([(ax - 16, ay - 86), (ax - 4, ay - 98), (ax + 12, ay - 96), (ax + 18, ay - 90), (ax + 4, ay - 90)], "#7ab8e0", 1)
    p.sparkle(ax + 74, ay - 120, 6, "#fff3a8", "#e0b24a")

    # garden arbour, top left: a white arch dripping with bougainvillea and a stepping path
    gx, gy = 120, 240
    for sx, sy in ((gx - 4, gy + 8), (gx + 6, gy + 26), (gx - 2, gy + 44)):
        p.ell(sx, sy, 9, 5, "#e8dcc8", 1)
    for side in (-1, 1):
        p.rect(gx + side * 30 - 4, gy - 64, gx + side * 30 + 4, gy - 2, "#ffffff", 3, 1.5)
    p.arc(gx - 34, gy - 98, gx + 34, gy - 30, 180, 360, INK, 9)
    p.arc(gx - 34, gy - 98, gx + 34, gy - 30, 180, 360, "#ffffff", 6)
    for i in range(12):
        a = math.pi + i * math.pi / 11
        p.hibiscus(gx + 32 * math.cos(a), gy - 64 + 34 * math.sin(a), 5.5, BOUG if i % 2 else HIBISCUS)
    for side in (-1, 1):
        for k in range(3):
            p.ell(gx + side * 30, gy - 50 + k * 16, 7, 6, LEAF, 1)
            p.hibiscus(gx + side * 32, gy - 46 + k * 16, 4, BOUG)
    bush(p, gx - 64, gy - 6, 22, HIBISCUS, 3, 1)
    bush(p, gx + 70, gy - 8, 20, PLUMERIA, 3, 2)

    # stable path at x 300: a sandy track, a horseshoe on a post, hoofprints
    sx, sy = 300, 238
    p.poly([(sx - 24, sy - 46), (sx + 24, sy - 46), (sx + 30, sy + 10), (sx - 30, sy + 10)], "#e8cf98", 0)
    p.rect(sx + 30, sy - 70, sx + 36, sy, "#c98f5a", 2, 1.5)
    p.rect(sx + 18, sy - 82, sx + 48, sy - 62, "#e8b47c", 4, 1.5)
    p.arc(sx + 25, sy - 80, sx + 41, sy - 64, 200, 340, "#f0f0f0", 3)
    p.arc(sx + 25, sy - 80, sx + 41, sy - 64, 200, 340, "#a0a8b0", 1)
    for hx, hy in ((sx - 8, sy - 30), (sx + 6, sy - 14), (sx - 6, sy + 2)):
        p.arc(hx - 4, hy - 4, hx + 4, hy + 4, 200, 340, "#c8ac78", 1.6)
    p.ell(sx - 40, sy - 30, 20, 12, LEAF, 1.5)
    p.ell(sx - 50, sy - 40, 14, 10, LEAF_DK, 1.5)

    # the little jetty and rowboat back to the island, under the village exit (480, 380)
    jx, jy = 480, 380
    p.ell(jx + 2, jy + 22, 46, 8, "#00000018", 0)
    p.poly([(jx - 40, jy + 4), (jx + 40, jy + 4), (jx + 30, jy + 22), (jx - 30, jy + 22)], "#ffffff", 1.5)
    p.poly([(jx - 40, jy + 4), (jx + 40, jy + 4), (jx + 34, jy + 13), (jx - 34, jy + 13)], CORAL, 0)
    p.line([(jx - 40, jy + 4), (jx + 40, jy + 4)], INK, 1.5)
    p.line([(jx - 28, jy + 8), (jx + 28, jy + 8)], "#ffffff", 1.4)
    p.line([(jx - 52, jy + 2), (jx - 26, jy - 14)], "#c98f5a", 3)  # an oar resting
    p.ell(jx - 28, jy - 13, 6, 3, "#c98f5a", 1)

    # a beach umbrella and towel, a sandcastle, starfish and shells, footprints
    ux, uy = 700, 300
    p.ell(ux + 30, uy + 20, 52, 14, "#00000018", 0)
    p.rect(ux - 20, uy + 2, ux + 40, uy + 30, "#ffffff", 4, 1.5)
    for k in range(4):
        p.rect(ux - 20 + k * 15, uy + 2, ux - 13 + k * 15, uy + 30, TURQ, 0, 0)
    p.rect(ux - 20, uy + 2, ux + 40, uy + 30, None, 4, 1.5)
    p.line([(ux + 10, uy + 10), (ux + 2, uy - 60)], "#ffffff", 3)
    for k in range(6):
        a0 = 180 + k * 30
        col = CORAL if k % 2 else "#fff6dc"
        p.d.pieslice([(ux + 2 - 46) * BG_S, (uy - 84) * BG_S, (ux + 2 + 46) * BG_S, (uy - 36) * BG_S],
                     a0, a0 + 30, fill=col, outline=INK, width=2 * BG_S)
    p.ell(ux + 2, uy - 62, 3, 3, "#ffe27a", 1)
    cx, cy = 180, 430  # sandcastle with a flag
    p.rect(cx - 22, cy - 10, cx + 22, cy + 8, "#e8c890", 3, 1.5)
    for tx in (cx - 16, cx, cx + 16):
        p.rect(tx - 6, cy - 22, tx + 6, cy - 6, "#f0d4a0", 2, 1.5)
    p.line([(cx, cy - 22), (cx, cy - 36)], INK, 1)
    p.poly([(cx, cy - 36), (cx + 10, cy - 32), (cx, cy - 28)], HIBISCUS, 1)
    p.rect(cx + 26, cy - 4, cx + 40, cy + 8, TURQ, 2, 1.2)  # bucket
    for x, y, c in ((880, 470, MANGO), (90, 340, CORAL), (560, 300, "#ff9ab8")):
        pts = []
        for i in range(10):
            r = 9 if i % 2 == 0 else 4
            a = -math.pi / 2 + i * math.pi / 5
            pts.append((x + r * math.cos(a), y + r * math.sin(a)))
        p.poly(pts, c, 1.2)
    for _ in range(26):
        x, y = rnd.uniform(30, 930), rnd.uniform(250, 530)
        p.ell(x, y, 3, 2, rnd.choice(["#fff1e6", "#ffd2dc", "#ffe0b0"]), 0.8)
    for i in range(9):  # footprints wandering from the jetty to the water
        x, y = 420 - i * 14, 360 - i * 14 + (4 if i % 2 else -4)
        p.ell(x, y, 2.4, 3.4, "#e6cc94", 0)
    # palms framing both sides
    palm(p, 30, 520, 1, 150, 1.0)
    palm(p, 930, 510, -1, 140, 1.0)
    palm(p, 600, 238, 1, 90, 0.75)
    bush(p, 60, 520, 26, BOUG, 4, 3)
    bush(p, 900, 530, 24, HIBISCUS, 4, 4)
    save(im, w, h, "bg_florida_beach", True)


# ---------------------------------------------------------------- garden (the house and its yard)

def garden_bg():
    """The yard behind the house: the Keys-style house on stilts along the top with a porch,
    lime and mango trees, a white picket fence, lush lawn, a tilled bed for the six plots
    (400-560 x 240-310) and a shell path down to the beach gate (x 120, y 500)."""
    w, h = 960, 540
    rnd = random.Random(11)
    im = Image.new("RGBA", (w * BG_S, h * BG_S), "#a8e08c")
    p = Pen(im, BG_S)
    gradient(im, 0, 60, "#9fdcf0", "#cfeff6", BG_S)
    # back hedge and trees behind the house
    for x in range(-20, 980, 70):
        p.ell(x, 70, 50, 34, LEAF_DK if (x // 70) % 2 else "#6abf62", 1.5)
    palm(p, 40, 170, 1, 140, 0.9)
    palm(p, 930, 175, -1, 130, 0.9)
    # the house: pastel turquoise on white stilts, coral tin roof, porch with railings
    hx0, hx1, hy0, hy1 = 210, 660, 22, 150
    p.ell((hx0 + hx1) / 2, hy1 + 6, (hx1 - hx0) / 2 + 20, 10, "#00000022", 0)
    for sx in range(hx0 + 10, hx1, 56):
        p.rect(sx - 4, hy1 - 20, sx + 4, hy1 + 6, "#ffffff", 2, 1.5)
    p.rect(hx0, hy0 + 26, hx1, hy1 - 14, "#a8e4e0", 6, 2)
    for y in range(hy0 + 36, hy1 - 14, 9):  # clapboard siding
        p.line([(hx0 + 4, y), (hx1 - 4, y)], "#8fd0cc", 1)
    p.poly([(hx0 - 20, hy0 + 32), ((hx0 + hx1) / 2, hy0 - 26), (hx1 + 20, hy0 + 32)], CORAL, 2)
    for k in range(1, 16):
        x = hx0 - 20 + k * (hx1 - hx0 + 40) / 16
        top_y = hy0 - 26 + abs(x - (hx0 + hx1) / 2) * 58 / ((hx1 - hx0) / 2 + 20)
        p.line([(x, top_y + 3), (x, hy0 + 30)], "#d86a50", 1)
    for wx in (hx0 + 60, hx0 + 160, hx1 - 160, hx1 - 60):  # shuttered windows
        p.rect(wx - 18, hy0 + 46, wx + 18, hy0 + 82, "#fff6dc", 3, 1.5)
        p.line([(wx, hy0 + 46), (wx, hy0 + 82)], INK, 1)
        p.line([(wx - 18, hy0 + 64), (wx + 18, hy0 + 64)], INK, 1)
        for s in (-1, 1):
            p.rect(wx + s * 22 - 4, hy0 + 44, wx + s * 22 + 4, hy0 + 84, CORAL, 2, 1.2)
        p.rect(wx - 20, hy0 + 84, wx + 20, hy0 + 92, "#c98f5a", 2, 1.2)  # window box
        for fx in range(wx - 15, wx + 16, 8):
            p.hibiscus(fx, hy0 + 84, 3.4, BOUG if fx % 3 else HIBISCUS)
    dx = (hx0 + hx1) / 2
    p.rect(dx - 20, hy0 + 52, dx + 20, hy1 - 14, "#f08060", 6, 2)  # the front door
    p.ell(dx + 12, hy0 + 90, 2.4, 2.4, "#ffe27a", 0.8)
    p.ell(dx, hy0 + 66, 9, 7, "#bfeaf6", 1.2)
    # porch with railings and steps down to the yard
    p.rect(hx0 - 6, hy1 - 16, hx1 + 6, hy1 - 6, "#ffffff", 2, 1.5)
    for x in range(int(hx0), int(hx1) + 1, 12):
        if abs(x - dx) > 26:
            p.line([(x, hy1 - 30), (x, hy1 - 16)], "#ffffff", 2.2)
    p.line([(hx0, hy1 - 30), (dx - 26, hy1 - 30)], "#ffffff", 3)
    p.line([(dx + 26, hy1 - 30), (hx1, hy1 - 30)], "#ffffff", 3)
    for k in range(3):
        p.rect(dx - 26 + k * 2, hy1 - 6 + k * 7, dx + 26 - k * 2, hy1 + 1 + k * 7, "#f6e6c8", 2, 1.2)
    # a rocking chair and a pitcher of key lime lemonade on the porch
    p.rect(hx0 + 20, hy1 - 46, hx0 + 44, hy1 - 18, "#c98f5a", 4, 1.5)
    p.rect(hx1 - 50, hy1 - 34, hx1 - 22, hy1 - 18, "#ffffff", 2, 1.2)
    p.rect(hx1 - 44, hy1 - 50, hx1 - 32, hy1 - 34, LIME, 3, 1.2)
    # key lime and mango trees in the yard corners
    for tx, ty, fruit in ((760, 150, LIME), (840, 120, MANGO), (150, 130, MANGO)):
        p.rect(tx - 5, ty - 10, tx + 5, ty + 20, COCONUT, 2, 1.5)
        for ox, oy, r in ((-18, -18, 20), (18, -18, 20), (0, -34, 22), (0, -12, 22)):
            p.ell(tx + ox, ty + oy, r, r * 0.9, LEAF if ox else "#6abf62", 1.5)
        for ox, oy in ((-16, -14), (12, -26), (20, -8), (-4, -36), (2, -6)):
            p.ell(tx + ox, ty + oy, 4.4, 4, fruit, 1)
    # picket fence along the top of the yard (behind the walkable lawn)
    for x in range(0, w + 1, 18):
        if hx0 - 10 < x < hx1 + 10:
            continue
        p.poly([(x - 5, 186), (x - 5, 160), (x, 153), (x + 5, 160), (x + 5, 186)], "#ffffff", 1.4)
    for y in (166, 178):
        p.line([(0, y), (hx0 - 10, y)], "#ffffff", 3)
        p.line([(hx1 + 10, y), (w, y)], "#ffffff", 3)
    for x in range(10, w, 46):  # bougainvillea along the fence
        if hx0 - 20 < x < hx1 + 20:
            continue
        p.hibiscus(x, 160 + (x * 7) % 14, 6, BOUG)
        p.ell(x + 12, 172, 9, 6, LEAF, 1)
    # lawn texture
    for _ in range(1400):
        x, y = rnd.uniform(0, w), rnd.uniform(160, h)
        c = rnd.choice(["#98d47c", "#b8ea9c", "#8cca72"])
        p.line([(x, y), (x + rnd.uniform(-1.5, 1.5), y - rnd.uniform(2, 4))], c, 1)
    for _ in range(60):
        x, y = rnd.uniform(0, w), rnd.uniform(190, h)
        p.plumeria(x, y, 2.4) if rnd.random() < 0.5 else p.ell(x, y, 2, 2, "#ffe27a", 0.6)
    # the tilled bed for the six plots, with a timber edge
    p.rect(352, 196, 608, 352, "#c98f5a", 10, 2)
    p.rect(360, 204, 600, 344, "#9a6c46", 8, 0)
    for y in range(214, 340, 12):
        p.line([(368, y), (592, y)], "#8a5e3c", 1.4)
    # watering can by the bed, a wheelbarrow of soil
    p.rect(616, 318, 642, 342, "#7ab8e0", 4, 1.5)
    p.line([(642, 324), (656, 312)], INK, 4)
    p.line([(642, 324), (656, 312)], "#7ab8e0", 2.4)
    p.arc(618, 306, 640, 330, 200, 340, INK, 2)
    # stepping-shell path from the lawn down to the beach gate (bottom left)
    for i in range(10):
        t = i / 9
        x = 470 - 350 * t + 30 * math.sin(t * 3)
        y = 400 + 100 * t
        p.ell(x, y, 13, 7, "#f2e6d0", 1.2)
        p.ell(x - 3, y - 2, 4, 1.5, "#ffffff", 0)
    # beach gate: two posts with hibiscus and a peek of sand
    p.poly([(80, 540), (160, 540), (150, 516), (90, 516)], SAND, 0)
    for gx in (84, 156):
        p.rect(gx - 6, 470, gx + 6, 540, "#ffffff", 3, 1.5)
        p.hibiscus(gx, 466, 7)
    for x in range(0, 78, 18):
        p.poly([(x - 5, 540), (x - 5, 506), (x, 499), (x + 5, 506), (x + 5, 540)], "#ffffff", 1.4)
    # flower borders and bushes
    for x, y, f, s in ((300, 420, HIBISCUS, 1), (700, 430, BOUG, 2), (860, 300, PLUMERIA, 3),
                       (240, 220, HIBISCUS, 4), (900, 470, MANGO, 5), (60, 300, BOUG, 6), (640, 520, HIBISCUS, 7)):
        bush(p, x, y, 24, f, 4, s)
    # a birdbath for the gull, a hammock between two palms on the right
    bx, by = 800, 360
    p.rect(bx - 4, by - 8, bx + 4, by + 16, "#e8e0d8", 2, 1.2)
    p.ell(bx, by - 10, 20, 7, "#e8e0d8", 1.5)
    p.ell(bx, by - 11, 15, 4.6, "#8fd3e8", 0)
    p.rect(bx - 12, by + 14, bx + 12, by + 20, "#e8e0d8", 2, 1.2)
    save(im, w, h, "bg_florida_garden", True)


# ---------------------------------------------------------------- aquarium

def aquarium_bg():
    """The aquarium show: a big glass pool across the top (the mermaids swim at y 70-180) with
    coral, sea grass, fish and light shafts; a sunny tiled deck below (nav from y 290) with
    bleacher benches, potted palms and a rope rail."""
    w, h = 960, 540
    rnd = random.Random(23)
    im = Image.new("RGBA", (w * BG_S, h * BG_S), "#f2fbfb")
    p = Pen(im, BG_S)
    # sun-bleached boardwalk deck: long planks with staggered joints and nail dots
    for row, ty in enumerate(range(250, h, 16)):
        p.rect(0, ty, w, ty + 16, "#f2dcb4" if row % 2 else "#ecd4a8", 0, 0)
        p.line([(0, ty), (w, ty)], "#d8b888", 1)
        off = (row * 97) % 160
        for jx in range(off, w, 160):
            p.line([(jx, ty), (jx, ty + 16)], "#d8b888", 1)
            p.ell(jx + 4, ty + 8, 0.9, 0.9, "#c8a070", 0)
            p.ell(jx - 4, ty + 8, 0.9, 0.9, "#c8a070", 0)
        for _ in range(6):
            gx = rnd.uniform(0, w)
            p.line([(gx, ty + 5), (gx + rnd.uniform(20, 50), ty + 5)], "#e4c89a", 0.8)
    # pool frame
    p.rect(20, 4, 940, 256, "#ffffff", 22, 2.5)
    pool = Image.new("RGBA", im.size)
    gradient(pool, 0, 250, "#5ec4dc", "#2f86b8", BG_S)
    mask = Image.new("L", im.size, 0)
    Pen(mask, BG_S).rect(34, 16, 926, 242, 255, 16, 0)
    im.paste(pool, (0, 0), mask)
    # light shafts
    shafts = Image.new("RGBA", im.size)
    sp = Pen(shafts, BG_S)
    for x in (120, 300, 520, 760):
        sp.poly([(x, 16), (x + 50, 16), (x + 110, 242), (x + 40, 242)], (255, 255, 255, 40), 0)
    shafts = shafts.filter(ImageFilter.GaussianBlur(6 * BG_S))
    im.paste(shafts, (0, 0), Image.composite(shafts, Image.new("RGBA", im.size), mask))
    # sand floor of the pool, coral, sea grass, shells
    floor = Image.new("RGBA", im.size)
    Pen(floor, BG_S).ell(480, 252, 470, 34, "#f0dcae", 0)
    im.paste(floor, (0, 0), Image.composite(floor, Image.new("RGBA", im.size), mask))
    for x in range(50, 920, 38):
        hgt = rnd.uniform(30, 70)
        p.line([(x, 236), (x + 8 * math.sin(x), 236 - hgt / 2), (x - 4, 236 - hgt)], "#4fb878", 4)
    for cx, col in ((110, "#ff8a9a"), (330, MANGO), (610, "#c8a0f0"), (850, CORAL)):
        for k in range(5):
            a = math.radians(-150 + k * 30)
            p.line([(cx, 238), (cx + 26 * math.cos(a), 238 + 34 * math.sin(a))], INK, 7)
            p.line([(cx, 238), (cx + 26 * math.cos(a), 238 + 34 * math.sin(a))], col, 4.6)
            p.ell(cx + 26 * math.cos(a), 238 + 34 * math.sin(a), 4, 4, col, 1)
    for x in (200, 460, 720):  # treasure: a sunken heart-shaped shell, a little castle
        p.ell(x, 232, 10, 6, "#ffd2dc", 1.2)
    p.rect(470, 196, 506, 236, "#f6c8d8", 3, 1.5)
    for tx in (470, 488, 500):
        p.rect(tx, 186, tx + 8, 200, "#f6c8d8", 1, 1.2)
    p.chord(480, 214, 496, 236, 180, 360, "#2f86b8", 1.2)
    # fish that wave back
    for fx, fy, col, d in ((180, 60, MANGO, 1), (240, 90, "#ff9ab8", 1), (690, 70, LIME, -1),
                           (420, 140, "#ffe27a", -1), (820, 150, MANGO, -1), (560, 40, "#ff9ab8", 1)):
        p.ell(fx, fy, 10, 6, col, 1.2)
        p.poly([(fx - 9 * d, fy), (fx - 17 * d, fy - 6), (fx - 17 * d, fy + 6)], col, 1.2)
        p.ell(fx + 5 * d, fy - 1, 1.4, 1.4, INK, 0)
        p.line([(fx + 1 * d, fy + 2), (fx - 1 * d, fy + 5)], "#ffffff", 1.2)
    for _ in range(60):  # bubbles
        x, y, r = rnd.uniform(40, 920), rnd.uniform(20, 230), rnd.uniform(1.5, 5)
        p.ell(x, y, r, r, "#e8fbff80", 1, "#e8fbff")
    # glass glare and the pool's rim
    for x in (60, 500):
        p.line([(x, 30), (x + 40, 30)], "#ffffff90", 4)
        p.line([(x, 42), (x + 18, 42)], "#ffffff90", 3)
    p.rect(20, 238, 940, 262, "#ffffff", 8, 2.5)
    p.line([(30, 250), (930, 250)], "#c8eaf0", 2)
    for x in range(60, 921, 120):
        p.ell(x, 250, 5, 5, TURQ, 1)
    # rope rail in front of the pool
    for x in range(40, 940, 110):
        p.rect(x - 4, 270, x + 4, 300, "#c98f5a", 2, 1.4)
        p.ell(x, 268, 6, 4, "#e8b47c", 1.2)
    for x in range(40, 830, 110):
        p.arc(x, 260, x + 110, 300, 20, 160, CORAL, 3)
    # bleachers: pastel benches facing the pool
    for row, (y, col) in enumerate(((410, "#ffb8c8"), (462, "#9fdcea"), (514, "#ffe08a"))):
        for x0, x1 in ((90, 400), (560, 900)):
            p.ell((x0 + x1) / 2, y + 30, (x1 - x0) / 2 + 6, 6, "#00000018", 0)
            for lx in (x0 + 16, x1 - 16, (x0 + x1) / 2):  # legs
                p.rect(lx - 4, y + 14, lx + 4, y + 30, "#c98f5a", 2, 1.2)
            p.rect(x0, y + 8, x1, y + 20, mix(col, INK, 0.18), 5, 1.6)  # seat front
            p.rect(x0, y, x1, y + 12, col, 6, 1.8)  # seat top
            p.line([(x0 + 8, y + 4), (x1 - 8, y + 4)], "#ffffff", 2)
            for cx in range(int(x0) + 30, int(x1) - 20, 62):  # a cushion every few seats
                p.ell(cx, y + 5, 9, 4, "#ffffff", 1)
                p.ell(cx, y + 5, 3, 1.8, col, 0)
    # potted palms and a cooler of drinks
    for x, y in ((40, 380), (920, 380), (480, 540)):
        p.rect(x - 16, y - 10, x + 16, y + 14, CORAL, 4, 1.5)
        palm(p, x, y - 12, 1 if x < 480 else -1, 60, 0.55)
    p.rect(470, 300, 520, 330, "#7ab8e0", 4, 1.5)
    p.rect(468, 296, 522, 304, "#ffffff", 2, 1.2)
    # a few sparkles on the water's surface
    for _ in range(14):
        p.sparkle(rnd.uniform(60, 900), rnd.uniform(20, 60), rnd.uniform(2, 4), "#ffffff")
    save(im, w, h, "bg_florida_aquarium", True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    father()
    daughter()
    hannah()
    mermaid()
    crab()
    gull()
    dolphin()
    shell()
    seed_bag()
    craft_bench()
    plots()
    beach_bg()
    garden_bg()
    aquarium_bg()
    print("Florida art written to", OUT)


if __name__ == "__main__":
    main()
