extends Area2D
## Clickable — base for Florida things: click to walk over, interact() on arrival.


func _ready() -> void:
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


## Small floating label above the thing (item gained, seed picked).
func float_text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.position = Vector2(-40, -44)
	l.custom_minimum_size = Vector2(80, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(0.3, 0.2, 0.3))
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", -64.0, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)
