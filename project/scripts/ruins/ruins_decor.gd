extends Node2D
## RuinsDecor — a ruins room's set dressing, read from data/ruins.json ("rooms"): a title,
## non-blocking props (coloured slabs with a caption) and ambient lines that cycle slowly.

const ForbiddenKnowledge := preload("res://scripts/ruins/forbidden_knowledge.gd")
const AMBIENT_SECONDS := 7.0

@export var room_id := ""

var _lines: Array = []
var _next := 0
var _ambient: Label


func _ready() -> void:
	var room: Dictionary = ForbiddenKnowledge.data().get("rooms", {}).get(room_id, {})
	# Title and ambient lines are read on screen, not in the room: the camera only
	# shows a slice of the room, so world-space text that wide never fits the view.
	var screen := CanvasLayer.new()
	screen.name = "RoomText"
	add_child(screen)
	var title := Label.new()
	title.text = room.get("title", "")
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 3
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(title, 11)
	screen.add_child(title)
	for prop: Dictionary in room.get("props", []):
		_add_prop(prop)
	_lines = room.get("ambient", [])
	_ambient = Label.new()
	_ambient.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_ambient.offset_left = 40
	_ambient.offset_right = -40
	_ambient.offset_top = -30
	_ambient.offset_bottom = -6
	_ambient.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ambient.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ambient.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_ambient.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(_ambient, 9)
	screen.add_child(_ambient)
	if not _lines.is_empty():
		var timer := Timer.new()
		timer.wait_time = AMBIENT_SECONDS
		timer.timeout.connect(_show_next)
		add_child(timer)
		timer.start()
		_show_next()


func _show_next() -> void:
	_ambient.text = _lines[_next % _lines.size()]
	_next += 1


func _add_prop(prop: Dictionary) -> void:
	var c: Array = prop.get("color", [0.5, 0.5, 0.5])
	var rect := ColorRect.new()
	rect.position = Vector2(prop["x"], prop["y"])
	rect.size = Vector2(prop["w"], prop["h"])
	rect.color = Color(c[0], c[1], c[2], 0.55)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var text: String = prop.get("text", "")
	if text != "":
		var cap := Label.new()
		cap.text = text
		cap.size = rect.size
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style(cap, 5, 2)
		rect.add_child(cap)


## World-space captions sit under the camera's 2x zoom, so they take half the screen size.
func _style(label: Label, size: int, outline := 2) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.25, 0.9))
	label.add_theme_constant_override("outline_size", outline)
