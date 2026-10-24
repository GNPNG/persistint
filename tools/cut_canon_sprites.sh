#!/usr/bin/env bash
# Cut canon sprites from the author's Gemini sheets at their source resolution.
#
# Usage: tools/cut_canon_sprites.sh [caste_sheet.jpg]
#   (default sheet: dev/art/canon-gemini/Gemini_Generated_Image_4bzs3l4bzs3l4bzs.jpg)
# Inputs:
#   dev/art/canon-gemini/Gemini_Generated_Image_4bzs*.jpg  caste turnaround sheet; boxes are the
#                                                      sheet's connected components
#                                                      (3 rows x 9 figures, ~440 px tall)
#   dev/art/canon-gemini/Gemini_Generated_Image_481b*.jpg  forbidden-instruments sheet
# Outputs (project/assets/canon/):
#   npc_<caste>_<view>.png  caste NPCs, views front/side/back; npc_<caste>.png is the front view
#   prop_scroll.png         the tide/moon scroll (a Forbidden Knowledge pickup in the ruins)
# Each cut is crop + background removal (flood fill from the border) + trim, nothing else:
# no resize, so the sprite keeps the sheet's full resolution and the game scales it to its
# display size with smooth (mipmapped) filtering. Deterministic: same sheet, same PNGs (with
# ImageMagick 7.1.2-31 and the versions in tools/requirements-art.txt).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASTES="${1:-$(ls "$ROOT"/dev/art/canon-gemini/Gemini_Generated_Image_4bzs*.jpg)}"
INSTRUMENTS="$(ls "$ROOT"/dev/art/canon-gemini/Gemini_Generated_Image_481b*.jpg)"
OUT="$ROOT/project/assets/canon"
mkdir -p "$OUT"

cut() {  # sheet out_name WxH+X+Y background fuzz%
	magick "$1" -crop "$3" +repage -bordercolor "$4" -border 6 \
		-alpha set -fuzz "$5%" -fill none -draw 'color 0,0 floodfill' -trim +repage \
		-define png:exclude-chunks=date,time -strip "$OUT/$2.png"
}

npc() {  # name view WxH+X+Y   (the caste sheet's cream ground)
	cut "$CASTES" "$1_$2" "$3" 'srgb(253,246,227)' 10
}

# name           front               side                back
npc npc_mother    front 261x442+88+58;   npc npc_mother    side 210x443+407+56;   npc npc_mother    back 250x442+653+58
npc npc_priestess front 216x438+1004+60; npc npc_priestess side 207x439+1304+59;  npc npc_priestess back 224x441+1565+60
npc npc_initiate  front 226x441+1001+556; npc npc_initiate side 194x440+1300+558; npc npc_initiate  back 227x440+1562+557
npc npc_drone     front 208x459+1903+547; npc npc_drone    side 208x455+2171+551; npc npc_drone     back 207x455+2445+548
npc npc_barren    front 265x442+1903+1058; npc npc_barren  side 236x441+2180+1061; npc npc_barren   back 263x441+2404+1059

# The game loads <name>.png; the front view is the default.
for n in npc_mother npc_priestess npc_initiate npc_drone npc_barren; do
	cp "$OUT/${n}_front.png" "$OUT/$n.png"
done

# Forbidden instruments (white ground).
cut "$INSTRUMENTS" prop_scroll 820x680+1850+765 white 8
