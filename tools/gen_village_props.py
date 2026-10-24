"""Draw the village's own small props that have no canon source.

Usage: python3 -I tools/gen_village_props.py
Inputs: none (palette hexes from dev/STYLE.md 4.3-4.4).
Outputs (project/assets/island/):
  (sizes in world px; each file is stored at 4x, the map builder shows it at scale 0.25)
  mirror.png  single 26x40 image (104x160 file): the standing dressing mirror that opens the wardrobe
              (scripts/mirror.gd); oval glass in a gold frame topped with a heart, on two
              little feet, with a contact shadow. Its foot line is y 37.
  temple_pavilion.png  single 150x140 image (600x560 file): the temple seen from the village, a blue-and-white
              striped pavilion with a gold dome (STYLE.md 5, "Temple"): a cream step, an arched
              blush door with a gold frame, two round windows, a gold cornice, a ribbed dome
              with a heart finial. The step's foot line is y 136, the door centred at x 75.
Kawaii sticker look: warm-brown outline #8a5a5a, flat fills, one white highlight, gold
#ffe3a8 with edge #e0b24a. Drawn at 16x and downscaled with LANCZOS to 4x (O).
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/island"
INK = "#8a5a5a"
O = 4   # file pixels per world pixel: sprites are stored at 4x their size on the map
K = 16  # drawing pixels per world pixel (4x supersample over the file, LANCZOS down)
GOLD, GOLD_HI, GOLD_LO = "#ffe3a8", "#fff4c4", "#e0b24a"


def P(*v):
    return [c * K for c in v]


def heart(d, x, y, r, col):
    d.ellipse(P(x - r, y - r, x, y + r * .2), fill=col)
    d.ellipse(P(x, y - r, x + r, y + r * .2), fill=col)
    d.polygon([((x - r * .97) * K, (y - r * .2) * K), ((x + r * .97) * K, (y - r * .2) * K), (x * K, (y + r * 1.1) * K)], fill=col)


def mirror():
    W, H = 26, 40
    im = Image.new("RGBA", (W * K, H * K))
    sh = Image.new("RGBA", im.size)
    sd = ImageDraw.Draw(sh)
    for i in range(5):
        sd.ellipse(P(3 + i, 34.5 + i * 0.3, 23 - i, 39.5 - i * 0.3), fill=(138, 90, 90, 18))
    im.alpha_composite(sh)
    d = ImageDraw.Draw(im)
    # Feet and stand.
    for x in (7, 19):
        d.rounded_rectangle(P(x - 2.4, 33, x + 2.4, 37.5), K, fill=GOLD, outline=INK, width=K)
    d.rounded_rectangle(P(11.5, 29, 14.5, 35), K // 2, fill=GOLD, outline=INK, width=K)
    # Frame and glass.
    d.ellipse(P(3, 6, 23, 33), fill=GOLD, outline=INK, width=int(1.2 * K))
    d.ellipse(P(5.4, 8.4, 20.6, 30.6), fill=GOLD_LO)
    d.ellipse(P(6.2, 9.2, 19.8, 29.8), fill="#d4eefa", outline="#ffffff", width=K // 2)
    d.ellipse(P(8, 12, 12.5, 20), fill="#f2fbff")
    d.polygon([(P(14, 24)[0], P(14, 24)[1]), (P(17.6, 18)[0], P(17.6, 18)[1]), (P(18.4, 20.5)[0], P(18.4, 20.5)[1]),
               (P(15.2, 26)[0], P(15.2, 26)[1])], fill="#eaf8ff")
    for x, y in ((4.2, 19.5), (21.8, 19.5)):
        d.ellipse(P(x - 1.2, y - 1.2, x + 1.2, y + 1.2), fill="#ffb3c8", outline=INK, width=K // 2)
    # Heart crest.
    heart(d, 13, 4.6, 4.4, INK)
    heart(d, 13, 4.7, 3.4, "#ff9fc0")
    d.ellipse(P(10.8, 2.6, 12.4, 3.8), fill="#ffffff")
    return im


def sparkle(d, x, y, r, fill="#fff3a8", ink=GOLD_LO):
    pts = [(x, y - r), (x + r * .3, y - r * .3), (x + r, y), (x + r * .3, y + r * .3), (x, y + r),
           (x - r * .3, y + r * .3), (x - r, y), (x - r * .3, y - r * .3)]
    d.polygon([(px * K, py * K) for px, py in pts], fill=fill, outline=ink, width=K // 2)


def pavilion():
    W, H = 150, 140
    im = Image.new("RGBA", (W * K, H * K))
    d = ImageDraw.Draw(im)
    o = int(1.4 * K)
    # Dome (behind the cornice): gold, ribbed, a highlight, a heart on a little orb.
    d.ellipse(P(31, 22, 119, 98), fill="#ffe59a", outline=INK, width=o)
    for dx in (-22, 0, 22):
        d.line(P(75 + dx * 0.55, 24.5, 75 + dx, 60), fill="#efc86a", width=int(1.2 * K))
    d.ellipse(P(46, 32, 62, 44), fill="#fff4c4")
    d.ellipse(P(71, 12, 79, 21), fill=GOLD, outline=INK, width=K)
    heart(d, 75, 8.4, 5.6, INK)
    heart(d, 75, 8.5, 4.4, "#ff9fc0")
    # Striped walls.
    d.rounded_rectangle(P(16, 60, 134, 124), 4 * K, fill="#ffffff", outline=INK, width=o)
    for x in range(22, 130, 10):
        d.rectangle(P(x, 66, x + 5, 121), fill="#a8d4f5")
    d.rectangle(P(17.5, 117, 132.5, 122.5), fill="#e6f2fb")
    # Cornice.
    d.rounded_rectangle(P(10, 54, 140, 66), 3 * K, fill=GOLD, outline=INK, width=o)
    d.rectangle(P(13, 56.5, 137, 58.5), fill=GOLD_HI)
    for x in range(18, 136, 9):
        d.ellipse(P(x - 1.3, 61, x + 1.3, 63.6), fill=GOLD_LO)
    # Round windows.
    for x in (38, 112):
        d.ellipse(P(x - 9, 78, x + 9, 96), fill=GOLD, outline=INK, width=o)
        d.ellipse(P(x - 6.4, 80.6, x + 6.4, 93.4), fill="#cfeaf8")
        d.ellipse(P(x - 4.4, 82.6, x - 0.6, 86.4), fill="#ffffff")
    # Arched door.
    d.rounded_rectangle(P(57, 76, 93, 124), 17 * K, fill=GOLD, outline=INK, width=o)
    d.rounded_rectangle(P(61, 80, 89, 124), 14 * K, fill="#ffc9da", outline="#f59ab5", width=K)
    d.line(P(75, 82, 75, 123), fill="#f59ab5", width=K)
    for x in (71, 79):
        d.ellipse(P(x - 1.4, 103, x + 1.4, 105.8), fill=GOLD_LO)
    heart(d, 75, 92, 4.2, "#fff4f8")
    # Step.
    d.rounded_rectangle(P(6, 122, 144, 136), 3 * K, fill="#fbefe0", outline=INK, width=o)
    d.rectangle(P(9, 124, 141, 126), fill="#fffaf2")
    d.rounded_rectangle(P(52, 127, 98, 139), 2 * K, fill="#fff6e8", outline=INK, width=K)
    sparkle(d, 128, 30, 5)
    sparkle(d, 20, 44, 3.4, "#ffffff", None)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    mirror().resize((26 * O, 40 * O), Image.LANCZOS).save(OUT / "mirror.png")
    pavilion().resize((150 * O, 140 * O), Image.LANCZOS).save(OUT / "temple_pavilion.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
