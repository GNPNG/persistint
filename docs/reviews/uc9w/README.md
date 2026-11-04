# Temple atlas integration — uc9w

Run `python3 -I tools/gen_island_tiles.py` with Pillow, NumPy and ImageMagick available.
The existing atlas generator now reads the eight interior rectangles from the native
1672×941 landed temple sheet, keys green at 12% fuzz with despill, excludes the brown
perimeters and resizes to 128×128. A differently sized source fails for remeasurement;
a missing source retains the complete procedural fallback.

The five floor variants, north-wall face/cap/wainscot, rug and both fringed ends use
the new art. The runner spans its existing 2×2 cells as one continuous image, so there
is no extra gold border down the middle. Its upper end reverses the supplied bottom
fringe. The dais top is one continuous panel across its existing cells; the silhouette
and two cream steps remain. Side walls, doorway, west stairs and all non-temple cells
retain their previous art. Shared rug/floor cells also change wherever other maps use
them; no new indices or map layouts are introduced.

`island_tiles.json` is byte-identical to the base version. Only 45 occupied atlas slots
change, all temple cells or their blocked duplicates. Animation and terrain-edge slots
are unchanged. No map rebuild is needed or performed.

## Seam inspection

![Each of the eight cropped sources tiled 3×3](seams.png)

There are no keyed gaps or brown perimeter lines. Floor highlights and the inset gold
motifs repeat visibly (four small motifs gather at a slab intersection). Brick top-edge
highlights also repeat in horizontal bands. These are present in the source art, not
claimed as mathematically seamless textures. Cap, wainscot, fringe and dais gold edges
are directional: their vertical repetitions in this diagnostic are not how they are
placed in the map. The actual runner is split from a complete wide piece, and the dais
is split after assembly, avoiding internal borders.

## In-game comparison

![Temple before](before.png)
![Temple after](after.png)

Both use the standard `temple-temple-overview` shot from `tools/shots/wso.json`.
The new checkerboard, runner, dais surface and north wall are visible with the existing
props, contact shadows and collisions. Review at native size for the repeated highlights.
No manual interactive playthrough or cross-platform check is claimed.

Focused checks: `python3 -I tools/test_temple_tiles.py` (4 pass), checking the exact cell
allowlist, opacity, fallback, continuous runner assembly and unchanged dais steps.

Full suite: 65/66 pass; only `test_quotes_vv` fails, as the coordinator predicted
because the private design text is encrypted in this clone. Beads 1.3.2 was on PATH.
The final runner was adjusted to span its full 2×2 footprint during the suite; final
Godot import, `test_island_maps`, asset gate and screenshots were rerun afterward
and passed. Exact atlas regeneration is byte-for-byte stable.
