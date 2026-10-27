extends Area2D
## Mirror — click to walk over and open the wardrobe (paper-doll) overlay.


func _ready() -> void:
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("click"):
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


func interact() -> void:
	var map := get_tree().current_scene
	if map.has_method("toggle_wardrobe"):
		map.toggle_wardrobe()
