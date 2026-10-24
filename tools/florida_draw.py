"""Shared drawing kit for the tropical Florida Keys generators (not run on its own).

Imported by tools/gen_florida_art.py, tools/gen_florida_cast.py and tools/gen_florida_critters.py.
Holds the Florida palette from dev/STYLE.md 4.3/4.4 (warm-brown outline #8a5a5a, pink blush,
sea blue, turquoise, foam, coral and the Florida plant colours), a Pen that draws at a
supersample factor with coordinates given in output pixels, the canon cut loader, the sticker
finish (supersample then LANCZOS down) and the SpriteFrames writer every rigged sheet uses.

Resolution: generators lay art out in world pixels (the units the maps, spawns and nav use),
but every PNG is written at D = 4 texture pixels per world pixel, which is one texture pixel
per screen pixel at the 1280x720 window with the 2x map camera. Drawing happens at a further
supersample on top of that and is LANCZOS-resized down. Scenes show the textures at
scale 1/D (DISPLAY_SCALE); every SpriteFrames written here carries
metadata/display_scale = 1/D so code that loads a rig at run time scales it the same way.
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "project/assets/florida"
RES = "res://assets/florida"
D = 4  # texture pixels per world pixel
DISPLAY_SCALE = 1.0 / D
sys.path.insert(0, str(ROOT / "tools"))

# dev/STYLE.md 4.3 / 4.4
INK = "#8a5a5a"
# The canon character drawings are lined darker than the island tiles; clothes and hair drawn
# over a canon body use the body's own line colour (sampled from the canon turnaround).
CANON_INK = "#603428"
BLUSH = "#ff9fb8"
SPARK = "#fff3a8"
GOLD = "#e0b24a"
SEA = "#80b0d0"
TURQ = "#70d0c0"
FOAM = "#e0f0f0"
WATER = "#a9ddf2"
WATER_HI = "#c6eefb"
CORAL = "#f08060"
LILAC = "#b090e0"
HIBISCUS = "#ff9ad0"
SEA_GRAPE = "#b89ae0"
KEY_LIME = "#d8f07a"
BOUG = "#e0408a"
PLUMERIA = "#fff1b8"
GUAVA = "#f4a6a0"
MANGO = "#ffb347"
COCONUT = "#b08a5a"
SAND = "#ffe9b8"
SAND_PEB = "#ffd3c2"
PATH = "#fff0cf"
PATH_PEB = "#ffe2b0"
GRASS = "#c5ecaa"
GRASS_DK = "#a6dc8a"
GRASS_HI = "#d6f5bf"
SOIL = "#e0b48f"
SOIL_DK = "#c99468"
SPROUT = "#9be07c"
SPROUT_HI = "#b4ee95"
LEAF = "#a0e0a0"
LEAF_MINT = "#a8e6a0"
HEDGE = "#95d37c"
WOOD = "#c09060"
TRUNK = "#c8956d"
SKIN = "#f0c0b0"
HAIR_BROWN = "#806050"
HAIR_DARK = "#704030"
GOLD_HAIR = "#f0e0a0"
HEART = "#ff8fb1"
FLOWER_PINK = "#ff9fc0"
FLOWER_YELLOW = "#ffd36e"
FLOWER_CENTRE = "#ffe27a"
WHITE = "#ffffff"
PLUM = "#593859"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return "#" + "".join(f"{round(a[i] + (b[i] - a[i]) * t):02x}" for i in range(3))


def alpha(h, a):
    """Hex colour with an alpha byte (Pen draws it on an overlay and blends)."""
    return f"{h}{a:02x}"


class Pen:
    """Draws at s times the output size; every coordinate is given in output pixels.
    Fills with an alpha byte (#rrggbbaa) are blended through an overlay."""

    def __init__(self, im, s, ink=INK, ox=0.0, oy=0.0):
        self.im, self.s, self.ink, self.ox, self.oy = im, s, ink, ox, oy
        self._d = ImageDraw.Draw(im)
        self._ov = None

    @property
    def d(self):
        return self._ov[1] if self._ov else self._d

    def _begin(self, fill):
        a = None
        if isinstance(fill, str) and len(fill) == 9:
            a = int(fill[7:], 16)
        if a is not None and a < 255:
            ov = Image.new("RGBA", self.im.size)
            self._ov = (ov, ImageDraw.Draw(ov))
        return self

    def _end(self):
        if self._ov:
            ov = self._ov[0]
            box = ov.getbbox()  # blend only the touched area (big supersampled grounds)
            if box:
                self.im.alpha_composite(ov.crop(box), box[:2])
            self._ov = None

    def _w(self, width):
        return max(1, round(width * self.s)) if width else 0

    def _o(self, width, outline):
        return (outline or self.ink) if width else None

    def ell(self, x, y, rx, ry, fill, width=1.0, outline=None):
        s = self.s
        x, y = x + self.ox, y + self.oy
        self._begin(fill).d.ellipse([(x - rx) * s, (y - ry) * s, (x + rx) * s, (y + ry) * s], fill=fill,
                                    outline=self._o(width, outline), width=self._w(width))
        self._end()

    def rect(self, x0, y0, x1, y1, fill, rad=0, width=1.0, outline=None):
        s = self.s
        x0, y0, x1, y1 = x0 + self.ox, y0 + self.oy, x1 + self.ox, y1 + self.oy
        self._begin(fill).d.rounded_rectangle([x0 * s, y0 * s, x1 * s, y1 * s], rad * s, fill=fill,
                                              outline=self._o(width, outline), width=self._w(width))
        self._end()

    def poly(self, pts, fill, width=1.0, outline=None):
        pts = [((x + self.ox) * self.s, (y + self.oy) * self.s) for x, y in pts]
        self._begin(fill).d.polygon(pts, fill=fill)
        self._end()
        if width:
            self.d.line(pts + [pts[0]], fill=outline or self.ink, width=self._w(width), joint="curve")
            r = self._w(width) / 2
            for x, y in pts:  # round the corners the way a marker does
                self.d.ellipse([x - r, y - r, x + r, y + r], fill=outline or self.ink)

    def line(self, pts, fill=None, width=1.0, round_ends=True):
        fill = fill or self.ink
        sp = [((x + self.ox) * self.s, (y + self.oy) * self.s) for x, y in pts]
        self._begin(fill).d.line(sp, fill=fill, width=self._w(width), joint="curve")
        if round_ends:
            r = self._w(width) / 2
            for x, y in (sp[0], sp[-1]):
                self.d.ellipse([x - r, y - r, x + r, y + r], fill=fill)
        self._end()

    def arc(self, x, y, rx, ry, a0, a1, fill=None, width=1.0):
        s = self.s
        x, y = x + self.ox, y + self.oy
        self.d.arc([(x - rx) * s, (y - ry) * s, (x + rx) * s, (y + ry) * s], a0, a1, fill=fill or self.ink,
                   width=self._w(width))

    def blob(self, circles, fill, width=1.0, outline=None):
        """A bubbly shape: the union of circles (x, y, r) with one outline around the whole."""
        w = self._w(width)
        for x, y, r in circles:
            self.ell(x, y, r + w / self.s, r + w / self.s, outline or self.ink, 0)
        for x, y, r in circles:
            self.ell(x, y, r, r, fill, 0)

    def face(self, x, y, sc=1.0, blush=True, catch=True):
        """Two dot eyes with a catch-light, a small smile and pink blush (STYLE.md 4.3)."""
        for dx in (-3.0, 3.0):
            self.ell(x + dx * sc, y, 0.95 * sc, 1.1 * sc, self.ink, 0)
            if catch:
                self.ell(x + dx * sc + 0.3 * sc, y - 0.4 * sc, 0.36 * sc, 0.36 * sc, WHITE, 0)
        self.arc(x, y + 0.9 * sc, 1.3 * sc, 1.0 * sc, 20, 160, self.ink, 0.55 * sc)
        if blush:
            for dx in (-4.9, 4.9):
                self.ell(x + dx * sc, y + 1.7 * sc, 1.35 * sc, 0.8 * sc, BLUSH, 0)

    def sparkle(self, x, y, r, fill=SPARK, outline=GOLD, width=0.35):
        k = 0.28
        pts = [(x, y - r), (x + r * k, y - r * k), (x + r, y), (x + r * k, y + r * k), (x, y + r),
               (x - r * k, y + r * k), (x - r, y), (x - r * k, y - r * k)]
        self.poly(pts, fill, width if outline else 0, outline)

    def heart(self, x, y, r, fill=HEART, width=0.4):
        pts = []
        for i in range(40):
            t = i / 40 * 2 * math.pi
            hx = 16 * math.sin(t) ** 3
            hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            pts.append((x + hx * r / 16, y + hy * r / 16))
        self.poly(pts, fill, width)
        self.ell(x - r * 0.4, y - r * 0.35, r * 0.18, r * 0.14, WHITE, 0)

    def hibiscus(self, x, y, r, color=HIBISCUS, width=0.5):
        for a in range(5):
            ang = a * 2 * math.pi / 5 - math.pi / 2
            self.ell(x + r * 0.6 * math.cos(ang), y + r * 0.6 * math.sin(ang), r * 0.52, r * 0.52, color, width)
        for a in range(5):
            ang = a * 2 * math.pi / 5 - math.pi / 2
            self.ell(x + r * 0.6 * math.cos(ang), y + r * 0.6 * math.sin(ang), r * 0.52 - width, r * 0.52 - width, color, 0)
        self.ell(x, y, r * 0.26, r * 0.26, FLOWER_CENTRE, 0)

    def plumeria(self, x, y, r, width=0.4):
        for a in range(5):
            ang = a * 2 * math.pi / 5 - math.pi / 2
            self.ell(x + r * 0.55 * math.cos(ang), y + r * 0.55 * math.sin(ang), r * 0.48, r * 0.48, WHITE, width)
        for a in range(5):
            ang = a * 2 * math.pi / 5 - math.pi / 2
            self.ell(x + r * 0.55 * math.cos(ang), y + r * 0.55 * math.sin(ang), r * 0.48 - width, r * 0.48 - width, WHITE, 0)
        self.ell(x, y, r * 0.3, r * 0.3, FLOWER_YELLOW, 0)


def canvas(w, h, s, bg=(0, 0, 0, 0)):
    im = Image.new("RGBA", (round(w * s), round(h * s)), bg)
    return im, Pen(im, s)


def finish(im, w, h):
    """Supersampled drawing of a w x h (world px) sprite down to its texture: (w*D) x (h*D)."""
    return im.resize((round(w * D), round(h * D)), Image.LANCZOS)


def save(img, name, rgb_only=False):
    OUT.mkdir(parents=True, exist_ok=True)
    if rgb_only:
        img = img.convert("RGB")
    img.save(OUT / f"{name}.png", optimize=False)
    return img


def canon_base(name):
    """A full-resolution canon drawing listed under 'bases' in project/data/florida_canon.json,
    cut by tools/cut_island_props.py."""
    from cut_island_props import cut
    cfg = json.loads((ROOT / "project/data/florida_canon.json").read_text())
    return cut(cfg["bases"][name])


def canon_prop(name):
    """A canon cut listed under 'props' in project/data/florida_canon.json, cut straight from its
    sheet at full resolution by tools/cut_island_props.py (no prior cut run needed)."""
    from cut_island_props import cut
    cfg = json.loads((ROOT / "project/data/florida_canon.json").read_text())
    return cut(cfg["props"][name])


def canon_sprite(name):
    return Image.open(ROOT / f"project/assets/canon/{name}.png").convert("RGBA")


def write_frames(name, fw, fh, anims):
    """Write project/assets/florida/<name>.tres: a SpriteFrames over <name>.png.
    fw, fh: the frame size in world px (the sheet holds frames of fw*D x fh*D texture px).
    anims: list of (anim_name, row, columns, fps, loop); a column given as a (column, row) pair
    takes that frame from another row (for sheets stacked one frame per row)."""
    fw, fh = round(fw * D), round(fh * D)
    lines, subs, frames_by_anim = [], [], []
    n = 0
    for anim, anim_row, cols, fps, loop in anims:
        refs = []
        for c in cols:
            c, row = c if isinstance(c, tuple) else (c, anim_row)
            n += 1
            sid = f"f{n}"
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("1")\n'
                        f"region = Rect2({c * fw}, {row * fh}, {fw}, {fh})\n")
            refs.append(sid)
        fr = ", ".join('{"duration": 1.0, "texture": SubResource("%s")}' % r for r in refs)
        frames_by_anim.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'
                              % (fr, "true" if loop else "false", anim, float(fps)))
    lines.append(f'[gd_resource type="SpriteFrames" load_steps={n + 2} format=3]\n')
    lines.append(f'[ext_resource type="Texture2D" path="{RES}/{name}.png" id="1"]\n')
    lines.extend(subs)
    lines.append("[resource]\nanimations = [%s]\nmetadata/display_scale = %s\n"
                 % (", ".join(frames_by_anim), DISPLAY_SCALE))
    (OUT / f"{name}.tres").write_text("\n".join(lines))
