extends CanvasLayer
## Wardrobe — Toca-style paper-doll overlay. Cycles options per slot from
## data/outfits.json and writes choices to WorldState (outfit_* flags).
## The island framing is KIND: play, expression, identity. (The cruise
## makeover mini-game will reuse this system in the judged framing.)

const OUTFITS_PATH := "res://data/outfits.json"

var options: Dictionary = {}  # slot -> Array[String]

@onready var preview_root: Control = $Panel/HBox/Preview


func _ready() -> void:
	var f := FileAccess.open(OUTFITS_PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			options = parsed
	for slot: String in ["hair", "dress", "accessory"]:
		var row: HBoxContainer = $Panel/HBox/VBox.get_node(slot.capitalize())
		row.get_node("Prev").pressed.connect(_cycle.bind(slot, -1))
		row.get_node("Next").pressed.connect(_cycle.bind(slot, 1))
	$Panel/HBox/VBox/CloseButton.pressed.connect(queue_free)
	_refresh()


func _cycle(slot: String, dir: int) -> void:
	var items: Array = options.get(slot, [])
	if items.is_empty():
		return
	var current: String = WorldState.get_flag("outfit_%s" % slot, items[0])
	var idx := items.find(current)
	idx = wrapi(idx + dir, 0, items.size())
	WorldState.set_flag("outfit_%s" % slot, items[idx])
	Voice.speak("ooh", randf_range(1.1, 1.5))
	_refresh()


func _refresh() -> void:
	for slot: String in ["body", "dress", "hair", "accessory"]:
		var tex_rect: TextureRect = preview_root.get_node_or_null(slot.capitalize())
		if tex_rect == null:
			continue
		var item: String = WorldState.get_flag("outfit_%s" % slot,
			"body_base" if slot == "body" else options.get(slot, ["none"])[0])
		var path := "res://assets/placeholder/%s.png" % item
		tex_rect.texture = load(path) if item != "none" and ResourceLoader.exists(path) else null
		var label: Label = $Panel/HBox/VBox.get_node_or_null("%s/Value" % slot.capitalize())
		if label:
			label.text = item.trim_prefix("%s_" % slot).capitalize()
