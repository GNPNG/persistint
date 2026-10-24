"""Shared rig motion for the character sheet generators (tools/gen_npc_rigs.py,
tools/gen_player_rig.py): the idle breath and a four-frame walk cycle derived from one still
drawing of a figure (a canon front, side or back view).

Every function takes a frame-sized RGBA image (the figure, or one paper-doll layer of it, drawn
in the frame) and the figure's geometry in that frame, and returns a new frame-sized image. The
geometry, not the layer's own pixels, decides the motion, so every layer of a paper doll moves
exactly alike and the stacked layers never drift apart.

  breathe(im, squash, feet)          idle: the figure squashes `squash` px at the top, feet fixed
  step(im, view, i, geo)             walk frame i (0-3) of the cycle
      front / back views: the lower band (hips to feet) splits down the middle; frame 0 lifts the
      left leg (and that side of a hem), frame 2 the right; frames 1 and 3 pass with both feet
      down and the whole figure bobbed up
      side view: the lower band shears forward and back about the hip line (the stride: legs or
      hem swing), frames 0 and 2 opposite, 1 and 3 passing and bobbed up
geo: dict with "top", "hip", "feet" (y) and "cx" (x) in frame px and "s" (frame px per world px).
Deterministic: no randomness.
"""
import numpy as np
from PIL import Image

HIP = 0.80        # the hip line, as a fraction of the figure's height from its top
LIFT = 2.0        # world px a stepping foot rises (front / back)
STRIDE = 2.5      # world px the feet swing forward and back (side)
BOB = 1.0         # world px the body rises while passing


def geometry(top, feet, cx, s):
    """The geometry dict for a figure standing from `top` to `feet` around x = cx."""
    return {"top": top, "hip": round(top + (feet - top) * HIP), "feet": feet, "cx": cx, "s": s}


def breathe(im, squash, feet):
    """The figure (everything above `feet`) squashed `squash` px shorter, feet where they were."""
    if squash <= 0:
        return im.copy()
    top = im.crop((0, 0, im.width, feet))
    h = feet - squash
    out = Image.new("RGBA", im.size)
    out.alpha_composite(top.resize((im.width, h), Image.LANCZOS), (0, squash))
    out.alpha_composite(im.crop((0, feet, im.width, im.height)), (0, feet))
    return out


def _shift_up(a, rows, x0, x1, dy):
    """Move the pixels of a[rows, x0:x1] up by dy rows (over what is above, leaving the vacated
    bottom rows clear)."""
    if dy <= 0:
        return
    y0, y1 = rows
    block = a[y0:y1, x0:x1].copy()
    a[y0:y1, x0:x1] = 0
    dst = a[y0 - dy:y1 - dy, x0:x1]
    alpha = block[..., 3:4].astype(np.float32) / 255.0
    dst[:] = (block * alpha + dst * (1.0 - alpha)).astype(np.uint8)


def step(im, view, i, geo):
    """Walk frame i (0-3) of `im` (frame-sized RGBA) for a figure seen from `view`."""
    s = geo["s"]
    hip, feet, cx = geo["hip"], geo["feet"], int(round(geo["cx"]))
    a = np.asarray(im.convert("RGBA")).copy()
    h, w = a.shape[:2]
    bottom = min(h, feet + 2)
    if view == "side":
        phase = (1, 0, -1, 0)[i]
        if phase:
            out = a.copy()
            out[hip:bottom] = 0
            span = max(1, feet - hip)
            for y in range(hip, bottom):
                dx = int(round(phase * STRIDE * s * min(1.0, (y - hip) / span)))
                row = a[y]
                if dx > 0:
                    out[y, dx:] = row[:w - dx]
                elif dx < 0:
                    out[y, :w + dx] = row[-dx:]
                else:
                    out[y] = row
            a = out
    else:
        lift = int(round(LIFT * s))
        if i == 0:
            _shift_up(a, (hip, bottom), 0, cx, lift)
        elif i == 2:
            _shift_up(a, (hip, bottom), cx, w, lift)
    out = Image.fromarray(a, "RGBA")
    if i in (1, 3):
        bob = int(round(BOB * s))
        moved = Image.new("RGBA", out.size)
        moved.alpha_composite(out.crop((0, bob, w, h)), (0, 0))
        out = moved
    return out
