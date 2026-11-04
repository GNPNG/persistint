# Character intake and matting — task 2, work in progress

Branch `codex/1rjz.2`, bead `persistint-game-1rjz.2`. This is a draft for coordinator
review, not an accepted replacement for the existing asset pipeline.

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

CLI: `node tools/doll/intake.mjs IMAGE.png PROVENANCE.json EXPECTED_COUNT` writes
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

## Pending acceptance and limits

The original canon JPEG under dev/art/canon-gemini is git-crypt ciphertext in this
checkout. A readable private fixture was requested on the bead. The existing crop
spec is `402x698+97+300`. No claim is made for the required <=2% fringe / >=64 alpha
levels until that input can be tested. `check_canon_matte.mjs BODY_CROP OUTPUT.png`
is prepared to emit metrics, save a review-only matte, and enforce both criteria.

Proof-pair visual identity/registration is task 3; this intake does not verify it.
No ML fallback, registration, production rematting, outfit fitting, or runtime changes.
The white-boundary algorithm currently has only synthetic validation. Transparent
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
results, not the missing JPEG acceptance.
