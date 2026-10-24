#!/usr/bin/env python3
"""Bake the paper-cut edge and the drop shadow into sprite sheets (persistint-game-1dx, gsd).

The overhead Paper Mario look is a light paper border around every cut-out and a soft shadow on
the ground under it. Doing that per frame on the client costs draw calls or shader taps on every
sprite, so this generator bakes it once, offline, into sibling sheets that cost exactly one draw
each in the game:

  <name>_edge<E>_<paper>.png   the art with an E world-px paper border baked in
  <name>_shadow_soft.png       the silhouette (border included) as a blurred black shadow, alpha 1;
  <name>_shadow_hard.png       the engine draws it under the sprite with its own offset and modulate
  <name>.json                  the new frame grid: frames are padded so the border and the shadow
                               never spill into the neighbouring frame

The grid stays uniform (cols x rows of equal frames), so RigSheet.frames() reads a baked rig sheet
unchanged; the sidecar says how much each frame grew (pad) and where the feet line moved to, which
SpriteFit needs to keep the character the same height. The border is slightly irregular (a smooth
noise field picks between two dilation radii) so it reads as cut paper rather than a vector stroke.

Several source layers (the player's body, dress, hair) can be composited first (--layers) when one
baked sheet for the whole figure is wanted; for the paper-doll player in the game the plan is a
per-part edge ring drawn under the stack instead (dilation distributes over union, so the union of
per-part rings is the ring of the composite).

Examples:
  tools/gen_paper_edges.py project/assets/characters/npc_mother_rig.png --cols 8 --rows 3 \
      --world-h 52 --feet 0.9615 --scale 4 --out project/assets/test/paper_look --name npc_mother
  tools/gen_paper_edges.py project/assets/canon/deco_tree_a.png --world-h 52 --scale 4 \
      --out project/assets/test/paper_look --name tree_a
"""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageFilter

PAPERS = {"white": (255, 253, 247), "cream": (255, 240, 210)}


def composite(paths: list[Path]) -> Image.Image:
    base = Image.open(paths[0]).convert("RGBA")
    for p in paths[1:]:
        layer = Image.open(p).convert("RGBA")
        if layer.size != base.size:
            raise SystemExit(f"{p}: size {layer.size} differs from {paths[0]} {base.size}")
        base = Image.alpha_composite(base, layer)
    return base


def frames_of(sheet: Image.Image, cols: int, rows: int) -> list[Image.Image]:
    fw, fh = sheet.width // cols, sheet.height // rows
    if fw * cols != sheet.width or fh * rows != sheet.height:
        raise SystemExit(f"sheet {sheet.size} does not divide into {cols}x{rows} frames")
    return [sheet.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh)) for r in range(rows) for c in range(cols)]


def dilate(alpha: Image.Image, radius: float) -> Image.Image:
    size = 2 * max(1, math.ceil(radius)) + 1
    return alpha.filter(ImageFilter.MaxFilter(size))


def cut_edge(alpha: Image.Image, radius: float, rng: random.Random) -> Image.Image:
    """The silhouette grown by about `radius` px, with a slow wobble so the border looks cut."""
    full = dilate(alpha, radius)
    small = dilate(alpha, max(1.0, radius * 0.6))
    w, h = alpha.size
    cells = (max(2, w // 6), max(2, h // 6))
    noise = Image.frombytes("L", cells, bytes(rng.randrange(256) for _ in range(cells[0] * cells[1])))
    noise = noise.resize((w, h), Image.BICUBIC).point(lambda v: 255 if v > 118 else 0)
    ring = Image.composite(full, small, noise)
    return ring.filter(ImageFilter.GaussianBlur(0.6))


def bake(args: argparse.Namespace) -> None:
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    sheet = composite([Path(p) for p in [args.sheet] + args.layers])
    cols, rows = args.cols, args.rows
    src_fw, src_fh = sheet.width // cols, sheet.height // rows
    src_scale = src_fh / args.world_h  # texture px per world px in the source
    scale = args.scale or src_scale
    k = scale / src_scale
    fw, fh = max(1, round(src_fw * k)), max(1, round(src_fh * k))
    frames = [f.resize((fw, fh), Image.LANCZOS) if (fw, fh) != f.size else f for f in frames_of(sheet, cols, rows)]
    max_edge = max(args.edges) * scale
    blur_soft = args.shadow_blur * scale
    pad = math.ceil(max_edge + blur_soft * 3) + 2
    pw, ph = fw + 2 * pad, fh + 2 * pad
    rng = random.Random(args.seed)
    rings: dict[int, list[Image.Image]] = {}
    for e in args.edges:
        rings[e] = []
        for f in frames:
            padded = Image.new("L", (pw, ph), 0)
            padded.paste(f.getchannel("A"), (pad, pad))
            rings[e].append(cut_edge(padded, e * scale, rng))
    written: dict[str, str] = {}
    for e in args.edges:
        for paper_name, rgb in PAPERS.items():
            if args.papers and paper_name not in args.papers:
                continue
            canvas = Image.new("RGBA", (pw * cols, ph * rows), (0, 0, 0, 0))
            for i, f in enumerate(frames):
                paper = Image.new("RGBA", (pw, ph), rgb + (255,))
                paper.putalpha(rings[e][i])
                art = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
                art.paste(f, (pad, pad))
                cell = Image.alpha_composite(paper, art)
                canvas.paste(cell, ((i % cols) * pw, (i // cols) * ph))
            name = f"{args.name}_edge{e}_{paper_name}.png"
            canvas.save(out / name, optimize=True)
            written[f"edge{e}_{paper_name}"] = name
    # Shadows: the widest silhouette (largest edge) so the shadow hugs the border, blurred or not.
    widest = rings[max(args.edges)]
    for kind, blur in (("soft", blur_soft), ("hard", 0.5)):
        canvas = Image.new("RGBA", (pw * cols, ph * rows), (0, 0, 0, 0))
        for i, ring in enumerate(widest):
            sh = Image.new("RGBA", (pw, ph), (0, 0, 0, 255))
            sh.putalpha(ring.filter(ImageFilter.GaussianBlur(blur)))
            canvas.paste(sh, ((i % cols) * pw, (i // cols) * ph))
        name = f"{args.name}_shadow_{kind}.png"
        canvas.save(out / name, optimize=True)
        written[f"shadow_{kind}"] = name
    feet = (pad + fh * args.feet) / ph
    side = {
        "source": [args.sheet] + args.layers, "cols": cols, "rows": rows,
        "src_frame": [src_fw, src_fh], "scaled_frame": [fw, fh], "frame": [pw, ph], "pad": pad,
        "scale": scale, "world_h": args.world_h, "feet": feet,
        "world_h_padded": args.world_h * ph / fh, "edges": args.edges, "files": written,
    }
    (out / f"{args.name}.json").write_text(json.dumps(side, indent=2) + "\n")
    print(f"{args.name}: {cols}x{rows} frames {src_fw}x{src_fh} -> {pw}x{ph} (pad {pad}, {scale:g} px/world px); {len(written)} sheets")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("sheet", help="source sheet (PNG, RGBA)")
    ap.add_argument("--layers", nargs="*", default=[], help="more sheets composited on top, in order")
    ap.add_argument("--cols", type=int, default=1)
    ap.add_argument("--rows", type=int, default=1)
    ap.add_argument("--world-h", type=float, required=True, help="height one frame is shown at, world px")
    ap.add_argument("--feet", type=float, default=1.0, help="feet line as a fraction of the source frame height")
    ap.add_argument("--scale", type=float, default=0.0, help="texture px per world px to bake at (0 = keep the source)")
    ap.add_argument("--edges", type=int, nargs="+", default=[1, 2, 3], help="border widths, world px")
    ap.add_argument("--papers", nargs="*", default=[], help="paper colours to bake (default: all of %s)" % ", ".join(PAPERS))
    ap.add_argument("--shadow-blur", type=float, default=1.5, help="soft shadow blur, world px")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--out", required=True)
    ap.add_argument("--name", required=True)
    bake(ap.parse_args())


if __name__ == "__main__":
    main()
