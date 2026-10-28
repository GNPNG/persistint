extends SceneTree
## The voice review character picker (persistint-game-rxu): every character that speaks a line in
## the game is in the row, voiced or not (crabs, gulls, ponies, cubs, Oprah, Father, Daughter ...);
## arrows move along the row; tapping the middle character cycles all its lines through Voice;
## voice verdicts and line thumbs persist across a reload; Export review is valid JSON.
## Run: godot --headless --path project -s tests/test_voice_review.gd

const SCENE := "res://scenes/playtest/voice_review.tscn"
const MANIFEST := "res://audio/voice/manifest.json"
const TEST_SAVE := "user://test_voice_review.json"
const VoiceScript := preload("res://scripts/autoload/voice.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _open() -> Control:
	var scene: Control = load(SCENE).instantiate()
	scene.save_path = TEST_SAVE  # never the author's review
	root.add_child(scene)
	return scene


func _run() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var heard: Array = []
	var voice: Node = root.get_node("/root/Voice")
	voice.spoke.connect(func(speaker: String, text: String) -> void: heard.append([speaker, text]))
	var scene := _open()
	await process_frame
	await process_frame

	# --- Roster: every character with lines, voiced or not, each with art and a card.
	var speakers := {}
	for e: Dictionary in scene.roster:
		speakers[e["speaker"]] = e
	for s: String in ["crab", "gull", "dolphin", "mermaid", "pony", "polar_bear_clone", "oprah", "Father", "Daughter",
			"Gloria", "Priestess Betty", "Bruce", "Susan", "Hannah", "First Mate", "Chelsea Clinton", "Tyra Banks",
			"epstein", "bill_clinton", "hillary_clinton", "bill_gates", "Margaret Atwood", "silverman"]:
		_check(speakers.has(s) and not speakers[s]["lines"].is_empty(), "%s is in the row with lines (%d)" % [s, speakers.get(s, {"lines": []})["lines"].size()])
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var keys := {}
	for e: Dictionary in scene.roster:
		for l: Dictionary in e["lines"]:
			keys[l["key"]] = true
			if l["key"] != VoiceScript.line_key(e["speaker"], l["text"]):
				_check(false, "%s line key matches VoiceScript.line_key" % e["speaker"])
	var missing := 0
	for m: Dictionary in manifest:
		if not keys.has(VoiceScript.line_key(m["speaker"], m["text"])):
			missing += 1
	_check(missing == 0, "every manifest line is in the roster (%d missing)" % missing)
	var crab_lines := 0
	for s: Dictionary in Florida.data()["critters"]["crab"]["surprises"]:
		crab_lines += s.get("lines", []).size()
	_check(speakers["crab"]["lines"].size() == crab_lines, "the crabs have every crab line (%d)" % crab_lines)
	var unvoiced := 0
	for i in scene.roster.size():
		var e: Dictionary = scene.roster[i]
		var card: Button = scene._cards[i]
		_check(card.get_node_or_null("Figure/Sprite") != null, "%s stands in the row with art (%s)" % [e["name"], e["art"]["kind"]])
		if scene.clips_of(e) == 0:
			unvoiced += 1
			var marked := false
			for c: Node in card.get_children():
				if c is Label and c.text == "no voice yet":
					marked = true
			_check(marked, "%s is marked no voice yet" % e["name"])
	_check(unvoiced > 0 and unvoiced < scene.roster.size(), "voiced and unvoiced both shown (%d of %d unvoiced)" % [unvoiced, scene.roster.size()])
	_check(scene.clips_of(scene.roster[0]) > 0, "characters with clips come first")
	_check(scene.art_for("crab")["kind"] == "sheet" and scene.art_for("pony")["kind"] == "pony" and scene.art_for("polar_bear_clone")["kind"] == "cub", "crab, pony and cub are their game art")
	_check(scene.art_for("father")["kind"] == "sheet" and scene.art_for("daughter")["kind"] == "sheet", "Father and Daughter are their Florida sheets")
	_check(scene.art_for("initiate")["kind"] == "rig" and scene.art_for("hillary_clinton")["kind"] == "clone", "Gloria is her caste rig, the Hillary clone the clone sheet")
	_check(speakers["crab"]["voice"] == "no voice set up in voices.json" and speakers["Gloria"]["voice"].begins_with("built-in XTTS voice") and speakers["epstein"]["voice"].begins_with("voice cloned from"), "each character shows its voices.json set-up (%s / %s / %s)" % [speakers["crab"]["voice"], speakers["Gloria"]["voice"], speakers["epstein"]["voice"]])
	_check("Sidestep" in speakers["crab"]["sub"], "the crabs card names Sidestep (%s)" % speakers["crab"]["sub"])

	# --- Arrows move the selection (keys through _unhandled_input, and the methods), wrapping.
	_check(scene.current == 0 and scene._cards[0].button_pressed, "starts on the first character")
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	Input.parse_input_event(right)
	await process_frame
	await process_frame
	_check(scene.current == 1 and scene._cards[1].button_pressed and not scene._cards[0].button_pressed, "right arrow moves to the second character")
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	Input.parse_input_event(left)
	await process_frame
	await process_frame
	_check(scene.current == 0, "left arrow moves back")
	scene.select_prev()
	_check(scene.current == scene.roster.size() - 1, "left from the first wraps to the last")
	scene.select_next()
	_check(scene.current == 0, "right from the last wraps to the first")
	_check(scene._big != null and scene._big.get_node_or_null("Sprite") != null, "the middle character is drawn large in its art")

	# --- Tapping the middle cycles every line of the character, in order, through Voice.
	var ci: int = scene.index_of("crab")
	scene.select(ci)
	await process_frame
	var crab: Dictionary = scene.roster[ci]
	var n: int = crab["lines"].size()
	_check(heard.size() > 0 and heard[-1][0] == "crab" and heard[-1][1] == VoiceScript.display_text(crab["lines"][0]["text"]), "selecting the crabs says their first line as crab")
	_check(scene.line_info().begins_with("line 1 of %d · no clip" % n), "shows line 1 of %d, no clip (%s)" % [n, scene.line_info()])
	var said: Array = [heard[-1][1]]
	for k in range(1, n):
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = Vector2(100, 100)
		scene._on_stage_input(press)
		var release := press.duplicate()
		release.pressed = false
		scene._on_stage_input(release)
		said.append(heard[-1][1])
	var all_in_order := true
	for k in n:
		all_in_order = all_in_order and said[k] == VoiceScript.display_text(crab["lines"][k]["text"])
	_check(all_in_order, "tapping says all %d crab lines in order" % n)
	_check(scene.line_info().begins_with("line %d of %d" % [n, n]), "shows line %d of %d" % [n, n])
	scene.next_line()
	_check(scene.line_info().begins_with("line 1 of %d" % n), "after the last line it wraps to line 1")
	_check(scene._bubble.visible and scene._bubble.text == VoiceScript.display_text(crab["lines"][0]["text"]), "the bubble shows the line")
	var swipe := InputEventMouseButton.new()
	swipe.button_index = MOUSE_BUTTON_LEFT
	swipe.pressed = true
	swipe.position = Vector2(200, 100)
	scene._on_stage_input(swipe)
	var swipe_end := swipe.duplicate()
	swipe_end.pressed = false
	swipe_end.position = Vector2(120, 100)
	scene._on_stage_input(swipe_end)
	_check(scene.current == wrapi(ci + 1, 0, scene.roster.size()), "a swipe left moves to the next character")
	scene.select(scene.index_of("Gloria"))
	var gloria: Dictionary = scene.entry_of("Gloria")
	_check(scene.line_info().contains(" · clip") == gloria["lines"][0]["has_clip"], "Gloria's line 1 shows clip / no clip right (%s)" % scene.line_info())
	scene.select(scene.index_of("hillary_clinton"))
	_check(voice._player.bus == "Clones", "the Hillary clone speaks on the Clones bus")

	# --- Verdicts and thumbs; they persist across a reload; feedback only.
	var lines_before: int = scene.entry_of("crab")["lines"].size()
	scene.set_verdict("crab", "sucks")
	scene.set_verdict("Gloria", "good")
	scene.set_verdict("pony", "good")
	scene.set_verdict("pony", "")
	var crab_key: String = crab["lines"][2]["key"]
	var gloria_key: String = gloria["lines"][0]["key"]
	scene.set_thumb(crab_key, "down")
	scene.set_thumb(gloria_key, "up")
	scene.select(scene.index_of("Gloria"))
	_check(scene._good.button_pressed and not scene._sucks.button_pressed, "Gloria's Voice good box is checked")
	_check(scene._up.button_pressed and not scene._down.button_pressed, "her line 1 shows thumbs up")
	var c: Dictionary = scene.counts()
	_check(c["good"] == 1 and c["sucks"] == 1 and c["unreviewed"] == scene.roster.size() - 2 and c["up"] == 1 and c["down"] == 1, "counts: 1 good, 1 sucks, rest unreviewed, 1 up, 1 down (%s)" % c)
	_check(scene.counts_text().contains("1 good, 1 suck, %d unreviewed" % (scene.roster.size() - 2)), "the counts show at the top (%s)" % scene.counts_text())
	_check(scene.entry_of("crab")["lines"].size() == lines_before, "a thumbs down or a sucks deletes nothing")
	_check(FileAccess.file_exists(TEST_SAVE), "verdicts are saved as they are given")
	scene.queue_free()
	await process_frame
	scene = _open()
	await process_frame
	_check(scene.verdict_of("crab") == "sucks" and scene.verdict_of("Gloria") == "good" and scene.verdict_of("pony") == "", "voice verdicts survive a reload")
	_check(scene.thumb_of(crab_key) == "down" and scene.thumb_of(gloria_key) == "up", "line thumbs survive a reload")
	var mark: Label = scene._card_marks[scene.index_of("crab")]
	_check(mark.text == "SUCKS", "the crabs card shows SUCKS after the reload")
	var rec: Dictionary = scene.review["characters"]["crab"]
	_check(str(rec.get("at", "")).length() >= 19, "a verdict carries its timestamp (%s)" % rec.get("at", ""))

	# --- Export: valid JSON with the verdicts, counts and the whole roster; written to user:// here.
	var parsed: Variant = JSON.parse_string(scene.export_json())
	_check(parsed is Dictionary, "export is a JSON object")
	if parsed is Dictionary:
		_check(parsed.has("build") and parsed.has("date") and parsed.has("counts") and parsed.has("roster"), "export has build, date, counts, roster")
		_check(parsed["characters"]["crab"]["verdict"] == "sucks" and parsed["lines"][crab_key]["thumb"] == "down", "export has the crab verdict and thumb")
		_check(parsed["lines"][gloria_key]["text"] == gloria["lines"][0]["text"], "a line thumb carries the line text")
		_check(parsed["roster"].size() == scene.roster.size(), "export lists every character (%d)" % parsed["roster"].size())
	var where: String = scene.export_review()
	_check(where != "" and FileAccess.file_exists(where) and JSON.parse_string(FileAccess.get_file_as_string(where)) is Dictionary, "Export review writes valid JSON on desktop (%s)" % where)
	if where != "":
		DirAccess.remove_absolute(where)

	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
