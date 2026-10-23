#!/usr/bin/env bash
# Cut caste NPC sprites (front/side/back) from the Gemini caste turnaround sheet.
# Usage: tools/cut_canon_sprites.sh /path/to/Gemini_Generated_Image_4bzs3l4bzs3l4bzs.jpg
# Boxes are the sheet's connected components (3 rows x 9 figures); output is
# project/assets/canon/<name>_<view>.png at 48 px tall, background removed.
set -euo pipefail
SHEET="$1"
OUT="$(dirname "$0")/../project/assets/canon"
H=48
mkdir -p "$OUT"

cut() {  # name view WxH+X+Y
	magick "$SHEET" -crop "$3" +repage -bordercolor 'srgb(253,246,227)' -border 6 \
		-alpha set -fuzz 10% -fill none -draw 'color 0,0 floodfill' -trim +repage \
		-resize "x$H" -strip "$OUT/$1_$2.png"
}

# name           front               side                back
cut npc_mother    front 261x442+88+58;   cut npc_mother    side 210x443+407+56;   cut npc_mother    back 250x442+653+58
cut npc_priestess front 216x438+1004+60; cut npc_priestess side 207x439+1304+59;  cut npc_priestess back 224x441+1565+60
cut npc_initiate  front 226x441+1001+556; cut npc_initiate side 194x440+1300+558; cut npc_initiate  back 227x440+1562+557
cut npc_drone     front 208x459+1903+547; cut npc_drone    side 208x455+2171+551; cut npc_drone     back 207x455+2445+548
cut npc_barren    front 265x442+1903+1058; cut npc_barren  side 236x441+2180+1061; cut npc_barren   back 263x441+2404+1059

# The game loads <name>.png; the front view is the default.
for n in npc_mother npc_priestess npc_initiate npc_drone npc_barren; do
	cp "$OUT/${n}_front.png" "$OUT/$n.png"
done
