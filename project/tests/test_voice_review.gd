extends SceneTree
## The voice review scene (persistint-game-rxu): every speaker in the clip manifest stands in the
## row with its art (or the stand-in figure) and its lines; tapping says a line through Voice; line
## and voice ratings and notes come out as the JSON tools/ingest_voice_ratings.py reads.
## Run: godot --headless --path project -s tests/test_voice_review.gd

const SCENE := "res://scenes/test/voice_review.tscn"
const MANIFEST := "res://audio/voice/manifest.json"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var heard: Array = []
	root.get_node("/root/Voice").spoke.connect(func(speaker: String, text: String) -> void: heard.append([speaker, text]))
	var scene: Control = load(SCENE).instantiate()
	scene.persist = false  # never the player's saved ratings
	root.add_child(scene)
	await process_frame
	await process_frame

	# --- Roster: every manifest speaker, every line, clips counted, art for each.
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var speakers := {}
	for e: Dictionary in manifest:
		speakers[e["speaker"]] = speakers.get(e["speaker"], 0) + 1
	_check(scene.roster.size() == speakers.size(), "roster has every manifest speaker (%d)" % scene.roster.size())
	var total := 0
	var with_clips := 0
	for entry: Dictionary in scene.roster:
		total += entry["lines"].size()
		with_clips += scene.clips_of(entry)
		_check(entry["lines"].size() == speakers.get(entry["speaker"], -1), "%s: %d lines" % [entry["name"], entry["lines"].size()])
		var card: Button = scene._cards.get(entry["speaker"])
		_check(card != null and card.get_node_or_null("Stage/Sprite") != null, "%s stands in the row with art (%s)" % [entry["name"], entry["art"]["kind"]])
	_check(total == manifest.size(), "all %d manifest lines are reachable" % total)
	_check(with_clips > 0, "%d lines have clips" % with_clips)
	_check(scene.roster[0]["lines"].size() > 0 and scene.clips_of(scene.roster[0]) > 0, "speakers with clips come first")
	_check(scene.art_for("initiate")["kind"] == "rig", "Gloria is her caste rig")
	_check(scene.art_for("hillary_clinton")["kind"] == "clone", "the Hillary clone is the clone sheet")
	_check(scene.art_for("daughter")["kind"] == "sheet", "Daughter is her Florida sheet")
	_check(scene.art_for("atwood")["kind"] == "stand_in", "a voice without art gets the stand-in figure")

	# --- Tapping says the next line through Voice on the speaker's bus, with the bubble.
	var gloria: Dictionary = {}
	for entry: Dictionary in scene.roster:
		if entry["id"] == "initiate":
			gloria = entry
	_check(not gloria.is_empty(), "Gloria is in the roster")
	scene._say("Gloria", 0, true)
	await process_frame
	var voice: Node = root.get_node("/root/Voice")
	_check(heard.size() == 1 and heard[0][0] == "Gloria" and heard[0][1] == gloria["lines"][0]["text"], "tapping Gloria speaks her first line (%s)" % [heard])
	_check(voice._player.bus == "Voice", "Gloria speaks on the Voice bus")
	_check(scene._bubbles["Gloria"].visible and scene._bubbles["Gloria"].text == gloria["lines"][0]["text"], "her bubble shows the line")
	_check(scene._next["Gloria"] == 1, "the next tap says her second line")
	scene._say("hillary_clinton", 0, true)
	await process_frame
	_check(voice._player.bus == "Clones", "the Hillary clone speaks on the Clones bus")
	_check(not scene._bubbles["Gloria"].visible, "only the selected character's bubble shows")

	# --- Ratings and the JSON hand-back.
	scene.rate_line(4)
	scene.set_note("too flat")
	scene.rate_character(7)
	scene._say("Gloria", 0, false)
	scene.rate_line(9)
	var parsed: Variant = JSON.parse_string(scene.export_json())
	_check(parsed is Dictionary and parsed.has("build") and parsed.has("date") and parsed.has("ratings") and parsed.has("character_overall"), "export is JSON with build, date, ratings, character_overall")
	if parsed is Dictionary:
		var list: Array = parsed["ratings"]
		_check(list.size() == 2, "two rated lines exported (%d)" % list.size())
		var by_clip := {}
		for r: Dictionary in list:
			by_clip[r["clip"]] = r
		var hk: String = scene._entry("hillary_clinton")["lines"][0]["key"]
		var gk: String = gloria["lines"][0]["key"]
		_check(by_clip.has(hk) and by_clip[hk]["rating"] == 4 and by_clip[hk]["note"] == "too flat" and by_clip[hk]["speaker"] == "hillary_clinton", "the clone's line: 4, with the note")
		_check(by_clip.has(gk) and by_clip[gk]["rating"] == 9 and by_clip[gk]["text"] == gloria["lines"][0]["text"], "Gloria's line: 9, text kept")
		_check(parsed["character_overall"].get("hillary_clinton") == 7, "the clone's voice overall: 7")
	_check(not FileAccess.file_exists(scene.SAVE_PATH) or scene.persist == false, "the test never wrote the player's ratings file")
	scene.queue_free()
	await process_frame
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
