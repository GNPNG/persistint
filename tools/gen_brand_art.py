"""Draw the PERSISTINT brand art: the wordmark, the title screen with the logo, the boot splash
and the app icon.

Usage: python3 -I tools/gen_brand_art.py   (run after tools/gen_ui_art.py and
                                           tools/gen_village_props.py: it reads their output)

Inputs:
  art/brand/fonts/Fredoka-VF.ttf                 Fredoka (SIL OFL, art/brand/fonts/OFL-Fredoka.txt),
                                                 the rounded face the promo site uses, at weight 700
  project/assets/ui/title/title_screen_plain.png the title art without a logo (tools/gen_ui_art.py)
  project/assets/island/temple_pavilion.png      the blue-and-white striped temple with its gold
                                                 dome (tools/gen_village_props.py)
Outputs:
  project/assets/ui/title/wordmark.png       1600x480, transparent: PERSISTINT in rounded, bubbly
                                             pastel letters (prompts/STYLE.md 4.8: pink, sky-blue
                                             and mint letterforms, warm-brown outline #8a5a5a,
                                             white sticker outline, one white shine per letter),
                                             letters tilted and bobbing a little; the main menu
                                             shows it (scenes/ui/main_menu.tscn) at a quarter size
  project/assets/ui/title/wordmark_letters.png
                                             the same ten sticker letters, one per cell in a
                                             row, each with its own shadow, at the wordmark's
                                             scale; project/data/title_wordmark.json says which
                                             cell is which letter and where it sits in the
                                             1600-px wordmark, so scenes/ui/main_menu.tscn can
                                             show the letters as separate sprites that jiggle
                                             and answer taps (scripts/ui/title_letters.gd)
  project/assets/ui/title/title_screen.png   2560x1440, stand-in for prompts/image/ui/title/
                                             title_screen.md (the title art with the logo at the
                                             top): title_screen_plain.png with the wordmark
  project/assets/ui/brand/boot_splash.png    1280x720, transparent: the wordmark over a small
                                             heart, shown on the cream boot splash colour
                                             (project.godot application/boot_splash)
  project/assets/ui/icon/app_icon.png        1024x1024 stand-in for prompts/image/ui/icon/
                                             app_icon.md: the striped gold-domed temple on a
                                             little island under a heart and a sparkle, on a
                                             turquoise-to-blush rounded square; reads at 64x64
                                             (project.godot application/config/icon)
Everything is drawn at SUPER x its output size and downscaled with LANCZOS (soft, antialiased
edges, STYLE.md 4.1). No randomness: the same inputs give the same PNGs.
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "project/assets"
FONT = ROOT / "art/brand/fonts/Fredoka-VF.ttf"
SUPER = 2

INK = (138, 90, 90)          # #8a5a5a warm-brown outline
WHITE = (255, 255, 255)
CREAM = (253, 246, 227)      # #fdf6e3
LETTERS = [(255, 143, 177), (168, 212, 245), (168, 230, 160)]  # pink #ff8fb1, sky #a8d4f5, mint #a8e6a0
HEART = (255, 143, 177)
SPARK, SPARK_EDGE = (255, 243, 168), (224, 178, 74)
WORD = "PERSISTINT"


def font(size):
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([700])
    return f


def letter(ch, size, fill):
    """One sticker letter: white outline, brown outline, pastel fill and a white shine."""
    f = font(size)
    white_w, ink_w = round(size * 0.11), round(size * 0.05)
    pad = white_w * 2
    l, t, r, b = f.getbbox(ch, stroke_width=white_w)
    w, h = r - l + pad * 2, b - t + pad * 2
    origin = (pad - l, pad - t)
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    d.text(origin, ch, font=f, fill=WHITE, stroke_width=white_w, stroke_fill=WHITE)
    d.text(origin, ch, font=f, fill=INK, stroke_width=ink_w, stroke_fill=INK)
    d.text(origin, ch, font=f, fill=fill)
    # The shine: the glyph's own shape, shrunk, kept only near its top, in translucent white.
    glyph = Image.new("L", (w, h))
    ImageDraw.Draw(glyph).text(origin, ch, font=f, fill=255)
    inner = glyph.filter(ImageFilter.MinFilter(2 * round(size * 0.07) + 1))
    gl, gt, gr, gb = glyph.getbbox()
    band = Image.new("L", (w, h))
    ImageDraw.Draw(band).ellipse([gl - size * 0.2, gt - size * 0.55, gr - size * 0.25, gt + (gb - gt) * 0.42], fill=255)
    shine = ImageChops.multiply(inner, band).point(lambda v: v * 0.55)
    im.alpha_composite(Image.merge("RGBA", (*[Image.new("L", (w, h), 255)] * 3, shine)))
    return im


def wordmark(width):
    """PERSISTINT, letters cycling pink / sky / mint, tilted and bobbing; width px wide."""
    size = 400
    parts = []
    for i, ch in enumerate(WORD):
        im = letter(ch, size, LETTERS[i % 3])
        im = im.rotate((-4, 3, -2, 4, -3, 2, -4, 3, -2, 4)[i], resample=Image.BICUBIC, expand=True)
        im = im.crop(im.getchannel("A").getbbox())
        parts.append((im, (0, -1, 1, -1, 0, 1, -1, 0, 1, -1)[i] * size * 0.035))
    overlap = size * 0.05  # the white sticker outlines touch, as on a sticker sheet
    total = sum(p.width for p, _ in parts) - overlap * (len(parts) - 1)
    tall = max(p.height for p, _ in parts) + size * 0.2
    canvas = Image.new("RGBA", (math.ceil(total), math.ceil(tall)))
    x = 0.0
    for p, dy in parts:
        canvas.alpha_composite(p, (round(x), round((tall - p.height) / 2 + dy)))
        x += p.width - overlap
    # A soft warm shadow under the sticker so it sits on the sky.
    alpha = canvas.getchannel("A")
    shadow = Image.merge("RGBA", (*[Image.new("L", canvas.size, c) for c in INK], alpha.point(lambda v: v * 0.3)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.03))
    out = Image.new("RGBA", canvas.size)
    out.alpha_composite(shadow, (0, round(size * 0.04)))
    out.alpha_composite(canvas)
    h = round(width * out.height / out.width)
    return out.resize((width, h), Image.LANCZOS)


def wordmark_parts(size=400):
    """The letters as wordmark() lays them out: (letter image, x, y) on the unscaled canvas, plus
    the canvas size. Shared with wordmark_letters() so the sheet matches the one-piece wordmark."""
    parts = []
    for i, ch in enumerate(WORD):
        im = letter(ch, size, LETTERS[i % 3])
        im = im.rotate((-4, 3, -2, 4, -3, 2, -4, 3, -2, 4)[i], resample=Image.BICUBIC, expand=True)
        im = im.crop(im.getchannel("A").getbbox())
        parts.append((im, (0, -1, 1, -1, 0, 1, -1, 0, 1, -1)[i] * size * 0.035))
    overlap = size * 0.05
    total = sum(p.width for p, _ in parts) - overlap * (len(parts) - 1)
    tall = max(p.height for p, _ in parts) + size * 0.2
    placed, x = [], 0.0
    for p, dy in parts:
        placed.append((p, round(x), round((tall - p.height) / 2 + dy)))
        x += p.width - overlap
    return placed, (math.ceil(total), math.ceil(tall))


def wordmark_letters(width):
    """One cell per letter, each with the sticker's soft shadow, scaled like wordmark(width);
    returns the sheet and the layout dict for project/data/title_wordmark.json."""
    size = 400
    placed, (cw, chh) = wordmark_parts(size)
    f = width / cw
    pad = round(size * 0.12)                                   # room for the shadow's blur and drop
    cells = []
    for im, x, y in placed:
        cell = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad))
        alpha = im.getchannel("A")
        shadow = Image.merge("RGBA", (*[Image.new("L", im.size, c) for c in INK], alpha.point(lambda v: v * 0.3)))
        shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.03))
        cell.alpha_composite(shadow, (pad, pad + round(size * 0.04)))
        cell.alpha_composite(im, (pad, pad))
        cells.append((cell, x - pad, y - pad))
    cell_w = max(round(c.width * f) for c, _, _ in cells)
    cell_h = max(round(c.height * f) for c, _, _ in cells)
    sheet = Image.new("RGBA", (cell_w * len(cells), cell_h))
    letters = []
    for i, (cell, x, y) in enumerate(cells):
        small = cell.resize((round(cell.width * f), round(cell.height * f)), Image.LANCZOS)
        sheet.alpha_composite(small, (i * cell_w, 0))
        letters.append({"ch": WORD[i], "cell": [i * cell_w, 0, small.width, small.height],
                        "x": round(x * f), "y": round(y * f)})
    layout = {
        "_note": "Written by tools/gen_brand_art.py: where each cell of ui/title/wordmark_letters.png sits in the %d-px-wide wordmark (scripts/ui/title_letters.gd)." % width,
        "sheet": "res://assets/ui/title/wordmark_letters.png",
        "width": width, "height": round(chh * f),
        "letters": letters,
    }
    return sheet, layout


def heart(d, cx, cy, r, fill, ink, w):
    pts = []
    for i in range(96):
        t = i / 96 * 2 * math.pi
        hx = 16 * math.sin(t) ** 3
        hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + hx / 16 * r, cy + hy / 16 * r))
    # The outline is a slightly larger ink heart behind the fill (no seam at the cusp).
    k = (r + w) / r
    d.polygon([(cx + (x - cx) * k, cy + (y - cy) * k + w * 0.1) for x, y in pts], fill=ink)
    d.polygon(pts, fill=fill)
    d.ellipse([cx - r * .62, cy - r * .55, cx - r * .22, cy - r * .2], fill=WHITE)


def sparkle(d, x, y, r, w):
    p = [(0, -r), (r * .28, -r * .28), (r, 0), (r * .28, r * .28), (0, r), (-r * .28, r * .28), (-r, 0), (-r * .28, -r * .28)]
    d.polygon([(x + a, y + b) for a, b in p], fill=SPARK, outline=SPARK_EDGE, width=w)


def title_screen():
    plain = Image.open(ASSETS / "ui/title/title_screen_plain.png").convert("RGBA")
    mark = wordmark(round(plain.width * 0.5))
    plain.alpha_composite(mark, ((plain.width - mark.width) // 2, round(plain.height * 0.045)))
    return plain


def boot_splash():
    W, H = 1280, 720
    big = Image.new("RGBA", (W * SUPER, H * SUPER))
    d = ImageDraw.Draw(big)
    heart(d, W * SUPER / 2, H * SUPER * 0.70, 46 * SUPER, HEART, INK, 5 * SUPER)
    out = big.resize((W, H), Image.LANCZOS)
    mark = wordmark(880)
    out.alpha_composite(mark, ((W - mark.width) // 2, round(H * 0.44 - mark.height / 2)))
    return out


def app_icon():
    S = 1024 * SUPER
    im = Image.new("RGBA", (S, S))
    # Rounded square, turquoise sky down to a blush horizon.
    grad = Image.new("RGBA", (1, S))
    top, bottom = (128, 214, 214), (255, 205, 222)
    for y in range(S):
        f = y / (S - 1)
        grad.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * f) for i in range(3)) + (255,))
    grad = grad.resize((S, S))
    mask = Image.new("L", (S, S))
    m = 40 * SUPER
    ImageDraw.Draw(mask).rounded_rectangle([m, m, S - m, S - m], 210 * SUPER, fill=255)
    im.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(im)
    # The island: a sand rim and a grass top.
    d.ellipse([150 * SUPER, 700 * SUPER, 874 * SUPER, 930 * SUPER], fill=(255, 233, 184), outline=INK, width=12 * SUPER)
    d.ellipse([200 * SUPER, 710 * SUPER, 824 * SUPER, 880 * SUPER], fill=(197, 236, 170), outline=INK, width=9 * SUPER)
    # A big heart and a sparkle in the sky.
    heart(d, 780 * SUPER, 250 * SUPER, 110 * SUPER, HEART, INK, 12 * SUPER)
    sparkle(d, 240 * SUPER, 230 * SUPER, 70 * SUPER, 8 * SUPER)
    d.rounded_rectangle([m, m, S - m, S - m], 210 * SUPER, outline=INK, width=14 * SUPER)
    out = im.resize((1024, 1024), Image.LANCZOS)
    temple = Image.open(ASSETS / "island/temple_pavilion.png").convert("RGBA")
    th = 560
    temple = temple.resize((round(temple.width * th / temple.height), th), Image.LANCZOS)
    out.alpha_composite(temple, ((1024 - temple.width) // 2, 820 - th))
    return out


def save(im, rel):
    path = ASSETS / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=False)
    print(path.relative_to(ROOT), im.size)


if __name__ == "__main__":
    import json
    save(wordmark(1600), "ui/title/wordmark.png")
    sheet, layout = wordmark_letters(1600)
    save(sheet, "ui/title/wordmark_letters.png")
    layout_path = ROOT / "project/data/title_wordmark.json"
    layout_path.write_text(json.dumps(layout, indent=2) + "\n")
    print(layout_path.relative_to(ROOT))
    save(title_screen(), "ui/title/title_screen.png")
    save(boot_splash(), "ui/brand/boot_splash.png")
    save(app_icon(), "ui/icon/app_icon.png")
