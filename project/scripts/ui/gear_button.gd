class_name GearButton
extends Control
## A floating sticker gear at the top right that opens the settings screen with a tap or a click.
## Drawn here (cream face, plum outline, eight teeth) so it needs no texture; sized for a finger.

signal pressed

const SIZE := 32.0
const MARGIN := 8.0
const FACE := Color(0.992, 0.965, 0.89)       # cream
const OUTLINE := Color(0.349, 0.22, 0.349)    # plum
const HOLE := Color(0.988, 0.906, 0.937)      # blush

var _down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	position = Vector2(get_viewport_rect().size.x - SIZE - MARGIN, MARGIN)
	tooltip_text = "Settings"
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	position = Vector2(get_viewport_rect().size.x - SIZE - MARGIN, MARGIN)


func _draw() -> void:
	var c := size / 2.0
	var r := SIZE * 0.36
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 2:
		var a := TAU * i / (teeth * 2)
		var rad := r * (1.25 if i % 2 == 0 else 0.95)
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, FACE if not _down else HOLE)
	pts.append(pts[0])
	draw_polyline(pts, OUTLINE, 2.0, true)
	draw_circle(c, r * 0.4, HOLE)
	draw_arc(c, r * 0.4, 0.0, TAU, 24, OUTLINE, 2.0, true)


func _gui_input(event: InputEvent) -> void:
	if event.is_action("click"):
		if event.pressed:
			_down = true
			queue_redraw()
		elif _down:
			_down = false
			queue_redraw()
			accept_event()
			pressed.emit()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_down = true
			queue_redraw()
		elif _down:
			_down = false
			queue_redraw()
			accept_event()
			pressed.emit()
