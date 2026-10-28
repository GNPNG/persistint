extends SceneTree
## Headless check of the tropical Florida Keys sandbox: gardening grows with days, crafting
## consumes ingredients, crafted pieces go on the paper doll, critters react to any outfit,
## everything survives save/load, and the maps load. Every seed and item shows by its name from
## the data, and the Father in the garden explains the garden and the craft bench on the first
## visit, in words that match the data (bd ke5). A thing's floating text (the seed's name, a
## shell's +1) stays inside the camera's view and outlives a thing that hides (bd wso.2), and is
## drawn at the screen's resolution, its font rasterized at the viewport's oversampling times the
## camera's zoom, in plum on a white outline (STYLE.md 4.8) at full opacity until it fades at the
## end of its rise (bd wso.4: the seed bag's "Now planting" was drawn at half the resolution and
## fading from the start, and read pale grey). The window is 1280x720 as in the game
## (root.oversampling_override = 2: a headless root is much smaller).
## Run: godot --headless --path project -s tests/test_florida.gd
## The player's real save (user://save.json) is backed up and restored.

const GARDEN_DIALOGUE := "res://dialogue/florida_garden.dialogue"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.oversampling_override = 2.0  # the 1280x720 window's stretch
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
			await _float_in_view(scene, "SeedBag", Vector2(0, 34), "approached from below (high in the view)")
			await _float_in_view(scene, "SeedBag", Vector2(150, 0), "at the left edge of the view")
			var rose: float = await _float_in_view(scene, "SeedBag", Vector2(0, -30), "low in the view")
			var rise: float = scene.get_node("SeedBag").FLOAT_RISE  # Clickable's
			_check(rose >= rise - 1.0, "garden: with room above, the text rises its full %.0f px (%.1f)" % [rise, rose])
		if m == "beach":
			var shell: Node = scene.get_node("Shell1")
			shell.interact()
			_check(Florida.count("shell") == 1 and not shell.visible, "beach: a shell can be picked up")
			var plus := _float_label(shell)
			_check(plus != null and plus.is_visible_in_tree() and plus.text == "+1 %s" % Florida.label("shell"),
				"beach: the shell's +1 floats up though the shell is gone")
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
	var l := _float_label(node)
	return l.text if l != null else ""


## The newest floating label over a Florida thing: it hangs in the thing's parent, marked with the
## thing's name ("over").
func _float_label(node: Node) -> Label:
	var labels := node.get_parent().get_children().filter(func(c: Node) -> bool:
		return c is Label and c.get_meta("over", &"") == node.name)
	return (labels.back() as Label) if not labels.is_empty() else null


## With the player standing at `stand` from a thing, its floating text is inside the camera's view
## over its whole rise (the seed bag approached from below floated its name off the top: bd
## wso.2). Returns how far the text rose.
func _float_in_view(scene: Node, thing_name: String, stand: Vector2, what: String) -> float:
	var thing: Node2D = scene.get_node(thing_name)
	var player: Node2D = scene.get_node("Player")
	var cam: Camera2D = player.get_node("Camera2D")
	player.global_position = thing.global_position + stand
	cam.reset_smoothing()
	cam.force_update_scroll()
	await process_frame
	thing.interact()
	var l := _float_label(thing)
	if l == null:
		_check(false, "garden: the %s floats a label" % thing_name)
		return 0.0
	var font := l.get_theme_font("font") as FontFile
	var want := root.get_oversampling() * absf(l.get_global_transform_with_canvas().get_scale().y)  # the camera's zoom
	_check(font != null and absf(font.oversampling - want) <= 0.125,
		"garden: the %s's text is drawn at the screen's resolution (oversampling %.2f for %.2f)" % [thing_name, font.oversampling if font else 0.0, want])
	var fill := l.get_theme_color("font_color")
	var edge := l.get_theme_color("font_outline_color")
	_check(fill.is_equal_approx(Color("#593859")) and edge == Color.WHITE and l.get_theme_constant("outline_size") >= 2,
		"garden: the %s's text is plum on a white outline (%s on %s)" % [thing_name, fill.to_html(false), edge.to_html(false)])
	var start := l.global_position.y
	var least := INF  # how far inside the view the text came, at the least
	var rose := 0.0
	var t0 := Time.get_ticks_msec()
	var early := 1.0  # its least opacity over the first 0.6 s (it fades from 0.8 s)
	while is_instance_valid(l):
		if Time.get_ticks_msec() - t0 < 600:
			early = minf(early, _modulate(l).a)
		var half := root.get_visible_rect().size / cam.zoom / 2.0
		var view := Rect2(cam.get_screen_center_position() - half, half * 2.0)
		var text := _text_rect(l)
		least = minf(least, minf(text.position.y - view.position.y, minf(text.position.x - view.position.x, view.end.x - text.end.x)))
		rose = maxf(rose, start - l.global_position.y)
		await process_frame
	_check(least >= 0.0, "garden: the %s's text, %s, stays inside the view (%.1f px in at the least)" % [thing_name, what, least])
	_check(early == 1.0, "garden: the %s's text is opaque until it fades at the end of its rise (%.2f at the least)" % [thing_name, early])
	return rose


## The colour a canvas item's own drawing is multiplied by: its self_modulate and the modulate
## of it and of every canvas item over it.
func _modulate(c: CanvasItem) -> Color:
	var m := c.self_modulate
	var n: Node = c
	while n is CanvasItem:
		m *= (n as CanvasItem).modulate
		n = n.get_parent()
	return m


## Where a floating label's one line of text is drawn: centred across its rect.
func _text_rect(l: Label) -> Rect2:
	var font := l.get_theme_font("font")
	var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x
	var r := l.get_global_rect()
	return Rect2(r.position.x + (r.size.x - w) / 2.0, r.position.y, w, r.size.y)


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
