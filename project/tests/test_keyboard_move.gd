extends SceneTree
func _initialize() -> void:
	change_scene_to_file("res://scenes/maps/village.tscn")
	await process_frame
	await process_frame
	var p: Node2D = current_scene.get_tree().get_first_node_in_group("player")
	var start := p.global_position
	Input.action_press("move_right")
	for i in 30: await physics_frame
	Input.action_release("move_right")
	var moved := p.global_position.x - start.x
	print("RESULT: ", "PASS" if moved > 20.0 else "FAIL", " moved_x=", moved)
	quit()
