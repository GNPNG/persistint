extends SceneTree
## The clone children's voices and dances (author 2026-10-24): a bark's bracketed sounds are
## shown without brackets and played as generated vocalizations, never read; the clones speak
## through the pitched-up, distorted Clones bus; the Hillary clone says her line about other
## people when another clone is near; a clone can floss or dab, and a dancing clone is what a
## cub pounces on.
## Run: godot --headless --path project -s tests/test_clone_voices.gd

const SheetRig := preload("res://scripts/ruins/sheet_rig.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var voice: Node = root.get_node("/root/Voice")
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()

	# --- Bracketed sounds: shown without brackets, played as vocalizations, keyed on the words.
	var line := "[Uuunnngh.] Shamble. Shamble. [Mrrh.] Rest."
	_check(voice.display_text(line) == "Uuunnngh. Shamble. Shamble. Mrrh. Rest.", "display_text drops the brackets, keeps the sounds")
	_check(voice.spoken_text(line) == "Shamble. Shamble. Rest.", "spoken_text drops the sounds")
	_check(voice.brackets_of(line) == "[Uuunnngh.] [Mrrh.]", "brackets_of lists the sounds")
	var parts: Array = voice.parts(line)
	_check(parts.size() == 4 and parts[0].has("sfx") and parts[1].get("say") == "Shamble. Shamble." and parts[2].has("sfx") and parts[3].get("say") == "Rest.",
		"parts: sound, words, sound, words in order (%s)" % [parts])
	_check(voice.line_key("x", line) == voice.line_key("x", "Shamble. Shamble. Rest."), "a line's clip key ignores its bracketed sounds")
	_check(voice.line_key("x", "Shamble.") == ("x|Shamble.").md5_text(), "lines without sounds keep their old clip keys")
	_check(voice.sfx_for("Grrrr.") == "growl" and voice.sfx_for("Mmmrrrh.") == "moan" and voice.sfx_for("Uuunnngh.").begins_with("groan_") \
		and voice.sfx_for("Hhhnn.").begins_with("groan_") and voice.sfx_for("Uuunnngh.") == voice.sfx_for("uuunnngh"),
		"sfx_for: g... growl, m... moan, else a groan, the same for the same spelling")
	for name: String in ["groan_1", "groan_2", "groan_3", "moan", "growl"]:
		_check(ResourceLoader.exists("res://audio/sfx/%s.wav" % name), "vocalization %s exists (tools/gen_clone_sfx.py)" % name)

	# Every clone bark writes its sounds in brackets, and every bracketed sound has a vocalization.
	var ZombieChild: GDScript = load("res://scripts/ruins/zombie_child.gd")
	var cc: Dictionary = ZombieChild.data()
	# a groan, hum or growl spelled out: a run of u/h/m/r/n, or a word starting mrr/hhn/grr
	var vocal := RegEx.create_from_string("(?i)\\b[a-z]*(u{3,}|h{3,}|m{3,}|r{3,}|n{3,})[a-z]*\\b|\\b(mrr|hhn|grr)[a-z]*\\b")
	var bracketed := 0
	for list: String in ["barks", "bump_barks"]:
		for bark: String in cc.get(list, []):
			var words: String = voice.spoken_text(bark)
			_check(vocal.search(words) == null, "%s: sounds are in brackets: %s" % [list, bark])
			for part: Dictionary in voice.parts(bark):
				if part.has("sfx"):
					bracketed += 1
					_check(ResourceLoader.exists("res://audio/sfx/%s.wav" % part["sfx"]), "%s -> %s.wav exists" % [bark, part["sfx"]])
	_check(bracketed >= 8, "the clone barks carry bracketed sounds (%d)" % bracketed)

	# --- The Clones bus: pitched up and distorted, under Voice.
	var bus := AudioServer.get_bus_index("Clones")
	_check(bus >= 0 and AudioServer.get_bus_send(bus) == &"Voice", "Clones bus exists and sends to Voice")
	var pitch: AudioEffect = null
	var dist: AudioEffect = null
	if bus >= 0:
		for i in AudioServer.get_bus_effect_count(bus):
			var fx := AudioServer.get_bus_effect(bus, i)
			if fx is AudioEffectPitchShift:
				pitch = fx
			if fx is AudioEffectDistortion:
				dist = fx
	_check(pitch != null and (pitch as AudioEffectPitchShift).pitch_scale > 1.1, "Clones bus pitches up (kid clones)")
	_check(dist != null and (dist as AudioEffectDistortion).drive > 0.0, "Clones bus distorts a little")
	_check(ZombieChild.bus() == "Clones", "clone children speak through the Clones bus")

	# --- In the clone hall: the bark bubble, the bus, the sounds first, then the original's line.
	var hall: Node = load("res://scenes/ruins/ruins_clone_hall.tscn").instantiate()
	root.add_child(hall)
	await process_frame
	var zs: Array = hall.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("zombie_clones"))
	var cubs: Array = hall.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("polar_cubs"))
	_check(zs.size() >= 2 and cubs.size() >= 1, "clone hall has clones and cubs")
	var heard: Array = []
	voice.spoke.connect(func(speaker: String, text: String) -> void: heard.append([speaker, text]))
	var z: Node2D = zs[0]
	for other: Node2D in zs:  # alone: no other clone near
		if other != z:
			other.global_position = z.global_position + Vector2(4000, 0)
	var text: String = z.bark()
	_check(text != "" and not z.bubble.text.contains("[") and not z.bubble.text.contains("]"), "the bubble shows no brackets: %s" % z.bubble.text.replace("\n", " / "))
	_check(heard.size() == 1 and heard[0][0] == z.original and not heard[0][1].contains("["), "Voice hears the clone's line without brackets (%s)" % [heard])
	_check(voice._player.bus == "Clones", "the clone's line plays through the Clones bus (%s)" % voice._player.bus)
	if text.contains("["):
		var spoken: String = heard[0][1] if heard.size() == 1 else ""
		_check(voice.parts(text)[0].has("sfx") or spoken != "", "a bark with a sound plays the sound first")

	# --- Hillary's clone and the other clones: her line about other people when one is near.
	var hillary: Node2D = null
	for c: Node2D in zs:
		if c.original == "hillary_clinton":
			hillary = c
	_check(hillary != null, "a Hillary Clinton clone batch is in the hall")
	if hillary:
		var others: Array = ZombieChild.quote_pool("hillary_clinton", true)
		var all: Array = ZombieChild.quote_pool("hillary_clinton")
		_check(others.size() >= 1 and others.size() < all.size() and others[0].contains("basket of deplorables") and all.has(others[0]),
			"Hillary's about_others line is the basket of deplorables, inside her verified pool (%d of %d)" % [others.size(), all.size()])
		for c: Node2D in zs:
			if c != hillary:
				c.global_position = hillary.global_position + Vector2(4000, 0)
		_check(not hillary.others_near(), "no clone near: others_near is false")
		var far_ok := true
		for i in 12:
			far_ok = far_ok and all.has(hillary.quote())
		_check(far_ok, "alone, she picks from her whole pool")
		var neighbour: Node2D = zs[0] if zs[0] != hillary else zs[1]
		neighbour.global_position = hillary.global_position + Vector2(30, 0)
		_check(hillary.others_near(), "another clone 30 px away counts as near")
		var near_ok := true
		for i in 6:
			near_ok = near_ok and hillary.quote().contains("basket of deplorables")
		_check(near_ok, "with another clone near, she calls them the basket of deplorables")
		hillary._talking = false
		hillary.bark()
		_check(hillary.bubble.text.contains("basket of deplorables"), "the bubble shows the line (%s)" % hillary.bubble.text.replace("\n", " / "))

	# --- The floss and the dab, and the cub that pounces on a dancer.
	for kind: String in ZombieChild.data().get("originals", {}):
		var sheet: Texture2D = load("res://assets/ruins/clone_%s.png" % kind)
		_check(sheet != null and sheet.get_height() == 272 * 5 and sheet.get_width() == 192 * 6, "clone_%s.png has the floss and dab rows" % kind)
	_check(SheetRig.CLONE["anims"].has("floss") and SheetRig.CLONE["anims"].has("dab") and SheetRig.CLONE_DANCES.keys() == ["floss", "dab"], "SheetRig knows the floss and the dab")
	var dancer: Node2D = zs[1]
	_check(dancer.sprite.sprite_frames.has_animation("floss") and dancer.sprite.sprite_frames.has_animation("dab"), "the rig has both dances")
	_check(not dancer.sprite.sprite_frames.get_animation_loop("dab") and dancer.sprite.sprite_frames.get_animation_loop("floss"), "the floss loops, the dab holds its last frame")
	_check(dancer.dance("floss") == "floss" and dancer.dancing and dancer.sprite.animation == &"floss" and not dancer.sprite.flip_h, "a clone can floss (%s)" % dancer.sprite.animation)
	_check(dancer.dance("dab") == "", "it can't start another dance mid-floss")
	var seconds: float = ZombieChild.data().get("dance", {}).get("seconds", 0.0)
	_check(seconds >= 1.0 and float(ZombieChild.data().get("dance", {}).get("interval_min", 0.0)) > 0.0, "dance timing is in data (%.1f s)" % seconds)
	var lab: Node = hall.get_node("CloneLab")
	var cub: Node2D = cubs[0]
	for c: Node2D in cubs:
		c.global_position = dancer.global_position + Vector2(5000, 0)
	_check(not lab.on_dance(dancer, true), "no cub within dance_radius: nothing pounces")
	cub.napping = false
	cub.busy = false
	cub.global_position = dancer.global_position + Vector2(60, 0)
	var key := "%s_batch_%d" % [dancer.original, dancer.batch]
	var before: int = lab.eaten_count(key)
	_check(lab.on_dance(dancer, true) and lab.eaten_count(key) == before + 1 and not dancer.is_in_group("zombie_clones"), "a cub near a dancing clone pounces on it")
	# try_pounce prefers a dancer over a nearer idle clone
	await process_frame
	var fresh_a: Node2D = lab.restock({"original": "epstein", "batch": 9, "wander": Rect2(200, 300, 10, 10)})
	var fresh_b: Node2D = lab.restock({"original": "bill_gates", "batch": 9, "wander": Rect2(200, 300, 10, 10)})
	await process_frame
	var cub2: Node2D = cubs[cubs.size() - 1]
	cub2.napping = false
	cub2.busy = false
	for c: Node2D in cubs:
		if c != cub2:
			c.napping = true
	fresh_a.global_position = Vector2(600, 600)
	fresh_b.global_position = Vector2(650, 600)
	cub2.global_position = Vector2(590, 600)  # fresh_a is nearer, fresh_b dances
	for other: Node2D in lab.zombies():
		if other != fresh_a and other != fresh_b:
			other.global_position = Vector2(-5000, -5000)
	fresh_b.dancing = true  # mid-dance (dance() itself would also book the cub through on_dance)
	fresh_b.sprite.play("dab")
	var b_key := "%s_batch_%d" % [fresh_b.original, fresh_b.batch]
	var b_before: int = lab.eaten_count(b_key)
	_check(lab.try_pounce() and lab.eaten_count(b_key) == b_before + 1 and fresh_a.is_in_group("zombie_clones"), "the timed pounce prefers the dancer over a nearer idle clone")
	hall.queue_free()
	await process_frame

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
