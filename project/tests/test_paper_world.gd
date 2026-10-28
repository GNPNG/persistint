extends SceneTree
## Paper look in the game (bd gsd): every world sprite on the maps is drawn from a baked paper sheet
## (assets/paper/, tools/bake_paper.sh, PaperBake) and has its baked soft shadow. Village and
## temple: the caste NPCs' rigs, the player's paper-doll parts (a baked ring under each part's art),
## the trees, the flowers and the props. Florida (beach, garden, stable, aquarium): the props, the
## craft bench, the seed bag, the garden plots and the shells (PaperBake.dress at load); the Father,
## the Daughter and the stable friend, the critters and the aquarium fish (PaperBake.dress_frames),
## and the stable ponies (a baked ring under each part's art, PonyDoll paper). The ruins rooms:
## every prop that stands or hangs on the wall (RuinsDecor), the clone children and the polar bear
## cubs (dress_frames) and the knowledge pickups' icons (dress). Nothing on the maps uses a
## ShaderMaterial for it. Exempt by design: EXEMPT below, the pony a rider sits on (Mount) and the
## ruins' "floor" props (painted flat). Not yet rolled out: PENDING and PENDING_SCRIPTS (emptied as
## each group lands; empty since bd f60i).
## Run: godot --headless --path project -s tests/test_paper_world.gd

const MAPS := [
	"res://scenes/maps/village.tscn", "res://scenes/maps/temple.tscn",
	"res://scenes/florida/beach.tscn", "res://scenes/florida/garden.tscn",
	"res://scenes/florida/stable.tscn", "res://scenes/florida/aquarium.tscn",
	"res://scenes/ruins/ruins_wreck.tscn", "res://scenes/ruins/ruins_corridor.tscn",
	"res://scenes/ruins/ruins_core.tscn", "res://scenes/ruins/ruins_bunker_lift.tscn",
	"res://scenes/ruins/ruins_clone_hall.tscn", "res://scenes/ruins/ruins_records.tscn",
]
const PAPER := "res://assets/paper/"
## Source art that is deliberately not baked: a shadow, two 14 px effects, the animated temple
## candles and twinkle, the door markers (an interface cue over a door, not a cut-out), the Florida
## backgrounds (ground art) and the animated sea foam, the ruins pickups' glow and the gore effects,
## and the ruins' gloom (the screen vignette laid over the camera's view in the room since bd wso.4:
## lighting over the room, not a cut-out in it).
const EXEMPT := ["temple_shadow", "deco_heart", "deco_sparkle", "temple_candles", "temple_twinkle", "door_marker",
	"bg_florida_beach", "bg_florida_garden", "bg_florida_stable", "bg_florida_aquarium", "sea_foam",
	"glow", "gore_bone", "gore_chunk", "gore_drop", "gore_puddle", "gore_puff", "vignette"]
## Source art whose bake lands in a later commit of the rollout (none now).
const PENDING := []
## Scripts whose drawing is rolled out later (none now).
const PENDING_SCRIPTS := []

var _ok := true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_path: String in MAPS:
		var scene: PackedScene = load(map_path)
		_check(scene != null, "loads " + map_path)
		if scene == null:
			continue
		var map := scene.instantiate()
		root.add_child(map)
		await process_frame
		await process_frame
		_check_map(map, map_path.get_file())
		map.queue_free()
		await process_frame
	print("RESULT: %s" % ("PASS" if _ok else "FAIL"))
	quit(0 if _ok else 1)


## The texture a world sprite shows: a Sprite2D's, or the atlas behind an AnimatedSprite2D's frame.
func _source(n: Node) -> String:
	var tex: Texture2D = null
	if n is Sprite2D:
		tex = n.texture
	elif n is AnimatedSprite2D and n.sprite_frames and n.sprite_frames.has_animation(n.animation) \
			and n.sprite_frames.get_frame_count(n.animation) > 0:
		tex = n.sprite_frames.get_frame_texture(n.animation, 0)
	if tex is AtlasTexture:
		tex = (tex as AtlasTexture).atlas
	return tex.resource_path if tex else ""


func _check_map(map: Node, label: String) -> void:
	var baked := 0
	var pending: Dictionary = {}
	for n in map.find_children("*", "Node2D", true, false):
		if not (n is Sprite2D or n is AnimatedSprite2D) or not n.is_visible_in_tree():
			continue
		if n.get_parent() is CanvasLayer or _under_canvas_layer(n):
			continue  # HUD and UI, not the world
		var src := _source(n)
		if src == "":
			continue
		var stem := src.get_file().get_basename()
		var what := "%s %s (%s)" % [label, map.get_path_to(n), src.get_file()]
		_check(not (n.material is ShaderMaterial), what + " has no shader")
		if src.begins_with(PAPER):
			baked += 1
			if src.contains("_edge"):
				_check(_has_shadow(n), what + " has its baked shadow")
			continue
		if EXEMPT.has(stem) or n.get_parent().name == "Mount" or n.get_parent().get_meta("place", "") == "floor":
			continue
		var by := _pending_script(n, map)
		if PENDING.has(stem) or by != "":
			pending[by if by != "" else stem] = true
			continue
		# A paper-doll part's art is drawn over its baked ring.
		var ring := n.get_parent().get_node_or_null(String(n.name) + "Ring")
		if ring:
			_check(_source(ring).begins_with(PAPER), what + " sits on a baked paper ring")
			continue
		_check(false, what + " uses a baked paper sheet")
	_check(baked > 0, "%s draws %d baked paper sheets" % [label, baked])
	if not pending.is_empty():
		print("  info %s: not rolled out yet: %s" % [label, ", ".join(pending.keys())])


## The PENDING_SCRIPTS script that draws n (n's own, or an ancestor's below the map), "" if none.
func _pending_script(n: Node, map: Node) -> String:
	var p := n
	while p and p != map:
		var sc: Script = p.get_script()
		if sc and PENDING_SCRIPTS.has(sc.resource_path.get_file()):
			return sc.resource_path.get_file()
		p = p.get_parent()
	return ""


func _under_canvas_layer(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is CanvasLayer:
			return true
		p = p.get_parent()
	return false


## A baked edge sprite's shadow: a sibling or child drawing a baked shadow sheet.
func _has_shadow(n: Node) -> bool:
	for c in n.get_children() + n.get_parent().get_children():
		if (c is Sprite2D or c is AnimatedSprite2D) and _source(c).contains("_shadow_"):
			return true
	return false


func _check(c: bool, what: String) -> bool:
	if not c:
		_ok = false
	print(("  ok   " if c else "  FAIL ") + what)
	return c
