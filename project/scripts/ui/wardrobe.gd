extends CanvasLayer
## Wardrobe — Toca-style paper-doll overlay. Cycles options per slot from
## data/outfits.json and writes choices to WorldState (outfit_* flags).
## The island framing is KIND: play, expression, identity. (The cruise
## makeover mini-game will reuse this system in the judged framing.)
## One row per PaperDoll slot but the body (the row named after it), shown when the slot has
## something to choose (more than one option); each slot is worn on its own, so a hat and a bow
## go together. The panel grows to fit the rows it shows.

const OUTFITS_PATH := "res://data/outfits.json"
## The panel is never shorter than this (px): its size with the hair, dress and accessory rows.
const MIN_PANEL_HEIGHT := 224.0

var options: Dictionary = {}  # slot -> Array[String]

@onready var doll: PaperDoll = $Panel/HBox/Preview


func _ready() -> void:
	var f := FileAccess.open(OUTFITS_PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			options = parsed
	for slot: String in slots():
		var row: HBoxContainer = $Panel/HBox/VBox.get_node(slot.capitalize())
		row.get_node("Prev").pressed.connect(_cycle.bind(slot, -1))
		row.get_node("Next").pressed.connect(_cycle.bind(slot, 1))
	$Panel/HBox/VBox/CloseButton.pressed.connect(queue_free)
	show_rows()
	_refresh()


## The slots with a row: every PaperDoll slot but the body.
static func slots() -> Array[String]:
	var out: Array[String] = []
	for slot: String in PaperDoll.LAYERS:
		if slot != "body":
			out.append(slot)
	return out


## Shows the rows of the slots that have a choice and sizes the panel to them (call again after
## changing `options`).
func show_rows() -> void:
	for slot: String in slots():
		var row: Control = $Panel/HBox/VBox.get_node(slot.capitalize())
		row.visible = options.get(slot, []).size() > 1
	var panel: Control = $Panel
	var box: Control = $Panel/HBox  # 10 px in from the panel's edges
	var h := maxf(MIN_PANEL_HEIGHT, box.get_combined_minimum_size().y + 20.0)
	panel.offset_top = -h / 2.0
	panel.offset_bottom = h / 2.0


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
