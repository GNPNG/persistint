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
## (root.oversampling_override = 2: a headless root is much smaller). Every NPC on every map that
## has them shows a figure: frames or a texture, visible, not faded out, a size on screen (the
## beach psychologists had no art at all; until their own sheets are drawn they show fallback art).
## The Father leaves the beach for the garden just as the Daughter leaves it for the ponies (bd
## b4z3): every way his beach conversation ends, he says he's headed to the house to look at the
## garden and sets the flag that takes him there; each of them, on that flag, walks to the beach's
## door to where they're going and is gone there (no blinking out; with no door, a fade), stays gone
## from the beach, and is at the other place by the same flag.
## Run: godot --headless --path project -s tests/test_florida.gd
## The player's real save (user://save.json) is backed up and restored.

const GARDEN_DIALOGUE := "res://dialogue/florida_garden.dialogue"
const BEACH_DIALOGUE := "res://dialogue/florida_beach.dialogue"
const BEACH := "res://scenes/florida/beach.tscn"
## The Father's last word on the beach, on every ending (bd b4z3), and the flag it sets.
const GARDEN_LINE := "Well, I'm headed to the house to look at the garden. You know where to find me."
const FATHER_FLAG := "fl_father_to_garden"
## Who leaves the beach, the flag that sends them, where they go, and the beach's door to there:
## the Father mirrors the Daughter.
const LEAVERS := [
	["Daughter", "fl_invited_to_horses", "res://scenes/florida/stable.tscn", "StableDoor"],
	["Father", FATHER_FLAG, "res://scenes/florida/garden.tscn", "GardenDoor"],
]
## The walks off the beach run this many times as fast (Engine.time_scale; timed in game seconds).
const TIME_SCALE := 8.0

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

	# The Father heads up to the garden as the Daughter goes to the ponies, both on foot (bd b4z3)
	ws.reset()
	await _beach_father_endings(ws)
	await _leavers(ws)
	await _fade_fallback(ws)

	# Every NPC shows a figure, on the beach and on every other map with NPCs.
	ws.reset()
	await _npcs_visible()

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## The Father in the garden (bd ke5): he is there once he has headed up from the beach (bd b4z3,
## FATHER_FLAG, as the Daughter is at the stable once she has invited you), his first-visit
## conversation explains the beds, the seed bag, what grows and what the bench makes (plant and
## recipe names exactly as the data labels them), it is remembered, and clicking him opens the
## conversation.
func _garden_father(scene: Node, ws: Node) -> void:
	var father: Node = scene.get_node_or_null("Father")
	if father == null:
		_check(false, "garden: the Father is in the garden")
		return
	_check(father.show_if_flag == FATHER_FLAG and not father.is_present() and not father.visible,
		"garden: no Father in the garden before he heads up from the beach (%s)" % FATHER_FLAG)
	ws.set_flag(FATHER_FLAG, true)
	await process_frame
	_check(father.npc_id == "father" and father.is_present() and father.visible and father.input_pickable,
		"garden: the Father is in the garden")
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


## The Father's beach conversation (bd b4z3): every way it can end, from either opener (meeting
## him, back again) down each answer, ends on his line that he's headed to the house to look at the
## garden, said once, and sets FATHER_FLAG, which takes him there (as fl_invited_to_horses takes
## the Daughter to the stable).
func _beach_father_endings(ws: Node) -> void:
	var dm: Node = root.get_node("/root/DialogueManager")
	var res: Resource = load(BEACH_DIALOGUE)
	var endings: Array = []
	for met: bool in [false, true]:
		ws.set_flag("fl_met_father", met)
		ws.set_flag(FATHER_FLAG, false)
		await _endings(dm, res, "father", ws, ["(met before)" if met else "(first meeting)"], endings)
	_check(endings.size() == 6, "beach Father: two openers, three answers each, six ways to end (%d)" % endings.size())
	for e: Array in endings:
		var said: Array = e[0]
		var steps := PackedStringArray()  # the opener and the answers chosen
		for t: String in said:
			if t.begins_with("(") or t.begins_with("> "):
				steps.append(t)
		var way := " ".join(steps)
		_check(said.back() == "Father: " + GARDEN_LINE and said.count("Father: " + GARDEN_LINE) == 1,
			"beach Father %s: his last line is the garden line, once (last: %s)" % [way, said.back()])
		_check(e[1], "beach Father %s: the ending sets %s" % [way, FATHER_FLAG])
	ws.reset()


## Plays the dialogue from `id` to its end down every response (nested ones too) and appends to
## out, for each way it can end, [the lines said on the way (after `said`), whether FATHER_FLAG is
## set at the end]. The flag is cleared at each choice, so each ending answers for itself.
func _endings(dm: Node, res: Resource, id: String, ws: Node, said: Array, out: Array, depth := 0) -> void:
	var path := said.duplicate()
	var line = await dm.get_next_dialogue_line(res, id)
	var steps := 0
	while line != null and steps < 60:
		steps += 1
		path.append("%s: %s" % [line.character, line.text])
		if line.responses.size() > 0:
			for r in line.responses:
				ws.set_flag(FATHER_FLAG, false)
				if depth < 4:
					await _endings(dm, res, r.next_id, ws, path + ["> " + r.text], out, depth + 1)
			return
		line = await dm.get_next_dialogue_line(res, line.next_id)
	out.append([path, ws.has_flag(FATHER_FLAG)])


## The Father mirrors the Daughter (bd b4z3: "just how daughter goes to the ponies", and "walk in
## the direction of the entry points instead of blinking out of existence"). For each in LEAVERS:
## not at the other place before the flag; on the beach, sent by that flag to the beach's door to
## there. With the beach open, the flag set: they set off toward that door at once and stay in
## sight on the way (facing the way they go, not clickable, no body to block the player or set the
## door off), and are gone on reaching it, in about the time the walk takes at npc.gd LEAVE_SPEED,
## the flag set. Coming back to the beach they're gone (also after leaving the beach mid-walk), and
## they're at the other place.
func _leavers(ws: Node) -> void:
	for l: Array in LEAVERS:
		var who: String = l[0]
		var flag: String = l[1]
		var dest: String = l[2]
		ws.reset()
		var there: Node = load(dest).instantiate()
		root.add_child(there)
		await process_frame
		var other: Node = there.get_node_or_null(who)
		_check(other != null and other.show_if_flag == flag and not other.visible and not other.input_pickable,
			"%s: not at %s before %s" % [who, dest.get_file(), flag])
		there.queue_free()
		await process_frame

		var beach: Node = load(BEACH).instantiate()
		root.add_child(beach)
		for i in 3:
			await physics_frame  # the beach's walkable area is in the navigation map
		await process_frame
		var npc: Node2D = beach.get_node(who)
		var door: Node2D = npc.exit_door(dest)
		_check(npc.visible and npc.input_pickable and npc.hide_if_flag == flag and npc.leave_to == dest,
			"%s: on the beach until %s, which sends them to %s" % [who, flag, dest.get_file()])
		_check(door != null and door == beach.get_node(String(l[3])) and door.target_scene == dest,
			"%s: they leave by the beach's %s (%s)" % [who, l[3], door.name if door else "no door"])
		if door == null:
			beach.queue_free()
			await process_frame
			continue
		var start := npc.global_position
		var way := 0.0
		var from := start
		for p: Vector2 in npc.leave_path(door.global_position):
			way += from.distance_to(p)
			from = p
		var speed: float = _npc_const(npc, "LEAVE_SPEED")
		var due := way / speed  # game seconds
		Engine.time_scale = TIME_SCALE
		var t0 := Time.get_ticks_msec()
		ws.set_flag(flag, true)
		for i in 4:
			await process_frame
		var to_door := (door.global_position - start).normalized()
		var went := npc.global_position - start
		_check(npc.visible and npc.is_leaving() and went.length() > 0.0 and went.normalized().dot(to_door) > 0.9,
			"%s: after %s they set off toward the %s, in sight (%.1f px on, heading %.2f)" % [who, flag, door.name, went.length(), went.normalized().dot(to_door)])
		_check(not npc.input_pickable and not npc.get_node("Proximity").monitoring and not (npc is PhysicsBody2D),
			"%s: on the way they can't be clicked or tapped or barked at, and have no body to block the player or set off a door" % who)
		# ...nor used with the E key (player.gd interact_nearest passes over what a click can't pick)
		var player: Node2D = beach.get_node("Player")
		current_scene = beach
		player.global_position = npc.global_position + Vector2(0, 12)
		var picked: Node = player.interact_nearest()
		current_scene = null
		if picked != null:  # walk nowhere: the walk off is what is timed here
			player.set("_interact_target", null)
			player.nav.target_position = player.global_position
		_check(picked != npc, "%s: on the way the E key beside them passes over them (%s)" % [who, picked.name if picked else "nothing"])
		var rig: AnimatedSprite2D = npc.get("rig")
		var anim := String(rig.animation) if rig else ""
		# A Florida sheet's side frames face right (flipped to go left); a rig sheet's face left.
		var facing_ok := (rig == null or (anim.ends_with("side") and rig.flip_h == (to_door.x < 0.0))
			or (anim.ends_with("left") and rig.flip_h == (to_door.x > 0.0)))
		var walk_ok := rig == null or anim.begins_with("walk_") or not rig.sprite_frames.has_animation(anim.replace("idle_", "walk_"))
		_check(facing_ok and walk_ok,
			"%s: they walk facing the way they go, on the sheet's walk frames if it has them (%s, flipped %s)" % [who, anim, rig.flip_h if rig else false])
		var ceiling := (due * 1.5 + 1.0) / TIME_SCALE * 1000.0 + 2000.0  # real ms
		var seen_all_way := true
		var last := npc.global_position
		while npc.visible and Time.get_ticks_msec() - t0 < ceiling:
			last = npc.global_position
			await process_frame
		var took := (Time.get_ticks_msec() - t0) / 1000.0 * TIME_SCALE
		Engine.time_scale = 1.0
		seen_all_way = last.distance_to(door.global_position) < speed * 2.0  # in sight until a frame or so from it
		_check(not npc.visible and not npc.input_pickable and not npc.is_leaving() and ws.has_flag(flag),
			"%s: gone once at the %s, %s set" % [who, door.name, flag])
		_check(seen_all_way and npc.global_position.distance_to(door.global_position) < 1.0,
			"%s: in sight all the way and gone at the %s, not before (last seen %.1f px from it)" % [who, door.name, last.distance_to(door.global_position)])
		_check(took >= due * 0.75 and took <= due * 1.5 + 1.0,
			"%s: the walk takes its time: %.1f s of game time for %.0f px at %.0f px/s (due %.1f s)" % [who, took, way, speed, due])
		_check(not door.get("_gone"), "%s: walking onto the %s doesn't set it off" % [who, door.name])
		beach.queue_free()
		await process_frame

		beach = load(BEACH).instantiate()
		root.add_child(beach)
		await process_frame
		_check(not beach.get_node(who).visible and not beach.get_node(who).input_pickable, "%s: back on the beach, they're gone" % who)
		beach.queue_free()
		await process_frame
		there = load(dest).instantiate()
		root.add_child(there)
		await process_frame
		_check(there.get_node(who).visible and there.get_node(who).input_pickable, "%s: ...and at %s" % [who, dest.get_file()])
		there.queue_free()
		await process_frame

		# The player leaves the beach while they walk: coming back, they're not there.
		ws.reset()
		beach = load(BEACH).instantiate()
		root.add_child(beach)
		await process_frame
		ws.set_flag(flag, true)
		for i in 6:
			await process_frame
		_check(beach.get_node(who).visible and beach.get_node(who).is_leaving(), "%s: walking off the beach" % who)
		beach.queue_free()
		await process_frame
		beach = load(BEACH).instantiate()
		root.add_child(beach)
		await process_frame
		_check(not beach.get_node(who).visible, "%s: the beach left while they walk and come back to, they're gone" % who)
		beach.queue_free()
		await process_frame
	ws.reset()


## With no door to where it's going, an NPC that leaves fades out (npc.gd LEAVE_FADE), never
## blinking out: there still the frame after its flag, part faded on the way, gone when the fade
## ends, in place, its colour back for when it's shown again.
func _fade_fallback(ws: Node) -> void:
	ws.reset()
	var holder := Node2D.new()  # a map with no doors
	root.add_child(holder)
	var npc: Node2D = load("res://scenes/npc/npc.tscn").instantiate()
	npc.npc_id = "father"
	npc.hide_if_flag = "test_leave_fade"
	npc.leave_to = "res://scenes/florida/garden.tscn"
	npc.position = Vector2(200, 300)
	holder.add_child(npc)
	await process_frame
	_check(npc.visible and npc.exit_door(npc.leave_to) == null, "fade: an NPC on a map with no door to where it's going")
	var fade: float = _npc_const(npc, "LEAVE_FADE")
	var t0 := Time.get_ticks_msec()
	ws.set_flag("test_leave_fade", true)
	await process_frame
	_check(npc.visible and npc.is_leaving() and npc.modulate.a > 0.0, "fade: still there the frame after the flag (no blinking out)")
	var part_faded := false
	while npc.visible and Time.get_ticks_msec() - t0 < 3000:
		part_faded = part_faded or (npc.modulate.a > 0.05 and npc.modulate.a < 0.95)
		await process_frame
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	_check(part_faded, "fade: it fades out")
	_check(not npc.visible and not npc.input_pickable and took >= fade * 0.8 and took <= fade + 1.0,
		"fade: gone when the fade ends (%.2f s, the fade %.1f s)" % [took, fade])
	_check(npc.position == Vector2(200, 300) and npc.modulate.a == 1.0, "fade: in place, its colour back for when it's shown again")
	holder.queue_free()
	await process_frame
	ws.reset()


## A constant of an NPC's script (npc.gd), read from the script: the tests never preload it.
func _npc_const(npc: Node, key: String) -> Variant:
	return (npc.get_script() as Script).get_script_constant_map().get(key)


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


## Each map scene with NPCs (scenes/npc/npc.tscn) under scenes/florida and scenes/maps, loaded in
## turn: every NPC there (scripts/npc.gd) that is present shows a figure (_figure_problem).
func _npcs_visible() -> void:
	var maps: Array[String] = []
	for dir: String in ["res://scenes/florida", "res://scenes/maps"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".tscn") and FileAccess.get_file_as_string(dir.path_join(f)).contains("res://scenes/npc/npc.tscn"):
				maps.append(dir.path_join(f))
	_check(maps.has("res://scenes/florida/beach.tscn"), "the maps with NPCs include the beach (%s)" % ", ".join(PackedStringArray(maps)))
	for path: String in maps:
		var scene: Node = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		var npcs: Array = []
		for n: Node in scene.find_children("*", "Area2D", true, false):
			if n.get_script() != null and (n.get_script() as Script).resource_path == "res://scripts/npc.gd":
				npcs.append(n)
		var bad: Array[String] = []
		var present := 0
		for npc: Node in npcs:
			if not npc.is_present():
				continue
			present += 1
			var why := _figure_problem(npc as Node2D)
			if why != "":
				bad.append("%s: %s" % [npc.name, why])
		_check(bad.is_empty(), "%s: every NPC shows a figure (%d of %d present; %s)"
			% [path.get_file(), present, npcs.size(), "; ".join(PackedStringArray(bad)) if not bad.is_empty() else "all visible"])
		if path.ends_with("/beach.tscn"):
			var pair: Array[String] = []
			for who: String in ["Psychologists", "PsychologistMan"]:
				var one: Node = scene.get_node_or_null(who)
				if one != null and one.is_present() and _figure_problem(one as Node2D) == "":
					pair.append(who)
			_check(pair.size() == 2, "beach: both psychologists show under the umbrella (%s)" % ", ".join(PackedStringArray(pair)))
		scene.queue_free()
		await process_frame


## Why an NPC shows no figure, or "": its art (the rig, else its Sprite2D) has frames or a texture,
## is visible, is not faded out and has a size on screen.
func _figure_problem(npc: Node2D) -> String:
	var art: Node2D = npc.get_node_or_null("Sprite2D") as Node2D
	if npc.get("rig") is AnimatedSprite2D:
		art = npc.get("rig")
	if art == null:
		return "no sprite node"
	var tex: Texture2D = null
	var frames := Vector2.ONE
	if art is AnimatedSprite2D:
		var a := art as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
			tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
	elif art is Sprite2D:
		tex = (art as Sprite2D).texture
		frames = Vector2((art as Sprite2D).hframes, (art as Sprite2D).vframes)
	if tex == null:
		return "no texture or frames"
	if not art.is_visible_in_tree():
		return "hidden"
	if _modulate(art).a <= 0.01:
		return "faded out (alpha %.2f)" % _modulate(art).a
	var size := tex.get_size() / frames * art.global_scale.abs()
	if size.x < 4.0 or size.y < 8.0:
		return "%.1f x %.1f px on screen" % [size.x, size.y]
	return ""


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
