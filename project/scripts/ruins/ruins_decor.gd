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
	var title := Label.new()
	title.text = room.get("title", "")
	title.position = Vector2(0, 28)
	title.size = Vector2(960, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(title, 14)
	add_child(title)
	for prop: Dictionary in room.get("props", []):
		_add_prop(prop)
	_lines = room.get("ambient", [])
	_ambient = Label.new()
	_ambient.position = Vector2(80, 504)
	_ambient.size = Vector2(800, 30)
	_ambient.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ambient.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style(_ambient, 9)
	add_child(_ambient)
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
		_style(cap, 8)
		rect.add_child(cap)


func _style(label: Label, size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.25, 0.9))
	label.add_theme_constant_override("outline_size", 3)
