extends PanelContainer
## The help panel (bd ctw: the "?" sticker or F1): how to play with each kind of input, read from
## the input map so a remapped key shows as it is now. Close, F1, the sticker or Escape shuts it.

signal closed

const ROWS := [
	["Walk", ["move_up", "move_left", "move_down", "move_right"], "tap or click where to go", "left stick or d-pad"],
	["Talk / use", ["interact"], "tap or click a person or thing", "A"],
	["Wardrobe", ["toggle_wardrobe"], "the hanger sticker", "Y"],
	["Journal", ["toggle_journal"], "the book sticker", "X"],
	["Zoom", ["zoom_out", "zoom_in"], "the magnifier sticker, pinch or the wheel", "LB / RB"],
	["Map", ["toggle_map"], "the map sticker, then a heart on it to walk to that way out", "R3"],
	["Pause and settings", [], "the gear", "Start"],
]

var _body: Label


func _ready() -> void:
	name = "Help"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "How to play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(300, 0)
	box.add_child(_body)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "Close"
	close.pressed.connect(shut)
	close.add_to_group(PadFocus.DEFAULT)
	box.add_child(close)
	refresh()


## Fills in the keys as the input map has them now.
func refresh() -> void:
	var lines: Array[String] = []
	for row: Array in ROWS:
		var keys: Array[String] = []
		for action: String in row[1]:
			keys.append(Controls.key_text(action))
		var k := " / ".join(keys) if not keys.is_empty() else "Escape"
		lines.append("%s: %s · %s · pad %s" % [row[0], k, row[2], row[3]])
	_body.text = "\n".join(lines)


func shut() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		shut()
