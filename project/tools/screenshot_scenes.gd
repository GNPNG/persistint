extends SceneTree
## Screenshot tool — loads each main scene, waits a few frames and saves the
## viewport as a PNG. Needs a display (not --headless):
##   godot --path project -s tools/screenshot_scenes.gd -- <out_dir> [prefix] [filter]
## [filter] is an optional comma-separated list of shot names to capture.

const SHOTS := [
	["main_menu", "res://scenes/ui/main_menu.tscn", ""],
	["village", "res://scenes/maps/village.tscn", ""],
	["temple", "res://scenes/maps/temple.tscn", ""],
	["ruins_wreck", "res://scenes/ruins/ruins_wreck.tscn", ""],
	["clone_hall", "res://scenes/ruins/ruins_clone_hall.tscn", ""],
	["beach", "res://scenes/florida/beach.tscn", ""],
	["interview", "res://scenes/minigames/interview.tscn", ""],
	["landing", "res://scenes/minigames/landing.tscn", ""],
	["hottest_chains", "res://scenes/minigames/hottest_chains.tscn", ""],
	["ritual_puzzle", "res://scenes/minigames/ritual_puzzle.tscn", ""],
	["wardrobe", "res://scenes/maps/village.tscn", "wardrobe"],
	["dialogue", "res://scenes/maps/village.tscn", "dialogue"],
	["journal", "res://scenes/maps/village.tscn", "journal"],
	["choices", "res://scenes/maps/village.tscn", "choices"],
	["village_door", "res://scenes/maps/village.tscn", "door"],
	["village_bark", "res://scenes/maps/village.tscn", "bark"],
	["florida_garden", "res://scenes/florida/garden.tscn", ""],
	["florida_stable", "res://scenes/florida/stable.tscn", ""],
	["florida_aquarium", "res://scenes/florida/aquarium.tscn", ""],
	["beach_talk", "res://scenes/florida/beach.tscn", "near_npc"],
	["chapter_end", "res://scenes/chapters/chapter_end.tscn", ""],
]


func _initialize() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	var prefix: String = args[1] if args.size() > 1 else ""
	var only: PackedStringArray = args[2].split(",") if args.size() > 2 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _wait(5)
	for shot: Array in SHOTS:
		if not only.is_empty() and not only.has(shot[0]):
			continue
		change_scene_to_file(shot[1])
		await _wait(10)
		match shot[2]:
			"wardrobe":
				current_scene.toggle_wardrobe()
			"journal":
				current_scene.toggle_journal()
			"dialogue":
				root.get_node("DialogueManager").show_dialogue_balloon(load("res://dialogue/priestess.dialogue"), "start")
			"choices":
				var dm := root.get_node("DialogueManager")
				var res: Resource = dm.create_resource_from_text("~ start\nPriestess Betty: Everyone contributes, initiate. What will you offer the Queen Mothers today?\n- I brought flowers from the garden, the pink ones you like.\n- Nothing. I am still thinking about what the offering is for.\n- Whatever the others are offering, but a little bit more of it.\n=> END")
				dm.show_dialogue_balloon(res, "start")
			"near_npc":
				var p := current_scene.get_tree().get_first_node_in_group("player") as Node2D
				for n in current_scene.find_children("*", "", true, false):
					var sc: Script = n.get_script()
					if sc != null and sc.resource_path.get_file() == "npc.gd" and n.visible:
						p.global_position = n.global_position + Vector2(40, 0)
						break
			"door", "bark":
				var player := current_scene.get_tree().get_first_node_in_group("player") as Node2D
				for n in current_scene.find_children("*", "", true, false):
					var script: Script = n.get_script()
					if script == null:
						continue
					var file := script.resource_path.get_file()
					if shot[2] == "door" and file == "door.gd":
						player.global_position = n.global_position + Vector2(0, 30)
						break
					if shot[2] == "bark" and file == "npc.gd":
						n.bubble.text = "Lovely morning! Everyone contributes. Everyone."
						n.bubble.show()
						player.global_position = n.global_position + Vector2(30, 10)
						break
		await _wait(60)
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s%s.png" % [out_dir, prefix, shot[0]]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
		for b in root.get_children():
			if b is CanvasLayer and b.get_parent() == root:
				b.queue_free()
	quit()
