"""Draw the tropical Florida Keys maps: ground backgrounds, standing props, garden items, fish.

Usage: python3 -I tools/gen_florida_art.py
Inputs: prompts/STYLE.md palette (via tools/florida_draw.py), project/data/florida.json (the
plants) and the canon flower cluster project/assets/canon/deco_flowers.png, scattered on the
lawns. The canon sheets hold no tropical scenery, so everything else is drawn in their sticker
look: warm-brown outline #8a5a5a, flat pastel fills with one highlight, faces on the big
friendly things (STYLE.md 4.1), Florida's saturated accents (coral, hibiscus, bougainvillea,
mango, key lime, turquoise). Sizes below are world px; every PNG is written at
tools/florida_draw.D (4) texture px per world px. Props and items are drawn at 8x and
backgrounds at 6x world size, then LANCZOS-resized. Every random choice comes from a
fixed-seed random.Random.

Outputs, all in project/assets/florida/:
  bg_florida_beach.png, bg_florida_garden.png, bg_florida_aquarium.png, bg_florida_stable.png
      960x540 world px (3840x2160 texture) ground only (sea, sand, lawn, paths, floors, the dock and the tank wall);
      everything a person can stand in front of or behind is a prop below.
  Props (the bottom edge is where the prop stands; scenes y-sort them with the people):
      prop_palm_a, prop_palm_b (76 wide), prop_tree_mango, prop_tree_key_lime, prop_bush_hibiscus,
      prop_bush_bougainvillea, prop_dune_grass, prop_umbrella, prop_rowboat, prop_aquarium,
      prop_garden_arch, prop_sign_stable, prop_sandcastle, prop_house, prop_fence_picket,
      prop_birdbath, prop_bench, prop_palm_potted, prop_barn, prop_fence_paddock, prop_hay,
      prop_trough
  Garden items: plot_empty, plot_growing, plot_ready_<plant> (one per plant in
      project/data/florida.json), seed_bag, craft_bench
  fish.png + fish.tres: frame 16x12 world px (64x48 texture); rows 0 coral, 1 mango, 2 lilac; columns 0-2 swim
      (tail wiggle), 3 fin wave. Animations swim_<colour> (frames 0,1,2,1 at 5 fps) and
      wave_<colour> (frames 3,0 at 2 fps). Faces right; anchor: frame centre.
"""
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves tools/ off the path
import florida_draw as fd  # noqa: E402
from florida_draw import INK, WHITE, Pen, mix  # noqa: E402

K = 8  # prop drawing scale (world px -> drawing px)
BG_S = 6  # background drawing scale
PLANTS = json.loads((fd.ROOT / "project/data/florida.json").read_text())["plants"]
CLEAR = fd.alpha(WHITE, 0)  # outline-only redraw


def prop(name, w, h, draw):
    im, p = fd.canvas(w, h, K)
    draw(p, w, h)
    fd.save(fd.finish(im, w, h), name)


# ================================================================== trees and plants

def palm_drawing(lean=1.0, fronds_seed=0):
    """A coconut palm: one smooth tapered trunk curving up (ring marks, a highlight down the
    lit side, a small face), a crown of saw-edged fronds and a cluster of coconuts."""
    def draw(p, w, h):
        base_x = w / 2 - lean * 6
        top_x, top_y = w / 2 + lean * 8, 26
        bark = fd.mix(fd.COCONUT, WHITE, 0.32)
        bark_dk = fd.mix(fd.COCONUT, INK, 0.12)

        def spine(t):
            return base_x + (top_x - base_x) * (t ** 1.6), h - 3 - (h - 3 - top_y) * t

        def radius(t):
            return 4.8 - t * 1.9 + (1 - t) ** 6 * 1.6  # flares a little at the foot

        n = 24
        left, right = [], []
        for i in range(n + 1):
            t = i / n
            x, y = spine(t)
            x2, y2 = spine(min(1, t + 0.01))
            dx, dy = x2 - x, y2 - y
            ln = math.hypot(dx, dy) or 1
            nx, ny = -dy / ln, dx / ln
            r = radius(t)
            left.append((x - nx * r, y - ny * r))
            right.append((x + nx * r, y + ny * r))
        p.ell(base_x, h - 2.6, 9, 2.4, fd.alpha(INK, 0x30), 0)  # shadow
        p.poly(left + list(reversed(right)), bark, 1.0)
        # lit side
        hi = [(x + (rx - x) * 0.18, y) for (x, y), (rx, _) in zip(left[2:-2], right[2:-2])]
        p.line(hi, fd.alpha(WHITE, 0x70), 1.1)
        # ring marks: shallow chevrons across the trunk
        for i in range(1, 12):
            t = i / 12
            x, y = spine(t)
            r = radius(t) - 0.5
            p.line([(x - r, y - 0.7), (x, y + 0.6), (x + r, y - 0.7)], bark_dk, 0.55)
        t = 0.38
        fx_, fy_ = spine(t)
        p.face(fx_, fy_ - 1, 0.5)
        # fronds: saw-edged leaves fanning out and drooping from the crown
        rnd = random.Random(fronds_seed)
        fronds = []
        for a in (-172, -140, -108, -76, -44, -12, 18, 200, 160):
            a += rnd.uniform(-5, 5)
            fronds.append((a, rnd.uniform(24, 30)))
        fronds.sort(key=lambda f: -math.sin(math.radians(f[0])))  # back (upward) fronds first
        for a, L in fronds:
            rad = math.radians(a)
            droop = 9 + 5 * abs(math.cos(rad))
            ex, ey = top_x + math.cos(rad) * L, top_y + math.sin(rad) * L * 0.6 + droop
            mx, my = top_x + math.cos(rad) * L * 0.55, top_y + math.sin(rad) * L * 0.5 - 4
            col = "#79cf86" if math.sin(rad) < -0.3 else "#62bd74"

            def bez(t):
                return ((1 - t) ** 2 * top_x + 2 * (1 - t) * t * mx + t * t * ex,
                        (1 - t) ** 2 * top_y + 2 * (1 - t) * t * my + t * t * ey)
            steps = 26
            up, down = [], []
            for k in range(steps + 1):
                t = k / steps
                bx, by = bez(t)
                bx2, by2 = bez(min(1, t + 0.02))
                dx, dy = bx2 - bx, by2 - by
                ln = math.hypot(dx, dy) or 1
                nx, ny = -dy / ln, dx / ln
                base_w = math.sin(min(1, t * 1.15) * math.pi) * 4.6 + 0.4
                tooth = 1.0 if k % 2 else 0.74  # leaflet tips
                wd = base_w * (tooth if 0 < k < steps else 1)
                up.append((bx + nx * wd, by + ny * wd))
                down.append((bx - nx * wd * 0.9, by - ny * wd * 0.9))
            p.poly(up + list(reversed(down)), col, 0.85)
            rib = [bez(k / 8) for k in range(9)]
            p.line(rib, fd.mix(col, INK, 0.28), 0.5)
            p.line([(x + 0.0, y - 0.9) for x, y in rib[1:6]], fd.alpha(WHITE, 0x60), 0.7)
        for dx, dy in ((-2.6, 3.0), (2.4, 3.4), (0, 5.2)):
            p.ell(top_x + dx, top_y + dy, 2.7, 2.7, "#a07850", 0.8)
            p.ell(top_x + dx - 0.8, top_y + dy - 0.9, 0.85, 0.7, "#c8a070", 0)
    return draw


def fruit_tree(canopy, fruit, fruit_hi, leaf_dk):
    """Canon-style bubbly tree (three or four circles, a face) bearing Florida fruit."""
    def draw(p, w, h):
        cx = w / 2
        p.rect(cx - 3.2, h - 22, cx + 3.2, h - 1.5, fd.TRUNK, 2, 0.9)
        p.line([(cx - 1, h - 18), (cx - 1, h - 6)], fd.mix(fd.TRUNK, INK, 0.25), 0.5)
        p.blob([(cx - 10, 22, 11), (cx + 10, 22, 11), (cx, 14, 12.5), (cx, 26, 12)], canopy, 1.0)
        p.ell(cx - 8, 12, 4, 2.4, fd.mix(canopy, WHITE, 0.45), 0)
        p.arc(cx + 6, 20, 5, 3, 200, 300, leaf_dk, 0.5)
        p.face(cx, 25, 0.62)
        for x, y in ((cx - 13, 18), (cx + 13, 26), (cx - 6, 33), (cx + 9, 12), (cx + 15, 16), (cx - 15, 29)):
            p.ell(x, y, 2.4, 2.6, fruit, 0.7)
            p.ell(x - 0.7, y - 0.9, 0.7, 0.6, fruit_hi, 0)
        p.sparkle(cx + 14, 6, 2.4, WHITE, None)
    return draw


def _hib(p, x, y, c):
    p.hibiscus(x, y, 3.2, c, 0.5)


def _boug(p, x, y, c):
    for dx, dy in ((-1.6, 0), (1.6, 0.4), (0, -1.5), (0.2, 1.6)):
        p.ell(x + dx, y + dy, 1.7, 1.5, c, 0.45)
    p.ell(x, y, 0.7, 0.7, WHITE, 0)


def bush(flower_fn, color):
    def draw(p, w, h):
        cx = w / 2
        p.blob([(cx - 8, h - 9, 7), (cx + 8, h - 9, 7), (cx, h - 13, 8.5), (cx, h - 7, 7)], fd.HEDGE, 1.0)
        p.ell(cx - 5, h - 17, 3, 1.6, fd.mix(fd.HEDGE, WHITE, 0.4), 0)
        for x, y in ((cx - 9, h - 11), (cx + 1, h - 16), (cx + 9, h - 9), (cx - 1, h - 7)):
            flower_fn(p, x, y, color)
    return draw


def dune_grass(p, w, h):
    rnd = random.Random(3)
    for i in range(7):
        x = 3 + i * (w - 6) / 6
        top = rnd.uniform(1, 5)
        lean = rnd.uniform(-3, 3)
        p.line([(x, h - 1), (x + lean, top)], "#9ccb7a", 1.4)
        p.line([(x, h - 1), (x + lean, top)], "#c2e59b", 0.6)
        if i % 2:
            p.ell(x + lean, top - 1, 1.1, 2.0, "#e8d79a", 0.5)


# ================================================================== beach props

def umbrella(p, w, h):
    cx = w / 2
    p.line([(cx, 14), (cx + 1, h - 2)], INK, 1.6)
    p.line([(cx, 14), (cx + 1, h - 2)], WHITE, 0.7)
    canopy = [(cx - 19, 18)]
    for i in range(9):
        a = math.pi + i / 8 * math.pi
        canopy.append((cx + math.cos(a) * 19, 16 + math.sin(a) * 12))
    canopy.append((cx + 19, 18))
    p.poly(canopy, WHITE, 1.0)
    for k in range(4):  # coral stripes
        a0 = math.pi + (2 * k) / 8 * math.pi
        a1 = math.pi + (2 * k + 1) / 8 * math.pi
        seg = [(cx, 5)]
        for j in range(5):
            a = a0 + (a1 - a0) * j / 4
            seg.append((cx + math.cos(a) * 18.4, 16 + math.sin(a) * 11.4))
        seg += [(cx + math.cos(a1) * 18.4, 18), (cx + math.cos(a0) * 18.4, 18)]
        p.poly(seg, fd.CORAL, 0)
    for i in range(8):  # scalloped rim
        x = cx - 17 + i * 34 / 7
        p.ell(x, 18, 2.6, 2.0, fd.CORAL if i % 2 == 0 else WHITE, 0.6)
    p.poly(canopy, CLEAR, 1.0)
    p.ell(cx, 4.6, 1.8, 1.8, fd.FLOWER_YELLOW, 0.6)
    p.ell(cx - 9, 10, 4, 1.6, fd.alpha(WHITE, 0xa0), 0)
    p.face(cx, 13.5, 0.55)


def rowboat(p, w, h):
    """The Father's boat pulled up on the sand (the way back to the village); bow to the right."""
    hull = [(4, 12), (w - 4, 9), (w - 10, 22), (12, 24)]
    p.poly([(x, y + 1.5) for x, y in hull], fd.alpha(INK, 0x40), 0)
    p.poly(hull, WHITE, 1.0)
    p.poly([(5, 13), (w - 5, 10), (w - 7, 15), (7, 18)], fd.CORAL, 0)
    p.poly(hull, CLEAR, 1.0)
    p.poly([(9, 11), (w - 9, 9), (w - 13, 13.5), (12, 15)], "#e4c597", 0.8)
    for x in (22, 36):
        p.line([(x, 10.5), (x + 1, 14.5)], fd.WOOD, 1.4)
    p.line([(18, 6), (44, 18)], INK, 1.5)  # oar
    p.line([(18, 6), (44, 18)], fd.WOOD, 0.8)
    p.ell(44.5, 18.5, 3, 1.6, fd.WOOD, 0.7)
    p.face(w - 18, 18.5, 0.55)
    p.ell(w - 30, 19, 1.4, 1.4, fd.TURQ, 0.4)


def aquarium_building(p, w, h):
    cx = w / 2
    p.poly([(cx - 4, 18), (cx + 6, 2), (cx + 10, 18)], fd.TURQ, 1.0)  # a fin on the dome
    p.ell(cx, 34, 52, 26, "#9fd6ef", 1.1)
    p.ell(cx - 22, 24, 14, 5, fd.alpha(WHITE, 0x90), 0)
    for i in range(5):
        x = cx - 40 + i * 20
        p.arc(cx, 34, abs(x - cx) + 4, 26, 190, 350, fd.mix("#9fd6ef", INK, 0.2), 0.5)
    p.rect(cx - 62, 36, cx + 62, h - 4, "#e9f7fb", 4, 1.1)
    p.rect(cx - 62, h - 16, cx + 62, h - 4, "#cfe9f4", 3, 0)
    p.rect(cx - 62, 36, cx + 62, h - 4, CLEAR, 4, 1.1)
    band = [(cx - 62 + i * 124 / 24, 46 + math.sin(i * 0.9) * 1.4) for i in range(25)]
    p.poly(band + [(cx + 62, 54), (cx - 62, 54)], fd.TURQ, 0)
    # porthole windows with fish: the building's eyes
    for x in (cx - 38, cx + 38):
        p.ell(x, 66, 11, 11, "#f6d98c", 1.0)
        p.ell(x, 66, 8, 8, "#7fc6ea", 0.8)
        p.ell(x - 2.5, 63, 2.4, 1.6, fd.alpha(WHITE, 0xb0), 0)
        p.ell(x + 1, 68, 3, 2, fd.MANGO, 0.5)
        p.poly([(x - 2, 68), (x - 5, 66), (x - 5, 70)], fd.MANGO, 0.5)
        p.ell(x, 81, 5, 2.2, fd.BLUSH, 0)
    p.arc(cx, 72, 7, 4, 20, 160, INK, 0.9)
    p.rect(cx - 13, 78, cx + 13, h - 4, "#7fc6ea", 12, 1.0)  # arched door
    p.line([(cx, 80), (cx, h - 4)], INK, 0.8)
    p.ell(cx - 4, 92, 1.1, 1.1, "#f6d98c", 0.4)
    p.ell(cx + 4, 92, 1.1, 1.1, "#f6d98c", 0.4)
    for x, y, r in ((cx + 50, 22, 2.6), (cx + 56, 12, 1.8), (cx - 52, 18, 2.0)):
        p.ell(x, y, r, r, fd.alpha(WHITE, 0xc0), 0.5, "#7fb8d8")
    p.rect(cx - 16, 26, cx + 16, 38, "#ffb3c8", 4, 0.9)  # sign: a fish, no text
    p.ell(cx + 1, 32, 5, 3, fd.MANGO, 0.6)
    p.poly([(cx - 4, 32), (cx - 8, 29), (cx - 8, 35)], fd.MANGO, 0.6)
    p.ell(cx + 3, 31.4, 0.6, 0.6, INK, 0)
    for x in (cx - 50, cx + 50):
        p.rect(x - 8, h - 14, x + 8, h - 5, fd.CORAL, 2, 0.8)
        p.hibiscus(x - 3, h - 15, 3, fd.HIBISCUS, 0.5)
        p.hibiscus(x + 4, h - 16, 2.6, fd.FLOWER_YELLOW, 0.5)


def garden_arch(p, w, h):
    for x in (6, w - 6):
        p.rect(x - 3, 12, x + 3, h - 1, WHITE, 1.5, 0.9)
    p.arc(w / 2, 16, w / 2 - 6, 14, 180, 360, INK, 7.2)
    p.arc(w / 2, 16, w / 2 - 6, 14, 180, 360, WHITE, 5.4)
    rnd = random.Random(8)
    for i in range(16):
        a = math.pi + i / 15 * math.pi
        p.ell(w / 2 + math.cos(a) * (w / 2 - 6) + rnd.uniform(-2, 2), 16 + math.sin(a) * 14 + rnd.uniform(-2, 2),
              2.4, 2.0, fd.HEDGE, 0.5)
    for i in range(9):
        a = math.pi + (i + 0.5) / 9 * math.pi
        _boug(p, w / 2 + math.cos(a) * (w / 2 - 6), 15 + math.sin(a) * 14, fd.BOUG if i % 2 else fd.HIBISCUS)
    for x in (6, w - 6):
        for y in (24, 34, 44):
            p.ell(x + (1.5 if y % 20 else -1.5), y, 2.2, 1.8, fd.HEDGE, 0.5)
        _boug(p, x, 30, fd.BOUG)
        _boug(p, x + 1, 42, fd.HIBISCUS)


def sign_stable(p, w, h):
    cx = w / 2
    p.ell(cx, h - 2, 6, 1.6, fd.alpha(INK, 0x30), 0)
    p.rect(cx - 2, 12, cx + 2, h - 1, fd.WOOD, 1, 0.9)
    p.poly([(2, 6), (w - 6, 5), (w - 1, 11), (w - 6, 17), (2, 16)], "#e9c79a", 1.0)
    # a horseshoe and a heart: the ponies are this way
    p.arc(9, 11, 4, 4, 160, 380, INK, 2.2)
    p.arc(9, 11, 4, 4, 160, 380, "#c8ccd8", 1.2)
    p.heart(17, 11, 3.0, fd.HEART, 0.4)


def sandcastle(p, w, h):
    sand, dk = "#f3d9a0", "#d9b77a"
    p.rect(3, 12, w - 3, h - 2, sand, 2, 0.9)
    for x in (4, w / 2 - 4, w - 12):
        p.rect(x, 5, x + 8, 14, sand, 1.5, 0.9)
        for k in range(3):
            p.rect(x + k * 3, 3.4, x + k * 3 + 2, 6, sand, 0.4, 0.6)
    p.rect(w / 2 - 3, h - 9, w / 2 + 3, h - 2, dk, 3, 0.7)
    p.line([(w / 2, 6), (w / 2, 2)], INK, 0.6)
    p.poly([(w / 2, 1.5), (w / 2 + 5, 3), (w / 2, 4.5)], fd.HIBISCUS, 0.4)
    p.ell(6, h - 4, 1.4, 1, "#ffb3c8", 0.4)
    p.face(w / 2, 15.5, 0.45)


# ================================================================== garden props

def house(p, w, h):
    """The house up from the beach: a Keys cottage with a porch, pastel turquoise siding, white
    trim, a coral tin roof, shutters and flower boxes. It smiles."""
    cx = w / 2
    wall_top, porch = 50, h - 22
    p.poly([(cx - 128, h - 6), (cx + 128, h - 6), (cx + 124, h - 2), (cx - 124, h - 2)], fd.alpha(INK, 0x30), 0)
    p.rect(cx - 118, wall_top, cx + 118, porch, "#9fe0dc", 2, 1.2)
    for y in range(wall_top + 7, porch, 7):  # siding
        p.line([(cx - 116, y), (cx + 116, y)], fd.mix("#9fe0dc", INK, 0.18), 0.5, False)
    p.poly([(cx - 132, wall_top + 4), (cx - 96, 6), (cx + 96, 6), (cx + 132, wall_top + 4)], fd.CORAL, 1.2)
    for i in range(1, 16):
        p.line([(cx - 96 + i * 192 / 16, 8), (cx - 132 + i * 264 / 16, wall_top + 2)], fd.mix(fd.CORAL, INK, 0.22), 0.6, False)
    p.line([(cx - 96, 6), (cx + 96, 6)], fd.mix(fd.CORAL, WHITE, 0.4), 1.2)
    p.rect(cx - 134, wall_top + 2, cx + 134, wall_top + 7, WHITE, 2, 1.0)
    # porch deck, steps, posts, railings
    p.rect(cx - 124, porch - 2, cx + 124, h - 8, "#f3e2c4", 1.5, 1.1)
    for x in range(int(cx - 120), int(cx + 121), 10):
        p.line([(x, porch), (x, h - 9)], fd.mix("#f3e2c4", INK, 0.15), 0.5, False)
    p.rect(cx - 16, h - 9, cx + 16, h - 1, "#ead2ae", 1, 1.0)
    p.line([(cx - 16, h - 5), (cx + 16, h - 5)], INK, 0.6)
    for x in (cx - 120, cx - 60, cx + 60, cx + 120, cx - 18, cx + 18):
        p.rect(x - 2, wall_top + 8, x + 2, porch, WHITE, 1, 0.8)
    for x0, x1 in ((cx - 120, cx - 18), (cx + 18, cx + 120)):
        p.line([(x0, porch - 14), (x1, porch - 14)], INK, 2.2)
        p.line([(x0, porch - 14), (x1, porch - 14)], WHITE, 1.2)
        for x in range(int(x0) + 4, int(x1), 6):
            p.line([(x, porch - 13), (x, porch - 2)], WHITE, 1.2)
            p.line([(x, porch - 13), (x, porch - 2)], fd.alpha(INK, 0x60), 0.3)
    # coral door with a round window, a heart over it
    p.rect(cx - 12, wall_top + 18, cx + 12, porch - 1, fd.CORAL, 3, 1.0)
    p.ell(cx, wall_top + 28, 5, 5, "#d8f2fb", 0.8)
    p.ell(cx + 7, wall_top + 44, 1.2, 1.2, "#f6d98c", 0.4)
    p.heart(cx, wall_top + 12, 3.2, fd.HEART, 0.5)
    # windows with shutters and flower boxes; the two by the door are its eyes
    for x in (cx - 88, cx - 46, cx + 46, cx + 88):
        p.rect(x - 11, wall_top + 14, x + 11, wall_top + 36, "#d8f2fb", 2, 1.0)
        p.line([(x, wall_top + 14), (x, wall_top + 36)], WHITE, 1.2)
        p.line([(x - 11, wall_top + 25), (x + 11, wall_top + 25)], WHITE, 1.2)
        p.ell(x - 5, wall_top + 18, 3, 1.5, fd.alpha(WHITE, 0xb0), 0)
        for s in (-1, 1):
            p.rect(x + s * 13 - 3, wall_top + 13, x + s * 13 + 3, wall_top + 37, "#ffb3c8", 1, 0.8)
        p.rect(x - 12, wall_top + 36, x + 12, wall_top + 41, fd.WOOD, 1, 0.8)
        for k in range(4):
            p.hibiscus(x - 8 + k * 5.3, wall_top + 35, 2.2, fd.HIBISCUS if k % 2 else fd.FLOWER_YELLOW, 0.4)
    for x in (cx - 46, cx + 46):
        p.ell(x, wall_top + 28, 2.2, 2.6, INK, 0)
        p.ell(x + 0.8, wall_top + 27, 0.8, 0.8, WHITE, 0)
    for x in (cx - 30, cx + 30):
        p.ell(x, wall_top + 44, 4.5, 2.2, fd.BLUSH, 0)
    for x in (cx - 26, cx + 26):  # porch lanterns
        p.line([(x, wall_top + 8), (x, wall_top + 13)], INK, 0.6)
        p.ell(x, wall_top + 15, 2.4, 2.8, "#fff1b8", 0.7)


def fence_picket(p, w, h):
    p.rect(0, 8, w, 11, WHITE, 1, 0.8)
    p.rect(0, 15, w, 18, WHITE, 1, 0.8)
    for i in range(8):
        x = 4 + i * (w - 8) / 7
        p.poly([(x - 2.6, h - 1), (x - 2.6, 4), (x, 1), (x + 2.6, 4), (x + 2.6, h - 1)], WHITE, 0.8)
    for x in (4 + 2 * (w - 8) / 7, 4 + 5 * (w - 8) / 7):
        p.hibiscus(x + 3, 9, 2.4, fd.HIBISCUS, 0.4)
        p.ell(x - 3, 13, 1.8, 1.2, fd.HEDGE, 0.4)


def birdbath(p, w, h):
    cx = w / 2
    p.poly([(cx - 3, 10), (cx + 3, 10), (cx + 4, h - 4), (cx - 4, h - 4)], "#f2ecf6", 0.9)
    p.ell(cx, h - 3, 7, 2.2, "#f2ecf6", 0.9)
    p.ell(cx, 8, 9.5, 3.6, "#f2ecf6", 0.9)
    p.ell(cx, 7.4, 7.5, 2.4, fd.WATER, 0.6)
    p.ell(cx - 3, 6.8, 2, 0.8, WHITE, 0)
    p.sparkle(cx + 6, 2, 1.8, WHITE, None)


# ================================================================== aquarium props

def bench(p, w, h):
    for x in (8, w - 8):
        p.rect(x - 2.5, 10, x + 2.5, h - 1, fd.WOOD, 1, 0.8)
    p.rect(2, 3, w - 2, 12, "#e2b886", 2, 1.0)
    for k in range(1, 4):
        p.line([(2 + k * (w - 4) / 4, 4), (2 + k * (w - 4) / 4, 11)], fd.mix("#e2b886", INK, 0.2), 0.5)
    p.rect(5, 1, w - 5, 7, "#ffb3c8", 3, 0.8)
    for k in range(5):
        p.heart(10 + k * (w - 20) / 4, 4, 1.4, WHITE, 0)


def palm_potted(p, w, h):
    cx = w / 2
    p.poly([(cx - 9, h - 13), (cx + 9, h - 13), (cx + 7, h - 1), (cx - 7, h - 1)], fd.CORAL, 0.9)
    p.rect(cx - 10, h - 15, cx + 10, h - 11, fd.mix(fd.CORAL, WHITE, 0.3), 1.5, 0.8)
    p.face(cx, h - 7, 0.45)
    p.line([(cx, h - 14), (cx + 1, 14)], INK, 2.6)
    p.line([(cx, h - 14), (cx + 1, 14)], fd.COCONUT, 1.6)
    for a in (-170, -135, -100, -70, -35, -5):
        rad = math.radians(a)
        ex, ey = cx + 1 + math.cos(rad) * 13, 14 + math.sin(rad) * 9 + 7
        mx, my = cx + 1 + math.cos(rad) * 7, 14 + math.sin(rad) * 6
        nx, ny = -math.sin(rad), math.cos(rad)
        p.poly([(cx + 1, 14), (mx + nx * 4.2, my + ny * 4.2), (ex, ey), (mx - nx * 1.4, my - ny * 1.4)], "#7fd08a", 0.8)
        p.line([(cx + 1, 14), (ex, ey)], "#5fae6c", 0.4)


# ================================================================== stable props

def barn(p, w, h):
    """The pony stable: a big friendly barn with a face, a hay loft and flower boxes."""
    cx = w / 2
    wall_top = 54
    p.poly([(cx - 124, h - 5), (cx + 124, h - 5), (cx + 120, h - 1), (cx - 120, h - 1)], fd.alpha(INK, 0x30), 0)
    p.rect(cx - 112, wall_top, cx + 112, h - 3, "#f4a6a0", 3, 1.2)
    for x in range(int(cx - 104), int(cx + 105), 8):
        p.line([(x, wall_top + 2), (x, h - 5)], fd.mix("#f4a6a0", INK, 0.14), 0.5, False)
    p.poly([(cx - 126, wall_top + 6), (cx - 70, 16), (cx, 2), (cx + 70, 16), (cx + 126, wall_top + 6)], "#e07a7a", 1.2)
    p.line([(cx - 70, 16), (cx, 2), (cx + 70, 16)], fd.mix("#e07a7a", WHITE, 0.4), 1.0)
    p.rect(cx - 128, wall_top + 2, cx + 128, wall_top + 8, WHITE, 2, 1.0)
    p.rect(cx - 16, 22, cx + 16, 46, "#c98f5a", 3, 1.0)  # hay loft
    p.rect(cx - 13, 34, cx + 13, 46, "#ffe27a", 2, 0.6)
    for x in range(int(cx - 12), int(cx + 13), 3):
        p.line([(x, 34), (x + 1, 31)], "#e0b24a", 0.6)
    p.heart(cx, 28, 3.2, fd.HEART, 0.5)
    p.rect(cx - 30, wall_top + 26, cx + 30, h - 3, "#c98f5a", 3, 1.1)  # double door
    for x0, x1 in ((cx - 30, cx), (cx, cx + 30)):
        p.line([(x0 + 3, wall_top + 29), (x1 - 3, h - 6)], WHITE, 1.4)
        p.line([(x1 - 3, wall_top + 29), (x0 + 3, h - 6)], WHITE, 1.4)
    p.line([(cx, wall_top + 26), (cx, h - 3)], INK, 0.9)
    for x in (cx - 70, cx + 70):  # window eyes with flower boxes
        p.rect(x - 18, wall_top + 14, x + 18, wall_top + 40, "#fff6dc", 4, 1.0)
        p.ell(x + (4 if x < cx else -4), wall_top + 27, 4, 5, INK, 0)
        p.ell(x + (5.4 if x < cx else -2.6), wall_top + 25, 1.4, 1.4, WHITE, 0)
        p.rect(x - 20, wall_top + 40, x + 20, wall_top + 46, fd.WOOD, 1.5, 0.8)
        for k in range(5):
            p.hibiscus(x - 15 + k * 7.5, wall_top + 40, 2.6, fd.HIBISCUS if k % 2 else fd.FLOWER_YELLOW, 0.4)
        p.ell(x, wall_top + 54, 7, 3.2, fd.BLUSH, 0)
    p.arc(cx, wall_top + 16, 9, 5, 20, 160, INK, 1.0)
    p.arc(cx, wall_top + 20, 4, 4, 160, 380, INK, 2.2)  # horseshoe over the door
    p.arc(cx, wall_top + 20, 4, 4, 160, 380, "#c8ccd8", 1.2)


def fence_paddock(p, w, h):
    for y in (6, 13):
        p.rect(0, y, w, y + 3.6, WHITE, 1.2, 0.8)
    for x in (4, w / 2, w - 4):
        p.rect(x - 2.6, 1, x + 2.6, h - 1, WHITE, 1.2, 0.8)


def hay(p, w, h):
    p.rect(1, 4, w - 1, h - 1, "#ffe27a", 4, 1.0)
    for y in (8, 13, 17):
        p.line([(4, y), (w - 4, y)], "#e0b24a", 0.6, False)
    for x in (9, w - 9):
        p.line([(x, 4), (x, h - 1)], "#c98f5a", 1.0, False)
    for x in range(3, w - 2, 3):
        p.line([(x, 5), (x + 1, 2.5)], "#e0b24a", 0.5)
    p.face(w / 2, 12, 0.5)


def trough(p, w, h):
    p.poly([(2, 6), (w - 2, 6), (w - 5, h - 2), (5, h - 2)], fd.WOOD, 1.0)
    p.ell(w / 2, 6.5, w / 2 - 2, 3.2, "#8fd3e8", 0.8)
    p.ell(w / 2 - 6, 6, 4, 1.2, WHITE, 0)
    p.line([(4, 11), (w - 4, 11)], fd.mix(fd.WOOD, INK, 0.25), 0.5)


# ================================================================== garden items

def plot_base(p, w, h, top):
    """A soft mound of tilled soil ringed with little white stones; three ridged rows."""
    cx, cy = w / 2, (top + h - 3) / 2
    rx, ry = w / 2 - 3, (h - 3 - top) / 2
    p.ell(cx, h - 3, rx + 1, 3, fd.alpha(INK, 0x30), 0)
    p.ell(cx, cy, rx, ry, fd.SOIL_DK, 0.9)
    p.ell(cx, cy - 0.6, rx - 1.6, ry - 1.6, fd.SOIL, 0)
    for k in (-1, 0, 1):
        y = cy + k * ry * 0.5
        half = math.sqrt(max(0.0, 1 - (k * 0.5) ** 2)) * (rx - 4)
        for i in range(6):
            x = cx - half + (2 * half) * (i + 0.5) / 6
            p.ell(x, y, half / 6.4, 1.3, fd.mix(fd.SOIL, WHITE, 0.25), 0)
            p.ell(x, y + 1.2, half / 7, 0.6, fd.SOIL_DK, 0)
    for i in range(14):
        a = i / 14 * 2 * math.pi
        p.ell(cx + math.cos(a) * (rx + 0.5), cy + math.sin(a) * (ry + 0.5), 1.6, 1.2, "#f6efe6", 0.45)


def plot_empty(p, w, h):
    plot_base(p, w, h, h - 20)
    p.ell(w / 2 + 7, h - 15, 1.6, 1.2, fd.alpha(WHITE, 0xc0), 0.3, "#7fb8d8")  # a drop of water


def plot_growing(p, w, h):
    plot_base(p, w, h, h - 20)
    for x in (10, 18, 26):
        y = h - 10
        p.line([(x, y), (x, y - 6)], "#6cbf5a", 0.9)
        p.ell(x - 2.6, y - 7, 2.8, 1.7, fd.SPROUT, 0.5)
        p.ell(x + 2.6, y - 8, 2.8, 1.7, fd.SPROUT_HI, 0.5)
    p.ell(30, h - 18, 1.4, 1.4, fd.alpha(WHITE, 0xc0), 0.3, "#7fb8d8")


def plot_ready(plant):
    """The bed with the grown plant, in its own colour from florida.json."""
    color = PLANTS[plant]["color"]

    def draw(p, w, h):
        plot_base(p, w, h, h - 20)
        cx, base = w / 2, h - 12
        hi = mix(color, WHITE, 0.45)
        if plant in ("hibiscus", "bougainvillea", "plumeria"):
            p.blob([(cx - 7, base - 7, 6), (cx + 7, base - 7, 6), (cx, base - 12, 7)], fd.HEDGE, 0.9)
            for x, y in ((cx - 8, base - 9), (cx + 7, base - 10), (cx, base - 16), (cx - 1, base - 6)):
                if plant == "hibiscus":
                    p.hibiscus(x, y, 3.4, color, 0.5)
                elif plant == "bougainvillea":
                    _boug(p, x, y, color)
                else:
                    p.plumeria(x, y, 3.2, 0.45)
        elif plant == "coconut":
            p.line([(cx, base), (cx + 1, base - 15)], INK, 2.4)
            p.line([(cx, base), (cx + 1, base - 15)], fd.COCONUT, 1.4)
            for a in (-160, -120, -60, -20):
                rad = math.radians(a)
                p.poly([(cx + 1, base - 15), (cx + 1 + math.cos(rad) * 9, base - 15 + math.sin(rad) * 6 + 5),
                        (cx + 1 + math.cos(rad) * 5, base - 17 + math.sin(rad) * 3)], "#7fd08a", 0.7)
            for dx in (-2, 2):
                p.ell(cx + 1 + dx, base - 12.5, 2.3, 2.3, color, 0.6)
        else:  # fruiting shrubs: sea grape, key lime, guava, mango
            p.line([(cx, base), (cx, base - 6)], fd.TRUNK, 1.4)
            p.blob([(cx - 7, base - 9, 6), (cx + 7, base - 9, 6), (cx, base - 14, 7)], fd.LEAF_MINT, 0.9)
            for x, y in ((cx - 8, base - 9), (cx + 7, base - 7), (cx + 2, base - 15), (cx - 3, base - 12), (cx + 9, base - 13)):
                if plant == "sea_grape":
                    for dx, dy in ((0, 0), (1.4, 1.2), (-1.4, 1.2), (0, 2.4)):
                        p.ell(x + dx, y + dy, 1.2, 1.2, color, 0.4)
                else:
                    p.ell(x, y, 2.2, 2.4, color, 0.6)
                    p.ell(x - 0.6, y - 0.8, 0.6, 0.6, hi, 0)
        p.sparkle(w - 5, 4, 2.4)
    return draw


def seed_bag(p, w, h):
    cx = w / 2
    p.ell(cx, h - 2, 9, 1.8, fd.alpha(INK, 0x30), 0)
    p.poly([(cx - 8, 8), (cx + 8, 8), (cx + 10, h - 6), (cx + 6, h - 2), (cx - 6, h - 2), (cx - 10, h - 6)], "#e8cfa0", 1.0)
    p.poly([(cx - 8, 8), (cx - 6, 4), (cx - 2, 7), (cx + 2, 3.5), (cx + 6, 7), (cx + 8, 8)], "#e8cfa0", 1.0)
    p.line([(cx - 8, 9.5), (cx + 8, 9.5)], fd.CORAL, 1.2)
    for x, y in ((cx - 3, 5.5), (cx + 1, 6), (cx + 4, 5.2)):
        p.ell(x, y, 1.1, 0.8, "#a07850", 0.3)
    p.rect(cx - 6, 12, cx + 6, h - 6, WHITE, 2, 0.7)
    p.hibiscus(cx, 16.5, 3.2, fd.HIBISCUS, 0.4)
    p.face(cx, h - 9, 0.4)


def craft_bench(p, w, h):
    p.ell(w / 2, h - 2, w / 2 - 2, 2.4, fd.alpha(INK, 0x30), 0)
    for x in (6, w - 6):
        p.rect(x - 2.5, 14, x + 2.5, h - 2, fd.WOOD, 1, 0.9)
    p.line([(6, h - 9), (w - 6, h - 9)], fd.WOOD, 1.6)
    p.rect(1, 9, w - 1, 16, "#e2b886", 2, 1.0)
    p.line([(3, 12.5), (w - 3, 12.5)], fd.mix("#e2b886", INK, 0.2), 0.5)
    # things being made: a flower crown, a shell garland, a key lime, a jar of sea grape jelly
    p.arc(12, 8, 6, 2.8, 0, 360, fd.HEDGE, 1.4)
    for k in range(5):
        a = k / 5 * 2 * math.pi
        p.hibiscus(12 + math.cos(a) * 6, 8 + math.sin(a) * 2.8, 1.8, fd.HIBISCUS if k % 2 else fd.FLOWER_YELLOW, 0.3)
    for k in range(4):
        p.ell(24 + k * 3.2, 8.4 + (k % 2) * 0.8, 1.5, 1.3, "#ffd3c2", 0.4)
    p.ell(37, 7, 2.4, 2.4, fd.KEY_LIME, 0.6)
    p.rect(41, 1.5, 47, 9, fd.SEA_GRAPE, 1.5, 0.7)
    p.rect(41, 0.5, 47, 2.6, "#f4e3c6", 1, 0.5)
    p.ell(42.6, 4, 0.8, 1.6, fd.alpha(WHITE, 0xb0), 0)
    p.face(w / 2, 19.5, 0.45)


# ================================================================== fish sheet

def fish_sheet():
    fw, fh = 16, 12
    cols = [("coral", fd.CORAL), ("mango", fd.MANGO), ("lilac", "#c9a8f0")]
    D = fd.D
    out = Image.new("RGBA", (fw * 4 * D, fh * 3 * D))
    for r, (_, col) in enumerate(cols):
        for c in range(4):
            im, p = fd.canvas(fw, fh, 8)
            wig = (-1, 0, 1, 0)[c]
            p.poly([(4, 6), (0.6, 2.4 + wig), (1.8, 6), (0.6, 9.6 + wig)], mix(col, WHITE, 0.25), 0.6)
            p.ell(8.5, 6, 5.4, 4.0, col, 0.7)
            p.ell(7.4, 4.4, 2.2, 1.0, mix(col, WHITE, 0.5), 0)
            p.poly([(7, 2.4), (9.8, 0.8), (10.4, 2.6)], mix(col, WHITE, 0.25), 0.5)
            if c == 3:  # waving a fin back at you
                p.poly([(8, 7), (5.6, 3.2), (9.6, 6)], mix(col, WHITE, 0.4), 0.5)
            else:
                p.poly([(8, 7), (6, 9.6), (9.6, 8)], mix(col, WHITE, 0.4), 0.5)
            p.ell(11.4, 5.4, 0.8, 0.9, INK, 0)
            p.ell(11.7, 5.0, 0.3, 0.3, WHITE, 0)
            p.arc(12.2, 6.6, 0.9, 0.6, 20, 160, INK, 0.35)
            p.ell(10.6, 7.0, 0.9, 0.5, fd.BLUSH, 0)
            out.alpha_composite(fd.finish(im, fw, fh), (c * fw * D, r * fh * D))
    fd.save(out, "fish")
    anims = []
    for r, (cname, _) in enumerate(cols):
        anims.append((f"swim_{cname}", r, [0, 1, 2, 1], 5, True))
        anims.append((f"wave_{cname}", r, [3, 0], 2, True))
    fd.write_frames("fish", fw, fh, anims)


# ================================================================== backgrounds

class Ground:
    """A 960x540 ground painting drawn at BG_S times scale."""

    def __init__(self, color):
        self.im = Image.new("RGBA", (960 * BG_S, 540 * BG_S), color)
        self.p = Pen(self.im, BG_S)

    def save(self, name):
        fd.save(self.im.resize((960 * fd.D, 540 * fd.D), Image.LANCZOS), name, rgb_only=True)


def speckle(p, rnd, box, n, colors, r=(0.6, 1.4)):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        rr = rnd.uniform(*r)
        p.ell(x, y, rr, rr * 0.75, rnd.choice(colors), 0)


def clover_patch(p, x, y, col=fd.GRASS_DK):
    for dx, dy in ((-1.6, 0), (1.6, 0), (0, -1.6)):
        p.ell(x + dx, y + dy, 1.6, 1.6, col, 0.4, "#79b45f")


def grass_tuft(p, x, y, col="#9fd585"):
    for dx, h in ((-2, 4), (0, 6), (2, 4.5)):
        p.line([(x + dx * 0.4, y), (x + dx, y - h)], col, 1.0)


def stone(p, x, y, r=5):
    p.ell(x, y, r, r * 0.62, "#f6efe6", 0.8)
    p.ell(x - r * 0.3, y - r * 0.2, r * 0.35, r * 0.18, WHITE, 0)


FLOWERS_W = 36


def canon_flowers(im, x, y):
    fl = fd.canon_sprite("deco_flowers")
    k = FLOWERS_W * BG_S / fl.width  # the cluster is FLOWERS_W world px wide at any cut size
    fl = fl.resize((round(fl.width * k), round(fl.height * k)), Image.LANCZOS)
    im.alpha_composite(fl, (round(x * BG_S - fl.width / 2), round(y * BG_S - fl.height)))


def wavy(y0, amp, period, phase, x0=-10, x1=970, step=6):
    return [(x, y0 + math.sin(x / period * 2 * math.pi + phase) * amp + math.sin(x / (period * 2.7) + phase) * amp * 0.6)
            for x in range(x0, x1 + 1, step)]


def beach_bg():
    """Sea across the top (deep blue to turquoise shallows), foam, wet sand, warm dry sand with
    starfish and shells, two towels, the dock out into the water, footprints, dune grass."""
    rnd = random.Random(101)
    g = Ground(fd.SAND)
    # the shoreline, pulled up on the right where the aquarium stands on its sandy point
    shore = [(x, y - 60 * min(1, max(0, (x - 760) / 80))) for x, y in wavy(268, 6, 220, 0.6)]
    bands = [(0, "#7ec3e6"), (70, "#88cdea"), (140, "#8fd6e8"), (200, "#86dccf"), (240, "#9be6d6")]
    sea = Image.new("RGBA", g.im.size)
    sp = Pen(sea, BG_S)
    for i, (y, col) in enumerate(bands):
        nxt = bands[i + 1][0] if i + 1 < len(bands) else 600
        sp.poly([(-10, y), (970, y), (970, nxt + 4), (-10, nxt + 4)], col, 0)
    sea = sea.filter(ImageFilter.GaussianBlur(18 * BG_S))  # soft gradient between the bands
    mask = Image.new("RGBA", g.im.size)
    Pen(mask, BG_S).poly([(-10, -10)] + shore + [(970, -10)], WHITE, 0)
    g.im = Image.composite(sea, g.im, mask.getchannel("A"))
    p = g.p = Pen(g.im, BG_S)
    for _ in range(70):  # wave arcs and sun glints
        x, y = rnd.uniform(0, 960), rnd.uniform(10, 230)
        if not (x > 790 and y > 170):
            p.arc(x, y, rnd.uniform(5, 9), 2.2, 200, 340, fd.alpha(WHITE, 0xb0), 1.0)
    for _ in range(26):
        x, y = rnd.uniform(0, 960), rnd.uniform(10, 220)
        if not (x > 790 and y > 160):
            p.sparkle(x, y, rnd.uniform(1.6, 2.8), WHITE, None)
    wet = [(x, y + 16) for x, y in shore]
    p.poly(shore + list(reversed(wet)), "#f3d9a6", 0)
    p.line(shore, "#bfeee4", 7)
    p.line([(x, y - 1) for x, y in shore], WHITE, 3.4)
    for x, y in shore[::5]:
        p.ell(x, y + 1, rnd.uniform(3, 5), 1.6, WHITE, 0)
    p.line([(x, y - 9) for x, y in wavy(262, 5, 180, 2.0, -10, 760)], fd.alpha(WHITE, 0x90), 1.4)
    # the dock: planks on posts out into the water, where the Father ties up
    dx0, dx1, dtop = 588, 624, 96
    for y in (110, 160, 210, 250):
        for x in (dx0 + 2, dx1 - 2):
            p.ell(x, y + 8, 3.4, 2.2, fd.alpha("#5f97b8", 0x80), 0)
            p.rect(x - 2.6, y - 2, x + 2.6, y + 8, "#a7744c", 1, 0.8)
    p.rect(dx0, dtop, dx1, 284, "#d6a774", 2, 1.2)
    for y in range(dtop + 6, 284, 7):
        p.line([(dx0 + 1, y), (dx1 - 1, y)], fd.mix("#d6a774", INK, 0.3), 0.7, False)
    p.rect(dx0 + 2, dtop + 2, dx0 + 8, 282, fd.alpha(WHITE, 0x40), 1, 0)
    p.rect(dx1 - 4, dtop + 2, dx1 - 1, 282, fd.alpha("#a7744c", 0x90), 1, 0)
    for y in range(dtop + 4, 284, 36):  # post tops along both edges
        for x in (dx0 + 1, dx1 - 1):
            p.ell(x, y, 3.2, 3.2, "#c08a5c", 0.9)
            p.ell(x - 0.8, y - 0.8, 1.1, 1.1, "#e2b886", 0)
    p.arc(dx0 + 12, dtop + 10, 7, 4, 0, 180, "#e9d49b", 1.4)  # a coil of rope
    p.ell(dx0 + 22, dtop + 30, 5, 3.6, "#9fd6ef", 0.9)  # a bait bucket
    p.ell(dx0 + 22, dtop + 29, 3.6, 1.6, "#7fc6ea", 0)
    speckle(p, rnd, (0, 280, 960, 540), 900, ["#ffe0a6", "#fff4d6", fd.SAND_PEB, "#f8d9a0"], (0.6, 1.5))
    # beach towels laid flat under the umbrella
    for x, y, c1, rot in ((352, 446, fd.TURQ, 0), (402, 452, "#ffb3c8", 1)):
        p.poly([(x - 14, y - 22 + rot * 3), (x + 14, y - 24 + rot * 3), (x + 16, y + 18), (x - 12, y + 20)], c1, 1.0)
        for k in range(4):
            yy = y - 16 + k * 10 + rot * 2
            p.poly([(x - 13, yy), (x + 15, yy - 1), (x + 15, yy + 4), (x - 13, yy + 5)], WHITE, 0)
    for x, y in ((150, 470), (690, 500), (880, 420), (250, 380), (520, 330)):  # starfish
        pts = [(x + math.cos(-math.pi / 2 + k * math.pi / 5) * (5 if k % 2 == 0 else 2.2),
                y + math.sin(-math.pi / 2 + k * math.pi / 5) * (5 if k % 2 == 0 else 2.2)) for k in range(10)]
        p.poly(pts, rnd.choice([fd.CORAL, "#ff9fc0", fd.MANGO]), 0.8)
        p.ell(x, y, 0.8, 0.8, WHITE, 0)
    for x, y in ((90, 300), (330, 315), (760, 310), (470, 520), (610, 470), (210, 520), (930, 520)):
        p.ell(x, y, 2.4, 1.8, rnd.choice(["#fff1e6", "#ffd3c2", "#f7c6d8"]), 0.6)
    for i in range(9):  # footprints from the boat up the beach
        p.ell(500 - i * 9 + (3 if i % 2 else -3), 360 + i * 14, 1.6, 2.4, fd.alpha("#e2bf86", 0xc0), 0)
    # stepping stones toward the garden (left), the stable (left of centre), the aquarium (right)
    for x, y in ((40, 352), (70, 346), (100, 340), (226, 334), (254, 330), (280, 327), (780, 316), (806, 320), (832, 318)):
        stone(p, x, y, 5)
    for x in range(0, 960, 26):
        if not 430 < x < 560:
            grass_tuft(p, x + rnd.uniform(-6, 6), 540 - rnd.uniform(0, 8))
    g.save("bg_florida_beach")


def garden_bg():
    """The yard: lawn up to the house porch, a path from the beach gate, the beds' patch of
    soil, flower borders and the canon flower clusters."""
    rnd = random.Random(202)
    g = Ground(fd.GRASS)
    p = g.p
    p.rect(-10, -10, 970, 54, "#a6dc8a", 0, 0)
    for x in range(-20, 980, 46):
        p.ell(x, 36, 34, 26, fd.HEDGE, 1.0)
    for x in range(10, 980, 46):
        p.ell(x, 26, 6, 3, fd.mix(fd.HEDGE, WHITE, 0.35), 0)
    speckle(p, rnd, (0, 60, 960, 540), 700, [fd.GRASS_DK, fd.GRASS_HI, "#b8e59a"], (0.8, 1.8))
    for _ in range(80):
        clover_patch(p, rnd.uniform(10, 950), rnd.uniform(70, 530))
    for _ in range(120):
        grass_tuft(p, rnd.uniform(0, 960), rnd.uniform(70, 540))
    path = [(150, 545), (200, 470), (300, 420), (420, 330), (470, 250), (480, 196)]
    p.line(path, fd.PATH_PEB, 34)
    p.line(path, fd.PATH, 28)
    for i in range(len(path) - 1):
        (x0, y0), (x1, y1) = path[i], path[i + 1]
        for t in (0.25, 0.75):
            stone(p, x0 + (x1 - x0) * t + rnd.uniform(-4, 4), y0 + (y1 - y0) * t, 6)
    p.line([(470, 300), (640, 300), (700, 290)], fd.PATH_PEB, 22)
    p.line([(470, 300), (640, 300), (700, 290)], fd.PATH, 17)
    for x, y in ((372, 230), (588, 230), (372, 368), (588, 368), (480, 386)):  # stepping stones by the beds
        stone(p, x, y, 5)
    for x in range(30, 940, 22):
        if not 430 < x < 530:
            p.hibiscus(x + rnd.uniform(-3, 3), 196 + rnd.uniform(-3, 3), 3.6, rnd.choice([fd.HIBISCUS, fd.FLOWER_YELLOW, fd.BOUG]), 0.6)
    for x, y in ((90, 140), (250, 330), (720, 420), (860, 300), (640, 500), (60, 420), (330, 500), (900, 470)):
        canon_flowers(g.im, x, y)
    g.save("bg_florida_garden")


POOL = (240, 140, 720, 340)  # the show pool, also used by the aquarium scene's navmesh


def aquarium_bg():
    """The aquarium show room seen from above: a pale boardwalk floor, the back wall with
    portholes onto the sea, and the big round-cornered show pool in the middle where the
    mermaids swim (turquoise water, light ripples, coral and sea grass, a rock with a pearl)."""
    rnd = random.Random(303)
    g = Ground("#f4e3c6")
    p = g.p
    for y in range(0, 545, 18):  # floor boards
        p.rect(-4, y, 964, y + 18, "#f1dcb8" if (y // 18) % 2 else "#f6e5c6", 0, 0)
        p.line([(-4, y), (964, y)], fd.mix("#f1dcb8", INK, 0.2), 0.8, False)
        for x in range(0 if (y // 18) % 2 else 60, 980, 120):
            p.line([(x, y), (x, y + 18)], fd.mix("#f1dcb8", INK, 0.2), 0.7, False)
    # back wall: aqua with a wave stripe and portholes looking out to sea
    p.rect(-10, -10, 970, 58, "#c9eef0", 0, 1.2)
    band = [(x, 40 + math.sin(x / 30) * 2.4) for x in range(-10, 975, 6)]
    p.poly(band + [(970, 58), (-10, 58)], fd.TURQ, 0)
    p.line([(-10, 58), (970, 58)], INK, 1.2)
    for x in range(80, 960, 160):
        p.ell(x, 22, 13, 13, "#f6d98c", 1.1)
        p.ell(x, 22, 9.5, 9.5, "#8fd8f0", 0.9)
        p.line([(x - 9, 25), (x + 9, 25)], "#c6eefb", 1.4)
        p.ell(x - 3, 18, 2.6, 1.6, fd.alpha(WHITE, 0xb0), 0)
    for x in range(160, 960, 160):  # little fish decals between them
        p.ell(x, 24, 7, 4, fd.CORAL if (x // 160) % 2 else fd.MANGO, 0.9)
        p.poly([(x - 6, 24), (x - 11, 20), (x - 11, 28)], fd.CORAL if (x // 160) % 2 else fd.MANGO, 0.9)
        p.ell(x + 3, 23, 0.9, 0.9, INK, 0)
    # the show pool
    x0, y0, x1, y1 = POOL
    p.rect(x0 - 16, y0 - 16, x1 + 16, y1 + 16, "#ffffff", 70, 1.4)
    p.rect(x0 - 8, y0 - 8, x1 + 8, y1 + 8, fd.alpha("#c6eefb", 0xff), 62, 0)
    water = Image.new("RGBA", g.im.size)
    wp = Pen(water, BG_S)
    for i in range(12):
        t = i / 11
        wp.rect(x0 + i * 6, y0 + i * 5, x1 - i * 6, y1 - i * 5, mix("#8fe0e0", "#58b8dc", t), max(10, 56 - i * 4), 0)
    water = water.filter(ImageFilter.GaussianBlur(6 * BG_S))
    clip = Image.new("RGBA", g.im.size)
    Pen(clip, BG_S).rect(x0, y0, x1, y1, WHITE, 56, 0)
    g.im.alpha_composite(Image.composite(water, Image.new("RGBA", g.im.size), clip.getchannel("A")))
    p = g.p = Pen(g.im, BG_S)
    p.rect(x0, y0, x1, y1, CLEAR, 56, 1.2)
    for _ in range(40):  # light ripples
        x, y = rnd.uniform(x0 + 30, x1 - 30), rnd.uniform(y0 + 20, y1 - 20)
        p.arc(x, y, rnd.uniform(6, 12), rnd.uniform(2, 3.5), 200, 340, fd.alpha(WHITE, 0x90), 1.0)
    # coral and sea grass along the pool's floor edge, a rock with a pearl in the middle
    for x, y, col in ((290, 175, fd.CORAL), (680, 180, "#ff9fc0"), (300, 310, "#c9a8f0"), (660, 305, fd.MANGO),
                      (420, 320, "#ff9fc0"), (560, 160, "#c9a8f0")):
        for a in (-50, -90, -130):
            rad = math.radians(a)
            ex, ey = x + math.cos(rad) * 10, y + math.sin(rad) * 12
            p.line([(x, y), (ex, ey)], INK, 4.4)
            p.line([(x, y), (ex, ey)], col, 2.6)
            p.ell(ex, ey, 2.4, 2.4, col, 0.8)
    for x, y in ((360, 160), (610, 320), (700, 240), (262, 240)):
        for k in range(3):
            pts = [(x + k * 5 + math.sin(j) * 2, y - j * 5) for j in range(5)]
            p.line(pts, "#6cbf8a", 3)
            p.line(pts, "#8fdca8", 1.4)
    p.blob([(472, 244, 22), (494, 236, 18), (486, 254, 16)], "#d7cfe6", 1.2)
    p.ell(470, 234, 7, 3, fd.alpha(WHITE, 0x90), 0)
    p.ell(492, 244, 9, 6, "#ffb3c8", 1.0)  # an open clam with a pearl
    p.ell(492, 243, 4, 4, WHITE, 0.8)
    p.sparkle(500, 232, 4, fd.SPARK, fd.GOLD)
    for _ in range(40):
        r = rnd.uniform(1.4, 3.2)
        p.ell(rnd.uniform(x0 + 30, x1 - 30), rnd.uniform(y0 + 20, y1 - 20), r, r, fd.alpha(WHITE, 0x80), 0.6, "#c6eefb")
    # a long rug from the door up to the pool
    p.rect(440, 372, 520, 545, "#ffb3c8", 0, 1.0)
    for y in range(388, 545, 26):
        p.heart(480, y, 4, "#ffd0e0", 0)
    p.line([(446, 372), (446, 545)], "#ffe3a8", 2)
    p.line([(514, 372), (514, 545)], "#ffe3a8", 2)
    g.save("bg_florida_aquarium")


def stable_bg():
    """Out back of the house: lawn, a soft sandy paddock for the stalls, the path from the
    barn door down to the gate and the beach."""
    rnd = random.Random(404)
    g = Ground(fd.GRASS)
    p = g.p
    p.rect(-10, -10, 970, 64, "#a6dc8a", 0, 0)
    for x in range(-20, 980, 52):
        p.ell(x, 40, 38, 28, fd.HEDGE, 1.0)
    speckle(p, rnd, (0, 60, 960, 540), 600, [fd.GRASS_DK, fd.GRASS_HI], (0.8, 1.8))
    for _ in range(70):
        clover_patch(p, rnd.uniform(10, 950), rnd.uniform(70, 530))
    for _ in range(90):
        grass_tuft(p, rnd.uniform(0, 960), rnd.uniform(70, 540))
    paddock = [(70, 220), (890, 220), (920, 300), (900, 480), (820, 500), (140, 500), (60, 470), (40, 300)]
    p.poly(paddock, "#efd9a6", 0)
    p.line(paddock + [paddock[0]], "#e2c48a", 3)
    speckle(p, rnd, (90, 230, 870, 490), 300, ["#e8cd94", "#f7e6bd"], (0.8, 1.8))
    for _ in range(40):
        p.arc(rnd.uniform(100, 860), rnd.uniform(240, 480), 2.4, 2.4, 200, 340, "#d9bb80", 1.0)
    for _ in range(60):
        x, y, a = rnd.uniform(100, 860), rnd.uniform(240, 480), rnd.uniform(0, math.pi)
        p.line([(x, y), (x + math.cos(a) * 4, y + math.sin(a) * 2)], "#f2d06a", 0.8)
    path = [(480, 200), (480, 300), (476, 420), (480, 545)]
    p.line(path, fd.PATH_PEB, 30)
    p.line(path, fd.PATH, 24)
    for y in (240, 300, 360, 420, 480, 525):
        stone(p, 480 + rnd.uniform(-5, 5), y, 5)
    for x, y in ((120, 120), (840, 130), (60, 520), (900, 520), (300, 150), (660, 150)):
        canon_flowers(g.im, x, y)
    g.save("bg_florida_stable")


# ================================================================== main

def main():
    prop("prop_palm_a", 76, 96, palm_drawing(1.0, 1))
    prop("prop_palm_b", 76, 88, palm_drawing(-1.0, 2))
    prop("prop_tree_mango", 48, 58, fruit_tree(fd.LEAF_MINT, fd.MANGO, "#ffd9a0", "#7fbf7a"))
    prop("prop_tree_key_lime", 48, 58, fruit_tree("#9ddc8e", fd.KEY_LIME, "#f4ffd0", "#6fb06a"))
    prop("prop_bush_hibiscus", 34, 26, bush(_hib, fd.HIBISCUS))
    prop("prop_bush_bougainvillea", 34, 26, bush(_boug, fd.BOUG))
    prop("prop_dune_grass", 24, 16, dune_grass)
    prop("prop_umbrella", 42, 52, umbrella)
    prop("prop_rowboat", 64, 28, rowboat)
    prop("prop_aquarium", 140, 120, aquarium_building)
    prop("prop_garden_arch", 44, 56, garden_arch)
    prop("prop_sign_stable", 26, 34, sign_stable)
    prop("prop_sandcastle", 32, 24, sandcastle)
    prop("prop_house", 276, 140, house)
    prop("prop_fence_picket", 64, 22, fence_picket)
    prop("prop_birdbath", 22, 28, birdbath)
    prop("prop_bench", 80, 22, bench)
    prop("prop_palm_potted", 30, 46, palm_potted)
    prop("prop_barn", 260, 160, barn)
    prop("prop_fence_paddock", 80, 22, fence_paddock)
    prop("prop_hay", 32, 22, hay)
    prop("prop_trough", 40, 18, trough)
    prop("plot_empty", 36, 28, plot_empty)
    prop("plot_growing", 36, 30, plot_growing)
    for plant in PLANTS:
        prop(f"plot_ready_{plant}", 36, 40, plot_ready(plant))
    prop("seed_bag", 22, 28, seed_bag)
    prop("craft_bench", 52, 30, craft_bench)
    fish_sheet()
    beach_bg()
    garden_bg()
    aquarium_bg()
    stable_bg()
    print("Florida art written to", fd.OUT)


if __name__ == "__main__":
    main()
