"""Rig the paper-doll player: one directional idle/walk sheet per paper-doll part, every sheet on
the same frame grid, so the game stacks body, dress, hair and accessory and steps them together.

Usage: python3 -I tools/gen_player_rig.py
       (after tools/cut_paperdoll.py and tools/gen_florida_wearables.py)
Inputs:
  project/assets/canon/{body,dress,hair,acc}_*.png   the canon paper-doll parts on their shared
                                                     721x760 frame (tools/cut_paperdoll.py)
  project/assets/florida/acc_*.png                   the crafted Florida wearables on that frame
  the canon body turnaround (front / side / back, sheet ekiw), cut at full resolution through
  tools/cut_island_props.py (project/data/florida_canon.json "bases")
Outputs: project/assets/characters/player/<part>_rig.png for every part
  frame   364x384 px (the 721x760 doll frame at 384/760; the doll is shown 48 world px tall, so
          8 px per world px), feet on the frame's bottom edge
  rows    0 down (front view), 1 left (side view, facing left; flip it for right), 2 up (back)
  columns 0-3 idle: a slow breath (squash 0 / 1 / 2 / 1 world px at the top, feet fixed)
          4-7 walk: tools/rig_walk.py's cycle (front and back lift the left then the right leg and
          that side of the hem; the side view swings legs and hem about the hip line; the body
          bobs up while passing)
How each view is made (canon art first; what canon lacks is derived from it, never invented):
  body    front: the canon paper-doll body; side and back: the canon body turnaround's side and
          back views, scaled to the doll's height, feet on its feet and head on its head
  hair    front: the canon part; back: the same hair with its face opening filled in the hair's
          own colour (the back of the head); side: that back hair narrowed to the side view's
          head width, with the face side (an ellipse over the left of the head, from the brow
          to the chin) opened again and edged in the canon outline colour
  dress   front and back: the canon part; side: narrowed to the side body's torso width and
          centred on it
  acc     front and back: the part as drawn; side: narrowed like the hair
The motion comes from the body's geometry, not from each layer, so the layers stay aligned.
Deterministic: no randomness.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))  # -I leaves tools/ off the path
import rig_walk  # noqa: E402
from cut_island_props import cut  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CANON = ROOT / "project/assets/canon"
FLORIDA = ROOT / "project/assets/florida"
OUT = ROOT / "project/assets/characters/player"
INK = (138, 90, 90, 255)
FRAME_H = 384
DOLL_WORLD_H = 48.0
IDLE_SQUASH = [0, 1, 2, 1]
VIEWS = ["front", "side", "back"]


def alpha(im):
    return np.asarray(im)[..., 3] > 128


def head_metrics(mask):
    """Top, feet, head centre x and head width of a standing figure mask (chibi: big head)."""
    rows = np.where(mask.any(axis=1))[0]
    top, feet = int(rows[0]), int(rows[-1])
    y = top + int((feet - top) * 0.22)
    xs = np.where(mask[y])[0]
    return top, feet, (xs[0] + xs[-1]) / 2.0, float(xs[-1] - xs[0])


def torso(mask, top, feet):
    y = top + int((feet - top) * 0.62)
    xs = np.where(mask[y])[0]
    return (xs[0] + xs[-1]) / 2.0, float(xs[-1] - xs[0])


def place_view(src, size, top, feet, head_cx):
    """A canon turnaround view scaled to the doll's height, feet on `feet`, head on head_cx."""
    m = alpha(src)
    st, sf, scx, _ = head_metrics(m)
    k = (feet - top) / float(sf - st)
    im = src.resize((round(src.width * k), round(src.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", size)
    out.alpha_composite(im, (round(head_cx - scx * k), round(feet - sf * k)))
    return out


def narrow(im, cx, ratio, new_cx=None):
    """The image squeezed horizontally by `ratio` about x = cx (moved to new_cx)."""
    new_cx = cx if new_cx is None else new_cx
    w = max(1, round(im.width * ratio))
    small = im.resize((w, im.height), Image.LANCZOS)
    out = Image.new("RGBA", im.size)
    x = round(new_cx - cx * ratio)
    out.alpha_composite(small.crop((max(0, -x), 0, w, im.height)), (max(0, x), 0))
    return out


def fill_face(hair):
    """The hair with its face opening (transparent and enclosed) filled in the hair's colour;
    returns the image and the opening's bounding box."""
    a = np.asarray(hair).copy()
    solid = a[..., 3] > 128
    lab, n = ndimage.label(~solid)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])))
    holes = [i for i in range(1, n + 1) if i not in edge]
    if not holes:
        return hair, None
    sizes = ndimage.sum(np.ones_like(lab), lab, holes)
    hole = lab == holes[int(np.argmax(sizes))]
    rgb = a[..., :3][solid].astype(int)
    bright = rgb[rgb.sum(axis=1) > 330]  # leave out the outline
    colour = np.median(bright if len(bright) else rgb, axis=0).astype(np.uint8)
    grown = ndimage.binary_dilation(hole, iterations=2) & ~solid | hole
    a[grown, :3] = colour
    a[grown, 3] = 255
    ys, xs = np.where(hole)
    return Image.fromarray(a, "RGBA"), (xs.min(), ys.min(), xs.max(), ys.max())


def open_face(hair, box, ink_w):
    """Clear the hair over the face of a left-facing head: the ellipse inscribed in `box`
    (x0, y0, x1, y1), with the new edge drawn in the canon outline colour."""
    a = np.asarray(hair).copy()
    x0, y0, x1, y1 = box
    yy, xx = np.mgrid[:a.shape[0], :a.shape[1]]
    face = ((xx - (x0 + x1) / 2) / ((x1 - x0) / 2)) ** 2 + ((yy - (y0 + y1) / 2) / ((y1 - y0) / 2)) ** 2 <= 1
    before = a[..., 3] > 128
    a[face, 3] = 0
    after = a[..., 3] > 128
    edge = after & ndimage.binary_dilation(face, iterations=ink_w) & before
    a[edge] = INK
    return Image.fromarray(a, "RGBA")


def parts():
    names = json.loads((ROOT / "project/data/paperdoll_parts.json").read_text())["parts"].keys()
    out = [(n, CANON / f"{n}.png") for n in names]
    out += [(p.stem, p) for p in sorted(FLORIDA.glob("acc_*.png"))]
    return out


def main():
    body = Image.open(CANON / "body_base.png").convert("RGBA")
    size = body.size
    top, feet, head_cx, head_w = head_metrics(alpha(body))
    side_body = place_view(cut(json.loads((ROOT / "project/data/florida_canon.json").read_text())["bases"]["body_side"]), size, top, feet, head_cx)
    back_body = place_view(cut(json.loads((ROOT / "project/data/florida_canon.json").read_text())["bases"]["body_back"]), size, top, feet, head_cx)
    _, _, side_cx, side_head_w = head_metrics(alpha(side_body))
    front_torso_cx, front_torso_w = torso(alpha(body), top, feet)
    side_torso_cx, side_torso_w = torso(alpha(side_body), top, feet)
    head_ratio = min(1.0, side_head_w / head_w)
    torso_ratio = min(1.0, side_torso_w / front_torso_w)

    k = FRAME_H / size[1]
    fw = round(size[0] * k)
    s = FRAME_H / DOLL_WORLD_H
    feet_f = round((feet + 1) * k)
    geo = rig_walk.geometry(round(top * k), min(FRAME_H - 1, feet_f), head_cx * k, s)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, path in parts():
        im = Image.open(path).convert("RGBA")
        kind = name.split("_")[0]
        if kind == "body":
            views = {"front": im, "side": side_body, "back": back_body}
        elif kind == "hair":
            back, hole = fill_face(im)
            side = narrow(back, head_cx, head_ratio, side_cx)
            if hole:
                hx0, hy0, hx1, hy1 = hole
                hw = (hx1 - hx0) * head_ratio
                hh = hy1 - hy0
                # the face side of the head, from the brow to below the chin, front edge past the head
                box = (round(side_cx - hw * 1.05), round(hy0 + hh * 0.30), round(side_cx + hw * 0.18), round(hy1 + hh * 0.25))
                side = open_face(side, box, max(2, round(size[1] / 160)))
            views = {"front": im, "side": side, "back": back}
        elif kind == "dress":
            views = {"front": im, "side": narrow(im, front_torso_cx, torso_ratio, side_torso_cx), "back": im}
        else:
            views = {"front": im, "side": narrow(im, head_cx, head_ratio, side_cx), "back": im}
        sheet = Image.new("RGBA", (fw * 8, FRAME_H * 3))
        for row, view in enumerate(VIEWS):
            still = views[view].resize((fw, FRAME_H), Image.LANCZOS)
            for i in range(4):
                sheet.alpha_composite(rig_walk.breathe(still, round(IDLE_SQUASH[i] * s), geo["feet"]), (i * fw, row * FRAME_H))
                sheet.alpha_composite(rig_walk.step(still, view, i, geo), ((4 + i) * fw, row * FRAME_H))
        sheet.save(OUT / f"{name}_rig.png", optimize=False)
        print(name, sheet.size)


if __name__ == "__main__":
    main()
