#!/usr/bin/env bash
# Generate placeholder sprites + backgrounds (pastel kawaii-ish blobs) with ImageMagick.
# These are stand-ins until the Track B NotebookLM/SD pipeline supplies canon art.
set -euo pipefail
OUT="$(dirname "$0")/../project/assets/placeholder"
mkdir -p "$OUT"

# ---------- character layers (24x32, transparent) ----------
SKIN='#ffdfc9'

# body_base: head + torso + eyes + blush
magick -size 24x32 xc:none \
  -fill "$SKIN" -draw 'roundrectangle 9,15 15,29 3,3' \
  -fill "$SKIN" -draw 'circle 12,10 12,3.5' \
  -fill '#3a2e2e' -draw 'circle 10,10 10,9.3' -draw 'circle 14,10 14,9.3' \
  -fill '#ffb3c1' -draw 'circle 8,12 8,11.4' -draw 'circle 16,12 16,11.4' \
  PNG32:"$OUT/body_base.png"

# No placeholder hair: the game wears canon hair (assets/canon/hair_*). hair_rose, hair_cocoa,
# hair_ink, dress_cream and the two backgrounds were removed 2026-11-05 (GC-11, d15.29): nothing
# in the game showed them.

dress() { # name color
  magick -size 24x32 xc:none \
    -fill "$2" -draw 'polygon 7,16 17,16 20,29 4,29' \
    -fill "$2" -draw 'circle 7,17 7,15.5' -draw 'circle 17,17 17,15.5' \
    PNG32:"$OUT/dress_$1.png"
}
dress teal '#7fd4c1'
dress rose '#f2a7c3'

# accessory: bow
magick -size 24x32 xc:none \
  -fill '#ff6fa5' -draw 'polygon 12,4 6,1 6,8' -draw 'polygon 12,4 18,1 18,8' \
  -fill '#e05585' -draw 'circle 12,4 12,2.6' \
  PNG32:"$OUT/acc_bow.png"

# ---------- NPC composites (24x32) ----------
# Devout Initiate: powder-blue dress, cocoa hair, white collar
magick -size 24x32 xc:none \
  -fill "$SKIN" -draw 'circle 12,10 12,3.5' \
  -fill '#9db8e8' -draw 'polygon 7,16 17,16 20,29 4,29' \
  -fill '#ffffff' -draw 'circle 12,17 12,15.8' \
  -fill '#8a5a3b' -draw 'ellipse 12,7 7.5,5.5 0,360' -draw 'roundrectangle 4,6 7,17 2,2' -draw 'roundrectangle 17,6 20,17 2,2' \
  -fill '#3a2e2e' -draw 'circle 10,10 10,9.3' -draw 'circle 14,10 14,9.3' \
  -fill '#ffb3c1' -draw 'circle 8,12 8,11.4' -draw 'circle 16,12 16,11.4' \
  PNG32:"$OUT/npc_initiate.png"

# Priestess/Mother: violet robe, ink hair, gold hat
magick -size 24x32 xc:none \
  -fill "$SKIN" -draw 'circle 12,11 12,4.5' \
  -fill '#b89ae0' -draw 'polygon 6,16 18,16 21,30 3,30' \
  -fill '#3a3a4a' -draw 'ellipse 12,8 7.5,5 0,360' \
  -fill '#e8c76a' -draw 'polygon 12,0 6,8 18,8' -draw 'circle 12,1 12,0.2' \
  -fill '#3a2e2e' -draw 'circle 10,11 10,10.3' -draw 'circle 14,11 14,10.3' \
  PNG32:"$OUT/npc_mother.png"

# Drone: green overalls + cap
magick -size 24x32 xc:none \
  -fill "$SKIN" -draw 'circle 12,10 12,3.5' -draw 'roundrectangle 9,15 15,29 3,3' \
  -fill '#9ccf8f' -draw 'polygon 8,18 16,18 17,29 7,29' -draw 'rectangle 9,15 10,19' -draw 'rectangle 14,15 15,19' \
  -fill '#6da05e' -draw 'ellipse 12,6 7,4 0,360' \
  -fill '#3a2e2e' -draw 'circle 10,10 10,9.3' -draw 'circle 14,10 14,9.3' \
  PNG32:"$OUT/npc_drone.png"

# Barren: grey wrap + kerchief
magick -size 24x32 xc:none \
  -fill "$SKIN" -draw 'circle 12,10 12,3.5' \
  -fill '#b8b3ad' -draw 'polygon 7,16 17,16 19,29 5,29' \
  -fill '#8f98a3' -draw 'ellipse 12,7 7.5,5.5 0,360' -draw 'polygon 12,12 19,6 19,12' \
  -fill '#3a2e2e' -draw 'circle 10,10 10,9.3' -draw 'circle 14,10 14,9.3' \
  PNG32:"$OUT/npc_barren.png"

# (The village mirror is drawn by tools/gen_village_props.py: project/assets/island/mirror.png.)

echo "Placeholder art written to $OUT"

# ---------- Tropical Florida Keys ----------
# Wearable crafted accessories (24x32, same frame as the other paper-doll layers)
magick -size 24x32 xc:none \
  -fill '#ff9ad0' -draw 'circle 5,5 5,2.5' -draw 'circle 9,3 9,0.5' -draw 'circle 15,3 15,0.5' -draw 'circle 19,5 19,2.5' \
  -fill '#ffe27a' -draw 'circle 12,2.5 12,1' \
  -fill '#7fd4a0' -draw 'circle 7,3 7,2' -draw 'circle 17,3 17,2' \
  PNG32:"$OUT/acc_flower_crown.png"
magick -size 24x32 xc:none \
  -fill '#7fd4a0' -draw 'roundrectangle 6,15 18,17 1,1' \
  -fill '#fff1e6' -draw 'ellipse 8,19 2,2.4 0,360' -draw 'ellipse 12,20 2,2.4 0,360' -draw 'ellipse 16,19 2,2.4 0,360' \
  -fill '#f7b6c8' -draw 'circle 12,20 12,19' \
  PNG32:"$OUT/acc_shell_garland.png"

# The Florida critters, people, garden items, ponies and maps are generated art, not
# placeholders: tools/gen_florida_art.py, gen_florida_cast.py, gen_florida_critters.py and
# gen_pony_sprites.py write them to project/assets/florida/.
