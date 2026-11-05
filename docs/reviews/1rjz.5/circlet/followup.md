# Follow-up to coordinator rerun, 2026-11-05 22:35

The previous circlet change had no effect on the real sheet (coordinator: AE 0). That result supersedes any expectation based on the earlier fixture.

The upper-gap selector now measures the proportion of white pixels near the upper central face rather than requiring a disjoint, enclosed bounding box at least 25% of face width. It permits bbox overlap and a narrow connection to the crop edge. The regression uses the reported 63x33 bbox at (335,185), with a tapered interior (not a copy of the actual 1160-pixel component), against a pre-cleared face opening. Both enclosed and edge-connected variants clear. Existing white-detail, ear-gap and non-hair preservation tests still pass.

Every legacy item's `matte_review` now records detected face bbox/area and white components, their bbox/area, selection and proximity shares. Please include `items.json`'s hair_braids.matte_review in the next actual-sheet result if the gap remains; it identifies which predicate rejected the real component instead of inferring topology from the registered bbox.

## Pigtails: what the rows establish

The body_base.png is available here and was visually inspected. Its chin is y399; y367–379 is lower face, not neck. The existing region's bottom is y399. Group (b) is therefore artwork overlapping actual lower-face pixels, not a face region extending onto the neck. The splitHair function moves only pixels below y399 to the back, so these reported pixels are above its cut and remain front. Changing the chin or deleting those face rows would hide a genuine overlap.

Group (a)'s reported half x bounds map approximately to source x249–487 in y311–365. These are inside the body's cheek silhouette. The old checked-in canon pigtail asset has inward locks and a thin brown arc enclosing the bottom of its face opening. That arc is a plausible source of group (b), but the checked-in asset is an older transform, not the coordinator's 50755eb output. No assertion of exact pixel identity is made.

The actual registered front PNG, its matching fit/anchor metadata, and the small source pigtail crop are needed to distinguish a source jaw-outline artifact from misplaced hair and test a correction without masking real cheek overlap. Please relay those inputs through the private channel. No change to the 3% gate, regions, fitting search, scale or production art is included. Pigtail acceptance remains open; the circlet revision also requires actual-sheet verification.
