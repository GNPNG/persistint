class_name PaperDoll
extends Control
## PaperDoll — layered sprite doll (DESIGN.md: paper-doll reused by wardrobe (kind) and
## makeover (judged)). Give it an outfit {slot: part_id}; layers stack in LAYERS order.
## Part art comes from assets/canon when it exists, else assets/placeholder.

const LAYERS: Array[String] = ["body", "dress", "hair", "accessory"]
const ART_DIRS: Array[String] = ["res://assets/canon/%s.png", "res://assets/placeholder/%s.png"]

var outfit: Dictionary = {}
var _layers: Dictionary = {}  # slot -> TextureRect


func _ready() -> void:
	for slot in LAYERS:
		var rect := TextureRect.new()
		rect.name = slot.capitalize()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_layers[slot] = rect
	_apply()


func set_outfit(new_outfit: Dictionary) -> void:
	outfit = new_outfit.duplicate()
	_apply()


func set_part(slot: String, part_id: String) -> void:
	outfit[slot] = part_id
	_apply()


## The first art set that has every worn part, so canon and placeholder layers never mix.
static func art_dir_for(parts: Array) -> String:
	for pattern in ART_DIRS:
		var complete := true
		for part_id: String in parts:
			if part_id != "" and part_id != "none" and not ResourceLoader.exists(pattern % part_id):
				complete = false
				break
		if complete:
			return pattern
	return ART_DIRS[-1]


func _apply() -> void:
	if _layers.is_empty():
		return
	var pattern := art_dir_for(outfit.values())
	for slot: String in _layers:
		var part_id: String = outfit.get(slot, "none")
		var path := pattern % part_id
		_layers[slot].texture = load(path) if part_id != "none" and ResourceLoader.exists(path) else null
