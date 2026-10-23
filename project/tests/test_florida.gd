extends SceneTree
## Headless check of the tropical Florida Keys sandbox: gardening grows with days, crafting
## consumes ingredients, crafted pieces go on the paper doll, critters react to any outfit,
## everything survives save/load, and the maps load.
## Run: godot --headless --path project -s tests/test_florida.gd
## The player's real save (user://save.json) is backed up and restored.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var backup := ""
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	if had_save:
		backup = FileAccess.get_file_as_string(ws.SAVE_PATH)
	ws.reset()

	# Gardening
	_check(Florida.plot_state("p1", 1) == "empty", "plot starts empty")
	_check(Florida.plant("p1", "hibiscus", 1), "plant a seed in an empty plot")
	_check(not Florida.plant("p1", "key_lime", 1), "an occupied plot takes no second seed")
	_check(Florida.plot_state("p1", 1) == "growing", "planted seed is growing")
	_check(Florida.harvest("p1", 1) == "", "nothing to pick before it is ready")
	_check(Florida.water("p1") and not Florida.water("p1"), "water once")
	_check(Florida.plot_state("p1", 2) == "ready", "watered plant is ready a day early")
	Florida.plant("p2", "hibiscus", 1)
	_check(Florida.plot_state("p2", 2) == "growing" and Florida.plot_state("p2", 3) == "ready",
		"unwatered plant still grows, just a day slower")
	_check(Florida.harvest("p1", 2) == "hibiscus" and Florida.count("hibiscus") == 2, "harvest adds yield")
	_check(Florida.plot_state("p1", 2) == "empty", "harvested plot is empty again")
	Florida.harvest("p2", 3)
	_check(Florida.count("hibiscus") == 4, "second harvest")

	# Crafting + paper doll
	_check(Florida.can_craft("flower_crown") and not Florida.can_craft("shell_garland"), "recipes need their ingredients")
	_check(Florida.craft("flower_crown") and Florida.count("hibiscus") == 2 and Florida.count("flower_crown") == 1,
		"crafting consumes ingredients and makes the piece")
	_check(not Florida.wear("shell_garland"), "cannot wear what is not made")
	_check(Florida.wear("flower_crown") and ws.get_flag("outfit_accessory") == "acc_flower_crown", "wear writes the outfit flag")
	var doll: Control = PaperDoll.new()
	root.add_child(doll)
	doll.set_outfit({"body": "body_base", "dress": "dress_teal", "hair": "hair_rose", "accessory": "acc_flower_crown"})
	_check(doll.get_node("Accessory").texture != null, "paper doll shows the crafted crown")
	doll.queue_free()
	for r: String in Florida.data()["recipes"]:
		if not Florida.data()["recipes"][r].has("wear"):
			continue
		_check(ResourceLoader.exists("res://assets/placeholder/%s.png" % Florida.data()["recipes"][r]["wear"]["part"]), "art exists for %s" % r)

	# Critter surprises: every outfit gets one, matching outfits get theirs
	for kind: String in ["dolphin", "crab", "gull", "mermaid"]:
		var plain := Florida.surprise_for(kind, {"accessory": "none"})
		_check(not plain.is_empty() and plain.has("effect"), "%s reacts to a plain outfit" % kind)
	_check(Florida.surprise_for("dolphin", {"accessory": "acc_shell_garland"})["effect"] == "spin", "dolphin: outfit-specific surprise")
	var critter: Area2D = load("res://scenes/florida/critter.tscn").instantiate()
	critter.kind = "gull"
	root.add_child(critter)
	_check(critter.surprise()["effect"] == "spin", "gull spins for the flower crown (worn above)")
	critter.queue_free()
	for kind: String in Florida.data()["critters"]:
		for s: Dictionary in Florida.data()["critters"][kind]["surprises"]:
			_check(s.get("lines", []).size() > 0, "%s surprise has lines" % kind)
		_check(Florida.data()["critters"][kind]["names"].size() > 0, "%s has names" % kind)
	_check(not Florida.wear("key_lime_pie"), "food is not wearable")
	for r: String in Florida.data()["recipes"]:
		for item: String in Florida.data()["recipes"][r]["needs"]:
			_check(item == "shell" or Florida.data()["plants"].has(item), "recipe %s ingredient %s is grown or found" % [r, item])

	# Save/load
	ws.flags = {}
	ws.load_save()
	_check(Florida.count("flower_crown") == 1 and ws.get_flag("outfit_accessory") == "acc_flower_crown",
		"garden, inventory and outfit survive save/load")

	# Maps load; things on them work
	for m in ["beach", "garden", "aquarium"]:
		var scene: Node = load("res://scenes/florida/%s.tscn" % m).instantiate()
		root.add_child(scene)
		await process_frame
		for c in scene.get_children():
			if c.get("kind") != null and c.get("nickname") != null:
				_check(c.nickname in Florida.data()["critters"][c.kind]["names"], "%s has a name from the data" % c.name)
		_check(scene.get_node("Player") != null, "%s map loads" % m)
		if m == "garden":
			var p: Node = scene.get_node("Plot1")
			ws.reset()
			p.interact()
			_check(p.state() == "growing", "garden: clicking soil plants the selected seed")
			scene.get_node("SeedBag").interact()
			_check(Florida.selected_seed() == "sea_grape", "garden: the seed bag switches seeds")
		if m == "beach":
			var shell: Node = scene.get_node("Shell1")
			shell.interact()
			_check(Florida.count("shell") == 1 and not shell.visible, "beach: a shell can be picked up")
		scene.queue_free()
		await process_frame

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
