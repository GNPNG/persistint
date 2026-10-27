#!/usr/bin/env bash
# Bake the paper look (bd gsd, 1dx) for every world sprite of the main maps into
# project/assets/paper/: per subject, the art with a 2 world-px white cut-paper border
# (<name>_edge2_white.png), or for the paper-doll player's parts the border alone
# (<name>_ring2_white.png, drawn under the art stack), a soft drop shadow
# (<name>_shadow_soft.png) and the sidecar <name>.json (frame grid, padding, feet line).
# The work is done by tools/gen_paper_edges.mjs (ImageMagick 7); the game reads the sheets
# through scripts/util/paper_bake.gd (PaperBake), so nothing is drawn per frame.
#
# Bake scale: the source's own resolution, capped at 6 texture px per world px (at the
# biggest size a subject is shown; the window shows 4 to 6 screen px per world px), so the
# baked art is never coarser than the screen.
#
# Usage: tools/bake_paper.sh [characters|greenery|props|florida|ruins|all]   (default all)
# Then: godot --headless --path project --import; node tools/set_texture_imports.mjs;
# node tools/gen_sources.mjs; for greenery and props, rebuild the maps (tools/build_island_maps.gd).
# Florida and ruins need no rebuild: their maps dress the art when they load (PaperBake.dress:
# map.gd paper_props, the Florida pickups, scripts/ruins/ruins_decor.gd).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
A=project/assets
OUT=project/assets/paper
GROUP="${1:-all}"
MAGICK="${MAGICK:-magick}"

bake() {  # bake SHEET NAME WORLD_H [more gen_paper_edges options]
  local sheet="$1" name="$2" h="$3"
  shift 3
  node tools/gen_paper_edges.mjs "$sheet" --world-h "$h" --edges 2 --papers white --max-scale 6 \
    --out "$OUT" --name "$name" "$@" < /dev/null
}

px_h() {  # px_h SHEET TEXELS: the sheet's height in world px, drawn at TEXELS texture px per world px
  awk -v h="$("$MAGICK" identify -format '%h' "$1")" -v t="$2" 'BEGIN { printf "%g", h / t }'
}

if [[ $GROUP == characters || $GROUP == all ]]; then
  # Caste rigs (tools/gen_npc_rigs.py): 8 columns x 3 rows, 52 world px, feet at 50/52.
  for c in barren drone initiate mother priestess; do
    bake "$A/characters/npc_${c}_rig.png" "npc_${c}_rig" 52 --cols 8 --rows 3 --feet 0.9615384615384616 \
      --outputs edge shadow_soft
  done
  # Player paper-doll parts (tools/gen_player_rig.py): 8 x 3 frames, 48 world px, feet on the
  # bottom edge. The border alone for every part; the shadow once, from the body.
  for part in body_base dress_white dress_robe dress_uniform hair_braids hair_crown hair_pigtails hair_short \
      acc_bow acc_bougainvillea_wreath acc_flower_crown acc_plumeria_lei acc_shell_garland; do
    outs=(ring)
    [[ $part == body_base ]] && outs+=(shadow_soft)
    bake "$A/characters/player/${part}_rig.png" "${part}_rig" 48 --cols 8 --rows 3 --outputs "${outs[@]}"
  done
fi

if [[ $GROUP == greenery || $GROUP == all ]]; then
  # Trees and flowers (tools/gen_island_deco.py, cut_canon_sprites.sh), feet on the bottom edge.
  for t in deco_tree_a deco_tree_b deco_tree_c; do
    bake "$A/canon/$t.png" "$t" 52 --outputs edge shadow_soft
  done
  bake "$A/canon/deco_flowers.png" deco_flowers 22 --outputs edge shadow_soft
fi

if [[ $GROUP == props || $GROUP == all ]]; then
  # Map props at the biggest height each is shown on the village and temple maps (world px).
  # Not baked: temple_shadow (it is a shadow), deco_heart and deco_sparkle (14 px effects),
  # the animated temple candles and twinkle.
  while read -r path name h; do
    bake "$A/$path" "$name" "$h" --outputs edge shadow_soft
  done <<'EOF'
canon/prop_bunker.png prop_bunker 114
canon/prop_fence_a.png prop_fence_a 34
canon/prop_fence_b.png prop_fence_b 34
canon/prop_sign_a.png prop_sign_a 48
canon/prop_sign_b.png prop_sign_b 48
canon/prop_tag_x.png prop_tag_x 36
canon/prop_icon_queen_mother.png prop_icon_queen_mother 72
canon/prop_seal_o.png prop_seal_o 36
canon/prop_ship.png prop_ship 150
canon/prop_calendar.png prop_calendar 40
canon/prop_pillar_orb.png prop_pillar_orb 64
canon/prop_skull_altar.png prop_skull_altar 48
island/temple_pavilion.png temple_pavilion 140
island/mirror.png mirror 40
temple/temple_plinth.png temple_plinth 14
temple/temple_urn.png temple_urn 36
temple/temple_cushion.png temple_cushion 20
EOF
fi

if [[ $GROUP == florida || $GROUP == all ]]; then
  # The Florida maps (beach, garden, stable, aquarium): their props, the craft bench, the seed bag
  # and every garden plot stage (tools/gen_florida_art.py; drawn at 4 texture px per world px and
  # shown at 0.25, feet on the bottom edge) at their own height / 4; the canon shells at
  # ShellPickup.HEIGHT (11). Not baked: the backgrounds (ground art) and the animated sea foam;
  # the critters, the aquarium fish and the Florida NPC sheets are still to come.
  for p in prop_aquarium prop_barn prop_bench prop_birdbath prop_bush_bougainvillea prop_bush_hibiscus \
      prop_dune_grass prop_fence_paddock prop_fence_picket prop_garden_arch prop_hay prop_house \
      prop_palm_a prop_palm_b prop_palm_potted prop_rowboat prop_sandcastle prop_sign_stable \
      prop_tree_key_lime prop_tree_mango prop_trough prop_umbrella craft_bench seed_bag; do
    bake "$A/florida/$p.png" "$p" "$(px_h "$A/florida/$p.png" 4)" --outputs edge shadow_soft
  done
  for src in "$A"/florida/plot_*.png; do
    bake "$src" "$(basename "$src" .png)" "$(px_h "$src" 4)" --outputs edge shadow_soft
  done
  for s in scallop spiral conch; do
    bake "$A/florida/shell_$s.png" "shell_$s" 11 --outputs edge shadow_soft
  done
fi

if [[ $GROUP == ruins || $GROUP == all ]]; then
  # The ruins rooms (data/ruins.json "rooms"; tools/gen_ruins_art.py): every prop that stands or
  # hangs on the wall, at its own height / 8 (RuinsDecor.TEXELS), so at most 6 texture px per
  # world px, and the two animated tanks as their 4-frame strips (RuinsDecor.ANIMATED). Not baked:
  # "floor" props, painted flat on the floor like temple_shadow; a canon cut (none stands here).
  jq -r '[.rooms[].props[]? | select((.place // "") != "floor") | .kind] | unique | .[]' project/data/ruins.json |
  while read -r kind; do
    src="$A/ruins/$kind.png"
    if [[ ! -f $src ]]; then
      echo "bake_paper: $kind has no $src (a canon cut?); not baked" >&2
      continue
    fi
    cols=1
    [[ $kind == ruins_tank || $kind == ruins_tank_duck ]] && cols=4
    bake "$src" "$kind" "$(px_h "$src" 8)" --cols "$cols" --rows 1 --outputs edge shadow_soft
  done
fi
