"""Build landed temple stills into the existing SpriteFrames strips (bd i3f2).

Run: python3 -I tools/build_temple_strips.py
Requires Pillow and ImageMagick. Sources stay unchanged. The candle flame mask
is measured on the 1254x1254 landed source; fail on other sizes for remeasurement.
Outputs: project/assets/temple/temple_twinkle.png and
project/assets/temple/temple_candles.png.
PNG provenance marks these derived strips so gen_temple_props cannot replace them.
"""
import hashlib
import io
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, PngImagePlugin

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "project/assets/sheets/temple"
OUT = ROOT / "project/assets/temple"
MARKER = "build_temple_strips.py/v1"
SCALES = (0.25, 0.6, 1.0, 0.75, 0.4, 0.0)


def keep_strip(path):
    """Only protect strips actually built by this tool, not stand-ins or missing files."""
    path = Path(path)
    if not path.exists():
        return False
    with Image.open(path) as im:
        return im.info.get("persistint_builder") == MARKER


def keyed(path):
    # Same 12% fuzz/despill recipe as .claude/skills/gemini-assets/SKILL.md.
    data = subprocess.check_output([
        "magick", str(path), "-alpha", "set", "-fuzz", "12%",
        "-transparent", "#00FF00", "-channel", "G", "-fx",
        "min(u.g,max(u.r,u.b))", "+channel", "PNG32:-"])
    return Image.open(io.BytesIO(data)).convert("RGBA")


def twinkle(im):
    im = im.crop(im.getbbox())
    strip = Image.new("RGBA", (288, 48))
    for i, scale in enumerate(SCALES):
        if not scale:
            continue
        # Four pixels of breathing room at the largest extent prevent edge clipping.
        factor = 44 * scale / max(im.size)
        frame = im.resize(tuple(max(1, round(n * factor)) for n in im.size), Image.Resampling.LANCZOS)
        frame.putalpha(frame.getchannel("A").point(lambda a: round(a * scale)))
        strip.alpha_composite(frame, (i * 48 + (48-frame.width)//2, (48-frame.height)//2))
    return strip


def candles(im):
    if im.size != (1254, 1254):
        raise ValueError("Candle source changed size; remeasure the flame mask")
    mask = Image.new("L", im.size)
    # Lower boundary follows the flame/wax join. The notch leaves the wick static.
    ImageDraw.Draw(mask).polygon([
        (520, 75), (720, 75), (720, 310), (678, 317), (640, 329),
        (638, 282), (608, 282), (606, 329), (563, 315), (520, 310)], fill=255)
    flame = im.copy()
    flame.putalpha(ImageChops.multiply(im.getchannel("A"), mask))
    body = im.copy()
    body.putalpha(ImageChops.subtract(im.getchannel("A"), flame.getchannel("A")))
    bounds = im.getbbox()
    factor = min(88 / (bounds[2]-bounds[0]), 156 / (bounds[3]-bounds[1]))
    size = tuple(round(n * factor) for n in im.size)
    body = body.resize(size, Image.Resampling.LANCZOS)
    # Source dish's bottom centre anchors to the requested file-pixel foot.
    x = round(48 - (bounds[0]+bounds[2]) / 2 * factor)
    y = round(168 - bounds[3] * factor)
    flame_bounds = flame.getbbox()
    flame = flame.crop(flame_bounds)
    pivot_x = (flame_bounds[0]+flame_bounds[2]) / 2
    pivot_y = flame_bounds[3]
    strip = Image.new("RGBA", (384, 176))
    for i, (sx, sy, dx) in enumerate(((1, 1, 0), (.94, 1.08, 1), (1.03, .92, -1), (.97, 1.04, 0))):
        frame = Image.new("RGBA", (96, 176))
        flicker = flame.resize((max(1, round(flame.width*factor*sx)),
                                max(1, round(flame.height*factor*sy))), Image.Resampling.LANCZOS)
        frame.alpha_composite(flicker, (round(x+pivot_x*factor-flicker.width/2)+dx,
                                       round(y+pivot_y*factor-flicker.height)))
        frame.alpha_composite(body, (x, y))  # the wick remains above the flame
        strip.alpha_composite(frame, (i*96, 0))
    return strip


def main():
    for name, build in (("temple_twinkle", twinkle), ("temple_candles", candles)):
        source = SOURCE / (name + ".png")
        result = build(keyed(source))
        meta = PngImagePlugin.PngInfo()
        meta.add_text("persistint_builder", MARKER)
        meta.add_text("source", str(source.relative_to(ROOT)))
        meta.add_text("source_sha256", hashlib.sha256(source.read_bytes()).hexdigest())
        result.save(OUT / (name + ".png"), pnginfo=meta)
        print(name, result.size)


if __name__ == "__main__":
    main()
