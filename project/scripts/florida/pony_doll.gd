class_name PonyDoll
extends Node2D
## PonyDoll — the paper doll on a pony (DESIGN.md section 3: grooming reuses the paper-doll /
## makeover tech). Same pattern as PaperDoll: parts {slot: part_id} stack in LAYERS order, one
## sprite per slot, all parts share one frame (tools/gen_pony_sprites.py). Used for the ponies
## in the stable, the pony under a mounted player and the big pony in the grooming panel.

const LAYERS: Array[String] = ["body", "spots", "mane", "accessory", "sparkle"]

var outfit: Dictionary = {}
var _layers: Dictionary = {}  # slot -> Sprite2D


func _ready() -> void:
	_ensure_layers()
	_apply()


func _ensure_layers() -> void:
	if not _layers.is_empty():
		return
	for slot in LAYERS:
		var sprite := Sprite2D.new()
		sprite.name = slot.capitalize()
		add_child(sprite)
		_layers[slot] = sprite


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
