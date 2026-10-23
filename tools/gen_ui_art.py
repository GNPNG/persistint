"""Draw the UI art: theme chrome (9-slice panels, buttons, bars, bubbles), the backdrops behind
the cruise and temple mini-game screens, and the stand-ins for the Gemini title screen and
chapter card.

Usage: python3 -I tools/gen_ui_art.py   (run after tools/cut_island_props.py: it reads canon props)

Inputs:  project/assets/canon/{prop_ship,prop_bunker,prop_pillar_orb,
         deco_tree_a,deco_tree_b,deco_tree_c,deco_flowers,deco_heart,deco_sparkle}.png
Outputs (all static, no animation frames):
  project/assets/ui/chrome/<id>.png     theme chrome, read by project/themes/default.tres as
                                        StyleBoxTexture 9-slices (margins listed in CHROME below)
  project/assets/ui/backdrops/<id>.png  640x360 screen backdrops: talk_show_set (The Interview),
                                        comedy_stage (Next Top Comic), runway (Hottest of the HOT),
                                        ship_cabin (get-ready chains), fog_sea (The Landing),
                                        temple_altar (ritual puzzle); ship_cutaway (600x150) is the
                                        Landing's station map
  project/assets/ui/title/title_screen_plain.png
      stand-in for prompts/image/ui/title/title_screen_plain.md (the main menu background)
  project/assets/ui/chapter_cards/chapter_card_before_the_wreck.png
      stand-in for prompts/image/ui/chapter_cards/chapter_card_before_the_wreck.md
A Gemini render synced to either stand-in path by tools/sync_rendered_assets.py replaces it with
no code change (the scenes load whatever PNG is at that path, scaled to cover the screen).

Style: prompts/STYLE.md 4.3/4.4 -- warm-brown outline #8a5a5a, cream #fdf6e3, flat pastel fills
with one highlight. Everything is drawn at K x size and downscaled (LANCZOS); noise uses fixed seeds.
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "project/assets"
CANON = ASSETS / "canon"
K = 4

INK = "#8a5a5a"
CREAM = "#fdf6e3"
WHITE = "#ffffff"
PINK = "#f7a8c4"
PINK_LT = "#ffe3ec"
PINK_MID = "#ffd0e0"
BLUSH = "#ff9fb8"
ROSE = "#ff8fb1"
LAVENDER = "#c0b0f0"
LILAC = "#b090e0"
SKY = "#a0d0f0"
SEA = "#80b0d0"
TURQ = "#70d0c0"
GOLD = "#f0e0a0"
SPARK = "#fff3a8"
SPARK_EDGE = "#e0b24a"
CORAL = "#f08060"
GRASS = "#c0e0a0"
LEAF = "#a0e0a0"
SAND = "#f0e0b0"
WOOD = "#c09060"
STONE = "#f0e0e0"


# ---------------------------------------------------------------- helpers

def canvas(w, h, bg=(0, 0, 0, 0)):
    im = Image.new("RGBA", (w * K, h * K), bg)
    return im, ImageDraw.Draw(im)


def down(im, w, h):
    return im.resize((w, h), Image.LANCZOS)


def save(im, rel):
    path = ASSETS / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=False)
    print(path.relative_to(ROOT), im.size)


def box(x0, y0, x1, y1):
    return [x0 * K, y0 * K, x1 * K - 1, y1 * K - 1]


def rr(d, x0, y0, x1, y1, r, fill, ink=INK, w=1):
    d.rounded_rectangle(box(x0, y0, x1, y1), r * K, fill=fill, outline=ink, width=int(w * K) if ink else 0)


def ell(d, x0, y0, x1, y1, fill, ink=None, w=1):
    d.ellipse(box(x0, y0, x1, y1), fill=fill, outline=ink, width=int(w * K) if ink else 0)


def heart(d, x, y, r, fill, ink=INK, w=1, shine=True):
    """Heart centred on x with its lobes' tops at y - r."""
    pts = []
    import math
    for i in range(64):
        t = i / 64 * 2 * math.pi
        hx = 16 * math.sin(t) ** 3
        hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append(((x + hx / 16 * r) * K, (y + hy / 16 * r) * K))
    d.polygon(pts, fill=fill, outline=ink, width=int(w * K) if ink else 0)
    if shine:
        ell(d, x - r * .62, y - r * .55, x - r * .22, y - r * .2, WHITE)


def sparkle(d, x, y, r, fill=SPARK, ink=SPARK_EDGE):
    p = [(0, -r), (r * .28, -r * .28), (r, 0), (r * .28, r * .28), (0, r), (-r * .28, r * .28), (-r, 0), (-r * .28, -r * .28)]
    d.polygon([((x + a) * K, (y + b) * K) for a, b in p], fill=fill, outline=ink, width=K // 2 if ink else 0)


def vgrad(w, h, stops):
    """Vertical gradient image (w x h, real pixels) through [(t, hex), ...]."""
    im = Image.new("RGBA", (w, h))
    px = im.load()
    cols = [(t, tuple(int(c[i:i + 2], 16) for i in (1, 3, 5))) for t, c in stops]
    for y in range(h):
        t = y / max(h - 1, 1)
        for (t0, c0), (t1, c1) in zip(cols, cols[1:]):
            if t0 <= t <= t1:
                f = (t - t0) / max(t1 - t0, 1e-6)
                c = tuple(round(c0[i] + (c1[i] - c0[i]) * f) for i in range(3))
                break
        else:
            c = cols[-1][1]
        for x in range(w):
            px[x, y] = c + (255,)
    return im


def canon(name, scale=1.0):
    im = Image.open(CANON / f"{name}.png").convert("RGBA")
    if scale != 1.0:
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    return im


def stamp(dst, src, x, y):
    """Paste src with its bottom centre at (x, y) (real pixels)."""
    dst.alpha_composite(src, (int(x - src.width / 2), int(y - src.height)))


def face(d, x, y, s=1.0):
    for dx in (-3, 3):
        ell(d, x + dx * s - s, y - s, x + dx * s + s, y + s, INK)
    d.arc(box(x - 1.4 * s, y - .2 * s, x + 1.4 * s, y + 2.2 * s), 20, 160, fill=INK, width=max(K // 2, int(s * K * .6)))
    for dx in (-5, 5):
        ell(d, x + dx * s - 1.4 * s, y + .8 * s, x + dx * s + 1.4 * s, y + 2.2 * s, BLUSH)


# ---------------------------------------------------------------- chrome (9-slice)
# id: (w, h) -- the 9-slice texture margins are set per StyleBoxTexture in default.tres.

def chrome_panel():
    w = h = 24
    im, d = canvas(w, h)
    rr(d, 1, 2, w, h, 6, (138, 90, 90, 70), None)            # soft drop shadow
    rr(d, 0, 0, w - 1, h - 2, 6, CREAM)
    d.line([(5 * K, 1.5 * K), ((w - 6) * K, 1.5 * K)], fill=WHITE, width=K)  # top highlight
    rr(d, 2, 2.5, w - 3, h - 4, 4, None, "#f3d6cc", .5)       # inner seam
    return down(im, w, h)


def chrome_dialogue():
    w = h = 40
    im, d = canvas(w, h)
    rr(d, 1, 2, w, h, 8, (138, 90, 90, 70), None)
    rr(d, 0, 0, w - 1, h - 2, 8, CREAM)
    d.line([(7 * K, 1.5 * K), ((w - 8) * K, 1.5 * K)], fill=WHITE, width=K)
    # stitched pink inner border
    for x in range(8, w - 8, 3):
        d.line([(x * K, 3.5 * K), ((x + 1.5) * K, 3.5 * K)], fill=PINK, width=K // 2 + 1)
        d.line([(x * K, (h - 5.5) * K), ((x + 1.5) * K, (h - 5.5) * K)], fill=PINK, width=K // 2 + 1)
    for y in range(8, h - 9, 3):
        d.line([(3.5 * K, y * K), (3.5 * K, (y + 1.5) * K)], fill=PINK, width=K // 2 + 1)
        d.line([((w - 4.5) * K, y * K), ((w - 4.5) * K, (y + 1.5) * K)], fill=PINK, width=K // 2 + 1)
    for cx, cy in ((5.5, 5), (w - 6.5, 5), (5.5, h - 7), (w - 6.5, h - 7)):
        heart(d, cx, cy, 2.6, ROSE, INK, .5, shine=False)
    return down(im, w, h)


def chrome_nametag():
    w, h = 20, 14
    im, d = canvas(w, h)
    rr(d, 0, 1, w, h, 6, (138, 90, 90, 70), None)
    rr(d, 0, 0, w - 1, h - 1, 6, PINK)
    ell(d, 3, 2, 8, 4.5, WHITE)
    return down(im, w, h)


def chrome_button(state):
    w, h = 16, 16
    im, d = canvas(w, h)
    if state == "disabled":
        rr(d, 0, 1, w, h, 5, "#f3ecee", "#cdb8bb")
        return down(im, w, h)
    if state == "focus":
        rr(d, 0, 0, w, h, 6, None, ROSE, 1)
        return down(im, w, h)
    fill, depth = {"normal": (PINK_LT, PINK), "hover": (PINK_MID, "#f39ab8"), "pressed": (PINK, "#e98aaa")}[state]
    if state == "pressed":
        rr(d, 0, 1, w, h, 5, fill)                             # pushed down, no lip
        d.line([(4 * K, 2.5 * K), ((w - 5) * K, 2.5 * K)], fill=depth, width=K)
    else:
        rr(d, 0, 0, w, h, 5, depth)                            # sticker lip
        rr(d, 0, 0, w, h - 2, 5, fill)
        d.line([(4 * K, 1.5 * K), ((w - 5) * K, 1.5 * K)], fill=WHITE, width=K)
    return down(im, w, h)


def chrome_bar(kind):
    w, h = 12, 8
    im, d = canvas(w, h)
    if kind == "bg":
        rr(d, 0, 0, w, h, 3.5, "#f2e0e0")
        d.line([(3 * K, 6 * K), ((w - 3) * K, 6 * K)], fill="#e8cccc", width=K)
    else:
        rr(d, 0, 0, w, h, 3.5, ROSE)
        d.line([(3 * K, 2 * K), ((w - 3) * K, 2 * K)], fill="#ffd0de", width=K)
    return down(im, w, h)


def chrome_scroll(kind):
    w, h = 6, 12
    im, d = canvas(w, h)
    if kind == "bg":
        rr(d, 1, 0, w - 1, h, 2, "#f2e0e0", None)
    else:
        rr(d, 0, 0, w, h, 3, PINK, INK, .75)
        d.line([(2 * K, 3 * K), (2 * K, (h - 3) * K)], fill="#ffd0de", width=K)
    return down(im, w, h)


def chrome_bubble():
    w, h = 20, 16
    im, d = canvas(w, h)
    rr(d, 0, 1, w, h, 6, (138, 90, 90, 60), None)
    rr(d, 0, 0, w - 1, h - 1, 6, WHITE)
    d.line([(6 * K, 1.8 * K), ((w - 7) * K, 1.8 * K)], fill="#fff0f5", width=K)
    return down(im, w, h)


def chrome_bubble_tail():
    w, h = 9, 6
    im, d = canvas(w, h)
    d.polygon([(0, 0), (w * K, 0), (4.5 * K, h * K)], fill=INK)
    d.polygon([(1.4 * K, 0), ((w - 1.4) * K, 0), (4.5 * K, (h - 1.6) * K)], fill=WHITE)
    return down(im, w, h)


def chrome_continue():
    w, h = 9, 8
    im, d = canvas(w, h)
    heart(d, 4.5, 3.6, 4.2, ROSE, INK, .8)
    return down(im, w, h)


def chrome_ribbon():
    """Section heading ribbon: forked ends live in the 9-slice side margins (6 px)."""
    w, h = 24, 12
    im, d = canvas(w, h)
    d.polygon([(0, 1 * K), (6 * K, 1 * K), (6 * K, 11 * K), (0, 11 * K), (2.5 * K, 6 * K)], fill="#f39ab8", outline=INK, width=K)
    d.polygon([(w * K, 1 * K), ((w - 6) * K, 1 * K), ((w - 6) * K, 11 * K), (w * K, 11 * K), ((w - 2.5) * K, 6 * K)], fill="#f39ab8", outline=INK, width=K)
    rr(d, 3, 0, w - 3, h - 1, 2, PINK)
    d.line([(5 * K, 2 * K), ((w - 6) * K, 2 * K)], fill="#ffd0de", width=K)
    return down(im, w, h)


def chrome_altar_tile(fill, selected=False):
    w = h = 24
    im, d = canvas(w, h)
    rr(d, 0, 1, w, h, 6, (138, 90, 90, 70), None)
    rr(d, 0, 0, w - 1, h - 2, 6, fill)
    d.line([(6 * K, 1.5 * K), ((w - 7) * K, 1.5 * K)], fill=WHITE, width=K)
    if selected:
        rr(d, 1, 1, w - 2, h - 3, 5, None, SPARK_EDGE, 1.5)
        rr(d, 2.5, 2.5, w - 3.5, h - 4.5, 4, None, SPARK, 1)
    return down(im, w, h)


# ---------------------------------------------------------------- backdrops (640x360)

W, H = 640, 360


def curtains(d, col, dark, width=70):
    for side in (0, 1):
        x0 = 0 if side == 0 else W - width
        d.rectangle(box(x0, 0, x0 + width, H), fill=col)
        for i in range(5):
            fx = x0 + 8 + i * (width - 16) / 4
            d.line([(fx * K, 0), (fx * K + (6 if side == 0 else -6) * K, H * K)], fill=dark, width=3 * K)
        edge = x0 + width if side == 0 else x0
        d.line([(edge * K, 0), (edge * K, H * K)], fill=INK, width=K)
    # pelmet with scallops
    d.rectangle(box(0, 0, W, 16), fill=col)
    for x in range(0, W, 20):
        ell(d, x - 2, 6, x + 22, 26, col, INK, 1)
    d.rectangle(box(0, 0, W, 14), fill=col)
    d.line([(0, 14 * K), (W * K, 14 * K)], fill=dark, width=K)
    for x in range(10, W, 40):
        ell(d, x - 3, 18, x + 3, 24, SPARK, SPARK_EDGE, .5)


def bulbs(d, y, x0, x1, step=16, sag=8):
    import math
    pts = []
    for i in range(int((x1 - x0) / 2) + 1):
        x = x0 + i * 2
        t = (x - x0) / (x1 - x0)
        pts.append((x * K, (y + math.sin(t * math.pi * ((x1 - x0) // 120)) ** 2 * sag) * K))
    d.line(pts, fill=INK, width=K // 2)
    cols = [ROSE, SPARK, TURQ, LAVENDER]
    for i, x in enumerate(range(int(x0) + 4, int(x1), step)):
        t = (x - x0) / (x1 - x0)
        yy = y + math.sin(t * math.pi * ((x1 - x0) // 120)) ** 2 * sag
        ell(d, x - 2.5, yy, x + 2.5, yy + 6, cols[i % 4], INK, .5)


def spotlight(im, x, top, bottom, spread, alpha=60):
    lay, d = canvas(W, H)
    d.polygon([((x - 8) * K, top * K), ((x + 8) * K, top * K), ((x + spread) * K, bottom * K), ((x - spread) * K, bottom * K)],
              fill=(255, 250, 220, alpha))
    lay = lay.filter(ImageFilter.GaussianBlur(6 * K))
    im.alpha_composite(lay)


def audience(d, y, rng, count, cols=("#7a5a8a", "#8a6a9a", "#6a5080")):
    for i in range(count):
        x = (i + .5) * W / count + rng.uniform(-6, 6)
        c = rng.choice(cols)
        r = rng.uniform(13, 16)
        yy = y + rng.uniform(-3, 4)
        ell(d, x - r, yy - r, x + r, yy + r * 2.2, c)            # shoulders + head silhouette
        ell(d, x - r * .7, yy - r * 1.9, x + r * .7, yy - r * .4, c)
        if rng.random() < .5:                                      # a bun or a bow
            ell(d, x - 4, yy - r * 2.3, x + 4, yy - r * 1.7, c)
        else:
            heart(d, x + r * .5, yy - r * 1.6, 3, PINK, None, shine=False)


def talk_show_set():
    rng = random.Random(11)
    im = vgrad(W * K, H * K, [(0, "#e8d8f8"), (.62, "#f8e0f0"), (.63, "#f6c6d8"), (1, "#f0b0c8")])
    d = ImageDraw.Draw(im)
    # big porthole window onto the sea at sunset
    cx, cy, r = 320, 112, 74
    ell(d, cx - r - 8, cy - r - 8, cx + r + 8, cy + r + 8, "#f6e7c8", INK, 1.5)
    sea = vgrad(2 * r * K, 2 * r * K, [(0, "#ffc8a8"), (.45, "#ffb0c0"), (.55, SKY), (1, SEA)])
    mask = Image.new("L", sea.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, sea.width - 1, sea.height - 1], fill=255)
    im.paste(sea, ((cx - r) * K, (cy - r) * K), mask)
    ell(d, cx - 22, cy - 40, cx + 22, cy + 4, "#fff0b0")                    # sun
    for i in range(6):
        y = cy + 12 + i * 9
        d.line([((cx - 50 + i * 6) * K, y * K), ((cx - 20 + i * 6) * K, y * K)], fill=WHITE, width=K)
    ell(d, cx - r, cy - r, cx + r, cy + r, None, INK, 1.5)
    for a in range(0, 360, 45):
        import math
        bx, by = cx + math.cos(math.radians(a)) * (r + 4), cy + math.sin(math.radians(a)) * (r + 4)
        ell(d, bx - 2, by - 2, bx + 2, by + 2, "#d9b98a", INK, .5)
    # wall panels
    for x in (110, 470):
        rr(d, x, 40, x + 60, 200, 8, "#f4e6fb", "#c9b0d8", 1)
        heart(d, x + 30, 110, 9, PINK, INK, 1)
    # stage platform
    d.rectangle(box(0, 222, W, 232), fill="#f9d0dc")
    d.line([(0, 222 * K), (W * K, 222 * K)], fill=INK, width=K)
    d.line([(0, 232 * K), (W * K, 232 * K)], fill=INK, width=K)
    for x in range(0, W, 32):
        d.line([(x * K, 232 * K), ((x - 40) * K, H * K)], fill="#eaa8bf", width=K)
    # rug
    ell(d, 170, 236, 470, 290, "#fde9f0", INK, 1)
    ell(d, 190, 244, 450, 282, None, PINK, 1)

    def armchair(x, col, dark, flip):
        rr(d, x - 34, 150, x + 34, 222, 16, col)                             # back
        rr(d, x - 40, 186, x + 40, 236, 10, col)                             # seat block
        rr(d, x - 26, 190, x + 26, 214, 8, dark)                             # cushion
        for ax in (x - 44, x + 28):
            rr(d, ax, 176, ax + 16, 232, 8, col)                             # arms
            ell(d, ax + 3, 179, ax + 9, 183, WHITE)
        for lx in (x - 32, x + 26):
            d.rectangle(box(lx, 236, lx + 6, 248), fill=WOOD, outline=INK, width=K)
        ell(d, x - 26, 156, x - 14, 162, WHITE)
    armchair(196, "#c8b4f4", "#b49ce8", False)
    armchair(444, "#ffc0b0", "#f8a898", True)
    # little table, mugs and a vase of flowers
    rr(d, 290, 218, 350, 226, 3, WOOD)
    d.rectangle(box(316, 226, 324, 252), fill=WOOD, outline=INK, width=K)
    rr(d, 304, 248, 336, 254, 2, WOOD)
    rr(d, 296, 206, 306, 219, 2, WHITE)
    ell(d, 304, 209, 310, 215, None, INK, .8)
    rr(d, 324, 196, 336, 219, 4, "#bfe8f0")
    for fx, fy, c in ((326, 186, ROSE), (334, 184, SPARK), (330, 178, WHITE)):
        d.line([((fx + 1) * K, (fy + 4) * K), (330 * K, 197 * K)], fill="#79b45f", width=K)
        ell(d, fx - 3, fy - 3, fx + 4, fy + 4, c, INK, .5)
    # spotlights and sparkles
    curtains(d, "#f39ab8", "#e98aaa")
    bulbs(d, 30, 76, W - 76)
    for _ in range(14):
        sparkle(d, rng.uniform(80, W - 80), rng.uniform(40, 210), rng.uniform(2, 4), WHITE, None)
    out = down(im, W, H)
    spotlight(out, 196, 0, 250, 60)
    spotlight(out, 444, 0, 250, 60)
    return out


def comedy_stage():
    rng = random.Random(23)
    im = vgrad(W * K, H * K, [(0, "#d8a0b8"), (.7, "#e8b4c4"), (1, "#e8b4c4")])
    d = ImageDraw.Draw(im)
    # pastel brick wall
    for row, y in enumerate(range(16, 232, 12)):
        off = 0 if row % 2 else 14
        for x in range(-28 + off, W, 28):
            c = rng.choice(["#f0b8c8", "#eeb0c2", "#f4c0ce", "#ebaabd"])
            rr(d, x + 1, y + 1, x + 27, y + 11, 2, c, "#c98ea2", .5)
    # spotlight disc on the wall
    glow, g = canvas(W, H)
    ell(g, 220, 40, 420, 230, (255, 246, 214, 170))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10 * K)))
    d = ImageDraw.Draw(im)
    # stage floor
    d.rectangle(box(0, 230, W, H), fill="#d8a878")
    for y in (246, 266, 292, 326):
        d.line([(0, y * K), (W * K, y * K)], fill="#c09060", width=K)
    d.line([(0, 230 * K), (W * K, 230 * K)], fill=INK, width=K)
    d.rectangle(box(0, 226, W, 231), fill="#e6c294")
    # stool and microphone
    ell(d, 352, 170, 392, 182, "#f39ab8", INK, 1)
    for lx in (356, 384):
        d.line([(lx * K, 178 * K), ((lx + (-4 if lx < 370 else 4)) * K, 236 * K)], fill=INK, width=2 * K)
    d.line([(358 * K, 212 * K), (390 * K, 212 * K)], fill=INK, width=K)
    d.line([(320 * K, 120 * K), (320 * K, 236 * K)], fill="#7a6a7a", width=2 * K)
    ell(d, 304, 232, 336, 240, "#7a6a7a", INK, .8)
    rr(d, 314, 104, 326, 124, 5, "#5a4a5e", INK, .8)
    ell(d, 316, 106, 320, 112, "#9a8aa0")
    d.line([(320 * K, 128 * K), (338 * K, 132 * K)], fill="#7a6a7a", width=K)
    # neon-pink sign shape (a heart and stars, no lettering)
    heart(d, 320, 46, 18, None, ROSE, 2, shine=False)
    for sx in (270, 370):
        sparkle(d, sx, 50, 8, None, SPARK)
    curtains(d, "#e86a92", "#d05a80", 80)
    audience(d, 300, rng, 9)
    out = down(im, W, H)
    spotlight(out, 320, 0, 236, 90, 70)
    return out


def runway():
    rng = random.Random(37)
    im = vgrad(W * K, H * K, [(0, "#3a2a4e"), (.55, "#6a4a7a"), (1, "#8a5a8a")])
    d = ImageDraw.Draw(im)
    # back screen with hearts pattern
    rr(d, 200, 30, 440, 150, 10, "#f39ab8")
    for i in range(12):
        hx, hy = 222 + (i % 6) * 40, 64 + (i // 6) * 50
        heart(d, hx, hy, 9, "#ffd0e0" if i % 2 else WHITE, None, shine=False)
    rr(d, 200, 30, 440, 150, 10, None, INK, 1.5)
    # runway, vanishing to the screen
    d.polygon([(260 * K, 150 * K), (380 * K, 150 * K), (520 * K, H * K), (120 * K, H * K)], fill="#fde9f0", outline=INK, width=K)
    d.polygon([(300 * K, 150 * K), (340 * K, 150 * K), (380 * K, H * K), (260 * K, H * K)], fill="#f7c4d6")
    for i in range(10):
        t = i / 9
        y = 154 + t * (H - 158)
        for side in (-1, 1):
            x = 320 + side * (60 + t * 140)
            ell(d, x - 2 - t * 2, y - 2 - t * 2, x + 2 + t * 2, y + 2 + t * 2, SPARK, SPARK_EDGE, .5)
    # audience both sides, with camera flashes
    for side in (-1, 1):
        for row in range(3):
            for j in range(4):
                x = 320 + side * (190 + j * 34 + row * 10)
                y = 200 + row * 46
                c = ["#4a3a5e", "#5a4a6e", "#6a5080"][row]
                ell(d, x - 14, y - 6, x + 14, y + 30, c)
                ell(d, x - 10, y - 28, x + 10, y - 6, c)
                if rng.random() < .35:
                    sparkle(d, x + rng.uniform(-10, 10), y - 30, rng.uniform(5, 9), WHITE, None)
    curtains(d, "#b07ac0", "#9a68aa", 56)
    out = down(im, W, H)
    spotlight(out, 320, 0, 300, 70, 70)
    return out


def ship_cabin():
    rng = random.Random(41)
    im = vgrad(W * K, H * K, [(0, "#fdf0f4"), (1, "#fde6ee")])
    d = ImageDraw.Draw(im)
    for x in range(0, W, 24):                                               # striped wallpaper
        d.rectangle(box(x, 0, x + 12, 240), fill="#fbe2ea")
    d.rectangle(box(0, 236, W, 244), fill=WOOD, outline=INK, width=K)          # dado rail
    d.rectangle(box(0, 244, W, H), fill="#c8e4f0")                             # carpet
    for x in range(-200, W, 28):
        d.line([(x * K, H * K), ((x + 120) * K, 244 * K)], fill="#b8dcec", width=K)
    for px in (90, 550):                                                       # portholes
        ell(d, px - 30, 50, px + 30, 110, "#d9b98a", INK, 1.5)
        ell(d, px - 22, 58, px + 22, 102, SKY, INK, 1)
        d.rectangle(box(px - 22, 84, px + 22, 102), fill=SEA)
        ell(d, px - 22, 58, px + 22, 102, None, INK, 1)
        ell(d, px - 14, 64, px - 6, 70, WHITE)
    # vanity with bulbs
    rr(d, 250, 40, 390, 170, 18, "#d9b98a")
    rr(d, 260, 50, 380, 160, 12, "#e8f4fa")
    d.line([(280 * K, 70 * K), (300 * K, 60 * K)], fill=WHITE, width=3 * K)
    for i in range(7):
        a = i / 6
        for bx, by in ((256 + a * 128, 44), (256 + a * 128, 166)):
            ell(d, bx - 4, by - 4, bx + 4, by + 4, SPARK, SPARK_EDGE, .5)
    rr(d, 230, 172, 410, 186, 4, WOOD)
    for lx in (240, 396):
        d.rectangle(box(lx, 186, lx + 6, 240), fill=WOOD, outline=INK, width=K)
    for i, c in enumerate((ROSE, LAVENDER, TURQ, SPARK)):
        rr(d, 252 + i * 22, 156, 264 + i * 22, 172, 3, c)
    # wardrobe and bed corner
    rr(d, 440, 60, 520, 236, 6, "#f4e6fb", INK, 1)
    d.line([(480 * K, 64 * K), (480 * K, 232 * K)], fill=INK, width=K)
    for kx in (474, 484):
        ell(d, kx - 2, 146, kx + 2, 150, SPARK_EDGE)
    rr(d, 30, 180, 200, 250, 10, "#ffffff")
    rr(d, 30, 210, 200, 250, 10, PINK)
    rr(d, 40, 186, 96, 208, 8, "#fff6fa")
    for _ in range(10):
        heart(d, rng.uniform(120, 620), rng.uniform(10, 30), 3, PINK, None, shine=False)
    return down(im, W, H)


def ship_cutaway():
    """Side cutaway of the cruise ship, bow to the right: the Landing's station map (600x150)."""
    w, h = 600, 150
    im, d = canvas(w, h)
    # hull
    d.polygon([(20 * K, 92 * K), (590 * K, 92 * K), (560 * K, 146 * K), (60 * K, 146 * K)], fill=SKY, outline=INK, width=K)
    d.polygon([(26 * K, 104 * K), (586 * K, 104 * K), (582 * K, 112 * K), (30 * K, 112 * K)], fill=PINK)
    for x in range(80, 560, 26):
        ell(d, x - 4, 122, x + 4, 130, "#e8f4fa", INK, .8)
    # decks: lido (bottom row in data), atrium, promenade, bridge up front
    rr(d, 40, 50, 560, 94, 6, "#fff6fa")
    rr(d, 90, 18, 470, 52, 6, "#fde9f0")
    rr(d, 430, 4, 540, 30, 6, "#ffffff")                                  # bridge
    for x in range(440, 534, 14):
        rr(d, x, 10, x + 10, 20, 2, "#bfe8f0", INK, .5)
    for x in range(56, 548, 18):
        rr(d, x, 62, x + 12, 76, 3, "#bfe8f0", INK, .5)
    for x in range(104, 460, 18):
        rr(d, x, 28, x + 12, 40, 3, "#d8ccf8", INK, .5)
    # funnel
    d.polygon([(200 * K, 19 * K), (208 * K, 1 * K), (250 * K, 1 * K), (246 * K, 19 * K)], fill=PINK, outline=INK, width=K)
    d.rectangle(box(206, 6, 248, 10), fill=SKY)
    # bunting
    for x in range(20, 580, 14):
        c = [ROSE, SKY, SPARK, LAVENDER][(x // 14) % 4]
        d.polygon([(x * K, 46 * K), ((x + 10) * K, 46 * K), ((x + 5) * K, 53 * K)], fill=c, outline=INK, width=K // 2)
    d.line([(20 * K, 46 * K), (580 * K, 46 * K)], fill=INK, width=K // 2)
    # bow face
    face(d, 548, 120, 1.6)
    out = down(im, w, h)
    # drifting fog
    fog, f = canvas(w, h)
    rng = random.Random(53)
    for _ in range(18):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ell(f, x - 50, y - 8, x + 50, y + 8, (255, 255, 255, 45))
    out.alpha_composite(down(fog.filter(ImageFilter.GaussianBlur(4 * K)), w, h))
    return out


def fog_sea():
    """The Landing: fog over a grey-blue sea, nothing on the horizon yet."""
    rng = random.Random(97)
    im = vgrad(W * K, H * K, [(0, "#ece6f2"), (.45, "#e2e4ee"), (.5, "#c8d8e2"), (1, "#a8c4d4")])
    d = ImageDraw.Draw(im)
    for _ in range(60):
        x, y = rng.uniform(0, W), rng.uniform(186, H)
        d.arc(box(x - 6, y - 2, x + 6, y + 4), 200, 340, fill="#e8f2f6", width=K)
    out = down(im, W, H)
    fog, f = canvas(W, H)
    for _ in range(26):
        x, y = rng.uniform(-40, W + 40), rng.uniform(40, H - 20)
        ell(f, x - 90, y - 14, x + 90, y + 14, (255, 255, 255, 110))
    out.alpha_composite(down(fog.filter(ImageFilter.GaussianBlur(8 * K)), W, H))
    return out


def temple_altar():
    rng = random.Random(61)
    im, d = canvas(W, H, (255, 255, 255, 255))
    for x in range(0, W, 32):                                                  # blue-and-white stripes
        d.rectangle(box(x, 0, x + 16, 250), fill="#a8d4f5")
    d.rectangle(box(0, 0, W, 22), fill="#ffe59a")
    d.line([(0, 22 * K), (W * K, 22 * K)], fill=SPARK_EDGE, width=K)
    for x in range(8, W, 16):
        ell(d, x - 3, 8, x + 3, 14, "#fff4c4", SPARK_EDGE, .5)
    d.rectangle(box(0, 246, W, H), fill=STONE)                                # blush stone floor
    d.line([(0, 246 * K), (W * K, 246 * K)], fill=INK, width=K)
    for y in range(262, H, 20):
        d.line([(0, y * K), (W * K, y * K)], fill="#e6cccc", width=K)
    for x in range(0, W, 40):
        d.line([(x * K, 246 * K), ((x - 30) * K, H * K)], fill="#e6cccc", width=K)
    for cx in (26, 96, 544, 614):                                              # candles
        rr(d, cx - 5, 226, cx + 5, 252, 3, CREAM)
        ell(d, cx - 3.5, 214, cx + 3.5, 226, "#ffe27a", SPARK_EDGE, .5)
    out = down(im, W, H)
    for x in (60, 580):
        stamp(out, canon("prop_pillar_orb", 1.25), x, 262)
    sp, s = canvas(W, H)
    for _ in range(16):
        sparkle(s, rng.uniform(20, W - 20), rng.uniform(30, 240), rng.uniform(2, 4))
    out.alpha_composite(down(sp, W, H))
    return out


# ---------------------------------------------------------------- Gemini stand-ins

def title_screen_plain():
    """The island at golden hour: pastel sky and sea, canon bunker homes, trees and the wreck."""
    rng = random.Random(71)
    im = vgrad(W * K, H * K, [(0, "#ffd8b8"), (.3, "#ffc8d8"), (.52, "#f8d8f0"), (.53, SKY), (1, "#70c8d0")])
    d = ImageDraw.Draw(im)
    for _ in range(7):                                                         # soft clouds
        x, y = rng.uniform(0, W), rng.uniform(20, 140)
        for dx in (-18, 0, 18):
            ell(d, x + dx - 16, y - 10 + abs(dx) / 3, x + dx + 16, y + 10, (255, 255, 255, 200))
    for _ in range(40):                                                        # sea glints
        x, y = rng.uniform(0, W), rng.uniform(196, H)
        d.line([(x * K, y * K), ((x + rng.uniform(4, 10)) * K, y * K)], fill=WHITE, width=K)
    # island: sand rim then grass
    ell(d, 40, 236, 600, 400, SAND, INK, 1.5)
    ell(d, 64, 248, 576, 410, GRASS, INK, 1)
    for _ in range(30):
        x, y = rng.uniform(100, 540), rng.uniform(270, 350)
        ell(d, x - 3, y - 2, x + 3, y + 2, LEAF)
    out = down(im, W, H)
    stamp(out, canon("prop_ship", .8), 520, 300)
    stamp(out, canon("prop_bunker", .55), 150, 300)
    stamp(out, canon("prop_bunker", .45), 250, 290)
    for i, (x, y) in enumerate(((80, 316), (330, 300), (400, 330), (210, 340), (300, 352), (110, 356))):
        stamp(out, canon("deco_tree_" + "abc"[i % 3]), x, y)
    for x, y in ((180, 330), (360, 350), (440, 352), (260, 356)):
        stamp(out, canon("deco_flowers"), x, y)
    for _ in range(9):
        stamp(out, canon("deco_heart"), rng.uniform(40, 600), rng.uniform(30, 190))
    for _ in range(14):
        stamp(out, canon("deco_sparkle"), rng.uniform(20, 620), rng.uniform(20, 220))
    return out


def chapter_card():
    """The ship before the wreck at sunset: white with gold trim and a smiling bow face, lit up,
    string lights and balloons, seen slightly from below over a sunset-gold and lavender sea, with
    film grain and faint VHS lines. The sky stays dark above the horizon so the card's centred 85%
    white lines read over it (STYLE.md 4.10); the ship sits low at the right, clear of them."""
    rng = random.Random(83)
    sky = vgrad(W * K, H * K, [(0, "#05080f"), (.45, "#2a1838"), (.64, "#a04a68"), (.72, CORAL),
                               (.73, "#c890a8"), (.8, "#9a78b0"), (1, "#3a2a58")])
    im = sky.copy()
    d = ImageDraw.Draw(im)
    ell(d, 70, 236, 150, 290, "#ffd080")                                    # setting sun, half set
    im.paste(sky.crop((0, 263 * K, W * K, H * K)), (0, 263 * K))
    d.rectangle(box(0, 263, W, 265), fill="#f0b8a8")                         # horizon glow
    for i in range(12):                                                      # sun path on the water
        y = 267 + i * 7
        half = 28 - i * 1.6
        d.line([((110 - half) * K, y * K), ((110 + half) * K, y * K)], fill="#ffd0a0", width=K)
    # the ship, bow to the left, drawn large on its own canvas then set small at the lower right
    ship_im, d = canvas(W, H)
    hull_lit, deck_lit, trim = "#fff4ec", "#fffaf2", "#e8c060"
    ow = 3                                                                   # outline, canvas px
    d.polygon([(250 * K, 230 * K), (620 * K, 230 * K), (600 * K, 284 * K), (300 * K, 284 * K)],
              fill=hull_lit, outline=INK, width=ow * K)
    d.line([(262 * K, 240 * K), (614 * K, 240 * K)], fill=trim, width=4 * K)    # gold trim
    d.line([(280 * K, 266 * K), (606 * K, 266 * K)], fill=PINK, width=5 * K)    # pink stripe
    for x0, x1, y0 in ((290, 600, 200), (320, 580, 176), (350, 540, 154), (420, 500, 134)):
        d.rectangle(box(x0, y0, x1, y0 + 30), fill=deck_lit, outline=INK, width=ow * K)
        d.line([((x0 + 3) * K, (y0 + 3) * K), ((x1 - 3) * K, (y0 + 3) * K)], fill=trim, width=2 * K)
    d.polygon([(450 * K, 134 * K), (460 * K, 104 * K), (494 * K, 104 * K), (490 * K, 134 * K)],
              fill=PINK, outline=INK, width=ow * K)                          # funnel
    d.rectangle(box(455, 112, 492, 120), fill=WHITE)
    for y0, x0, x1 in ((208, 296, 596), (184, 326, 576), (162, 356, 536), (246, 360, 590)):
        for x in range(x0, x1, 9):
            if rng.random() < .82:
                d.rectangle(box(x, y0, x + 5, y0 + 5), fill=rng.choice(["#ffe08a", "#ffd070", "#fff0b0"]),
                            outline="#c09060", width=K)
    face(d, 296, 250, 2.6)                                                   # smiling bow
    # string lights from bow to funnel to stern, and balloons
    import math
    for (ax, ay), (bx, by) in (((252, 228), (470, 104)), ((470, 104), (618, 226))):
        n = int(math.dist((ax, ay), (bx, by)) / 7)
        for i in range(n + 1):
            t = i / n
            x, y = ax + (bx - ax) * t, ay + (by - ay) * t + math.sin(t * math.pi) * 10
            c = [ROSE, SPARK, TURQ, LAVENDER][i % 4]
            ell(d, x - 2, y - 2, x + 2, y + 2, c)
    for _ in range(9):
        x, y = rng.uniform(320, 620), rng.uniform(64, 120)
        c = rng.choice([ROSE, LAVENDER, TURQ, SPARK])
        d.line([(x * K, (y + 9) * K), ((x + rng.uniform(-4, 4)) * K, (y + 30) * K)], fill=INK, width=K)
        ell(d, x - 6, y - 7, x + 6, y + 9, c, INK, 1.5)
        ell(d, x - 3.5, y - 4, x - 1, y - 1, WHITE)
    ship_im = ship_im.crop((240 * K, 50 * K, 630 * K, 290 * K))
    ship_im = ship_im.resize((ship_im.width // 2, ship_im.height // 2), Image.LANCZOS)
    im.alpha_composite(ship_im, (442 * K, 218 * K))
    out = down(im, W, H)
    # film grain, VHS lines and a vignette
    px = out.load()
    for y in range(H):
        line = -10 if y % 3 == 0 else 0
        for x in range(W):
            r, g, b, a = px[x, y]
            n = rng.randint(-9, 9) + line
            px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)), a)
    vig, v = canvas(W, H)
    v.rectangle([0, 0, W * K, H * K], fill=(5, 8, 15, 170))
    v.ellipse([60 * K, 20 * K, (W - 60) * K, (H - 20) * K], fill=(0, 0, 0, 0))
    out.alpha_composite(down(vig.filter(ImageFilter.GaussianBlur(30 * K)), W, H))
    return out


CHROME = {
    # id: (draw, 9-slice margin)   margins are the texture_margin_* in themes/default.tres
    "panel": (chrome_panel, 7),
    "dialogue": (chrome_dialogue, 11),
    "nametag": (chrome_nametag, 6),
    "button_normal": (lambda: chrome_button("normal"), 5),
    "button_hover": (lambda: chrome_button("hover"), 5),
    "button_pressed": (lambda: chrome_button("pressed"), 5),
    "button_disabled": (lambda: chrome_button("disabled"), 5),
    "button_focus": (lambda: chrome_button("focus"), 5),
    "bar_bg": (lambda: chrome_bar("bg"), 4),
    "bar_fill": (lambda: chrome_bar("fill"), 4),
    "scroll_bg": (lambda: chrome_scroll("bg"), 3),
    "scroll_grabber": (lambda: chrome_scroll("grab"), 3),
    "bubble": (chrome_bubble, 6),
    "bubble_tail": (chrome_bubble_tail, 0),
    "continue_heart": (chrome_continue, 0),
    "ribbon": (chrome_ribbon, 6),
    "altar_tile_rose": (lambda: chrome_altar_tile("#f7a8c4"), 7),
    "altar_tile_sky": (lambda: chrome_altar_tile("#a8d8f0"), 7),
    "altar_tile_gold": (lambda: chrome_altar_tile("#f9e4a8"), 7),
    "altar_tile_selected": (lambda: chrome_altar_tile("#fff6d8", True), 7),
}

if __name__ == "__main__":
    for cid, (fn, _m) in CHROME.items():
        save(fn(), f"ui/chrome/{cid}.png")
    save(talk_show_set(), "ui/backdrops/talk_show_set.png")
    save(comedy_stage(), "ui/backdrops/comedy_stage.png")
    save(runway(), "ui/backdrops/runway.png")
    save(ship_cabin(), "ui/backdrops/ship_cabin.png")
    save(ship_cutaway(), "ui/backdrops/ship_cutaway.png")
    save(temple_altar(), "ui/backdrops/temple_altar.png")
    save(fog_sea(), "ui/backdrops/fog_sea.png")
    save(title_screen_plain(), "ui/title/title_screen_plain.png")
    save(chapter_card(), "ui/chapter_cards/chapter_card_before_the_wreck.png")
