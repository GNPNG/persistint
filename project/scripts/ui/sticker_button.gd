class_name StickerButton
extends Control
## A floating sticker under the settings gear (top right) that a finger or a click can press: the
## wardrobe's clothes hanger or the journal's book (author 2026-10-24, bd ctw: "float like a little
## icon ... a little animated like clothes hanger"). Drawn here in the gear's colours, so it needs
## no texture; it sways a little so it reads as a toy, not a toolbar. Replace with rendered art
## when it lands; the map only needs `pressed`.

signal pressed

const SIZE := 32.0
const MARGIN := 8.0
const FACE := Color(0.992, 0.965, 0.89)       # cream
const OUTLINE := Color(0.349, 0.22, 0.349)    # plum
const ACCENT := Color(0.988, 0.906, 0.937)    # blush
const SWAY_DEGREES := 6.0
const SWAY_SECONDS := 2.4

## "hanger" (wardrobe) or "book" (journal).
@export var kind := "hanger"
## Which slot under the gear: 1 is the first one below it.
@export var slot := 1

var _down := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = Vector2(SIZE / 2.0, 2.0)  # it hangs from its top, like a hanger on a rail
	tooltip_text = {"hanger": "Wardrobe (P)", "book": "Journal (J)"}.get(kind, "")
	_t = slot * 0.7  # neighbours don't sway in step
	_place()
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	position = Vector2(get_viewport_rect().size.x - SIZE - MARGIN, MARGIN + slot * (SIZE + MARGIN))


func _process(delta: float) -> void:
	_t += delta
	rotation_degrees = sin(_t * TAU / SWAY_SECONDS) * SWAY_DEGREES


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-2.0)
	draw_rect(r, FACE if not _down else ACCENT)
	draw_rect(r, OUTLINE, false, 2.0)
	var c := size / 2.0
	if kind == "hanger":
		# hook, then the triangle shoulders and the bar
		draw_arc(c + Vector2(0, -8), 3.0, PI, TAU * 0.95, 12, OUTLINE, 2.0, true)
		var neck := c + Vector2(0, -5)
		var left := c + Vector2(-10, 5)
		var right := c + Vector2(10, 5)
		draw_polyline(PackedVector2Array([neck, left, right, neck]), OUTLINE, 2.0, true)
		draw_line(neck, neck + Vector2(0, -0.5), OUTLINE, 2.0)
	else:
		# a closed book: cover, spine and page edge
		var cover := Rect2(c + Vector2(-8, -10), Vector2(16, 20))
		draw_rect(cover, ACCENT)
		draw_rect(cover, OUTLINE, false, 2.0)
		draw_line(cover.position + Vector2(4, 0), cover.position + Vector2(4, cover.size.y), OUTLINE, 2.0)
		draw_line(cover.position + Vector2(7, 6), cover.end - Vector2(3, 14), OUTLINE, 1.5)


func _gui_input(event: InputEvent) -> void:
	var down: bool
	if event.is_action("click"):
		down = event.pressed
	elif event is InputEventScreenTouch:
		down = event.pressed
	else:
		return
	if down:
		_down = true
		queue_redraw()
	elif _down:
		_down = false
		queue_redraw()
		accept_event()
		pressed.emit()
