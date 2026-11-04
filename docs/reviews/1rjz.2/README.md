# Character intake and matting — task 2, acceptance delivery

Branch `codex/1rjz.2`, bead `persistint-game-1rjz.2`. Submitted for coordinator acceptance; source assets remain unchanged.

Node built-ins and ImageMagick only. Source assets are unchanged.

- `lib/image.mjs`: RGBA8 I/O and alpha-weighted Lanczos resampling.
- `lib/matte.mjs`: measured-border green unmix, enclosed-green removal, palette
  preservation, and exterior-boundary white unmix with local outline estimates.
- `intake.mjs`: PNG/provenance checks, byte SHA-1, native dimensions, border/background
  diagnostics, alpha/halo diagnostics, components with no size cutoff, optional explicit
  merging, edge contact and expected count. Gaps are Manhattan blank-pixel distances
  before merging; bounding-box gap is separately reported as a lower bound.
- `test_doll_tools.gd`: discovers and runs every `tools/doll/test_*.mjs`, failing on
  missing Node/ImageMagick or any test failure. No implicit skip.

CLI: `node tools/doll/intake.mjs IMAGE.png PROVENANCE.json EXPECTED_COUNT [--reference-body]` writes
`IMAGE.png.intake.json` and a one-line verdict. The API supports `referenceBody:true`
when the leftmost component is explicitly the brief's reference doll; it is retained
in the report and excluded only from itemCount. Merging is opt-in; no specks are deleted.

Synthetic tests check known coverage (mean alpha error 0.000613), enclosed holes,
exact opaque white/cream/turquoise/sky-blue interiors (delta E zero), white interior
preservation, alpha-weighted resize, rejection of gradients/green leaves/touching/edge
contact, provenance, component retention and measured gaps.

Delivered segmentation: Daughter five, Mother seven, Oprah four items **plus one
reference body**. The Mother sheet also triggers the background-spread diagnostic;
component-count success does not override that intake rejection. Threshold calibration
against real source art remains for review.

## Canon acceptance and limits

The team runs canon acceptance against the encrypted source. Coordinator cc-srv-lxd
reported on the bead at 2026-11-04 07:12:59 UTC that e3fe013 passed on the margin crop
**482x778+57+250**: fringe ratio **0**, **256 alpha levels**, clean on dark and pink.
Use this margin crop for future checks. The legacy tighter crop clipped the head
(33 opaque first-row pixels); its reported fringe ratio was 0.0036, with 256 alpha levels.

The coordinator observed the same ring count (2521) for both crops. The implementation
counts the supplied image's alpha>127 pixels having any four-neighbour outside that
mask, treating outside the canvas as transparent. It uses no cached body geometry.
Hand-counted full and clipped fixtures verify this, including an equal-perimeter case:
ring count alone cannot detect clipping. Reports now include dimensions, threshold and
borderOpaquePixels; check_canon_matte rejects opaque crop-edge contact as well as
fringe above2% or fewer than64 alpha levels. The exact equality on the encrypted JPEG
cannot be independently reproduced here; the team should rerun the enhanced probe.

The check_canon_matte.mjs BODY_CROP OUTPUT.png command writes review output and
metrics without modifying production art.

Proof-pair visual identity/registration is task 3; this intake does not verify it.
No ML fallback, registration, production rematting, outfit fitting, or runtime changes.
White-boundary canon validation above was performed by the team. Transparent
white artwork can trigger the conservative light-ring diagnostic; it is not silently
accepted. Cross-build resampling is checked by tolerances, not PNG byte equality.

The wrapper was fault-tested with a temporary newly discovered test that exits 7:
it reports that file and exits 1. The fixture is removed and not committed. The clean
wrapper rerun passes. Native alpha identity and exact palette preservation are tested;
resampled RGB tolerances are two channel values.

A synthetic white-backed curved outline produces 181 alpha levels and zero light
pixels in its 277-pixel outline ring. White unmix stops at the opaque outline so it
does not cross into enclosed white content; boundary foreground estimation prefers
nearby dark outline samples over partially blended pixels. These are synthetic
results, separate from the team-run JPEG acceptance.

Validation run: full `tools/run_tests.sh` reports **67/68** in 281 seconds; only
`test_quotes_vv` fails on the known encrypted private design file. Final targeted
`tools/run_tests.sh test_doll_tools` passes all three Node regression files (7 seconds)
after the boundary/segmentation refinements. No production art was regenerated.

Revision validation: all three Node files pass through test_doll_tools after adding
actual-frame ring and crop-edge regressions. Full suite was not repeated for these
diagnostic changes; its preceding result remains 67/68 as described above.
