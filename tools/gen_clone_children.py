"""Draw the failed clone children of the bunker's clone hall: small, pale-green, shambling,
kawaii. One sprite per original (every batch of an original shares the same little face),
told apart by hair; stitches, a goo drip and one X eye on every one of them. Also the
polar bear cub batch (not zombies: fluffy, round, healthy), its pink-muzzle and napping
frames, and the kawaii gore bits a cub's pounce leaves behind (bone, sweat-drop chunk, puddle).

Usage: python3 -I tools/gen_clone_children.py
Writes project/assets/canon/clone_<original>.png (20x30; originals are cast ids in
data/cast.json), clone_polar_bear*.png (24x22) and gore_*.png.
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "project/assets/canon"
INK = "#5a4a5e"
SKIN = "#c9ecc4"
GOO = "#8fe07a"
K = 4
W, H = 20, 30


def canvas():
    im = Image.new("RGBA", (W * K, H * K))
    return im, ImageDraw.Draw(im)


def ell(d, x0, y0, x1, y1, fill, outline=INK, width=1):
    d.ellipse([x0 * K, y0 * K, x1 * K, y1 * K], fill=fill, outline=outline, width=max(1, int(width * K / 2)))


def body(d, gown):
    # little legs, gown, arms stretched forward in the classic shamble
    for x in (7, 11):
        d.rounded_rectangle([x * K, 24 * K, (x + 2.4) * K, 29 * K], K, fill=SKIN, outline=INK, width=K // 2)
    d.rounded_rectangle([5 * K, 16 * K, 15 * K, 26 * K], 3 * K, fill=gown, outline=INK, width=K // 2)
    for y in (17.5, 19.5):
        d.rounded_rectangle([12 * K, y * K, 19 * K, (y + 1.8) * K], K, fill=SKIN, outline=INK, width=K // 2)
    # hospital-gown stitches
    d.line([7 * K, 21 * K, 13 * K, 21 * K], fill=INK, width=K // 2)
    for x in (8, 10, 12):
        d.line([x * K, 20.3 * K, x * K, 21.7 * K], fill=INK, width=K // 2)


def head(d):
    ell(d, 2, 1, 18, 17, SKIN)
    # one sleepy eye, one X eye, blush, a tiny groaning mouth
    ell(d, 5.6, 8.4, 7.6, 10.4, INK, None)
    for dx in (0, 1):
        d.line([(11.6 + dx * 2) * K, 8.4 * K, (13.6 - dx * 2) * K, 10.4 * K], fill=INK, width=K // 2 + 1)
    for x in (4.6, 13.4):
        d.ellipse([(x - 1.4) * K, 11 * K, (x + 1.4) * K, 12.6 * K], fill="#ff9fb8")
    d.ellipse([8.8 * K, 12 * K, 11.2 * K, 14.2 * K], fill="#7a4a5a")
    # forehead stitches
    d.line([4 * K, 6 * K, 8 * K, 5 * K], fill=INK, width=K // 2)
    for x in (5, 6.5):
        d.line([x * K, 4.6 * K, (x + 0.2) * K, 6.4 * K], fill=INK, width=K // 2)
    # goo drip off the chin
    d.rounded_rectangle([12 * K, 14 * K, 13.4 * K, 18.5 * K], K // 2, fill=GOO)
    d.ellipse([11.6 * K, 17.6 * K, 13.8 * K, 19.6 * K], fill=GOO)


def hair(d, kind):
    if kind == "epstein":  # grey, swept back
        d.chord([2 * K, 0, 18 * K, 12 * K], 180, 360, fill="#b7b4bd", outline=INK, width=K // 2)
        d.line([5 * K, 2 * K, 13 * K, 1.4 * K], fill="#8f8c96", width=K // 2)
    elif kind == "bill_clinton":  # white, puffy, a round red nose
        for x, y in ((5, 3), (10, 1.6), (15, 3)):
            ell(d, x - 3.6, y - 2.6, x + 3.6, y + 3.4, "#f4f1ee")
        ell(d, 8.8, 10, 11.2, 12, "#f2a0a0")
    elif kind == "hillary_clinton":  # blonde bob
        d.chord([1.4 * K, 0, 18.6 * K, 13 * K], 180, 360, fill="#f2d48a", outline=INK, width=K // 2)
        for x in (1.4, 15.4):
            d.rounded_rectangle([x * K, 5 * K, (x + 3.2) * K, 13 * K], K, fill="#f2d48a", outline=INK, width=K // 2)
    elif kind == "bill_gates":  # side part and big round glasses
        d.chord([2 * K, 0, 18 * K, 11 * K], 180, 360, fill="#9a7458", outline=INK, width=K // 2)
        d.line([8 * K, 0.6 * K, 7 * K, 5 * K], fill=INK, width=K // 2)
        for x in (6.6, 12.6):
            ell(d, x - 2.4, 7, x + 2.4, 11.8, None, INK, 0.8)
        d.line([9 * K, 9.2 * K, 10.2 * K, 9.2 * K], fill=INK, width=K // 2)


def clone(kind, gown):
    im, d = canvas()
    body(d, gown)
    head(d)
    hair(d, kind)
    im.resize((W, H), Image.LANCZOS).save(OUT / f"clone_{kind}.png")


def cub(name, smeared=False, asleep=False):
    w, h = 24, 22
    im = Image.new("RGBA", (w * K, h * K))
    d = ImageDraw.Draw(im)
    fur = "#fbfbff"
    for x in (5, 15):  # stubby feet
        ell(d, x, 16, x + 5, 21, fur)
    ell(d, 3, 9, 21, 20, fur)  # round body
    for x in (4, 15):  # ears
        ell(d, x, 1, x + 5, 6, fur)
        ell(d, x + 1.4, 2.4, x + 3.6, 4.6, "#ffc4d4", None)
    ell(d, 4, 2, 20, 15, fur)  # head
    ell(d, 9, 9, 15, 14, "#f0eef6")  # muzzle
    ell(d, 11, 9.6, 13, 11, INK, None)  # nose
    if smeared:
        for x, y, r in ((9.6, 12.6, 1.6), (14, 13, 1.3), (12, 14, 1.1)):
            d.ellipse([(x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K], fill="#ff7a9a")
    if asleep:
        for x in (7, 15):
            d.arc([x * K, 6.6 * K, (x + 3) * K, 9.4 * K], 20, 160, fill=INK, width=K // 2 + 1)
    else:
        for x in (8.4, 15.6):
            ell(d, x - 1.2, 6.4, x + 1.2, 8.8, INK, None)
            d.ellipse([(x - 0.6) * K, 6.8 * K, (x + 0.1) * K, 7.5 * K], fill="#ffffff")
    for x in (6, 18):
        d.ellipse([(x - 1.4) * K, 9.6 * K, (x + 1.4) * K, 11.2 * K], fill="#ffb3c8")
    im.resize((w, h), Image.LANCZOS).save(OUT / f"{name}.png")


def gore():
    im = Image.new("RGBA", (12 * K, 6 * K))
    d = ImageDraw.Draw(im)  # a little cartoon bone
    d.rounded_rectangle([2.5 * K, 2 * K, 9.5 * K, 4 * K], K // 2, fill="#fff8ec", outline=INK, width=K // 2)
    for x in (2.2, 9.8):
        for y in (1.8, 4.2):
            ell(d, x - 1.6, y - 1.6, x + 1.6, y + 1.6, "#fff8ec", INK, 0.5)
    im.resize((12, 6), Image.LANCZOS).save(OUT / "gore_bone.png")
    im = Image.new("RGBA", (10 * K, 10 * K))
    d = ImageDraw.Draw(im)  # a pink chunk with a worried face and a sweat drop
    ell(d, 0.5, 2, 9.5, 9.5, "#ff8fa8")
    for x in (3.4, 6.6):
        d.ellipse([(x - 0.6) * K, 5 * K, (x + 0.6) * K, 6.2 * K], fill=INK)
    d.arc([3.8 * K, 6.8 * K, 6.2 * K, 8.6 * K], 200, 340, fill=INK, width=K // 2)
    d.polygon([(8.6 * K, 0.4 * K), (9.8 * K, 2.6 * K), (7.4 * K, 2.6 * K)], fill="#9fd8ff")
    d.ellipse([7.4 * K, 1.6 * K, 9.8 * K, 3.8 * K], fill="#9fd8ff")
    im.resize((10, 10), Image.LANCZOS).save(OUT / "gore_chunk.png")
    im = Image.new("RGBA", (32 * K, 14 * K))
    d = ImageDraw.Draw(im)  # a pastel puddle with a heart outline
    for x0, y0, x1, y1 in ((1, 3, 22, 13), (12, 1, 31, 12), (6, 6, 28, 13.5)):
        d.ellipse([x0 * K, y0 * K, x1 * K, y1 * K], fill="#e8547a")
    hx, hy = 16, 7.6
    heart = [(hx, hy + 3.4), (hx - 4, hy), (hx - 4, hy - 1.6), (hx - 2.6, hy - 3), (hx - 1, hy - 3), (hx, hy - 1.8),
             (hx + 1, hy - 3), (hx + 2.6, hy - 3), (hx + 4, hy - 1.6), (hx + 4, hy), (hx, hy + 3.4)]
    d.line([(x * K, y * K) for x, y in heart], fill="#ffd0dc", width=K // 2 + 1)
    im.resize((32, 14), Image.LANCZOS).save(OUT / "gore_puddle.png")


if __name__ == "__main__":
    cub("clone_polar_bear")
    cub("clone_polar_bear_smeared", smeared=True)
    cub("clone_polar_bear_nap", smeared=True, asleep=True)
    gore()
    for kind, gown in (("epstein", "#ffb3c8"), ("bill_clinton", "#a8d8f0"), ("hillary_clinton", "#c9b3f0"), ("bill_gates", "#ffe08a")):
        clone(kind, gown)
