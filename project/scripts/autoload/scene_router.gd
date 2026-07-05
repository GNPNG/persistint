extends Node
## SceneRouter — map transitions with named spawn points.
## Maps read `next_spawn` on ready and place the player at the matching Marker2D.

var next_spawn := "spawn_default"


func goto_map(scene_path: String, spawn := "spawn_default") -> void:
	next_spawn = spawn
	get_tree().call_deferred("change_scene_to_file", scene_path)
