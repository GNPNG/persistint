extends SceneTree
## Paper look in the game (bd gsd): every world sprite on the main maps (village, temple) is drawn
## from a baked paper sheet (assets/paper/, tools/bake_paper.sh, PaperBake) and has its baked soft
## shadow: the caste NPCs' rigs, the player's paper-doll parts (a baked ring under each part's
## art), the trees, the flowers and the props. Nothing on the maps uses a ShaderMaterial for it.
## Exempt by design: EXEMPT below. Not yet rolled out: PENDING (emptied as each group lands).
## Run: godot --headless --path project -s tests/test_paper_world.gd

const MAPS := ["res://scenes/maps/village.tscn", "res://scenes/maps/temple.tscn"]
const PAPER := "res://assets/paper/"
## Source art that is deliberately not baked: a shadow, two 14 px effects, the animated temple
## candles and twinkle, the door markers (an interface cue over a door, not a cut-out), and the
## pony (Florida).
const EXEMPT := ["temple_shadow", "deco_heart", "deco_sparkle", "temple_candles", "temple_twinkle", "door_marker"]
## Source art whose bake lands in a later commit of the rollout.
const PENDING := [
	"prop_bunker", "prop_fence_a", "prop_fence_b", "prop_sign_a", "prop_sign_b", "prop_tag_x",
	"prop_icon_queen_mother", "prop_seal_o", "prop_ship", "prop_calendar", "prop_pillar_orb",
	"prop_skull_altar", "temple_pavilion", "mirror", "temple_plinth", "temple_urn", "temple_cushion"]

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
		if EXEMPT.has(stem) or src.contains("/florida/") or n.get_parent().name == "Mount":
			continue
		if PENDING.has(stem):
			pending[stem] = true
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
