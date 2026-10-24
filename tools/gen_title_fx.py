#!/usr/bin/env python3
"""Draw the layers of the animated title screen (scenes/ui/main_menu_backdrop.tscn, bd 3m3).

Usage: python3 -I tools/gen_title_fx.py   (run after tools/gen_ui_art.py, gen_island_deco.py,
                                          gen_florida_art.py and cut_island_props.py: it reads
                                          their output and draws with gen_ui_art's helpers)

The author's spec: the island and the wreck in the background with waves crashing and the day
sped up into a day/night cycle; palms swaying; birds flying, landing and flying again; charms
falling slowly in the foreground like anime cherry-blossom petals, blurred with depth (hearts,
Atwood's skull, polar bear cubs, the Seal of the O book-club seal, a chibi uterus in estrus
that winks); the O drawn very slowly over the title theme, finished at about 80% of the track,
then a blood trickle down to the end of the track, a fade and a reset.

Outputs (project/assets/ui/title/ unless said):
  sky_day.png, sky_dusk.png, sky_night.png   640x360: sky-and-sea gradients for the three
                                             phases the backdrop crossfades (dusk = the golden
                                             hour of title_screen_plain.png)
  clouds.png                                 1280x400 transparent (2x): seven soft clouds, drifted
                                             and wrapped by the backdrop
  waves.png                                  4 frames of 1280x328 (2x), one per row: the sea's
                                             white glints and little crests, played as a loop
  foam.png                                   6 frames of 1184x272 (2x), one per row: the surf
                                             lapping round the island's shore (frame origin in
                                             project/data/title_layout.json "foam")
  island.png                                 2352x760 (4x): sand rim, grass, bunker homes, the
                                             temple, the wreck and flowers; no trees (they sway
                                             as their own sprites) and no sky
  sun.png, moon.png                          160x160 (4x of 40 world px) with faces
  bird.png                                   3 frames of 56x48 (4x of 14x12): wings up, wings
                                             down, perched
  o_ring.png, o_drip.png                     600x920 (4x of 150x230): the O as the book trailer
                                             poster paints it (site/public/img/trailer-poster.jpg),
                                             a thick uneven dark-red brush-stroke ring that starts
                                             at the top and runs clockwise to just short of a full
                                             turn, and, on the same canvas, its drips: one long one
                                             from the lower right and two short ones; the backdrop
                                             reveals the ring along its stroke (shaders/
                                             reveal_ring.gdshader) and the drips top-down
  charm_<kind>.png, charm_<kind>_mid.png, charm_<kind>_far.png
                                             4x of about 16 world px; _mid and _far are the same
                                             charm blurred for the middle and far depth layers;
                                             kinds: heart (canon deco_heart), sparkle (canon
                                             deco_sparkle), skull (Atwood's skull cut from the
                                             canon skull altar), cub (the polar bear cub rig's
                                             front idle frame), seal (canon prop_seal_o, the Seal
                                             of the O / book club), uterus and uterus_wink (drawn
                                             here: pink, two dot eyes, blush, a smile, a little
                                             heart; the wink frame has one eye shut)
  project/data/title_layout.json             where the layers and the sprites go, in 640x360
                                             world px: the island and foam frame origins, the
                                             tree and palm spots, the birds' perches, the O and
                                             the track length the backdrop falls back on

No randomness beyond fixed seeds: the same inputs give the same PNGs.
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_ui_art as ui  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "project/assets"
OUT = "ui/title"
W, H = 640, 360
SEA_TOP = 196                    # the horizon in title_screen_plain
INK = ui.INK
WHITE = "#ffffff"
PINK, PINK_DEEP, BLUSH = "#ffb3c8", "#ff8fb1", "#ff9fb8"
GOLD, GOLD_EDGE, GOLD_PALE = "#ffe59a", "#e0b24a", "#fff4c4"
CORAL = "#f08060"
RED = "#d04848"

SKIES = {
    # the golden hour of title_screen_plain, a plain day and a soft night; sea below SEA_TOP
    "dusk": [(0, "#ffd8b8"), (.3, "#ffc8d8"), (.52, "#f8d8f0"), (.53, ui.SKY), (1, "#70c8d0")],
    "day": [(0, "#8cc8f0"), (.3, "#a8d4f5"), (.52, "#d8ecfa"), (.53, "#7fc9dc"), (1, "#5fb8c8")],
    "night": [(0, "#2a2850"), (.3, "#3e3a70"), (.52, "#6a5a98"), (.53, "#2e567a"), (1, "#3a6f90")],
}

# Where things go, in 640x360 world px (the island composition of gen_ui_art.title_screen_plain).
TREES = [(80, 316, "a"), (330, 300, "b"), (400, 330, "c"), (210, 340, "a"), (300, 352, "b"), (110, 356, "c")]
PALMS = [(62, 296, "a"), (455, 357, "b")]
PERCHES = [[150, 236], [250, 238], [385, 220], [548, 188], [80, 266], [455, 296]]
ISLAND_BOX = (36, 170, 624, 360)          # x0, y0, x1, y1 of island.png in world px
FOAM_BOX = (24, 224, 616, 360)            # one foam frame
O_SEAL = {"cx": 100, "cy": 118, "r": 54, "ring_w": 150, "ring_h": 230, "ring_cx": 75, "ring_cy": 78, "scale": 0.25}
REDS = ["#8c1c1c", "#a62828", "#6b1212", "#9a2222", "#b23030"]
TRACK_SECONDS_FALLBACK = 172.0            # the title theme's length when no stream is playing


def save(im, rel):
    ui.save(im, f"{OUT}/{rel}")


def trim(im):
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


# ---------------------------------------------------------------- sky, clouds, sea
def skies():
    ui.use_scale((2, 1))
    for name, stops in SKIES.items():
        save(ui.vgrad(W, H, stops), f"sky_{name}.png")


def clouds():
    ui.use_scale((8, 2))
    rng = random.Random(71)
    im, d = ui.canvas(W, 200)
    for _ in range(7):
        x, y = rng.uniform(20, W - 20), rng.uniform(24, 150)
        for dx in (-18, 0, 18):
            ui.ell(d, x + dx - 16, y - 10 + abs(dx) / 3, x + dx + 16, y + 10, (255, 255, 255, 215))
    save(ui.down(im, W, 200), "clouds.png")


def waves():
    """Four frames of the sea's glints and crests; the dashes shift and some blink between frames."""
    ui.use_scale((8, 2))
    band = H - SEA_TOP
    rng = random.Random(72)
    dashes = [(rng.uniform(0, W), rng.uniform(4, band - 2), rng.uniform(4, 10), rng.random()) for _ in range(44)]
    crests = [(rng.uniform(0, W), rng.uniform(20, band - 20), rng.uniform(10, 18)) for _ in range(10)]
    sheet = Image.new("RGBA", (W * ui.O, band * ui.O * 4))
    for f in range(4):
        im, d = ui.canvas(W, band)
        for x, y, ln, blink in dashes:
            if (blink * 4 + f) % 4 < 3:                       # each dash sits one frame out
                d.line([((x + f * 1.5) * ui.K, y * ui.K), ((x + f * 1.5 + ln) * ui.K, y * ui.K)], fill=WHITE, width=ui.K)
        for x, y, r in crests:                               # a crest: a small white arc that rolls
            ph = f / 4
            ui_arc = [x - r, y - r * .5 + ph * 2, x + r, y + r * .5 + ph * 2]
            d.arc(ui.box(*ui_arc), 200 + ph * 20, 340 - ph * 20, fill=(255, 255, 255, 230), width=ui.K)
        sheet.alpha_composite(ui.down(im, W, band), (0, f * band * ui.O))
    save(sheet, "waves.png")


def foam():
    """Six frames of surf round the island's sand rim: a soft white band whose edge laps in and out."""
    ui.use_scale((4, 2))
    x0, y0, x1, y1 = FOAM_BOX
    fw, fh = x1 - x0, y1 - y0
    cx, cy, rx, ry = 320, 318, 280, 82                        # the sand ellipse (40,236)-(600,400)
    sheet = Image.new("RGBA", (fw * ui.O, fh * ui.O * 6))
    for f in range(6):
        im, d = ui.canvas(fw, fh)
        ph = f / 6 * 2 * math.pi
        outer, inner = [], []
        for i in range(240):
            th = i / 240 * 2 * math.pi
            wob = 4 * math.sin(5 * th + ph) + 2.5 * math.sin(9 * th - ph) + 1.5 * math.sin(13 * th + 2 * ph)
            outer.append(((cx + (rx + 6 + wob) * math.cos(th) - x0) * ui.K, (cy + (ry + 6 + wob * .6) * math.sin(th) - y0) * ui.K))
            inner.append(((cx + (rx + 1) * math.cos(th) - x0) * ui.K, (cy + (ry + 1) * math.sin(th) - y0) * ui.K))
        d.polygon(outer, fill=(255, 255, 255, 215))
        d.polygon(inner, fill=(0, 0, 0, 0))
        rng = random.Random(100 + f)
        for _ in range(40):                                   # bubbles in the wash
            th = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(8, 13)
            px, py = cx + (rx + r) * math.cos(th) - x0, cy + (ry + r * .7) * math.sin(th) - y0
            ui.ell(d, px - 1.2, py - 1.2, px + 1.2, py + 1.2, (255, 255, 255, 200))
        im = im.filter(ImageFilter.GaussianBlur(ui.K * .7))
        sheet.alpha_composite(ui.down(im, fw, fh), (0, f * fh * ui.O))
    save(sheet, "foam.png")


# ---------------------------------------------------------------- the island
def island():
    """title_screen_plain's island without sky, trees, hearts and sparkles, cropped to ISLAND_BOX."""
    ui.use_scale((8, 4))
    rng = random.Random(71)
    im, d = ui.canvas(W, H)
    ui.ell(d, 40, 236, 600, 400, ui.SAND, INK, 1.5)
    ui.ell(d, 64, 248, 576, 410, ui.GRASS, INK, 1)
    for _ in range(30):
        x, y = rng.uniform(100, 540), rng.uniform(270, 350)
        ui.ell(d, x - 3, y - 2, x + 3, y + 2, ui.LEAF)
    out = ui.down(im, W, H)
    ui.stamp(out, ui.canon("prop_ship", 120), 520, 300)
    ui.stamp(out, ui.canon("prop_bunker", 66), 150, 300)
    ui.stamp(out, ui.canon("prop_bunker", 54), 250, 290)
    ui.stamp(out, ui.asset("island/temple_pavilion", 74), 385, 292)
    for x, y in ((180, 330), (360, 350), (440, 352), (260, 356)):
        ui.stamp(out, ui.canon("deco_flowers", 22), x, y)
    x0, y0, x1, y1 = ISLAND_BOX
    save(out.crop((x0 * ui.O, y0 * ui.O, x1 * ui.O, y1 * ui.O)), "island.png")


# ---------------------------------------------------------------- sun, moon, birds, drop
def sun():
    ui.use_scale((8, 4))
    im, d = ui.canvas(40, 40)
    for i in range(8):                                        # short rounded rays
        a = i / 8 * 2 * math.pi
        x, y = 20 + 17 * math.cos(a), 20 + 17 * math.sin(a)
        d.line([(20 * ui.K, 20 * ui.K), (x * ui.K, y * ui.K)], fill=GOLD_EDGE, width=int(3.2 * ui.K))
        d.line([(20 * ui.K, 20 * ui.K), (x * ui.K, y * ui.K)], fill=GOLD, width=int(2 * ui.K))
    ui.ell(d, 7, 7, 33, 33, GOLD, INK, 1)
    ui.ell(d, 11, 10, 18, 15, GOLD_PALE)
    ui.face(d, 20, 20, 1.0)
    save(ui.down(im, 40, 40), "sun.png")


def moon():
    ui.use_scale((8, 4))
    im, d = ui.canvas(40, 40)
    ui.ell(d, 6, 6, 34, 34, GOLD_PALE, INK, 1)
    cut = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(cut).ellipse(ui.box(14, 2, 40, 28), fill=(255, 255, 255, 255))
    im.paste((0, 0, 0, 0), mask=cut.split()[3])             # bite out the crescent
    d = ImageDraw.Draw(im)
    d.arc(ui.box(14, 2, 40, 28), 95, 275, fill=INK, width=ui.K)
    ui.face(d, 15, 21, .85)
    save(ui.down(im, 40, 40), "moon.png")


def bird():
    """Three frames of a little white seabird: wings up, wings down, perched."""
    ui.use_scale((8, 4))
    sheet = Image.new("RGBA", (14 * ui.O * 3, 12 * ui.O))
    for f in range(3):
        im, d = ui.canvas(14, 12)
        ui.ell(d, 3, 5, 11, 11, WHITE, INK, .8)               # body
        ui.ell(d, 8, 3, 13, 8, WHITE, INK, .8)                # head
        d.polygon([(12.5 * ui.K, 5.5 * ui.K), (14 * ui.K, 6.2 * ui.K), (12.5 * ui.K, 6.9 * ui.K)], fill=CORAL)
        ui.ell(d, 10.3, 4.6, 11.3, 5.6, INK)                  # eye
        if f == 0:
            d.line([(6 * ui.K, 8 * ui.K), (4 * ui.K, 1 * ui.K), (1 * ui.K, 4 * ui.K)], fill=INK, width=int(1.6 * ui.K), joint="curve")
            d.line([(6 * ui.K, 8 * ui.K), (4 * ui.K, 1.6 * ui.K)], fill=WHITE, width=int(.8 * ui.K))
        elif f == 1:
            d.line([(6 * ui.K, 7 * ui.K), (3 * ui.K, 11.5 * ui.K), (0.5 * ui.K, 10 * ui.K)], fill=INK, width=int(1.6 * ui.K), joint="curve")
        else:
            ui.ell(d, 3.5, 6, 8.5, 9.5, "#f4f4ff", INK, .6)   # folded wing
            d.line([(5 * ui.K, 11 * ui.K), (5 * ui.K, 12 * ui.K)], fill=CORAL, width=ui.K)
            d.line([(8 * ui.K, 11 * ui.K), (8 * ui.K, 12 * ui.K)], fill=CORAL, width=ui.K)
        sheet.alpha_composite(ui.down(im, 14, 12), (f * 14 * ui.O, 0))
    save(sheet, "bird.png")


def o_ring():
    """The poster's O: a brush-stroke ring, thick and uneven, drawn as runs of round dabs along a
    slightly wandering circle in several dark reds (opaque, so the passes streak over each other),
    tapered at both ends, with dry-brush breaks and bristle lines; and, in o_drip.png on the same
    canvas, its drips."""
    ui.use_scale((8, 4))
    o = O_SEAL
    w, h, cx, cy, r = o["ring_w"], o["ring_h"], o["ring_cx"], o["ring_cy"], 54
    k = ui.K
    rng = random.Random(9)
    colour, dc = ui.canvas(w, h)
    mask = Image.new("L", colour.size, 0)
    dm = ImageDraw.Draw(mask)
    start, end = -90, 268                                      # degrees: from the top, clockwise, an enso gap
    passes = [(REDS[i % len(REDS)], rng.uniform(-3, 3), rng.uniform(.55, 1.0), rng.uniform(0, 6.28), rng.uniform(0, 6.28)) for i in range(8)]
    for col, dr, wm, wob_a, wob_b in passes:
        rc = tuple(int(col[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
        for deg in range(start, end + 1):
            t = (deg - start) / (end - start)
            th = math.radians(deg)
            taper = min(1.0, t / .07, (1 - t) / .16)
            width = (9 + 3.5 * math.sin(th + wob_a) + 1.5 * math.sin(3 * th + wob_b)) * wm * (.5 + .5 * taper) + rng.uniform(-.8, .8)
            rr = r + dr + 1.2 * math.sin(2 * th + wob_a) + rng.uniform(-.5, .5)
            px, py = cx + rr * math.cos(th), cy + rr * math.sin(th)
            bb = [(px - width / 2) * k, (py - width / 2) * k, (px + width / 2) * k, (py + width / 2) * k]
            dc.ellipse(bb, fill=rc)
            dm.ellipse(bb, fill=255)
    for _ in range(18):                                         # bristle lines: thin lighter and darker arcs
        a0 = rng.uniform(start + 8, end - 30)
        rr = r + rng.uniform(-5, 5)
        dc.arc(ui.box(cx - rr, cy - rr, cx + rr, cy + rr), a0, a0 + rng.uniform(12, 45),
               fill=(rng.choice([(176, 64, 64), (92, 14, 14)])) + (255,), width=int(.6 * k))
    for _ in range(10):                                         # dry-brush breaks near the edges
        a0 = rng.uniform(start + 30, end - 30)
        rr = r + rng.choice([-1, 1]) * rng.uniform(3.5, 6.5)
        dm.arc(ui.box(cx - rr, cy - rr, cx + rr, cy + rr), a0, a0 + rng.uniform(6, 20), fill=0, width=int(.9 * k))
    colour.putalpha(mask)
    colour = colour.filter(ImageFilter.GaussianBlur(k * .22))
    save(ui.down(colour, w, h), "o_ring.png")
    # the drips: a long one from the lower right, two short ones from the bottom
    im, d = ui.canvas(w, h)
    dark = (116, 20, 20, 255)
    for ang, length, width in ((48, 104, 7.0), (76, 16, 4.6), (102, 26, 5.2)):
        th = math.radians(ang)
        sx, sy = cx + (r + 2) * math.cos(th), cy + (r + 2) * math.sin(th)
        for i in range(int(length * 2)):
            y = sy + i / 2
            wd = width * (1 - .5 * i / (length * 2))
            x = sx + .5 * math.sin(i * .05)
            d.ellipse([(x - wd / 2) * k, (y - wd / 4) * k, (x + wd / 2) * k, (y + wd / 4) * k], fill=dark)
        ex, ey = sx + .5 * math.sin(length * .1), sy + length
        d.ellipse([(ex - width * .6) * k, (ey - width * .75) * k, (ex + width * .6) * k, (ey + width * .5) * k], fill=dark)
        d.ellipse([(ex - width * .28) * k, (ey - width * .35) * k, (ex - width * .06) * k, (ey - width * .05) * k], fill=(214, 110, 110, 255))
        d.ellipse([(sx - width * .9) * k, (sy - width * .35) * k, (sx + width * .9) * k, (sy + width * .35) * k], fill=dark)   # the bead where it leaves the ring
    im = im.filter(ImageFilter.GaussianBlur(k * .18))
    save(ui.down(im, w, h), "o_drip.png")


# ---------------------------------------------------------------- charms
def charm_skull():
    """Atwood's skull with its flower crown and bow, cut off the canon skull altar's pedestal."""
    im = Image.open(ASSETS / "canon/prop_skull_altar.png").convert("RGBA")
    return trim(im.crop((0, 0, im.width, 136)))


def charm_cub():
    """The polar bear cub rig's front idle frame (scripts/ruins/sheet_rig.gd CUB: 192x176 frames)."""
    im = Image.open(ASSETS / "ruins/clone_polar_bear.png").convert("RGBA")
    return trim(im.crop((0, 0, 192, 176)))


def charm_uterus(wink):
    """A chibi uterus in estrus: pink, two round ovaries on curling tubes, a face and a heart."""
    ui.use_scale((8, 4))
    im, d = ui.canvas(24, 24)
    k = ui.K
    cx, cy = 12, 12.5
    for side in (-1, 1):                                      # tubes curling up and out
        bx = cx + side * 5.2
        d.arc(ui.box(bx - 4, cy - 9.5, bx + 4, cy - 1.5), 180 if side < 0 else 270, 270 if side < 0 else 360, fill=INK, width=int(2.6 * k))
        d.arc(ui.box(bx - 4, cy - 9.5, bx + 4, cy - 1.5), 180 if side < 0 else 270, 270 if side < 0 else 360, fill=PINK, width=int(1.4 * k))
    body = [(cx - 6.5, cy - 4), (cx + 6.5, cy - 4), (cx + 2.4, cy + 7.5), (cx - 2.4, cy + 7.5)]
    d.polygon([(x * k, y * k) for x, y in body], fill=PINK, outline=INK, width=k)
    ui.ell(d, cx - 6.6, cy - 7.2, cx + 6.6, cy + 1.2, PINK, INK, 1)
    d.polygon([(x * k, y * k) for x, y in [(cx - 5.9, cy - 3), (cx + 5.9, cy - 3), (cx + 2.2, cy + 7), (cx - 2.2, cy + 7)]], fill=PINK)
    ui.ell(d, cx - 2.6, cy + 5.2, cx + 2.6, cy + 9.4, PINK, INK, 1)
    ui.ell(d, cx - 2.0, cy + 5.8, cx + 2.0, cy + 8.6, PINK)
    ui.ell(d, cx - 5.2, cy - 6, cx - 2.8, cy - 4.4, (255, 255, 255, 200))            # shine
    for side in (-1, 1):                                      # ovaries
        ox = cx + side * 9.4
        ui.ell(d, ox - 2.2, cy - 10.4, ox + 2.2, cy - 6, "#ffc4d4", INK, .8)
        ui.ell(d, ox - .9, cy - 9.6, ox + .1, cy - 8.8, WHITE)
    # face: dot eyes (the wink shuts the right one), smile, blush
    ui.ell(d, cx - 3.2, cy - 2.4, cx - 1.6, cy - .8, INK)
    if wink:
        d.arc(ui.box(cx + 1.2, cy - 2.6, cx + 3.6, cy - .6), 20, 160, fill=INK, width=int(.7 * k))
    else:
        ui.ell(d, cx + 1.6, cy - 2.4, cx + 3.2, cy - .8, INK)
    d.arc(ui.box(cx - 1.6, cy - 1.2, cx + 1.6, cy + 1.6), 20, 160, fill=INK, width=int(.6 * k))
    for side in (-1, 1):
        ui.ell(d, cx + side * 4.4 - 1.4, cy - .6, cx + side * 4.4 + 1.4, cy + .8, BLUSH)
    ui.heart(d, cx + 8.6, cy + 3.4, 1.7, PINK_DEEP, INK, .6, shine=False)           # in estrus
    return trim(ui.down(im, 24, 24))


def charms():
    ui.use_scale((8, 4))
    kinds = {
        "heart": lambda: ui.canon("deco_heart", 16),
        "sparkle": lambda: ui.canon("deco_sparkle", 16),
        "skull": lambda: fit(charm_skull(), 18),
        "cub": lambda: fit(charm_cub(), 17),
        "seal": lambda: ui.canon("prop_seal_o", 17),
        "uterus": lambda: charm_uterus(False),
        "uterus_wink": lambda: charm_uterus(True),
    }
    for name, fn in kinds.items():
        im = fn()
        save(im, f"charm_{name}.png")
        pad = 8
        padded = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad))
        padded.alpha_composite(im, (pad, pad))
        save(padded.filter(ImageFilter.GaussianBlur(1.6)), f"charm_{name}_mid.png")
        save(padded.filter(ImageFilter.GaussianBlur(3.6)), f"charm_{name}_far.png")


def fit(im, height):
    h = round(height * ui.O)
    return im.resize((max(1, round(im.width * h / im.height)), h), Image.LANCZOS)


def layout():
    data = {
        "_note": "Written by tools/gen_title_fx.py for scenes/ui/main_menu_backdrop.tscn; 640x360 world px.",
        "sea_top": SEA_TOP,
        "island": {"x": ISLAND_BOX[0], "y": ISLAND_BOX[1], "scale": 0.25},
        "foam": {"x": FOAM_BOX[0], "y": FOAM_BOX[1], "frame_w": FOAM_BOX[2] - FOAM_BOX[0], "frame_h": FOAM_BOX[3] - FOAM_BOX[1], "frames": 6, "scale": 0.5, "fps": 5},
        "waves": {"y": SEA_TOP, "frame_w": W, "frame_h": H - SEA_TOP, "frames": 4, "scale": 0.5, "fps": 3},
        "clouds": {"scale": 0.5, "y": 0},
        "trees": [{"x": x, "y": y, "kind": k} for x, y, k in TREES],
        "palms": [{"x": x, "y": y, "kind": k} for x, y, k in PALMS],
        "perches": PERCHES,
        "o": O_SEAL,
        "track_seconds_fallback": TRACK_SECONDS_FALLBACK,
    }
    path = ROOT / "project/data/title_layout.json"
    path.write_text(json.dumps(data, indent=2) + "\n")
    print(path.relative_to(ROOT))


if __name__ == "__main__":
    skies()
    clouds()
    waves()
    foam()
    island()
    sun()
    moon()
    bird()
    o_ring()
    charms()
    layout()
