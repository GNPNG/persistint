extends SceneTree
## Screenshot tool — loads each main scene, waits a few frames and saves the
## viewport as a PNG. Needs a display (not --headless):
##   godot --path project -s tools/screenshot_scenes.gd -- <out_dir> [prefix] [filter]
## [filter] is an optional comma-separated list of shot names, or one substring ("ruins");
## only matching shots are taken; without it every shot is taken.
## The run never touches the player's save: WorldState is pointed at <out_dir>/save.json and
## seeded with a fixed state (SEED) so every run shoots the same thing.

## Island chapter, two pieces recovered (the Landing flashback unlocked and active for its
## card), one tactic named, so the journal, chapter card and flashback card all have content.
const SEED := {
	"chapter": "island",
	"_clock": {"day": 4, "phase_index": 0},
	"forbidden_knowledge": ["fk_wreck_2", "fk_corridor_1"],
	"journal": {"negging": ["The Covenant loves an easy girl."]},
	"flashback_active": {"id": "landing", "chapter": "island",
		"origin": {"scene": "res://scenes/maps/village.tscn", "spawn": "spawn_default"}},
}

const SHOTS := [
	["main_menu", "res://scenes/ui/main_menu.tscn", ""],
	["village", "res://scenes/maps/village.tscn", ""],
	["temple", "res://scenes/maps/temple.tscn", ""],
	["ruins_wreck", "res://scenes/ruins/ruins_wreck.tscn", ""],
	["ruins_corridor", "res://scenes/ruins/ruins_corridor.tscn", ""],
	["ruins_core", "res://scenes/ruins/ruins_core.tscn", ""],
	["ruins_bunker_lift", "res://scenes/ruins/ruins_bunker_lift.tscn", ""],
	["clone_hall", "res://scenes/ruins/ruins_clone_hall.tscn", ""],
	["ruins_clone_hall_bark", "res://scenes/ruins/ruins_clone_hall.tscn", "clone_bark"],
	["ruins_clone_hall_east", "res://scenes/ruins/ruins_clone_hall.tscn", "east"],
	["ruins_records", "res://scenes/ruins/ruins_records.tscn", ""],
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
	["beach_crown", "res://scenes/florida/beach.tscn", "crown"],
	["chapter_end", "res://scenes/chapters/chapter_end.tscn", ""],
	["next_top_comic", "res://scenes/minigames/next_top_comic.tscn", ""],
	["hottest_of_the_hot", "res://scenes/minigames/hottest_of_the_hot.tscn", ""],
	["flashback_card", "res://scenes/chapters/flashback_card.tscn", ""],
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
	var filter: String = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws := root.get_node("WorldState")
	ws.SAVE_PATH = out_dir.path_join("save.json")
	ws.flags = SEED.duplicate(true)
	ws.save()
	root.get_node("GameClock").restore()
	await _wait(5)
	for shot: Array in SHOTS:
		if filter != "" and not (shot[0] in filter.split(",") or (not "," in filter and filter in shot[0])):
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
			"crown":
				# A crafted Florida wearable on the canon doll (assets/florida/acc_flower_crown.png).
				root.get_node("WorldState").set_flag("outfit_accessory", "acc_flower_crown")
				current_scene.get_tree().get_first_node_in_group("player").refresh_outfit()
			"near_npc":
				var p := current_scene.get_tree().get_first_node_in_group("player") as Node2D
				for n in current_scene.find_children("*", "", true, false):
					var sc: Script = n.get_script()
					if sc != null and sc.resource_path.get_file() == "npc.gd" and n.visible:
						p.global_position = n.global_position + Vector2(40, 0)
						break
			"clone_bark":
				for n in current_scene.get_children():
					if n.is_in_group("zombie_clones"):
						n.bark("barks")
						break
				for n in current_scene.get_children():
					if n.is_in_group("polar_cubs"):
						n.say("Mrrf!")
						break
			"east":
				var p := current_scene.get_tree().get_first_node_in_group("player") as Node2D
				p.global_position = Vector2(820, 300)
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
						n.bubble.say("Lovely morning! Everyone contributes. Everyone.")
						player.global_position = n.global_position + Vector2(30, 10)
						break
		await _wait(60)
		var img := root.get_viewport().get_texture().get_image()
		var path := "%s/%s%s.png" % [out_dir, prefix, shot[0]]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
		if shot[2] == "crown":
			root.get_node("WorldState").set_flag("outfit_accessory", "none")
		for b in root.get_children():
			if b is CanvasLayer and b.get_parent() == root:
				b.queue_free()
	quit()
