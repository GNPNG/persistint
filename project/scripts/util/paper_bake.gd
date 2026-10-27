class_name PaperBake
extends RefCounted
## PaperBake — the baked paper look (bd gsd, 1dx): every world sprite drawn as a cut-out with a
## white paper border and a soft drop shadow, both baked offline into sibling sheets under
## assets/paper/ by tools/bake_paper.sh (tools/gen_paper_edges.mjs), so the client pays no shader
## and no per-frame work: one draw for the bordered art, one for the shadow.
##
## Each baked subject <name> (the source file's base name, e.g. deco_tree_a, npc_initiate_rig,
## body_base_rig) has a sidecar <name>.json: the padded frame grid (same cols x rows as the
## source), the padding, the feet line and the padded display height (world_h_padded), and its
## sheets: edge2_white (art + border), ring2_white (the border alone, for paper-doll layers drawn
## under the art stack) and shadow_soft.

const DIR := "res://assets/paper/"
const EDGE := "edge2_white"
const RING := "ring2_white"
const SHADOW := "shadow_soft"
## The shadow falls down and to the right of what casts it, world px; black at this strength.
const SHADOW_OFFSET := Vector2(3.0, 1.8)
const SHADOW_COLOR := Color(0, 0, 0, 0.3)

static var _sides: Dictionary = {}  # name -> sidecar Dictionary ({} when not baked)


## The sidecar of the baked subject `name`, {} when it has none.
static func side(name: String) -> Dictionary:
	if _sides.has(name):
		return _sides[name]
	var path := DIR + name + ".json"
	var d: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			d = parsed
	_sides[name] = d
	return d


## The baked subject for a source texture path (res://.../deco_tree_a.png -> deco_tree_a).
static func name_of(source_path: String) -> String:
	return source_path.get_file().get_basename()


## Path of one of `name`'s sheets (EDGE, RING, SHADOW), "" when it has no such sheet.
static func sheet(name: String, which: String) -> String:
	var s := side(name)
	if s.is_empty() or not s["files"].has(which):
		return ""
	return DIR + String(s["files"][which])


## Display height of a baked frame for art shown `world_h` tall unbaked (the padding grows it).
static func padded_height(name: String, world_h: float) -> float:
	var s := side(name)
	var fr: Array = s["frame"]
	var sf: Array = s["scaled_frame"]
	return world_h * float(fr[1]) / float(sf[1])


## Feet line of a baked frame (fraction of its height) for a source feet line `feet`.
static func padded_feet(name: String, feet: float) -> float:
	var s := side(name)
	var fr: Array = s["frame"]
	var sf: Array = s["scaled_frame"]
	return (float(s["pad"]) + float(sf[1]) * feet) / float(fr[1])


## Texture px of the baked sheet per texture px of the source (x, y).
static func resample(name: String) -> Vector2:
	var s := side(name)
	var sf: Array = s["scaled_frame"]
	var src: Array = s["src_frame"]
	return Vector2(float(sf[0]) / float(src[0]), float(sf[1]) / float(src[1]))


## Dress a shadow sprite: black at SHADOW_COLOR, nudged SHADOW_OFFSET world px. `parent_scale`
## is the scale the shadow's position is measured in (1 for a sibling, the sprite's own scale for
## a child of the sprite).
static func style_shadow(shadow: Node2D, parent_scale := Vector2.ONE) -> void:
	shadow.modulate = SHADOW_COLOR
	shadow.position = SHADOW_OFFSET / parent_scale


## The paper look for a Sprite2D already showing its source art (texture, offset and scale set),
## for maps that are not built by tools/build_island_maps.gd (Florida, the ruins): when that art
## has a bake, the sprite shows the bordered sheet at the same size and place (the sheet is
## resampled by k and padded evenly, so the centre stays: offset x k, scale / k) over a soft shadow
## child drawn behind it (PaperShadow, show_behind_parent), as _paper in build_island_maps.gd does.
## Art with no bake (or a bake of another file with the same name) is left as it is. Call it again
## after giving the sprite new source art (a garden plot that grew): the shadow is reused, or
## removed when the new art has none. Returns true when the sprite shows a baked sheet.
static func dress(s: Sprite2D) -> bool:
	var src := s.texture.resource_path if s.texture else ""
	if src.begins_with(DIR):
		return true  # already dressed
	var old := s.get_node_or_null("PaperShadow") as Sprite2D
	var bake := name_of(src)
	var edge := sheet(bake, EDGE) if src != "" else ""
	var from: Array = side(bake).get("source", []) if edge != "" else []
	if edge == "" or (not from.is_empty() and String(from[0]) != "project/" + src.trim_prefix("res://")):
		_drop(s, old)
		return false
	var k := resample(bake)
	s.texture = load(edge)
	s.offset *= k
	s.scale /= k
	var shadow_path := sheet(bake, SHADOW)
	if shadow_path == "":
		_drop(s, old)
		return true
	var sh := old if old else Sprite2D.new()
	sh.name = "PaperShadow"
	sh.texture = load(shadow_path)
	sh.offset = s.offset
	sh.flip_h = s.flip_h
	sh.show_behind_parent = true
	style_shadow(sh, s.scale)
	if sh.get_parent() == null:
		s.add_child(sh)
	return true


static func _drop(s: Node, shadow: Node) -> void:
	if shadow:
		s.remove_child(shadow)
		shadow.queue_free()
