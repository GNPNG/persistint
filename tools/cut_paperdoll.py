"""Cut aligned paper-doll layers from the paper-doll sheets: the canon Gemini paper-doll sheet and
the Gemini wardrobe sheets (prompts/image/wardrobe/, staged in project/assets/sheets/wardrobe/).

Usage: python3 -I tools/cut_paperdoll.py [SHEET] [--sheet ID ...] [--parts FILE] [--out DIR]
  SHEET    the canon sheet, for the parts that name no sheet (default:
           dev/art/canon-gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg, the paper-doll sheet)
  --sheet  cut only the parts on this sheet (repeatable; "canon" is the canon sheet); every other
           part's PNG is left as it is. Default: every part on every sheet.
  --parts  the parts file (default project/data/paperdoll_parts.json)
  --out    where the PNGs go (default project/assets/canon)
Deterministic: with the versions in tools/requirements-art.txt it reproduces the committed PNGs.

The parts file: "parts" {name: {"crop": "WxH+X+Y", ...}}, each part on the canon sheet unless it
names one of the "sheets" with "sheet": id. "sheets" {id: {"path": the sheet keyed to white, from
the repo root; "doll": "WxH+X+Y"; optional "white_threshold"}}: a wardrobe sheet's "doll" is the
crop of the bald reference doll at its far left; every item on the sheet is drawn at her scale, at
the height of the part of her it belongs to.
Every layer is placed on one shared frame so the game can stack them at one origin. The canon
parts set the frame (the canvas that holds them all); a part from another sheet is placed on that
frame, measured against the cut body as it stands on it (body_base.png), and clipped to it, with a
warning when anything falls off. The part's prefix before the first underscore picks the rule (and
the PaperDoll slot it is worn in, SLOTS):
  - body: placed as drawn (canon sheet only: it sets the frame).
  - dress: drawn on the same baseline as the body; centered on the body, feet on feet.
  - hair: the face opening is measured, scaled to the body's face width, centered on the
    head and its bottom set on the chin.
  - acc, hat: scaled by "scale" and placed at "anchor" relative to the head.
  - top, bottom, shoes: scaled by the body's height over the reference doll's (head top to soles),
    at the height on the frame that matches where the item stands beside her on the sheet (her
    head top on the body's), centred on the body. On the canon sheet the body is the doll.
  Any part: "offset" [dx, dy] (frame px) moves it after placing.
White background and hair face openings become transparent.
Layers keep the sheet's resolution (the shared canvas is 721x760 px for the current sheet): no downscale, so
the doll stays smooth illustration. Code scales it to its display size (player.gd fits it to
48 world px tall; PaperDoll fits its rect).
Outputs: DIR/<part>.png for every part cut, all on the frame.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SHEET = ROOT / "dev/art/canon-gemini/Gemini_Generated_Image_ktfw47ktfw47ktfw.jpg"
CANON = "canon"  # the sheet of the parts that name none
## Part prefix -> the PaperDoll slot it is worn in (project/scripts/systems/paper_doll.gd LAYERS).
SLOTS = {"body": "body", "shoes": "shoes", "bottom": "bottom", "top": "top", "dress": "dress",
         "hair": "hair", "hat": "hat", "acc": "accessory"}
## Prefixes placed by the sheet's reference doll.
DOLL_PLACED = {"top", "bottom", "shoes"}


def cut(sheet, spec, white):
    """Crop WxH+X+Y; return RGBA with outside white cleared, plus the enclosed-white mask."""
    size, x, y = spec.split("+")
    w, h = map(int, size.split("x"))
    x, y = int(x), int(y)
    rgb = sheet[y:y + h, x:x + w]
    white_px = rgb.min(axis=2) > white
    lab, _ = ndimage.label(white_px)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    outside = np.isin(lab, edge[edge > 0])
    outside = ndimage.binary_dilation(outside, iterations=1) & (rgb.min(axis=2) > white - 40) | outside
    # Keep the drawing itself; drop small neighbours that fall inside the crop box.
    lab, n = ndimage.label(~outside)
    if n > 1:
        sizes = ndimage.sum(~outside, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * 0.1]
        outside |= ~np.isin(lab, keep)
    rgba = np.dstack([rgb, np.where(outside, 0, 255).astype(np.uint8)])
    enclosed = white_px & ~outside
    return rgba, enclosed


def crop_y(spec):
    return int(spec.split("+")[2])


def largest(mask):
    lab, n = ndimage.label(mask)
    if n == 0:
        return None
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    return lab == (int(np.argmax(sizes)) + 1)


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max(), ys.max()


def landmarks(solid, cfg):
    """The body's landmarks from its mask: head top, feet, neck, chin, head centre x, face width."""
    widths = solid.sum(axis=1)
    rows = np.arange(len(widths))
    top = rows[widths > 0][0]
    feet = rows[widths > 0][-1]
    # Chin: the narrowest row of the neck, below the head's widest point.
    head_rows = rows[top:top + int((feet - top) * 0.6)]
    neck = head_rows[np.argmax(widths[head_rows])] + np.argmin(widths[head_rows[np.argmax(widths[head_rows]):]])
    chin = neck - cfg.get("chin_above_neck", 8)
    face_row = top + int((chin - top) * 0.6)
    xs = np.where(solid[face_row])[0]
    head_cx = (xs.min() + xs.max()) / 2
    face_w = widths[top + int((chin - top) * 0.45)] * cfg.get("face_fill", 0.86)
    return {"top": top, "feet": feet, "neck": neck, "chin": chin, "head_cx": head_cx, "face_w": face_w,
            "body_cx": head_cx}


def place(name, part, rgba, enclosed, lm, cfg, doll):
    """The part scaled, and where its top-left corner goes (in lm's coordinates), by its prefix's
    rule. doll: the sheet's reference doll's head top and soles (sheet rows), for top/bottom/shoes."""
    kind = name.split("_")[0]
    scale, ox, oy = 1.0, 0.0, 0.0
    if kind == "body":
        pass
    elif kind == "dress":
        # Fit from just above the neck down to the feet, centered on the body.
        bx0, by0, bx1, by1 = bbox(rgba[:, :, 3] > 0)
        collar = lm["neck"] - part.get("collar", cfg.get("collar", 14))
        scale = (lm["feet"] - collar) / (by1 - by0)
        ox = lm["body_cx"] - (bx0 + bx1) / 2 * scale
        oy = collar - by0 * scale
    elif kind == "hair":
        hole = largest(enclosed)
        rgba[hole, 3] = 0
        hx0, hy0, hx1, hy1 = bbox(hole)
        scale = lm["face_w"] / (hx1 - hx0)
        ox = lm["head_cx"] - (hx0 + hx1) / 2 * scale
        oy = lm["chin"] - hy1 * scale
    elif kind in ("acc", "hat"):
        scale = part.get("scale", 1.0)
        ax, ay = part["anchor"]
        bx0, by0, bx1, by1 = bbox(rgba[:, :, 3] > 0)
        ox = lm["head_cx"] + ax - (bx0 + bx1) / 2 * scale
        oy = lm["top"] + ay - (by0 + by1) / 2 * scale
    elif kind in DOLL_PLACED:
        if doll is None:
            sys.exit(f"cut_paperdoll: {name}: its sheet has no \"doll\" (the reference doll's crop)")
        doll_top, doll_feet = doll
        scale = (lm["feet"] - lm["top"]) / (doll_feet - doll_top)
        bx0, _, bx1, _ = bbox(rgba[:, :, 3] > 0)
        ox = lm["body_cx"] - (bx0 + bx1) / 2 * scale
        oy = lm["top"] + (crop_y(part["crop"]) - doll_top) * scale
    else:
        sys.exit(f"cut_paperdoll: {name}: no rule for the prefix {kind!r} (one of {', '.join(SLOTS)})")
    if "offset" in part:
        ox += part["offset"][0]
        oy += part["offset"][1]
    img = Image.fromarray(rgba, "RGBA")
    if scale != 1.0:
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    return img, round(ox), round(oy)


def on_frame(name, img, x, y, size):
    """A frame-size canvas with `img` at (x, y), clipped to the frame (with a warning when it is)."""
    canvas = Image.new("RGBA", size)
    left, top = max(0, -x), max(0, -y)
    right, bottom = min(img.width, size[0] - x), min(img.height, size[1] - y)
    solid = np.asarray(img)[:, :, 3] > 0
    kept = int(solid[top:bottom, left:right].sum()) if right > left and bottom > top else 0
    if kept < int(solid.sum()):
        print(f"cut_paperdoll: {name}: {int(solid.sum()) - kept} px fall off the {size[0]}x{size[1]} frame",
              file=sys.stderr)
    if kept:
        canvas.alpha_composite(img.crop((left, top, right, bottom)), (x + left, y + top))
    return canvas


def main(argv=None):
    ap = argparse.ArgumentParser(description="Cut aligned paper-doll layers from the paper-doll sheets.")
    ap.add_argument("canon_sheet", nargs="?", default=str(DEFAULT_SHEET), metavar="SHEET")
    ap.add_argument("--sheet", action="append", dest="only", metavar="ID")
    ap.add_argument("--parts", default=str(ROOT / "project/data/paperdoll_parts.json"))
    ap.add_argument("--out", default=str(ROOT / "project/assets/canon"))
    a = ap.parse_args(argv)
    cfg = json.loads(Path(a.parts).read_text())
    out = Path(a.out)
    white = cfg.get("white_threshold", 232)
    sheets = cfg.get("sheets", {})
    parts = cfg["parts"]
    for name, part in parts.items():
        sid = part.get("sheet", CANON)
        if sid != CANON and sid not in sheets:
            sys.exit(f"cut_paperdoll: {name}: no sheet {sid!r} in \"sheets\"")
        if sid != CANON and name.split("_")[0] == "body":
            sys.exit(f"cut_paperdoll: {name}: a body sets the frame, so it is cut from the canon sheet")
    only = set(a.only) if a.only else None
    if only and only - set(sheets) - {CANON}:
        sys.exit(f"cut_paperdoll: no such sheet: {', '.join(sorted(only - set(sheets) - {CANON}))}")

    def chosen(sid):
        return only is None or sid in only

    out.mkdir(parents=True, exist_ok=True)
    if chosen(CANON):
        sheet = np.asarray(Image.open(a.canon_sheet).convert("RGB"))
        # Body landmarks.
        body_crop = parts["body_base"]["crop"]
        body, _ = cut(sheet, body_crop, white)
        lm = landmarks(body[:, :, 3] > 0, cfg)
        doll = (crop_y(body_crop) + lm["top"], crop_y(body_crop) + lm["feet"])
        layers = {}
        for name, part in parts.items():
            if part.get("sheet", CANON) == CANON:
                rgba, enclosed = cut(sheet, part["crop"], white)
                layers[name] = place(name, part, rgba, enclosed, lm, cfg, doll)
        # One canvas that holds every canon layer: the frame.
        x0 = min(ox for _, ox, _ in layers.values())
        y0 = min(oy for _, _, oy in layers.values())
        x1 = max(ox + im.width for im, ox, _ in layers.values())
        y1 = max(oy + im.height for im, _, oy in layers.values())
        frame_body = None
        for name, (img, ox, oy) in layers.items():
            canvas = Image.new("RGBA", (x1 - x0, y1 - y0))
            canvas.alpha_composite(img, (ox - x0, oy - y0))
            canvas.save(out / f"{name}.png")
            print(name, canvas.size)
            if name == "body_base":
                frame_body = canvas
    else:
        if not (out / "body_base.png").is_file():
            sys.exit(f"cut_paperdoll: {out / 'body_base.png'} is missing: cut the canon sheet first")
        frame_body = Image.open(out / "body_base.png").convert("RGBA")

    # The other sheets' parts, on the frame, measured against the body as it stands on it.
    todo = [sid for sid in sheets if chosen(sid) and any(p.get("sheet") == sid for p in parts.values())]
    if not todo:
        return
    lm = landmarks(np.asarray(frame_body)[:, :, 3] > 0, cfg)
    for sid in todo:
        spec = sheets[sid]
        sheet = np.asarray(Image.open(ROOT / spec["path"]).convert("RGB"))
        w = spec.get("white_threshold", white)
        doll = None
        if "doll" in spec:
            d, _ = cut(sheet, spec["doll"], w)
            rows = np.where((d[:, :, 3] > 0).any(axis=1))[0]
            doll = (crop_y(spec["doll"]) + rows[0], crop_y(spec["doll"]) + rows[-1])
        for name, part in parts.items():
            if part.get("sheet") != sid:
                continue
            rgba, enclosed = cut(sheet, part["crop"], w)
            img, ox, oy = place(name, part, rgba, enclosed, lm, cfg, doll)
            canvas = on_frame(name, img, ox, oy, frame_body.size)
            canvas.save(out / f"{name}.png")
            print(name, canvas.size)


if __name__ == "__main__":
    main()
