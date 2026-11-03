# Temple strips — persistint-game-i3f2

`tools/build_temple_strips.py` derives the two shipped animation strips from the landed
stills under `project/assets/sheets/temple/`. Run `python3 -I tools/build_temple_strips.py`
with Pillow and ImageMagick installed. The source PNGs and SpriteFrames resources are unchanged.

The twinkle has six centered 48×48 frames, scaling and fading through
0.25, 0.6, 1, 0.75, 0.4, 0. The candle has four 96×176 frames with its foot at (48,168).
Only a measured flame mask changes size and position; the wick and stand remain static.
The mask assumes the current 1254×1254 source and must be remeasured for replacement art.
Both strips use the repository's 12% green-key and despill recipe. Embedded builder/source
metadata protects the strips from `gen_temple_props.py`; missing or unmarked stand-ins
can still be generated normally.

![Old and new frames at game scale and enlarged](frames.png)

The left strips are at one quarter file size (world pixels); the right strips enlarge
that view three times using nearest-neighbor sampling. The new candle follows the landed
single-candle still rather than the old three-arm procedural stand.

![Temple at the first sampled animation time](temple-first.png)
![Temple eight simulation frames later](temple-next.png)

Visual check: both candles sit on their contact shadows, with unclipped flame silhouettes,
no visible green edge, and stationary wax/stands. The pale twinkles remain subtle on the
pastel background. These are rendered Godot scene samples, not a manual interactive playthrough.
Reproduce with `tools/shot_walk.sh docs/reviews/i3f2/shots.json /tmp/i3f2-shots`.
The standard temple overview and ritual-table shot also rendered without engine errors.

Focused checks: `python3 -I tools/test_temple_strips.py` covers byte-for-byte reproduction,
unchanged sources, frame sizes, twinkle centering/fade, stationary candle body, flame variation,
and stand-in overwrite protection. Asset provenance: `node tools/gen_sources.mjs`, then
`node tools/check_assets.mjs` (1017 assets, zero failures).

Full suite (`tools/run_tests.sh`): initial result 63/66. Regenerating provenance fixed
`check_assets`; putting Beads 1.3.2 on PATH fixed `test_sync_agent_channel` (the installed
0.49.6 CLI is incompatible with that test). Both targeted reruns pass, leaving 65/66
checks passing. `test_quotes_vv` still rejects the existing Hottest of the HOT verdicts
“who did your hair?” and “so brave to wear that” as absent from both verified quotes and
`dev/DESIGN.md`. Those data, design, and test files are unchanged from base `2a93bc8`.
This patch does not alter unrelated quote content; coordinator resolution is needed
before claiming a fully passing suite. Manual interactive play and other platforms
were not checked.
