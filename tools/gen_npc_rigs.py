"""Rig the canon caste NPCs: pack each caste's front/side/back cut into a sprite sheet.

Usage: python3 -I tools/gen_npc_rigs.py   (run after tools/cut_canon_sprites.sh)
Inputs:  project/assets/canon/npc_<caste>_{front,side,back}.png (canon cuts, 48 px tall;
         the side view faces left)
Outputs: project/assets/characters/npc_<caste>_rig.png for caste in CASTES

Sheet layout (scripts/npc.gd builds its SpriteFrames from it):
  frame 32x52; the figure stands centred with its feet on y 50
  rows    0 down (front view), 1 left (side view; flip it for right), 2 up (back view)
  columns 0-3 idle: a slow breath, the figure squashes 0 / 1 / 2 / 1 px at the top, feet fixed
          4-7 walk: a step bob, up 0 / 2 / 0 / 2 px, leaning a little into the stride
The canon art is used as cut; only its height changes (LANCZOS), nothing is redrawn.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "project/assets/canon"
OUT = ROOT / "project/assets/characters"
CASTES = ["priestess", "mother", "initiate", "drone", "barren"]
FW, FH, FEET = 32, 52, 50
VIEWS = ["front", "side", "back"]
IDLE_SQUASH = [0, 1, 2, 1]
WALK_BOB = [0, 2, 0, 2]
WALK_LEAN = [0, 1, 0, -1]


def place(sheet, fig, col, row, squash=0, bob=0, shift=0):
    h = fig.height - squash
    f = fig if squash == 0 else fig.resize((fig.width, h), Image.LANCZOS)
    x = col * FW + (FW - f.width) // 2 + shift
    y = row * FH + FEET - h - bob
    sheet.alpha_composite(f, (x, y))


def rig(caste):
    sheet = Image.new("RGBA", (FW * 8, FH * 3))
    for row, view in enumerate(VIEWS):
        fig = Image.open(SRC / f"npc_{caste}_{view}.png").convert("RGBA")
        for i in range(4):
            place(sheet, fig, i, row, squash=IDLE_SQUASH[i])
            place(sheet, fig, 4 + i, row, bob=WALK_BOB[i], shift=WALK_LEAN[i] if view == "side" else 0)
    return sheet


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for caste in CASTES:
        rig(caste).save(OUT / f"npc_{caste}_rig.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
