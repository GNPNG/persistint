class_name PonyDoll
extends Node2D
## PonyDoll — the paper doll on a pony (DESIGN.md section 3: grooming reuses the paper-doll /
## makeover tech). Same pattern as PaperDoll: parts {slot: part_id} stack in LAYERS order, one
## sprite per slot, all parts share one frame (tools/gen_pony_sprites.py). Used for the ponies
## in the stable, the pony under a mounted player and the big pony in the grooming panel.
## Rig: every part is a 4x2 sheet (row 0 idle, row 1 walk); one AnimationPlayer steps every
## layer's frame together so the stacked parts never drift apart.

const LAYERS: Array[String] = ["body", "spots", "mane", "accessory", "sparkle"]

const IDLE_FPS := 3.0
const WALK_FPS := 8.0

var outfit: Dictionary = {}
var _layers: Dictionary = {}  # slot -> Sprite2D
var _anim: AnimationPlayer


func _ready() -> void:
	_ensure_layers()
	_apply()


func _ensure_layers() -> void:
	if not _layers.is_empty():
		return
	for slot in LAYERS:
		var sprite := Sprite2D.new()
		sprite.name = slot.capitalize()
		sprite.hframes = 4
		sprite.vframes = 2
		add_child(sprite)
		_layers[slot] = sprite
	_anim = AnimationPlayer.new()
	_anim.name = "Anim"
	add_child(_anim)
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _frames_animation(0, IDLE_FPS))
	lib.add_animation(&"walk", _frames_animation(4, WALK_FPS))
	_anim.add_animation_library(&"", lib)
	_anim.play(&"idle")
	_anim.seek(randf() * 4.0 / IDLE_FPS, true)


## Four frames from first_frame on, stepped on every layer at once.
func _frames_animation(first_frame: int, fps: float) -> Animation:
	var a := Animation.new()
	a.length = 4.0 / fps
	a.loop_mode = Animation.LOOP_LINEAR
	for slot in LAYERS:
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath("%s:frame" % slot.capitalize()))
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
	for sprite: Sprite2D in _layers.values():
		sprite.flip_h = left


func layer(slot: String) -> Sprite2D:
	_ensure_layers()
	return _layers.get(slot)


func _apply() -> void:
	for slot: String in _layers:
		var part_id: String = outfit.get(slot, "none")
		var path := Ponies.ART % part_id
		_layers[slot].texture = load(path) if part_id != "none" and ResourceLoader.exists(path) else null
