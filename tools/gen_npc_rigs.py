"""Rig the canon caste NPCs: pack each caste's front/side/back cut into a sprite sheet.

Usage: python3 -I tools/gen_npc_rigs.py   (run after tools/cut_canon_sprites.sh)
Inputs:  project/assets/canon/npc_<caste>_{front,side,back}.png (canon cuts at the caste
         sheet's own resolution, about 440 px tall; the side view faces left)
Outputs: project/assets/characters/npc_<caste>_rig.png for caste in CASTES

Sheet layout (scripts/npc.gd builds its SpriteFrames from it and reads the frame size from the
sheet: width / 8, height / 3):
  frame   32x52 world px, stored at the cuts' resolution: s = (tallest cut of the caste) / 48,
          frame = round(32 s) x round(52 s) file px; the figure stands centred with its feet
          on y round(50 s) (npc.gd: feet = frame height * 50 / 52), shown 52 world px tall
  rows    0 down (front view), 1 left (side view; flip it for right), 2 up (back view)
  columns 0-3 idle: a slow breath, the figure squashes 0 / 1 / 2 / 1 world px at the top,
          feet fixed
          4-7 walk: a step bob, up 0 / 2 / 0 / 2 world px, leaning a little into the stride
The canon art is used as cut, at full resolution: only the breath squash resamples it (LANCZOS);
nothing is redrawn, and the game downsamples the sheet smoothly (mipmaps) to its display size.
Deterministic: the same cuts give the same sheets.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "project/assets/canon"
OUT = ROOT / "project/assets/characters"
CASTES = ["priestess", "mother", "initiate", "drone", "barren"]
VIEWS = ["front", "side", "back"]
FIG_H, FW, FH, FEET = 48, 32, 52, 50   # world px: figure height, frame, feet line
IDLE_SQUASH = [0, 1, 2, 1]
WALK_BOB = [0, 2, 0, 2]
WALK_LEAN = [0, 1, 0, -1]
MIN_CUT_H = 4 * FIG_H   # cuts shorter than this are the old 48 px shrink, not source resolution


def rig(caste):
    figs = [Image.open(SRC / f"npc_{caste}_{view}.png").convert("RGBA") for view in VIEWS]
    s = max(f.height for f in figs) / FIG_H
    if max(f.height for f in figs) < MIN_CUT_H:
        raise SystemExit(f"npc_{caste} cuts are {max(f.height for f in figs)} px tall, not the canon "
                         f"sheet's resolution (at least {MIN_CUT_H} px); re-run tools/cut_canon_sprites.sh "
                         "from a checkout where it keeps the source resolution, then this script")
    fw, fh, feet = round(FW * s), round(FH * s), round(FEET * s)
    sheet = Image.new("RGBA", (fw * 8, fh * 3))

    def place(fig, col, row, squash=0.0, bob=0.0, shift=0.0):
        h = fig.height - round(squash * s)
        f = fig if h == fig.height else fig.resize((fig.width, h), Image.LANCZOS)
        x = col * fw + (fw - f.width) // 2 + round(shift * s)
        y = row * fh + feet - h - round(bob * s)
        sheet.alpha_composite(f, (x, y))

    for row, (view, fig) in enumerate(zip(VIEWS, figs)):
        for i in range(4):
            place(fig, i, row, squash=IDLE_SQUASH[i])
            place(fig, 4 + i, row, bob=WALK_BOB[i], shift=WALK_LEAN[i] if view == "side" else 0)
    return sheet


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for caste in CASTES:
        sh = rig(caste)
        sh.save(OUT / f"npc_{caste}_rig.png")
        print(caste, sh.size)


if __name__ == "__main__":
    main()
