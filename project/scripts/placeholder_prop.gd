extends Sprite2D
## PlaceholderProp: a prop whose art is a drop that may not be rendered yet. At run time it
## loads the drop when the file is there (res://assets/island/prop_<art_path>.png) and shows
## fallback_path (existing art) until then, so the rendered file replaces the placeholder with
## no code change (SOP-03/04 art drops). The drop path is built with %, so the asset gate
## (tools/check_assets.mjs) does not ask for the not-yet-rendered file.
## The node's origin is the prop's feet (SpriteFit), so it y-sorts with everything else.
## Paper look (bd gsd, tests/test_paper_world.gd): the art shown is dressed with its baked sheet and
## soft shadow at load (PaperBake.dress), as the Florida props are. The fallback art is baked
## (tools/bake_paper.sh); a rendered drop is shown unbordered until it is added to the props list
## there and baked.

## Art name of the drop under assets/island (prop_<art_path>.png).
@export var art_path := ""
## Existing art shown until the drop lands (a full res:// path to a shipped asset).
@export var fallback_path := ""
## Height the prop is shown at on the map, in world px (SpriteFit).
@export var height := 64.0

const DROP_PATH := "res://assets/island/prop_%s.png"


func _ready() -> void:
	var t: Texture2D = null
	var drop := DROP_PATH % art_path
	if art_path != "" and ResourceLoader.exists(drop):
		t = load(drop)
	if t == null and fallback_path != "" and ResourceLoader.exists(fallback_path):
		t = load(fallback_path)
	texture = t
	SpriteFit.fit(self, height)
	PaperBake.dress(self)
