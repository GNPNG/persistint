extends SceneTree
## Headless check of the tropical Florida Keys sandbox: gardening grows with days, crafting
## consumes ingredients, crafted pieces go on the paper doll, critters react to any outfit,
## everything survives save/load, and the maps load. Every seed and item shows by its name from
## the data, and the Father in the garden explains the garden and the craft bench on the first
## visit, in words that match the data (bd ke5).
## Run: godot --headless --path project -s tests/test_florida.gd
## The player's real save (user://save.json) is backed up and restored.

const GARDEN_DIALOGUE := "res://dialogue/florida_garden.dialogue"

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
		var part: String = Florida.data()["recipes"][r]["wear"]["part"]
		_check(ResourceLoader.exists("res://assets/placeholder/%s.png" % part), "placeholder art exists for %s" % r)
		_check(PaperDoll.art_dir_for(["body_base", "dress_white", "hair_braids", part]) == PaperDoll.ART_DIRS[0]
			and ResourceLoader.exists(PaperDoll.part_path(PaperDoll.ART_DIRS[0], part)),
			"%s goes on the canon doll without dropping it to placeholder art" % r)

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

	# Names: every seed, ingredient and made thing shows by its label from the data, never its id
	var named: Array = Florida.data()["seeds"].duplicate()
	for r: String in Florida.data()["recipes"]:
		named.append(r)
		named.append_array(Florida.data()["recipes"][r]["needs"].keys())
	for item: String in named:
		var entry: Dictionary = {}
		for group: String in ["plants", "recipes", "items"]:
			if Florida.data().get(group, {}).has(item):
				entry = Florida.data()[group][item]
		_check(entry.has("label") and Florida.label(item) == entry["label"] and not Florida.label(item).contains("_"),
			"%s has a name in the data (%s)" % [item, Florida.label(item)])

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
				_check(root.get_node("/root/Cast").short(c.nickname) != c.nickname, "%s name comes from cast.json" % c.name)
		_check(scene.get_node("Player") != null, "%s map loads" % m)
		if m == "garden":
			var p: Node = scene.get_node("Plot1")
			ws.reset()
			p.interact()
			_check(p.state() == "growing", "garden: clicking soil plants the selected seed")
			_check(_floated(p) == "%s planted" % Florida.label("hibiscus"), "garden: planting says what went in")
			scene.get_node("SeedBag").interact()
			_check(Florida.selected_seed() == "sea_grape", "garden: the seed bag switches seeds")
			_check(_floated(scene.get_node("SeedBag")) == "Now planting: %s" % Florida.label("sea_grape"),
				"garden: the seed bag says which seed it is now")
			await _garden_father(scene, ws)
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


## The Father in the garden (bd ke5): he is there, his first-visit conversation explains the
## beds, the seed bag, what grows and what the bench makes (plant and recipe names exactly as the
## data labels them), it is remembered, and clicking him opens the conversation.
func _garden_father(scene: Node, ws: Node) -> void:
	var father: Node = scene.get_node_or_null("Father")
	_check(father != null and father.npc_id == "father" and father.is_present(), "garden: the Father is in the garden")
	if father == null:
		return
	_check(father.dialogue_path == GARDEN_DIALOGUE and ResourceLoader.exists(GARDEN_DIALOGUE) and father.dialogue_title == "father",
		"garden: the Father has the garden conversation")
	var dm: Node = root.get_node("/root/DialogueManager")
	var res: Resource = load(GARDEN_DIALOGUE)
	ws.set_flag("fl_met_garden", false)
	var first: Array = []
	await _walk(dm, res, "father", first)
	var text := "\n".join(first)
	_check(text.contains("You found the garden"), "garden intro: the first-visit opener plays")
	_check(ws.has_flag("fl_met_garden"), "garden intro: the first visit is remembered")
	for want: String in ["six beds", "seed bag", "plant it", "water it", "a day sooner", "you pick it", "craft bench",
			"shells from the beach", "wear straight off the bench", "you just keep", "dolphins", "can't plant it wrong"]:
		_check(text.contains(want), "garden intro explains: %s" % want)
	for id: String in Florida.data()["seeds"]:
		_check(text.to_lower().contains(Florida.label(id).to_lower()), "garden intro names %s as the data does" % id)
	for id: String in Florida.data()["recipes"]:
		_check(text.to_lower().contains(Florida.label(id).to_lower()), "garden intro names %s as the data does" % id)
	_check(text.contains("Mango and coconut take four") and int(Florida.data()["plants"]["mango"]["grow_days"]) == 4
		and int(Florida.data()["plants"]["coconut"]["grow_days"]) == 4, "garden intro: grow times match the data")
	for id: String in Florida.data()["plants"]:
		var days := int(Florida.data()["plants"][id]["grow_days"])
		_check(id in ["mango", "coconut"] or days in [2, 3], "garden intro: %s is ready in two or three days" % id)
	_check(not text.contains("{{"), "garden intro: every {{...}} resolves")
	var again: Array = []
	await _walk(dm, res, "father", again)
	_check("\n".join(again).contains("Back in the garden") and not "\n".join(again).contains("You found the garden"),
		"garden intro: a return visit gets the welcome back")
	# Clicking him (arriving beside him) opens the conversation
	father.interact()
	for i in 4:
		await process_frame
	_check(not get_nodes_in_group("dialogue_balloon").is_empty(), "garden: talking to the Father opens the conversation")
	for b in get_nodes_in_group("dialogue_balloon"):
		b.queue_free()
	await process_frame


## Text of the newest floating label over a Florida thing (Clickable.float_text).
func _floated(node: Node) -> String:
	var labels := node.get_children().filter(func(c: Node) -> bool: return c is Label)
	return (labels.back() as Label).text if not labels.is_empty() else ""


## Plays the dialogue from title, following every response into its own branch (nested ones
## too); appends each line's speaker and text to out (as in test_pony_stable.gd).
func _walk(dm: Node, res: Resource, title: String, out: Array, depth := 0) -> void:
	var line = await dm.get_next_dialogue_line(res, title)
	var steps := 0
	while line != null and steps < 60:
		steps += 1
		out.append("%s: %s" % [line.character, line.text])
		if line.responses.size() > 0:
			for r in line.responses:
				out.append("> " + r.text)
				if depth < 4:
					await _walk(dm, res, r.next_id, out, depth + 1)
			return
		line = await dm.get_next_dialogue_line(res, line.next_id)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
