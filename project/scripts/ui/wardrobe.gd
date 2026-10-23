extends CanvasLayer
## Wardrobe — Toca-style paper-doll overlay. Cycles options per slot from
## data/outfits.json and writes choices to WorldState (outfit_* flags).
## The island framing is KIND: play, expression, identity. (The cruise
## makeover mini-game will reuse this system in the judged framing.)

const OUTFITS_PATH := "res://data/outfits.json"

var options: Dictionary = {}  # slot -> Array[String]

@onready var doll: PaperDoll = $Panel/HBox/Preview


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
	var current: String = WorldState.get_flag("outfit_%s" % slot, _defaults().get(slot, items[0]))
	var idx := items.find(current)
	idx = wrapi(idx + dir, 0, items.size())
	WorldState.set_flag("outfit_%s" % slot, items[idx])
	_refresh()


func _defaults() -> Dictionary:
	var defaults := {"body": "body_base"}
	for slot: String in options:
		defaults[slot] = options[slot][0]
	# Start from what the player is actually wearing, not the first option.
	for slot: String in PaperDoll.DEFAULT_OUTFIT:
		if slot == "body" or options.get(slot, []).has(PaperDoll.DEFAULT_OUTFIT[slot]):
			defaults[slot] = PaperDoll.DEFAULT_OUTFIT[slot]
	return defaults


func _refresh() -> void:
	var defaults := _defaults()
	var outfit := {}
	for slot: String in PaperDoll.LAYERS:
		outfit[slot] = WorldState.get_flag("outfit_%s" % slot, defaults.get(slot, "none"))
	doll.set_outfit(outfit)
	for slot: String in outfit:
		var label: Label = $Panel/HBox/VBox.get_node_or_null("%s/Value" % slot.capitalize())
		if label:
			label.text = String(outfit[slot]).trim_prefix("%s_" % slot).capitalize()
