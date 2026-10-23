"""Draw the Florida critters as rigged sprite sheets: crab, gull and dolphin.

Usage: python3 -I tools/gen_florida_critters.py
The canon sheets have no animals of the Keys, so these are drawn in the canon sticker look of
prompts/STYLE.md 4.3: warm-brown outline #8a5a5a, flat fills with one highlight, dot eyes with a
catch-light, pink blush, a small smile; Florida colours from 4.4 (coral, sea blue, foam).
Drawn at 8x and LANCZOS-resized. Deterministic: no randomness.
Outputs (project/assets/florida/), each a PNG sheet and a SpriteFrames .tres over it:
  crab.png     frame 24x18  row 0 idle (claws snip: 4 frames, 4 fps)
                            row 1 walk (sideways scuttle: 4 frames, 8 fps)
  gull.png     frame 24x24  row 0 idle (look about, peck: 4 frames, 3 fps)
                            row 1 walk (hop: 4 frames, 8 fps)
  dolphin.png  frame 48x32  row 0 idle (bob at the surface, tail sway: 4 frames, 4 fps)
                            row 1 walk (swim: arcs through the water with a splash, 4 frames, 6 fps)
All face right; the critter script flips them for left. Anchor: frame centre.
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves tools/ off the path
import florida_draw as fd  # noqa: E402
from florida_draw import INK, WHITE  # noqa: E402

K = 8


def sheet(name, fw, fh, rows, fps):
    from PIL import Image
    out = Image.new("RGBA", (fw * 4, fh * len(rows)))
    for r, frames in enumerate(rows):
        for c, draw in enumerate(frames):
            im, p = fd.canvas(fw, fh, K)
            draw(p)
            out.alpha_composite(fd.finish(im, fw, fh), (c * fw, r * fh))
    fd.save(out, name)
    names = ["idle", "walk"]
    fd.write_frames(name, fw, fh, [(names[r], r, [0, 1, 2, 3], fps[r], True) for r in range(len(rows))])
    return out


# ------------------------------------------------------------------ crab

CRAB = fd.CORAL
CRAB_HI = fd.mix(fd.CORAL, WHITE, 0.45)
CRAB_DK = fd.mix(fd.CORAL, INK, 0.3)


def crab(open_claws=1.0, step=0, bob=0.0):
    def draw(p):
        y = 10 + bob
        # legs, three a side, alternating with the step
        for i, dx in enumerate((3.2, 5.2, 7.0)):
            lift = (1.2 if (i + step) % 2 else 0) if step >= 0 else 0
            for s in (-1, 1):
                x0 = 12 + s * dx
                p.line([(x0, y + 2), (x0 + s * 2.2, y + 4.2 - lift), (x0 + s * 2.6, y + 6.6 - lift)], INK, 0.9)
                p.line([(x0, y + 2), (x0 + s * 2.2, y + 4.2 - lift), (x0 + s * 2.6, y + 6.6 - lift)], CRAB_DK, 0.45)
        # claws on little arms
        for s in (-1, 1):
            ax = 12 + s * 7.6
            p.line([(12 + s * 4.5, y + 0.5), (ax, y - 2.5)], INK, 1.0)
            p.line([(12 + s * 4.5, y + 0.5), (ax, y - 2.5)], CRAB, 0.5)
            cx, cy = ax + s * 0.6, y - 4.4
            gap = 0.9 * open_claws
            p.ell(cx, cy + gap * 0.3, 2.3, 1.9, CRAB, 0.7)
            p.poly([(cx - s * 0.6, cy - gap * 0.2), (cx + s * 2.6, cy - 1.2 - gap), (cx + s * 2.2, cy + 0.2 - gap * 0.2)], CRAB, 0.7)
            p.ell(cx - s * 0.6, cy - 0.3, 0.7, 0.45, CRAB_HI, 0)
        # body
        p.ell(12, y + 1.2, 6.6, 4.4, CRAB, 0.8)
        p.ell(10, y - 0.6, 2.6, 1.2, CRAB_HI, 0)
        # eye stalks
        for s in (-1, 1):
            ex = 12 + s * 2.2
            p.line([(ex, y - 2.4), (ex, y - 4.6)], INK, 0.8)
            p.ell(ex, y - 5.2, 1.25, 1.25, WHITE, 0.6)
            p.ell(ex + 0.15, y - 5.0, 0.6, 0.7, INK, 0)
        p.arc(12, y + 1.4, 1.1, 0.8, 20, 160, INK, 0.45)
        for s in (-1, 1):
            p.ell(12 + s * 3.6, y + 2.0, 1.1, 0.6, fd.BLUSH, 0)
    return draw


# ------------------------------------------------------------------ gull

GULL_GREY = "#c9d3e3"
BEAK = fd.FLOWER_YELLOW


def gull(head=0.0, peck=0.0, hop=0.0, legs=0, blink=False):
    def draw(p):
        y = 13 - hop
        # legs
        for i, x in enumerate((10.5, 13.5)):
            off = (0.8 if (i + legs) % 2 else -0.4) if legs else 0
            p.line([(x, y + 4.5), (x + off, y + 8.6 + (hop * 0.3 if hop else 0))], BEAK, 0.7)
            p.line([(x + off - 0.8, y + 8.8), (x + off + 1.3, y + 8.8)], BEAK, 0.6)
        # tail and body
        p.poly([(4.2, y + 1.0), (1.4, y - 0.6), (2.0, y + 2.8), (5.2, y + 3.6)], GULL_GREY, 0.7)
        p.ell(11.5, y + 1.6, 7.0, 4.8, WHITE, 0.8)
        # wing
        p.poly([(6.0, y - 0.6), (13.4, y - 1.4), (15.2, y + 1.6), (11.0, y + 4.0), (5.6, y + 2.8)], GULL_GREY, 0.7)
        p.line([(7.4, y + 1.6), (12.4, y + 1.2)], fd.mix(GULL_GREY, INK, 0.25), 0.4)
        p.poly([(4.6, y + 0.6), (6.6, y - 0.2), (6.2, y + 2.6)], "#8f98a8", 0)
        # head (tilts for look/peck)
        hx, hy = 16.6 + peck * 1.4, y - 3.2 + peck * 3.4
        p.ell(hx, hy, 3.9, 3.6, WHITE, 0.8)
        bx = hx + 3.4 + head
        p.poly([(bx - 0.4, hy - 0.4), (bx + 3.0, hy + 0.5), (bx - 0.2, hy + 1.6)], BEAK, 0.55)
        p.ell(bx + 1.6, hy + 0.9, 0.35, 0.3, fd.CORAL, 0)
        if blink:
            p.arc(hx + 1.2 + head * 0.4, hy - 0.4, 0.9, 0.6, 20, 160, INK, 0.5)
        else:
            p.ell(hx + 1.2 + head * 0.4, hy - 0.6, 0.8, 0.95, INK, 0)
            p.ell(hx + 1.5 + head * 0.4, hy - 1.0, 0.3, 0.3, WHITE, 0)
        p.ell(hx + 0.6 + head * 0.4, hy + 1.3, 1.0, 0.55, fd.BLUSH, 0)
    return draw


# ------------------------------------------------------------------ dolphin

DOLPHIN = "#8cc4e6"
DOLPHIN_DK = fd.mix(DOLPHIN, INK, 0.25)
BELLY = "#eaf6fb"


def dolphin(arc=0.0, tail=0.0, splash=0.0, rise=0.0):
    """arc: body curve (-1 dive .. 1 leap); tail: flick; splash: 0..1 splash size; rise: lift."""
    def draw(p):
        cy = 18 - rise
        # water ripple ring at the surface under the dolphin
        p.ell(24, 25.5, 17, 3.2, fd.alpha(fd.WATER_HI, 0xd0), 0)
        p.arc(24, 25.5, 17, 3.2, 200, 340, WHITE, 0.7)
        pts_top, pts_bot = [], []
        for i in range(21):
            t = i / 20
            x = 7 + t * 30
            bend = math.sin(t * math.pi) * (4 + arc * 3)
            thick = 0.7 + 5.0 * math.sin(min(t / 0.78, 1.0) * math.pi / 2) ** 0.8
            y = cy - bend + (t - 0.5) * arc * 4
            pts_top.append((x, y - thick))
            pts_bot.append((x, y + thick * 0.85))
        hx, hy = pts_top[20][0], (pts_top[20][1] + pts_bot[20][1]) / 2
        # tail flukes at the left end
        tx, ty = pts_top[0][0], (pts_top[0][1] + pts_bot[0][1]) / 2
        flick = tail * 2.4
        p.poly([(tx + 2, ty), (tx - 4, ty - 4 + flick), (tx - 2.5, ty + flick * 0.3), (tx - 4, ty + 4 + flick), (tx + 2, ty + 0.6)], DOLPHIN, 0.75)
        # dorsal fin (behind the body outline)
        mx, my = pts_top[11]
        p.poly([(mx - 3.4, my + 1.2), (mx - 0.4, my - 4.8), (mx + 2.8, my + 0.8)], DOLPHIN, 0.7)
        # snout, then the body and the round head over it
        p.ell(hx + 4.2, hy + 1.4, 3.4, 1.8, DOLPHIN, 0.7)
        body = pts_top + list(reversed(pts_bot))
        p.poly(body, DOLPHIN, 0.8)
        p.ell(hx, hy - 0.2, 5.6, 5.2, DOLPHIN, 0.8)
        p.poly(body[1:-1], DOLPHIN, 0)
        p.ell(hx, hy - 0.2, 5.6 - 0.8, 5.2 - 0.8, DOLPHIN, 0)
        p.ell(hx + 4.2, hy + 1.4, 3.4 - 0.7, 1.8 - 0.7, DOLPHIN, 0)
        # belly
        belly = [(x, y + (yb - y) * 0.45) for (x, y), (_, yb) in zip(pts_top[5:20], pts_bot[5:20])]
        p.poly(belly + list(reversed(pts_bot[5:20])), BELLY, 0)
        p.ell(hx + 1.5, hy + 2.8, 4.0, 1.6, BELLY, 0)
        p.ell(hx + 4.4, hy + 2.0, 2.4, 0.8, BELLY, 0)
        # flipper
        fx_, fy_ = pts_bot[13]
        p.poly([(fx_ - 1.5, fy_ - 1.6), (fx_ - 4.2, fy_ + 2.6), (fx_ + 1.2, fy_ - 0.6)], DOLPHIN_DK, 0.6)
        # face
        ex, ey = hx + 0.8, hy - 1.4
        p.ell(ex, ey, 0.95, 1.1, INK, 0)
        p.ell(ex + 0.35, ey - 0.4, 0.35, 0.35, WHITE, 0)
        p.arc(hx + 4.0, hy + 1.6, 1.8, 1.0, 20, 160, INK, 0.5)
        p.ell(hx + 1.6, hy + 1.0, 1.3, 0.65, fd.BLUSH, 0)
        p.ell(pts_top[12][0], pts_top[12][1] + 1.4, 3.0, 0.9, fd.alpha(WHITE, 0xb0), 0)
        # the splash
        if splash:
            for i, (dx, r) in enumerate(((-6, 1.6), (-2, 2.2), (3, 1.8), (7, 1.3))):
                p.ell(24 + dx * (1 + splash * 0.6), 24.4 - splash * (2.4 + (i % 2) * 1.6), r * (0.6 + splash * 0.5), r * (0.6 + splash * 0.5), WHITE, 0.45, "#7fb8d8")
        for x in (14, 34):
            p.arc(x, 26.2, 3, 1.0, 200, 340, "#7fb8d8", 0.45)
    return draw


def submerge(img, waterline, tint="#7fc0e0"):
    """Below the waterline the critter shows through the water: tinted and paler."""
    from PIL import Image
    px = img.load()
    t = fd.rgb(tint)
    for y in range(waterline, img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (round(r * 0.45 + t[0] * 0.55), round(g * 0.45 + t[1] * 0.55), round(b * 0.45 + t[2] * 0.55), round(a * 0.75))
    return img


def main():
    crab_rows = [
        [crab(1.0), crab(1.0), crab(0.0), crab(1.0)],
        [crab(0.6, 0, 0), crab(0.6, 1, -0.5), crab(0.6, 0, 0), crab(0.6, 1, -0.5)],
    ]
    print("crab", sheet("crab", 24, 18, crab_rows, [4, 8]).size)
    gull_rows = [
        [gull(), gull(head=0.4), gull(peck=1.0), gull(blink=True)],
        [gull(hop=0, legs=1), gull(hop=1.6, legs=2), gull(hop=2.2, legs=1), gull(hop=0.8, legs=2)],
    ]
    print("gull", sheet("gull", 24, 24, gull_rows, [3, 8]).size)

    from PIL import Image
    out = Image.new("RGBA", (48 * 4, 32 * 2))
    rows = [
        [dolphin(0, 0), dolphin(0.15, 0.6, 0, 0.6), dolphin(0, 0), dolphin(-0.15, -0.6, 0, -0.4)],
        [dolphin(-0.6, -1, 0.3, -1.5), dolphin(0.2, 0.5, 0.8, 1.5), dolphin(0.9, 1, 1.0, 3.2), dolphin(0.3, -0.5, 0.5, 1.0)],
    ]
    for r, frames in enumerate(rows):
        for c, draw in enumerate(frames):
            im, p = fd.canvas(48, 32, K)
            draw(p)
            small = fd.finish(im, 48, 32)
            out.alpha_composite(submerge(small, 26), (c * 48, r * 32))
    fd.save(out, "dolphin")
    fd.write_frames("dolphin", 48, 32, [("idle", 0, [0, 1, 2, 3], 4, True), ("walk", 1, [0, 1, 2, 3], 6, True)])
    print("dolphin", out.size)


if __name__ == "__main__":
    main()
