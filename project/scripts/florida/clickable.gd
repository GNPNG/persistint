extends Area2D
## Clickable — base for Florida things: click to walk over, interact() on arrival.


func _ready() -> void:
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("click"):
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


## A floating label starts this far over the thing's origin and rises FLOAT_RISE as it fades.
const FLOAT_START := 44.0
const FLOAT_RISE := 20.0
const FLOAT_SECONDS := 1.2


## Small floating label above the thing (item gained, seed picked). It stays inside the camera's
## view as a bark bubble does: over a thing high in the view (the seed bag or a bed approached
## from below, the player stopping about 34 px under it) it rises only to the top edge instead of
## out of the view, and it slides in from a side edge. It is drawn over everyone near (z 20, as
## bubbles and door names) and hangs in the thing's parent, marked with the thing's name ("over"),
## so it outlives a thing that hides when it is picked (a shell, whose "+1" never showed).
func float_text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(80, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 20
	l.add_theme_font_size_override("font_size", 5)
	l.add_theme_color_override("font_color", Color(0.3, 0.2, 0.3))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 2)
	l.set_meta("over", name)
	var host: Node = get_parent() if get_parent() is Node2D else self
	host.add_child(l)
	l.reset_size()
	var base := position if host != self else Vector2.ZERO  # the thing's origin in the host
	var at := global_position
	_place_float(l, base, at, -FLOAT_START)
	var tw := l.create_tween()
	tw.tween_method(func(y: float) -> void: _place_float(l, base, at, y), -FLOAT_START, -FLOAT_START - FLOAT_RISE, FLOAT_SECONDS)
	tw.parallel().tween_property(l, "modulate:a", 0.0, FLOAT_SECONDS)
	tw.tween_callback(l.queue_free)


## Puts a floating label `y` over a thing standing at `at` (global; `base` in the label's parent),
## centred on it, inside the camera's view across and under the view's top.
static func _place_float(l: Label, base: Vector2, at: Vector2, y: float) -> void:
	var dx := 0.0
	var cam := l.get_viewport().get_camera_2d()
	if cam:
		var half := l.get_viewport().get_visible_rect().size / cam.zoom / 2.0
		var center := cam.get_screen_center_position()
		var font := l.get_theme_font("font")
		var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
		w = minf(w + 2.0 * l.get_theme_constant("outline_size"), l.size.x)
		var lo := center.x - half.x + w / 2.0 + 2.0
		var hi := maxf(lo, center.x + half.x - w / 2.0 - 2.0)
		dx = clampf(at.x, lo, hi) - at.x
		y += maxf(0.0, center.y - half.y + 2.0 - (at.y + y))
	l.position = base + Vector2(-l.size.x / 2.0 + dx, y)
	WorldText.fit(l)  # drawn at the screen's resolution under the camera's zoom (bd wso.4)
