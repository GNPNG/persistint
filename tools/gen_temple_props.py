"""Draw the temple's small furnishings: candle stands, flower urns and twinkling sparkles.

Usage: python3 -I tools/gen_temple_props.py
Inputs: none (palette hexes from dev/STYLE.md 4.3-4.4 and 6.1; fixed seed).
Outputs (project/assets/temple/; sizes in world px, each file stored at 4x and shown by the
map builder at scale 0.25, so a 24x44 frame is 96x176 file px):
  temple_candles.png  sprite sheet, frame 24x44, 1 row (idle) x 4 columns (flame flicker);
                      origin at the foot of the stand (frame x 12, y 42)
  temple_urn.png      single 28x36 image, a cream urn of pink and white flowers; foot at y 34
  temple_plinth.png   single 32x14 image, a square stone step a pillar stands on, with its
                      contact shadow; the pillar's foot goes at y 9
  temple_cushion.png  single 30x20 image, a tufted blush kneeling cushion with gold tassels;
                      its foot at y 18
  temple_shadow.png   single 24x8 image, a soft contact shadow put under furnishings
  temple_twinkle.png  sprite sheet, frame 12x12, 1 row (idle) x 6 columns (a four-point sparkle
                      swelling and fading); centred
The canon sheets have none of these, so they are drawn in the canon sticker look: warm-brown
outline #8a5a5a, flat pastel fills, one highlight, gold #ffe3a8 / edge #e0b24a.
Drawn at 16x and downscaled with LANCZOS to 4x the map size (O); the map shows them at
scale 0.25, so every size below is in world pixels and the files are 4x that.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/temple"
INK = "#8a5a5a"
O = 4   # file pixels per world pixel: sprites are stored at 4x their size on the map
K = 16  # drawing pixels per world pixel (4x supersample over the file, LANCZOS down)
GOLD, GOLD_HI, GOLD_LO = "#ffe3a8", "#fff4c4", "#e0b24a"
random.seed(14)


def P(*v):
    return [c * K for c in v]


def ell(d, x, y, rx, ry, fill, ink=INK, w=1.0):
    d.ellipse(P(x - rx, y - ry, x + rx, y + ry), fill=fill, outline=ink if w else None, width=int(w * K))


def sparkle(d, x, y, r, fill="#fff3a8", ink=GOLD_LO, w=0.6):
    pts = [(x, y - r), (x + r * .3, y - r * .3), (x + r, y), (x + r * .3, y + r * .3), (x, y + r),
           (x - r * .3, y + r * .3), (x - r, y), (x - r * .3, y - r * .3)]
    d.polygon([(px * K, py * K) for px, py in pts], fill=fill, outline=ink, width=max(1, int(w * K)))


def sheet(frames, w, h):
    out = Image.new("RGBA", (w * O * len(frames), h * O))
    for i, f in enumerate(frames):
        out.paste(f.resize((w * O, h * O), Image.LANCZOS), (i * w * O, 0))
    return out


# ---------- candle stand ----------

def candles(frame):
    W, H = 24, 44
    im = Image.new("RGBA", (W * K, H * K))
    glow = Image.new("RGBA", im.size)
    gd = ImageDraw.Draw(glow)
    pulse = [1.0, 0.85, 0.95, 0.8][frame]
    for i in range(6, 0, -1):
        a = int(26 * pulse * (1 - i / 7))
        gd.ellipse(P(12 - i * 1.9, 8 - i * 1.6, 12 + i * 1.9, 8 + i * 1.6), fill=(255, 236, 170, a))
    im = Image.alpha_composite(im, glow)
    d = ImageDraw.Draw(im)
    # Foot, stem and the three-armed cup.
    ell(d, 12, 40.5, 7, 2.6, GOLD)
    d.rounded_rectangle(P(10.6, 22, 13.4, 40), K, fill=GOLD, outline=INK, width=K)
    ell(d, 12, 31, 2.6, 1.6, GOLD_HI)
    d.arc(P(4, 13, 20, 25), 0, 180, fill=INK, width=int(2.6 * K))
    d.arc(P(4, 13, 20, 25), 0, 180, fill=GOLD, width=int(1.4 * K))
    for cx in (4.6, 12, 19.4):
        ell(d, cx, 19, 2.4, 1.2, GOLD)
    # Candles (pink, cream, pink), each with a flame that leans and stretches per frame.
    for i, (cx, col, top) in enumerate(((4.6, "#ffb3c8", 12), (12, "#fff6e8", 10), (19.4, "#ffb3c8", 12))):
        d.rounded_rectangle(P(cx - 1.6, top, cx + 1.6, 19), K // 2, fill=col, outline=INK, width=K)
        d.rectangle(P(cx - 0.9, top + 1, cx - 0.3, 18), fill="#ffffff")
        lean = [0.0, 0.5, -0.4, 0.2][(frame + i) % 4]
        tall = [3.8, 4.4, 3.4, 4.0][(frame + i * 2) % 4]
        fx, fy = cx + lean, top - 0.6
        pts = [(fx - 1.3, fy), (fx + 1.3, fy), (fx + lean * 0.8, fy - tall)]
        d.ellipse(P(fx - 1.4, fy - 2.0, fx + 1.4, fy + 0.6), fill="#ffd36e", outline="#f3a25a", width=K // 2)
        d.polygon([(x * K, y * K) for x, y in pts], fill="#ffd36e")
        d.ellipse(P(fx - 0.6, fy - 1.4, fx + 0.6, fy - 0.1), fill="#fffbe6")
    return im


# ---------- flower urn ----------

def urn():
    W, H = 28, 36
    im = Image.new("RGBA", (W * K, H * K))
    d = ImageDraw.Draw(im)
    # Leaves and flowers first, the urn's rim covers their stems.
    for x, y, r in ((6, 15, 3.6), (22, 15, 3.6), (9, 9, 3.4), (19, 9, 3.4), (14, 12, 4)):
        ell(d, x, y, r, r * 0.7, "#a6dc8a", "#5fa84a", 0.8)
    rng = random.Random(3)
    spots = [(8, 12), (14, 7), (20, 12), (11, 15), (17, 15), (14, 11.5)]
    for i, (x, y) in enumerate(spots):
        petal = ["#ff9fc0", "#ffffff", "#ffc9de", "#ff9fc0", "#ffffff", "#ffb8d1"][i]
        r = 2.0 + rng.random() * 0.5
        for a in range(5):
            ang = a * 2 * math.pi / 5 - math.pi / 2
            ell(d, x + math.cos(ang) * r * 0.8, y + math.sin(ang) * r * 0.8, r * 0.62, r * 0.62, petal, INK, 0.6)
        ell(d, x, y, r * 0.45, r * 0.45, "#ffe27a", INK, 0.5)
    # Urn body: rim, bowl, neck, foot.
    ell(d, 14, 18.5, 9, 2.4, GOLD)
    d.chord(P(5.5, 10, 22.5, 32), 0, 180, fill="#fbefe0", outline=INK, width=K)
    d.rectangle(P(6, 19.5, 22, 21), fill="#ffc9da")
    d.ellipse(P(8, 22, 11, 25.5), fill="#fffdf8")
    d.rounded_rectangle(P(11, 30, 17, 32.5), K // 2, fill="#fbefe0", outline=INK, width=K)
    ell(d, 14, 33.6, 6, 1.6, GOLD)
    for x in (10.5, 17.5):
        ell(d, x, 25.5, 0.9, 0.6, "#ff9fb8", None, 0)
    return im


# ---------- plinth and shadow ----------

def shadow(w, h, alpha=70):
    im = Image.new("RGBA", (w * K, h * K))
    d = ImageDraw.Draw(im)
    for i in range(6):
        t = i / 6
        d.ellipse(P(w * t / 4, h * t / 4, w - w * t / 4, h - h * t / 4), fill=(138, 90, 90, int(alpha * (0.25 + t * 0.75) / 3)))
    return im


def plinth():
    W, H = 32, 14
    im = Image.new("RGBA", (W * K, H * K))
    im.alpha_composite(shadow(30, 8, 90), (K, 6 * K))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(P(4, 3, 28, 11), K, fill="#f6eadb", outline=INK, width=K)
    d.rectangle(P(5, 3.8, 27, 5.2), fill="#fffaf2")
    d.rectangle(P(5, 8.6, 27, 10.2), fill="#e9d8c0")
    d.rectangle(P(4.5, 6.6, 27.5, 7.2), fill=GOLD_LO)
    return im


def cushion():
    W, H = 22, 16
    im = Image.new("RGBA", (W * K, H * K))
    im.alpha_composite(shadow(20, 6, 110), (K, 9 * K))  # drawn at 22x16, saved at 30x20
    d = ImageDraw.Draw(im)
    for x, y in ((2.2, 4.2), (19.8, 4.2), (2.2, 11.2), (19.8, 11.2)):  # tassels
        ell(d, x, y, 1.3, 1.3, GOLD, INK, 0.6)
    d.rounded_rectangle(P(2.5, 3, 19.5, 13), 4 * K, fill="#ffc2d4", outline=INK, width=K)
    d.rounded_rectangle(P(4.5, 4.5, 17.5, 10), 3 * K, fill="#ffd3e0")
    d.ellipse(P(5.5, 5, 9.5, 6.6), fill="#fff0f5")
    ell(d, 11, 8, 1.1, 0.9, "#f59ab5", INK, 0.5)
    for x in (7, 15):
        d.line(P(x, 7.6, 11, 8), fill="#f59ab5", width=K // 2)
    return im


# ---------- twinkle ----------

def twinkle(frame):
    im = Image.new("RGBA", (12 * K, 12 * K))
    d = ImageDraw.Draw(im)
    s = [0.25, 0.6, 1.0, 0.75, 0.4, 0.0][frame]
    if s > 0:
        sparkle(d, 6, 6, 5.4 * s, "#fff3a8" if frame != 2 else "#ffffff", GOLD_LO, 0.5)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet([candles(f) for f in range(4)], 24, 44).save(OUT / "temple_candles.png")
    urn().resize((28 * O, 36 * O), Image.LANCZOS).save(OUT / "temple_urn.png")
    plinth().resize((32 * O, 14 * O), Image.LANCZOS).save(OUT / "temple_plinth.png")
    cushion().resize((30 * O, 20 * O), Image.LANCZOS).save(OUT / "temple_cushion.png")
    shadow(24, 8, 110).resize((24 * O, 8 * O), Image.LANCZOS).save(OUT / "temple_shadow.png")
    sheet([twinkle(f) for f in range(6)], 12, 12).save(OUT / "temple_twinkle.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
