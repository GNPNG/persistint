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

hair() { # name color
  magick -size 24x32 xc:none \
    -fill "$2" -draw 'ellipse 12,7 7.5,5.5 0,360' \
    -fill "$2" -draw 'roundrectangle 4,6 7,17 2,2' \
    -fill "$2" -draw 'roundrectangle 17,6 20,17 2,2' \
    PNG32:"$OUT/hair_$1.png"
}
hair rose '#e88aa8'
hair cocoa '#8a5a3b'
hair ink '#3a3a4a'

dress() { # name color
  magick -size 24x32 xc:none \
    -fill "$2" -draw 'polygon 7,16 17,16 20,29 4,29' \
    -fill "$2" -draw 'circle 7,17 7,15.5' -draw 'circle 17,17 17,15.5' \
    PNG32:"$OUT/dress_$1.png"
}
dress teal '#7fd4c1'
dress cream '#f6ecd8'
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

# ---------- backgrounds (960x540) ----------
# Village: pastel green, temple plaza strip up top, paths, houses, garden, well, pond
magick -size 960x540 xc:'#cdecc0' \
  -fill '#f6e7ee' -draw 'rectangle 0,0 960,118' \
  -fill '#e8b7cd' -draw 'rectangle 0,118 960,130' \
  -fill '#e7d9b8' -draw 'roundrectangle 440,130 520,540 18,18' \
  -fill '#e7d9b8' -draw 'roundrectangle 120,300 840,360 18,18' \
  -fill '#d9a7e0' -draw 'polygon 415,118 545,118 530,50 430,50' \
  -fill '#fff6fa' -draw 'roundrectangle 448,80 512,118 6,6' \
  -fill '#f7e2c8' -draw 'roundrectangle 620,180 740,260 10,10' \
  -fill '#e89aae' -draw 'polygon 610,185 750,185 680,140' \
  -fill '#f7e2c8' -draw 'roundrectangle 200,380 320,460 10,10' \
  -fill '#9fc4e8' -draw 'polygon 190,385 330,385 260,340' \
  -fill '#b58c5f' -draw 'roundrectangle 100,170 260,290 12,12' \
  -fill '#a3d17e' -draw 'rectangle 112,190 248,206' -draw 'rectangle 112,222 248,238' -draw 'rectangle 112,254 248,270' \
  -fill '#b9c4cc' -draw 'circle 800,470 800,442' \
  -fill '#7d8b96' -draw 'circle 800,470 800,454' \
  -fill '#a9d8ef' -draw 'ellipse 120,500 90,40 0,360' \
  PNG24:"$OUT/bg_village.png"

# Temple: cream/rose interior, icon wall, O seal, altar, carpet, ritual table, ruins arch
magick -size 960x540 xc:'#f7ecf2' \
  -fill '#efd9e6' -draw 'rectangle 0,0 960,142' \
  -fill '#e3c1d8' -draw 'rectangle 0,142 960,150' \
  -fill '#fff8fb' -draw 'roundrectangle 60,0 100,150 8,8' -draw 'roundrectangle 300,0 340,150 8,8' -draw 'roundrectangle 620,0 660,150 8,8' -draw 'roundrectangle 860,0 900,150 8,8' \
  -fill '#f2a7c3' -draw 'roundrectangle 150,30 210,110 6,6' -draw 'roundrectangle 730,30 790,110 6,6' \
  -fill '#fff0f6' -draw 'roundrectangle 156,36 204,88 4,4' -draw 'roundrectangle 736,36 784,88 4,4' \
  -stroke '#d4788f' -strokewidth 12 -fill none -draw 'circle 480,72 480,30' \
  -stroke none -fill '#e8b7cd' -draw 'roundrectangle 440,150 520,540 16,16' \
  -fill '#e8c76a' -draw 'roundrectangle 420,170 540,230 10,10' \
  -fill '#c9a2e0' -draw 'roundrectangle 660,230 740,290 8,8' \
  -fill '#6f5f6e' -draw 'roundrectangle 110,180 170,262 12,12' \
  -fill '#57495a' -draw 'roundrectangle 118,190 162,254 8,8' \
  PNG24:"$OUT/bg_temple.png"

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

# Critters
magick -size 40x20 xc:none \
  -fill '#8fb8d8' -draw 'ellipse 18,11 15,6 0,360' -draw 'polygon 30,10 40,4 38,14' -draw 'polygon 14,6 20,0 22,7' \
  -fill '#e8f4fb' -draw 'ellipse 16,14 11,3 0,360' \
  -fill '#3a2e2e' -draw 'circle 8,9 8,8.2' \
  PNG32:"$OUT/dolphin.png"
magick -size 16x12 xc:none \
  -fill '#f08a6a' -draw 'ellipse 8,7 5,3.5 0,360' -draw 'circle 2,3 2,1.6' -draw 'circle 14,3 14,1.6' \
  -fill '#f08a6a' -draw 'rectangle 2,9 3,11' -draw 'rectangle 13,9 14,11' \
  -fill '#3a2e2e' -draw 'circle 6,5 6,4.4' -draw 'circle 10,5 10,4.4' \
  PNG32:"$OUT/crab.png"
magick -size 20x16 xc:none \
  -fill '#ffffff' -draw 'ellipse 9,9 6,4 0,360' -draw 'circle 15,6 15,3.4' \
  -fill '#b8c4d0' -draw 'polygon 4,8 0,4 7,6' \
  -fill '#ffc75a' -draw 'polygon 17,6 20,7 17,8' -draw 'rectangle 8,12 8,15' -draw 'rectangle 11,12 11,15' \
  -fill '#3a2e2e' -draw 'circle 15,5 15,4.5' \
  PNG32:"$OUT/gull.png"
magick -size 24x32 xc:none \
  -fill '#7fd4c1' -draw 'polygon 8,18 16,18 18,26 12,31 6,26' -draw 'polygon 12,28 4,32 10,24' -draw 'polygon 12,28 20,32 14,24' \
  -fill '#ffdfc9' -draw 'circle 12,11 12,5' -draw 'roundrectangle 9,15 15,20 2,2' \
  -fill '#b89ae0' -draw 'ellipse 12,7 7.5,5.5 0,360' -draw 'roundrectangle 4,6 7,19 2,2' -draw 'roundrectangle 17,6 20,19 2,2' \
  -fill '#3a2e2e' -draw 'circle 10,11 10,10.4' -draw 'circle 14,11 14,10.4' \
  PNG32:"$OUT/mermaid.png"

# Garden plots (empty soil / growing sprout / ready bloom), seed bag, craft bench, shell
plot_base() { # magick output spec
  magick -size 32x24 xc:none -fill '#a9794f' -draw 'roundrectangle 1,6 31,23 5,5' \
    -fill '#8a5f3c' -draw 'roundrectangle 4,9 28,20 4,4' "$@"
}
plot_base PNG32:"$OUT/plot_empty.png"
magick "$OUT/plot_empty.png" -fill '#7fd4a0' -draw 'polygon 16,16 11,7 16,11' -draw 'polygon 16,16 21,7 16,11' PNG32:"$OUT/plot_growing.png"
magick "$OUT/plot_empty.png" -fill '#7fd4a0' -draw 'rectangle 15,8 17,17' -fill '#ffffff' -draw 'circle 16,6 16,1.5' PNG32:"$OUT/plot_ready.png"
magick -size 20x24 xc:none -fill '#e8c76a' -draw 'roundrectangle 2,6 18,23 4,4' \
  -fill '#c9a14a' -draw 'rectangle 5,3 15,7' -fill '#fff8e0' -draw 'circle 10,15 10,11' PNG32:"$OUT/seed_bag.png"
magick -size 40x28 xc:none -fill '#c98f5a' -draw 'roundrectangle 1,8 39,27 3,3' \
  -fill '#e3b07a' -draw 'roundrectangle 0,4 40,11 3,3' \
  -fill '#7fd4c1' -draw 'circle 10,7 10,4' -fill '#ff9ad0' -draw 'circle 30,7 30,4' PNG32:"$OUT/craft_bench.png"
magick -size 10x10 xc:none -fill '#fff1e6' -draw 'ellipse 5,5 4,3.5 0,360' -fill '#f7b6c8' -draw 'circle 5,5 5,3.5' PNG32:"$OUT/shell.png"

# Beach: sea strip up top, sand, a pier, palm trunks
magick -size 960x540 xc:'#f6e6bd' \
  -fill '#8fd3e8' -draw 'rectangle 0,0 960,200' \
  -fill '#b6e6f2' -draw 'ellipse 200,60 140,22 0,360' -draw 'ellipse 700,110 160,26 0,360' \
  -fill '#fff6dc' -draw 'rectangle 0,200 960,214' \
  -fill '#e9d49b' -draw 'ellipse 480,400 220,70 0,360' \
  -fill '#b98a5a' -draw 'rectangle 60,120 80,330' -fill '#7fd4a0' -draw 'ellipse 70,110 48,20 0,360' \
  -fill '#b98a5a' -draw 'rectangle 880,130 900,340' -fill '#7fd4a0' -draw 'ellipse 890,120 48,20 0,360' \
  PNG24:"$OUT/bg_florida_beach.png"
# Garden: green yard under a pergola
magick -size 960x540 xc:'#c4eab0' \
  -fill '#a9dc92' -draw 'rectangle 0,0 960,150' \
  -fill '#f6e6bd' -draw 'rectangle 0,150 960,162' \
  -fill '#e3cfa0' -draw 'roundrectangle 330,170 630,520 20,20' \
  -fill '#ff9ad0' -draw 'circle 120,80 120,70' -draw 'circle 820,90 820,80' -draw 'circle 600,60 600,50' \
  PNG24:"$OUT/bg_florida_garden.png"
# Aquarium: deep tank wall with a lit stage
magick -size 960x540 xc:'#e3f3f8' \
  -fill '#6fc3dc' -draw 'roundrectangle 80,30 880,230 30,30' \
  -fill '#8fd3e8' -draw 'roundrectangle 100,50 860,210 24,24' \
  -fill '#fff6dc' -draw 'rectangle 0,250 960,262' \
  -fill '#f7e9f2' -draw 'rectangle 0,262 960,540' \
  -fill '#ffd8e8' -draw 'ellipse 480,420 200,60 0,360' \
  PNG24:"$OUT/bg_florida_aquarium.png"
