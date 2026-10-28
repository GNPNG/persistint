extends SceneTree
## Headless check of the Florida pony stable: grooming writes the pony's paper-doll parts,
## riding makes click-to-move faster with the pony drawn under the doll, foals inherit one
## allele per gene from each parent (seeded, deterministic, Mendelian), the herd and the ride
## survive save/load, the panel's buttons (Foal, Hop down) and the H key work, the Daughter moves
## from the beach to the stable once she invites you (walking off to the stable door, bd b4z3;
## test_florida.gd checks the walk and that the Father leaves for the garden the same way), Hannah
## brushes a pony, every branch of the stable dialogue plays, and the beach <-> stable doors sit on
## the walkable area, land on real spawn markers and go through SceneRouter.
## Run: godot --headless --path project -s tests/test_pony_stable.gd
## WorldState saves to a temp file for the run; the player's real save is never touched.

const TEMP_SAVE := "user://test_pony_stable_save.json"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var cast: Node = root.get_node("/root/Cast")
	var real_save: String = ws.SAVE_PATH
	ws.SAVE_PATH = TEMP_SAVE
	ws.reset()

	# The herd: starters arrive, every name comes from cast.json, every part has art
	var ids: Array = Ponies.ids()
	_check(ids.size() == Ponies.data()["starters"].size() and ids.size() >= 2, "starter ponies arrive")
	for id: String in ids + Ponies.data()["foal_names"]:
		_check(cast.short(id) != id, "%s has a name in cast.json" % id)
	for coat: String in Ponies.data()["genes"]["coat"]["alleles"]:
		_check(ResourceLoader.exists(Ponies.ART % "body_%s" % coat), "art for %s coat" % coat)
	for style: String in Ponies.data()["groom"]["mane_style"]:
		for mane: String in Ponies.data()["genes"]["mane"]["alleles"]:
			_check(ResourceLoader.exists(Ponies.ART % "mane_%s_%s" % [style, mane]), "art for %s %s mane" % [mane, style])
	for acc: String in Ponies.data()["groom"]["accessory"]:
		_check(acc == "none" or ResourceLoader.exists(Ponies.ART % "acc_%s" % acc), "art for %s" % acc)
	_check(ResourceLoader.exists(Ponies.ART % "spots") and ResourceLoader.exists(Ponies.ART % "sparkle"), "art for spots and sparkle")
	for kind: String in Ponies.data()["lines"]:
		_check(Ponies.data()["lines"][kind].size() > 0, "pony lines: %s" % kind)

	# Grooming: the paper-doll makeover on a pony
	var a: String = ids[0]
	var b: String = ids[1]
	_check(Ponies.groom(a, "mane_style", "braids") and Ponies.pony(a)["groom"]["mane_style"] == "braids", "groom sets the mane style")
	_check(Ponies.groom(a, "accessory", "flower_crown"), "groom puts on an accessory")
	_check(not Ponies.groom(a, "accessory", "crown_of_thorns"), "only accessories from the data")
	_check(not Ponies.groom(a, "coat", "mint"), "grooming never changes genes")
	_check(Ponies.parts(a)["mane"] == "mane_braids_%s" % Ponies.phenotype(a, "mane") and Ponies.parts(a)["accessory"] == "acc_flower_crown",
		"groomed look becomes doll parts")
	_check(Ponies.parts(a)["sparkle"] == "none" and Ponies.brush(a) and Ponies.parts(a)["sparkle"] == "sparkle", "brushing makes the pony sparkle")
	var before: String = Ponies.pony(b)["groom"]["mane_style"]
	_check(Ponies.cycle(b, "mane_style") != before, "groom cycle picks the next style")
	var doll := PonyDoll.new()
	root.add_child(doll)
	doll.set_outfit(Ponies.parts(a))
	_check(doll.layer("body").texture != null and doll.layer("mane").texture != null and doll.layer("accessory").texture != null
		and doll.layer("sparkle").texture != null, "PonyDoll stacks body, mane, accessory and sparkle")
	doll.set_part("accessory", "none")
	_check(doll.layer("accessory").texture == null, "PonyDoll: taking an accessory off")
	doll.queue_free()

	# Genetics: dominance, seeded determinism, every allele from a parent, Mendelian ratios
	var het := {"genes": {"coat": ["honey", "cloud"], "mane": ["rose", "lavender"], "spots": ["dappled", "plain"]}}
	var rec := {"genes": {"coat": ["cloud", "cloud"], "mane": ["lavender", "lavender"], "spots": ["plain", "plain"]}}
	var dom := {"genes": {"coat": ["honey", "honey"], "mane": ["rose", "rose"], "spots": ["dappled", "dappled"]}}
	_check(Ponies.phenotype(het, "coat") == "honey" and Ponies.phenotype(het, "spots") == "dappled", "the dominant allele is the one you see")
	_check(Ponies.phenotype(rec, "coat") == "cloud", "two recessive alleles show")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 42
	var r2 := RandomNumberGenerator.new()
	r2.seed = 42
	_check(Ponies.cross(het, het, r1) == Ponies.cross(het, het, r2), "same seed, same foal")
	var all_dom := true
	var all_rec := true
	var dappled := 0
	var cloud := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var from_parents := true
	for i in 400:
		var f: Dictionary = {"genes": Ponies.cross(dom, rec, rng)}
		all_dom = all_dom and Ponies.phenotype(f, "coat") == "honey" and Ponies.phenotype(f, "mane") == "rose" and Ponies.phenotype(f, "spots") == "dappled"
		var g: Dictionary = {"genes": Ponies.cross(rec, rec, rng)}
		all_rec = all_rec and Ponies.phenotype(g, "coat") == "cloud" and Ponies.phenotype(g, "spots") == "plain"
		var h: Dictionary = {"genes": Ponies.cross(het, het, rng)}
		for gene: String in h["genes"]:
			from_parents = from_parents and h["genes"][gene][0] in het["genes"][gene] and h["genes"][gene][1] in het["genes"][gene]
		dappled += 1 if Ponies.phenotype(h, "spots") == "dappled" else 0
		cloud += 1 if Ponies.phenotype(h, "coat") == "cloud" else 0
	_check(all_dom, "dominant x recessive: every foal shows the dominant traits")
	_check(all_rec, "recessive x recessive: every foal shows the recessive traits")
	_check(from_parents, "every foal allele comes from a parent")
	_check(dappled > 270 and dappled < 330, "carrier x carrier: about three in four dappled (%d/400)" % dappled)
	_check(cloud > 70 and cloud < 130, "carrier x carrier: a hidden colour shows about one in four (%d/400)" % cloud)

	# Breeding in the stable: the foal joins the herd
	var today: int = root.get_node("/root/GameClock").day
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 2026
	var foal := Ponies.breed(a, b, today, seeded)
	_check(foal == Ponies.data()["foal_names"][0] and Ponies.ids().has(foal), "a foal joins the stable with a cast name")
	_check(Ponies.pony(foal)["parents"] == [a, b], "the foal knows its parents")
	for gene: String in Ponies.data()["genes"]:
		var fg: Array = Ponies.pony(foal)["genes"][gene]
		_check(fg[0] in Ponies.pony(a)["genes"][gene] and fg[1] in Ponies.pony(b)["genes"][gene], "foal %s: one allele from each parent" % gene)
	var replay := RandomNumberGenerator.new()
	replay.seed = 2026
	_check(Ponies.cross(Ponies.pony(a), Ponies.pony(b), replay) == Ponies.pony(foal)["genes"], "seeded foal is reproducible")
	_check(Ponies.is_foal(foal, today) and not Ponies.is_foal(foal, today + int(Ponies.data()["foal_grow_days"])), "foals grow up")
	_check(not Ponies.mount(foal, today) and Ponies.breed(foal, a, today) == "", "foals are too little to ride or have foals")
	_check(Ponies.breed(a, a, today) == "", "a pony needs a friend to have a foal")
	var next := Ponies.breed(a, b, today)
	_check(next == Ponies.data()["foal_names"][1], "the next foal gets the next name")

	# Riding: faster click-to-move, pony under the doll, hop down
	var stable: Node = load("res://scenes/florida/stable.tscn").instantiate()
	root.add_child(stable)
	await process_frame
	var player: Node = stable.get_node("Player")
	_check(is_equal_approx(player.current_speed(), player.SPEED) and not player.is_mounted(), "on foot at walking speed")
	_check(stable.pony_node(a) != null and stable.pony_node(a).visible, "the stable shows every pony")
	_check(stable.pony_node(foal) != null and stable.pony_node(foal).doll.scale.x < 1.0, "foals are drawn little")
	_check(Ponies.mount(a, today), "hop on a grown-up pony")
	await process_frame
	var mult := float(Ponies.data()["ride_speed_multiplier"])
	_check(mult > 1.0 and is_equal_approx(player.current_speed(), player.SPEED * mult), "riding is faster (x%s)" % mult)
	_check(player.is_mounted() and player.mount_doll.layer("body").texture != null, "the pony is drawn under the player")
	_check(player.get_children().find(player.mount_doll) < player.get_children().find(player.get_node("Body")), "the pony draws beneath the doll")
	_check(not stable.pony_node(a).visible, "the ridden pony is out of its stall")
	_check(not stable.pony_node(a).input_pickable, "the ridden pony can't be clicked in its empty stall")
	_check(player.get_node_or_null("RideUI/HopDown") != null, "a hop-down button while riding")

	# Save/load: herd, grooming, foal and the ride
	var saved_herd: Dictionary = ws.get_flag("fl_ponies").duplicate(true)
	ws.flags = {}
	ws.load_save()
	_check(Ponies.ids().size() == saved_herd.size() and Ponies.pony(foal)["parents"] == [a, b], "herd and foals survive save/load")
	_check(Ponies.pony(a)["groom"]["mane_style"] == "braids" and Ponies.pony(a)["groom"]["brushed"] == true, "grooming survives save/load")
	_check(Ponies.riding() == a, "the ride survives save/load")
	_check(Ponies.phenotype(foal, "coat") == Ponies.phenotype(saved_herd[foal], "coat"), "foal genes survive save/load")

	var key := InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	root.push_input(key)
	await process_frame
	_check(not player.is_mounted() and Ponies.riding() == "", "the H key hops down")
	_check(is_equal_approx(player.current_speed(), player.SPEED), "hop down: back to walking speed")
	_check(stable.pony_node(a).visible and stable.pony_node(a).input_pickable, "the pony is back in its stall, clickable")
	Ponies.mount(a, today)
	await process_frame
	var hop: Button = player.get_node_or_null("RideUI/HopDown")
	_check(hop != null, "riding again shows the hop-down button")
	if hop:
		hop.pressed.emit()
	await process_frame
	_check(not player.is_mounted() and Ponies.riding() == "", "the Hop down button hops down")

	# The grooming panel: a big herd's Foal buttons scroll inside the 360 px view; Foal works
	var clock: Node = root.get_node("/root/GameClock")
	clock.day = today + int(Ponies.data()["foal_grow_days"])  # every foal grown: the longest list
	var panel_pony: Node = stable.pony_node(b)
	panel_pony.interact()
	await process_frame
	await process_frame
	var panel: Node = panel_pony.get_child(panel_pony.get_child_count() - 1)
	_check(panel is CanvasLayer and panel.get_node("Panel/HBox/Buttons") != null, "clicking a pony opens the grooming panel")
	_check(panel.find_children("*", "Button", true, false).size() >= 4, "the panel has brush, groom and ride buttons")
	var foal_list: Node = panel.get_node_or_null("Panel/HBox/Buttons/Foals/List")
	var friends := Ponies.ids().size() - 1
	_check(foal_list != null and foal_list.get_child_count() == friends and friends > panel.FOAL_ROWS,
		"one Foal button per grown-up friend, in a scrolling list (%d)" % friends)
	var view_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var panel_h: float = panel.get_node("Panel").get_combined_minimum_size().y
	_check(panel_h <= view_h, "the panel fits the view (%d <= %d px)" % [panel_h, view_h])
	var herd_before := Ponies.ids().size()
	var foal_button: Button = foal_list.get_child(0) if foal_list else null
	_check(foal_button != null and foal_button.text.begins_with("Foal with"), "the Foal button")
	if foal_button:
		foal_button.pressed.emit()
	await process_frame
	await process_frame
	_check(Ponies.ids().size() == herd_before + 1, "pressing Foal brings a foal to the stable")
	_check(not is_instance_valid(panel) or panel.is_queued_for_deletion(), "the panel closes for the new foal")
	_check(stable.pony_node(Ponies.ids()[-1]) != null, "the new foal trots into a stall")
	clock.day = today

	# The Daughter moves: beach until she invites you, then the stable (STYLE.md 6.5)
	var st_daughter: Node = stable.get_node("Daughter")
	_check(not st_daughter.visible and not st_daughter.input_pickable, "no Daughter at the stable before she invites you")
	var hannah: Node = stable.get_node("Hannah")
	_check(hannah.visible and hannah.display_name == cast.full("stable_friend") and cast.full("stable_friend") != "stable_friend",
		"Hannah brushes a pony at the stable, named from cast.json")
	_check(hannah.current_bark() != "..." and hannah.sprite_texture != ""
		and hannah.rig != null and hannah.rig.sprite_frames.has_animation("idle_front"),
		"Hannah has barks and a rigged sprite sheet")
	stable.queue_free()
	await process_frame
	var beach_map: Node = load("res://scenes/florida/beach.tscn").instantiate()
	root.add_child(beach_map)
	await process_frame
	var beach_daughter: Node = beach_map.get_node("Daughter")
	_check(beach_daughter.visible and beach_daughter.input_pickable, "the Daughter is on the beach at first")
	ws.set_flag("fl_invited_to_horses", true)
	await process_frame
	await process_frame
	_check(beach_daughter.visible and beach_daughter.is_leaving() and not beach_daughter.input_pickable,
		"after the invitation she sets off for the stable on foot, not on the spot (bd b4z3)")
	Engine.time_scale = 8.0  # her walk to the StableDoor (test_florida.gd times it), eight times as fast
	var t0 := Time.get_ticks_msec()
	while beach_daughter.visible and Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	Engine.time_scale = 1.0
	_check(not beach_daughter.visible and not beach_daughter.input_pickable and not beach_daughter.get_node("Proximity").monitoring,
		"after the invitation she leaves the beach")
	beach_map.queue_free()
	await process_frame
	stable = load("res://scenes/florida/stable.tscn").instantiate()
	root.add_child(stable)
	await process_frame
	_check(stable.get_node("Daughter").visible and stable.get_node("Daughter").input_pickable, "...and is at the stable with her hat and brush")
	stable.queue_free()
	await process_frame

	# The stable dialogue: every opener and every branch plays, names come from cast.json
	var dm: Node = root.get_node("/root/DialogueManager")
	var res: Resource = load("res://dialogue/florida_stable.dialogue")
	var all_text := []
	for opener in [{"fl_invited_to_horses": false, "fl_met_ponies": false}, {"fl_invited_to_horses": true, "fl_met_ponies": false},
			{"fl_invited_to_horses": true, "fl_met_ponies": true}]:
		for flag: String in opener:
			ws.set_flag(flag, opener[flag])
		var walked: Array = []
		await _walk(dm, res, "daughter", walked)
		all_text.append_array(walked)
	_check(all_text.any(func(t: String) -> bool: return t.contains("found the horses")), "dialogue: the uninvited opener")
	_check(all_text.any(func(t: String) -> bool: return t.contains("Hat's on")), "dialogue: the invited opener")
	_check(all_text.any(func(t: String) -> bool: return t.contains("You're back")), "dialogue: the welcome-back opener")
	for want: String in ["Long strokes", "hop on", "Two ponies", "neither of them", "wait and see", "Nobody's in a hurry"]:
		_check(all_text.any(func(t: String) -> bool: return t.contains(want)), "dialogue branch: %s" % want)
	_check(ws.has_flag("fl_met_ponies"), "meeting the ponies is remembered")
	var hannah_text: Array = []
	await _walk(dm, res, "hannah", hannah_text)
	for want: String in ["I'm Hannah", "brushing a cloud", "two braids", "so shiny"]:
		_check(hannah_text.any(func(t: String) -> bool: return t.contains(want)), "Hannah's branch: %s" % want)
	all_text.append_array(hannah_text)
	_check(all_text.any(func(t: String) -> bool: return t.contains("Butterscotch")), "pony names come from cast.json")
	_check(not all_text.any(func(t: String) -> bool: return t.contains("{{")), "every {{...}} resolves")

	# Riding outside Florida: the pony stays home
	Ponies.mount(a, today)
	var village: Node = load("res://scenes/maps/village.tscn").instantiate()
	root.add_child(village)
	await process_frame
	_check(Ponies.riding() == "" and not village.get_node("Player").is_mounted(), "ponies stay in Florida")
	village.queue_free()
	await process_frame

	# Door wiring: beach <-> stable, each door on the walkable area and landing on a real spawn marker
	for pair in [["beach", "StableDoor"], ["stable", "BeachDoor"]]:
		var scene: Node = load("res://scenes/florida/%s.tscn" % pair[0]).instantiate()
		var door: Node = scene.get_node_or_null(pair[1])
		_check(door != null, "%s has %s" % [pair[0], pair[1]])
		if door:
			var nav: NavigationPolygon = scene.get_node("Nav").navigation_polygon
			_check(Geometry2D.is_point_in_polygon(door.position, nav.get_outline(0)), "%s sits inside the walkable area" % pair[1])
			_check(ResourceLoader.exists(door.target_scene), "%s leads to a real map" % pair[1])
			var dest: Node = load(door.target_scene).instantiate()
			_check(dest.find_child(door.target_spawn, true, false) is Marker2D, "%s lands on %s" % [pair[1], door.target_spawn])
			dest.free()
		scene.free()
	var beach: Node = load("res://scenes/florida/beach.tscn").instantiate()
	_check(beach.get_node("StableDoor").target_scene == "res://scenes/florida/stable.tscn", "the beach leads to the stable")
	beach.free()
	var st: Node = load("res://scenes/florida/stable.tscn").instantiate()
	_check(st.get_node("Daughter").dialogue_path == "res://dialogue/florida_stable.dialogue"
		and ResourceLoader.exists(st.get_node("Daughter").dialogue_path), "the Daughter is at the stable with her conversation")
	st.free()

	# Last (it changes the scene): walking onto the stable's BeachDoor goes through SceneRouter
	var router: Node = root.get_node("/root/SceneRouter")
	var leaving: Node = load("res://scenes/florida/stable.tscn").instantiate()
	root.add_child(leaving)
	await process_frame
	leaving.get_node("BeachDoor").interact()
	_check(router.next_spawn == "spawn_from_stable", "the BeachDoor asks SceneRouter for spawn_from_stable")
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://scenes/florida/beach.tscn", "...and the beach loads")
	leaving.queue_free()
	await process_frame

	for suffix in ["", ".bak"]:  # the save keeps a backup of the previous write (GC-07)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE + suffix))
	ws.SAVE_PATH = real_save
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## Plays the dialogue from title, following every response into its own branch (nested ones
## too); appends each line's speaker and text to out.
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
