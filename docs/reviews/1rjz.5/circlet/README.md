# Coordinator follow-up, 2026-11-05

The legacy white-backing cleanup now selects substantial enclosed central gaps immediately above the face opening, including the gap between a circlet notch and hairline. This is geometric selection, not semantic accessory recognition. Small highlights, distant crown whites, side ornaments, the gold boundary, dresses and non-white-backed sheets remain unchanged in synthetic regressions. The actual encrypted sheet still needs coordinator inspection.

Tests: test_hair_fit.mjs, test_legacy.mjs and test_rig.mjs pass. The diagnostic also ran on a synthetic registered layer: 372 forehead samples plus 118 cheek-row samples = 490 overlap, out of 7253 face samples. The cheek row is source y=331. Its output is diagnostic-synthetic.txt. No production asset, fitting rule, region map, scale rule or QA gate changed.

## Pigtail overlap needs the actual registered pixels

The existing rig includes forehead above brow_y=236. Exact Godot nearest half-resolution sampling (the same as task 4) gives 7253 face samples, of which only 372 are above the brow. Thus the reported 650 overlaps cannot all be forehead: at least 278 are at or below the brow. Even removing every above-brow face sample would leave at least 278/6881 = 4.04%, above the existing 3% limit. A region-only correction cannot establish acceptance. The earlier coarse even-coordinate inspection counted 336; it is not task 4's sampling and must not be used for acceptance.

Run this on the existing 50755eb canon output BEFORE regenerating it, so the 650 pixels can be located without changing placement:

```sh
godot --headless --path . --script tools/doll/inspect_face_overlap.gd -- /path/to/canon-output hair_pigtails
```

The JSON gives overlap above/at-or-below the brow, row counts and half-resolution x bounds. Please relay that JSON, or the registered pigtail PNG and matching rig/region map, in this bead. Those pixels are not available in the contractor checkout. The diagnostic is read-only. It reports the front layer, where the face lies above chin_y; it does not alter the region or placement.

For the circlet fix, rerun check_canon_registration.mjs and task 4 QA as documented in the parent README, and inspect the braids contact. Crown/braids/short scale-class acceptance is now assigned to 1rjz.6 by the coordinator. Pigtails must still pass all checks; this revision does not claim that pass or completion of 1rjz.5.
