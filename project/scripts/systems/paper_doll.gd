class_name PaperDoll
extends Control
## PaperDoll — layered sprite doll (DESIGN.md: paper-doll reused by wardrobe (kind) and
## makeover (judged)). Give it an outfit {slot: part_id}; layers stack in LAYERS order.
## Part art comes from the canon set when it has every worn part, else assets/placeholder.
## The canon set is the canon cuts (assets/canon) plus area parts drawn on the canon doll frame
## (assets/florida: the crafted Florida wearables, tools/gen_florida_wearables.py).

const LAYERS: Array[String] = ["body", "dress", "hair", "accessory"]
const ART_DIRS: Array[String] = ["res://assets/canon/%s.png", "res://assets/placeholder/%s.png"]
## Extra folders searched for a part, after the set's own folder, keyed by the set's pattern.
const ART_EXTRA := {"res://assets/canon/%s.png": ["res://assets/florida/%s.png"]}
## What the player wears before any outfit_* flag is set (player and wardrobe agree on it).
const DEFAULT_OUTFIT := {"body": "body_base", "dress": "dress_white", "hair": "hair_braids", "accessory": "none"}

## Shown this tall (px) when set: the doll sizes itself (custom_minimum_size) to the art's
## frame at that height through SpriteFit, aspect kept. 0 leaves the size to the layout.
@export var display_height := 0.0:
	set(h):
		display_height = h
		_fit()

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
	_fit()


func set_outfit(new_outfit: Dictionary) -> void:
	outfit = new_outfit.duplicate()
	_apply()


func set_part(slot: String, part_id: String) -> void:
	outfit[slot] = part_id
	_apply()


func _fit() -> void:
	if display_height <= 0.0:
		return
	var body: Texture2D = load(part_path(art_dir_for([DEFAULT_OUTFIT["body"]]), DEFAULT_OUTFIT["body"]))
	custom_minimum_size = SpriteFit.size_for(body, display_height)


## The first art set that has every worn part, so canon and placeholder layers never mix.
static func art_dir_for(parts: Array) -> String:
	for pattern in ART_DIRS:
		var complete := true
		for part_id: String in parts:
			if part_id != "" and part_id != "none" and not ResourceLoader.exists(part_path(pattern, part_id)):
				complete = false
				break
		if complete:
			return pattern
	return ART_DIRS[-1]


## Where a part's art lives within the set art_dir_for chose.
static func part_path(pattern: String, part_id: String) -> String:
	for extra: String in ART_EXTRA.get(pattern, []):
		if not ResourceLoader.exists(pattern % part_id) and ResourceLoader.exists(extra % part_id):
			return extra % part_id
	return pattern % part_id


func _apply() -> void:
	if _layers.is_empty():
		return
	var pattern := art_dir_for(outfit.values())
	for slot: String in _layers:
		var part_id: String = outfit.get(slot, "none")
		var path := part_path(pattern, part_id)
		_layers[slot].texture = load(path) if part_id != "none" and ResourceLoader.exists(path) else null
