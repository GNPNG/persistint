class_name PonyDoll
extends Node2D
## PonyDoll — the paper doll on a pony (DESIGN.md section 3: grooming reuses the paper-doll /
## makeover tech). Same pattern as PaperDoll: parts {slot: part_id} stack in LAYERS order, one
## sprite per slot, all parts share one frame (tools/gen_pony_sprites.py). Used for the ponies
## in the stable, the pony under a mounted player and the big pony in the grooming panel.
## Rig: every part is a 4x2 sheet (row 0 idle, row 1 walk); one AnimationPlayer steps every
## layer's frame together so the stacked parts never drift apart.
## Paper look (bd gsd, PaperBake; tools/bake_paper.sh florida_cast) for a doll with `paper` on (the
## stable ponies), as the player's doll has it: under the stack one paper ring per worn part (the
## union of the rings is the border of the whole pony; each a sibling <Layer>Ring) and one soft
## shadow, baked from the body, all on the parts' frame grid and stepped by the same
## AnimationPlayer. The pony under a rider and the grooming panel's pony stay without.

const LAYERS: Array[String] = ["body", "spots", "mane", "accessory", "sparkle"]

## One frame is 64x52 world px whatever the sheet's resolution (the art is drawn at 4x); the
## hooves stand on the frame's bottom edge, which SpriteFit puts on the doll's origin.
const FRAME_HEIGHT := 52.0
const IDLE_FPS := 3.0
const WALK_FPS := 8.0

## The paper rings and shadow (set before the doll is in the tree, as pony.tscn does).
@export var paper := false

var outfit: Dictionary = {}
var _layers: Dictionary = {}  # slot -> Sprite2D
var _rings: Dictionary = {}  # slot -> its ring Sprite2D (paper only)
var _shadow: Sprite2D  # paper only
var _anim: AnimationPlayer


func _ready() -> void:
	_ensure_layers()
	_apply()


func _ensure_layers() -> void:
	if not _layers.is_empty():
		return
	if paper:  # drawn first: the shadow, then the rings, then the art
		_shadow = _grid_sprite("PaperShadow")
		PaperBake.style_shadow(_shadow)
		for slot in LAYERS:
			_rings[slot] = _grid_sprite(slot.capitalize() + "Ring")
	for slot in LAYERS:
		_layers[slot] = _grid_sprite(slot.capitalize())
	_anim = AnimationPlayer.new()
	_anim.name = "Anim"
	add_child(_anim)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _frames_animation(0, IDLE_FPS))
	lib.add_animation(&"walk", _frames_animation(4, WALK_FPS))
	_anim.add_animation_library(&"", lib)
	_anim.play(&"idle")
	_anim.seek(randf() * 4.0 / IDLE_FPS, true)


## A child sprite on the parts' 4x2 frame grid.
func _grid_sprite(node_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.hframes = 4
	sprite.vframes = 2
	add_child(sprite)
	return sprite


## Everything drawn for the doll: the art layers, and with `paper` their rings and the shadow.
func _sprites() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for sprite: Sprite2D in _layers.values() + _rings.values():
		out.append(sprite)
	if _shadow:
		out.append(_shadow)
	return out


## Four frames from first_frame on, stepped on every layer (and ring and shadow) at once.
func _frames_animation(first_frame: int, fps: float) -> Animation:
	var a := Animation.new()
	a.length = 4.0 / fps
	a.loop_mode = Animation.LOOP_LINEAR
	for sprite in _sprites():
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath("%s:frame" % sprite.name))
		a.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
		for i in 4:
			a.track_insert_key(t, i / fps, first_frame + i)
	return a


## Walking (the mounted pony on the move) or standing.
func set_moving(moving: bool) -> void:
	_ensure_layers()
	var want := &"walk" if moving else &"idle"
	if _anim.current_animation != want:
		_anim.play(want)


func set_outfit(new_outfit: Dictionary) -> void:
	outfit = new_outfit.duplicate()
	_ensure_layers()
	_apply()


func set_part(slot: String, part_id: String) -> void:
	outfit[slot] = part_id
	_ensure_layers()
	_apply()


func set_facing_left(left: bool) -> void:
	for sprite in _sprites():
		sprite.flip_h = left


func layer(slot: String) -> Sprite2D:
	_ensure_layers()
	return _layers.get(slot)


func _apply() -> void:
	for slot: String in _layers:
		var part_id: String = outfit.get(slot, "none")
		var path := Ponies.ART % part_id
		var sprite: Sprite2D = _layers[slot]
		sprite.texture = load(path) if part_id != "none" and ResourceLoader.exists(path) else null
		SpriteFit.fit(sprite, FRAME_HEIGHT)
		if paper:
			_paper_part(slot, sprite)


## The worn part's baked paper ring (and, for the body, the shadow): the bake's sheet on the same
## frame grid, at the part's size and place (offset x k, scale / k: the bake pads each frame
## evenly); none when the part is not worn or has no bake.
func _paper_part(slot: String, sprite: Sprite2D) -> void:
	var bake := PaperBake.bake_of(sprite.texture.resource_path if sprite.texture else "")
	var paper_nodes: Array = [[_rings[slot], PaperBake.RING]]
	if slot == "body":
		paper_nodes.append([_shadow, PaperBake.SHADOW])
	for p: Array in paper_nodes:
		var node: Sprite2D = p[0]
		var sheet := PaperBake.sheet(bake, p[1]) if bake != "" else ""
		node.texture = load(sheet) if sheet != "" else null
		if node.texture == null:
			continue
		var k := PaperBake.resample(bake)
		node.centered = sprite.centered
		node.offset = sprite.offset * k
		node.scale = sprite.scale / k
		node.flip_h = sprite.flip_h
		node.frame = sprite.frame
