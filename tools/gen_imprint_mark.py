"""Render the GNPNG Ping Pong imprint mark (the publisher's colophon for its games) for the engine.

Usage: python3 -I tools/gen_imprint_mark.py   (needs rsvg-convert from librsvg on PATH)

Inputs:
  art/brand/gnpng-pingpong.svg        the author's mark, verbatim from site/public/img/: the
                                      letters G P G, two paddles and a gold ball that rally
                                      (SMIL <animate>, 3 s loop), a rule, PING PONG, and
                                      "an imprint of GNPNG"
  art/brand/fonts/EBGaramond-VF.ttf   EB Garamond (SIL OFL, art/brand/fonts/OFL.txt), the face the
                                      SVG names; a private fontconfig file points rsvg at this
                                      file only, so the render does not depend on system fonts

Outputs (transparent background; the cream plate behind the mark is theme chrome, the
ImprintPlate StyleBox in project/themes/default.tres):
  project/assets/ui/brand/gnpng_pingpong.png
      still, 1008x632 (4x the SVG viewBox 252x158), the rally at t = 0 (ball on the left paddle);
      the boot splash (project.godot application/boot_splash/image)
  project/assets/ui/brand/gnpng_pingpong_sheet.png
      the rally as a sprite sheet, read by project/scripts/ui/imprint_mark.gd into SpriteFrames:
        frame size 504x316 (2x the viewBox), 6 columns x 6 rows, 36 frames, row-major,
        one animation "idle" (the rally), 12 fps, looping; frame i is the SVG at t = i / 12 s

Each frame is the SVG with every <animate> evaluated at its time (values evenly spaced over dur,
linear, as SMIL does without keyTimes), rendered by rsvg-convert at 4x the output size and
downscaled with LANCZOS. No randomness; the output is the same on every run with the same librsvg
and font.
"""
import copy
import io
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SVG = ROOT / "art/brand/gnpng-pingpong.svg"
FONT_DIR = ROOT / "art/brand/fonts"
OUT = ROOT / "project/assets/ui/brand"

NS = "http://www.w3.org/2000/svg"
VIEW_W, VIEW_H = 252, 158
FPS = 12
LOOP_S = 3.0                      # the longest dur in the SVG; the 1.5 s ball x loop fits twice
FRAMES = int(FPS * LOOP_S)        # 36
COLS = 6
FRAME_W, FRAME_H = VIEW_W * 2, VIEW_H * 2
STILL_W, STILL_H = VIEW_W * 4, VIEW_H * 4
SUPER = 4                         # render at SUPER x the output size, then downscale

ET.register_namespace("", NS)


def _seconds(dur: str) -> float:
    return float(dur[:-2]) / 1000.0 if dur.endswith("ms") else float(dur.rstrip("s"))


def _value_at(values: list[float], dur: float, t: float) -> float:
    """SMIL linear interpolation over evenly spaced values, repeating every dur seconds."""
    u = (t % dur) / dur * (len(values) - 1)
    i = min(int(u), len(values) - 2)
    f = u - i
    return values[i] + (values[i + 1] - values[i]) * f


def frame_svg(tree: ET.ElementTree, t: float) -> bytes:
    """The SVG with each <animate> applied at time t and then removed."""
    root = copy.deepcopy(tree.getroot())
    for parent in root.iter():
        for anim in list(parent.findall(f"{{{NS}}}animate")):
            values = [float(v) for v in anim.get("values").split(";")]
            v = _value_at(values, _seconds(anim.get("dur")), t)
            parent.set(anim.get("attributeName"), f"{v:.4f}")
            parent.remove(anim)
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def render(svg: bytes, w: int, h: int, env: dict) -> Image.Image:
    png = subprocess.run(
        ["rsvg-convert", "-w", str(w * SUPER), "-h", str(h * SUPER), "-f", "png"],
        input=svg, capture_output=True, check=True, env=env).stdout
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    return im.resize((w, h), Image.LANCZOS)


def save(im: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    im.save(path, optimize=False)
    print(path.relative_to(ROOT), im.size)


def main() -> None:
    if shutil.which("rsvg-convert") is None:
        sys.exit("rsvg-convert not found (install librsvg)")
    tree = ET.parse(SVG)
    with tempfile.TemporaryDirectory() as tmp:
        conf = Path(tmp) / "fonts.conf"
        conf.write_text(
            '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd"><fontconfig>'
            f"<dir>{FONT_DIR}</dir><cachedir>{tmp}/cache</cachedir></fontconfig>")
        env = dict(os.environ, FONTCONFIG_FILE=str(conf))

        save(render(frame_svg(tree, 0.0), STILL_W, STILL_H, env), "gnpng_pingpong.png")

        rows = (FRAMES + COLS - 1) // COLS
        sheet = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * rows), (0, 0, 0, 0))
        for i in range(FRAMES):
            im = render(frame_svg(tree, i / FPS), FRAME_W, FRAME_H, env)
            sheet.paste(im, ((i % COLS) * FRAME_W, (i // COLS) * FRAME_H))
        save(sheet, "gnpng_pingpong_sheet.png")


if __name__ == "__main__":
    main()
