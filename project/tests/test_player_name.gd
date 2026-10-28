extends SceneTree
## The player's name (bd 1ce): New Game asks for her full name and an optional nickname, and the
## characters call her WorldState.player_call_name(): the nickname, else the first name, else the
## default. Checked here:
## - cleaning (WorldState.clean_name): the ends trimmed and runs of space made one, cut to the
##   limits, only letters, marks, digits, spaces and ' ’ . -, a BBCode or Dialogue Manager tag and
##   a {{...}} removed whole, nothing that is not text, and "" when no letter is left;
## - the resolver's order, and the default;
## - the save: the name is written and read back, and goes through a save file (export, import);
## - old saves: a bare flags dictionary and a schema-1 save with no name load as they are, with
##   nothing to report, and use the default; given a name they save it with the rest; a name with
##   markup in a save file is cleaned on load, one that is not text is dropped;
## - a Florida line says the name (the stable's Daughter, the beach's Father), and markup in a
##   stored name shows as plain text and a [do ...] in it never runs, in the balloon too;
## - the name screen: New Game opens it over the hidden menu with the typing in the full name; the
##   line under the fields follows the typing; Enter goes on to the nickname; Tab and the arrows
##   stay in the panel; Back and Escape go back to the menu with the save as it was; Start starts
##   a fresh game in the village with the names stored cleaned.
## Run: godot --headless --path project -s tests/test_player_name.gd
## WorldState saves to a temp file for the run; the player's real save is never touched.

const TEMP_SAVE := "user://test_player_name_save.json"
const MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"
const STABLE_DIALOGUE := "res://dialogue/florida_stable.dialogue"
const BEACH_DIALOGUE := "res://dialogue/florida_beach.dialogue"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var real_save: String = ws.SAVE_PATH
	_check(real_save == ws.TEST_SAVE_PATH, "a test run uses the test save")
	ws.SAVE_PATH = TEMP_SAVE
	_clean(ws)

	_cleaning(ws)
	_resolver(ws)
	_round_trip(ws)
	_old_saves(ws)
	await _lines(ws)
	await _name_screen(ws)
	await _balloon(ws)

	_clean(ws)
	ws.SAVE_PATH = real_save
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _cleaning(ws: Node) -> void:
	var cases := [
		["  Mary   Ann\tSmith  ", "Mary Ann Smith", "the ends trimmed, runs of space made one"],
		["Zoë O'Neil-Brown Jr.", "Zoë O'Neil-Brown Jr.", "accents, apostrophe, hyphen and full stop kept"],
		["D’Arcy", "D’Arcy", "a curly apostrophe kept"],
		["[b]Zed[/b]", "Zed", "BBCode tags removed whole"],
		["[color=#ff0000]Zed[/color]", "Zed", "a colour tag removed whole"],
		["[url=https://example.com]Zed[/url]", "Zed", "a link tag removed whole"],
		["[do WorldState.reset()]Zed", "Zed", "a Dialogue Manager [do] removed whole"],
		["[if true]Zed[/if]", "Zed", "a Dialogue Manager [if] removed whole"],
		["{{WorldState.reset()}}Zed", "Zed", "a {{...}} removed whole"],
		["Zed[", "Zed", "a stray bracket removed"],
		["Ze{d}|", "Zed", "braces and bars removed"],
		["Zed\n[i]Ann", "Zed Ann", "a new line is a space"],
		["Ze" + char(7) + "d", "Zed", "control characters removed"],
		["🌸Zed🌸", "Zed", "an emoji removed"],
		["123", "", "no letter: no name"],
		["...", "", "punctuation alone: no name"],
		["   ", "", "spaces alone: no name"],
		["[[Ann|Bea]]", "", "a random pick removed"],
	]
	for c: Array in cases:
		var got: String = ws.clean_name(c[0])
		_check(got == c[1], "clean_name: %s (got \"%s\")" % [c[2], got])
	_check(ws.clean_name(5) == "" and ws.clean_name(null) == "" and ws.clean_name({"a": 1}) == "", "clean_name: what is not text is no name")
	_check(ws.clean_name("A".repeat(60)).length() == ws.NAME_MAX, "a full name stops at %d characters" % ws.NAME_MAX)
	_check(ws.clean_name("B".repeat(60), ws.NICKNAME_MAX).length() == ws.NICKNAME_MAX, "a nickname stops at %d characters" % ws.NICKNAME_MAX)
	_check(ws.clean_name("Ann" + " ".repeat(37) + "Smith") == "Ann Smith", "the limit counts the cleaned name")
	_check(ws.clean_name("A".repeat(39) + " B") == "A".repeat(39), "no space is left at the end of a cut name")


func _resolver(ws: Node) -> void:
	var d: String = ws.PLAYER_NAME_DEFAULT
	_check(d != "" and ws.clean_name(d) == d, "the default is a clean word (%s)" % d)
	_check(ws.call_name_of("Mary Ann Smith", "Kit") == "Kit", "the nickname comes first")
	_check(ws.call_name_of("Mary Ann Smith", "") == "Mary", "no nickname: the first name")
	_check(ws.call_name_of("Mary Ann Smith", "  [b] ") == "Mary", "a nickname that cleans to nothing: the first name")
	_check(ws.call_name_of("- Ann Smith", "") == "Ann", "the first name is the first word with a letter")
	_check(ws.call_name_of("", "") == d and ws.call_name_of(null, null) == d and ws.call_name_of("[i]", "42") == d, "no name: the default")
	ws.flags = {}
	_check(ws.player_call_name() == d and ws.player_full_name() == "" and ws.player_nickname() == "", "a game without a name uses the default")
	ws.flags = {"player_name": "Mary Ann Smith"}
	_check(ws.player_call_name() == "Mary", "the resolver reads the save's full name")
	ws.flags = {"player_name": "Mary Ann Smith", "player_nickname": "Kit"}
	_check(ws.player_call_name() == "Kit", "...and its nickname")
	ws.flags = {}


func _round_trip(ws: Node) -> void:
	_clean(ws)
	ws.set_flag("chapter", "island")
	var heard: Array = []
	var on_flag := func(key: String, _v: Variant) -> void: heard.append(key)
	ws.flag_changed.connect(on_flag)
	ws.set_player_name("  Mary   Ann Smith ", " Kit ")
	ws.flag_changed.disconnect(on_flag)
	_check(ws.flags.get("player_name") == "Mary Ann Smith" and ws.flags.get("player_nickname") == "Kit", "set_player_name stores both names cleaned")
	_check(heard.has("player_name") and heard.has("player_nickname"), "...and tells the listeners")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE))
	var on_disk: Dictionary = parsed.get("flags", {}) if parsed is Dictionary else {}
	_check(int(parsed.get("schema", -1)) == ws.SCHEMA and on_disk.get("player_name") == "Mary Ann Smith"
		and on_disk.get("player_nickname") == "Kit", "the names are in the save file, the schema unchanged")
	ws.flags = {}
	ws.load_save()
	_check(ws.load_report == "" and ws.player_full_name() == "Mary Ann Smith" and ws.player_nickname() == "Kit"
		and ws.player_call_name() == "Kit" and ws.get_flag("chapter") == "island", "the names come back from the save with the rest")
	var text: String = ws.export_text()
	ws.flags = {}
	_check(ws.import_text(text) == "" and ws.player_full_name() == "Mary Ann Smith" and ws.player_call_name() == "Kit",
		"a save file keeps the names (export, import)")
	ws.set_player_name("Mary Ann Smith", "")
	_check(ws.flags.get("player_nickname") == "" and ws.player_call_name() == "Mary", "an empty nickname is stored empty and the first name is used")
	_clean(ws)


func _old_saves(ws: Node) -> void:
	var d: String = ws.PLAYER_NAME_DEFAULT
	# Before the schema: a bare flags dictionary.
	_clean(ws)
	_write(TEMP_SAVE, JSON.stringify({"_location": {"scene": VILLAGE, "spawn": "spawn_default"}, "fl_met_father": true}))
	ws.load_save()
	_check(ws.load_report == "" and ws.get_flag("fl_met_father") == true and ws.get_flag("_location") is Dictionary
		and not ws.flags.has("player_name") and not ws.flags.has("player_nickname"),
		"a save from before the schema loads as it is, nothing to report, no name added")
	_check(ws.player_call_name() == d, "...and the characters use the default")
	# Schema 1, before the name.
	_clean(ws)
	_write(TEMP_SAVE, JSON.stringify({"schema": 1, "flags": {"chapter": "island", "fl_met_ponies": true}}))
	ws.load_save()
	_check(ws.load_report == "" and ws.has_flag("fl_met_ponies") and not ws.flags.has("player_name"),
		"a schema-1 save without a name loads as it is, nothing to report")
	_check(ws.player_call_name() == d, "...and the characters use the default")
	ws.set_player_name("Mary Ann Smith")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE))
	var on_disk: Dictionary = parsed.get("flags", {}) if parsed is Dictionary else {}
	_check(int(parsed.get("schema", -1)) == ws.SCHEMA and on_disk.get("fl_met_ponies") == true and on_disk.get("chapter") == "island"
		and on_disk.get("player_name") == "Mary Ann Smith", "the old save, given a name, saves it with everything it had")
	ws.flags = {}
	ws.load_save()
	_check(ws.player_call_name() == "Mary" and ws.has_flag("fl_met_ponies"), "...and reads back with it")
	# A save file with markup in the name, and a nickname that is not text.
	_clean(ws)
	_write(TEMP_SAVE, JSON.stringify({"schema": 1, "flags": {"player_name": "[color=red]Mary[/color]  {{WorldState.reset()}} Smith", "player_nickname": 7}}))
	ws.load_save()
	_check(ws.load_report == "" and ws.flags.get("player_name") == "Mary Smith" and not ws.flags.has("player_nickname"),
		"a name with markup in a save is cleaned on load; a nickname that is not text is dropped")
	_check(ws.import_text(JSON.stringify({"player_name": "[b]Zed[/b]"})) == "" and ws.flags.get("player_name") == "Zed",
		"an imported save file's name is cleaned too")
	_clean(ws)


## The Florida lines with the name, as Dialogue Manager resolves them.
func _lines(ws: Node) -> void:
	var d: String = ws.PLAYER_NAME_DEFAULT
	var dm: Node = root.get_node("/root/DialogueManager")
	var stable: Resource = load(STABLE_DIALOGUE)
	var beach: Resource = load(BEACH_DIALOGUE)
	ws.flags = {"fl_met_ponies": true, "fl_met_father": true}
	var line = await dm.get_next_dialogue_line(stable, "daughter")
	_check(line != null and line.character == "Daughter" and line.text == "Hi, %s!" % d, "with no name the Daughter says the default (%s)" % (line.text if line else "no line"))
	ws.flags["player_name"] = "Mary Ann Smith"
	line = await dm.get_next_dialogue_line(stable, "daughter")
	_check(line != null and line.text == "Hi, Mary!", "the Daughter calls the player by her first name (%s)" % (line.text if line else "no line"))
	ws.flags["player_nickname"] = "Kit"
	line = await dm.get_next_dialogue_line(stable, "daughter")
	_check(line != null and line.text == "Hi, Kit!", "...and by her nickname when she has one (%s)" % (line.text if line else "no line"))
	line = await dm.get_next_dialogue_line(beach, "father")
	_check(line != null and line.character == "Father" and line.text == "There you are, Kit.", "the Father on the beach says it too (%s)" % (line.text if line else "no line"))
	if line:
		var after = await dm.get_next_dialogue_line(beach, line.next_id)
		_check(after != null and String(after.text).begins_with("Back again."), "...and his welcome back follows as before")
	# A stored name with markup and a [do ...] (a hand-edited save, put straight into the flags).
	ws.flags["player_nickname"] = "[do WorldState.set_flag(\"pwned\", true)][b]Zed[/b][[A|B]]"
	line = await dm.get_next_dialogue_line(stable, "daughter")
	_check(line != null and line.text == "Hi, Zed!" and "[" not in line.text, "markup in a stored name never reaches the line (%s)" % (line.text if line else "no line"))
	_check(not ws.flags.has("pwned"), "a [do ...] in a stored name never runs")
	ws.flags = {}


## The name screen over the main menu, then Start into the village.
func _name_screen(ws: Node) -> void:
	_clean(ws)
	ws.set_flag("fl_met_father", true)  # a game to keep through Back
	change_scene_to_file(MENU)
	await _frames(3)
	var menu: Node = current_scene
	var entry: Control = menu.get_node_or_null("NameEntry") if menu else null
	_check(entry != null and not entry.is_open(), "the main menu has the name screen, closed")
	if entry == null:
		return
	var full: LineEdit = entry.get_node("%FullName")
	var nick: LineEdit = entry.get_node("%Nickname")
	var preview: Label = entry.get_node("%Preview")
	var start: Button = entry.get_node("%StartButton")
	var back: Button = entry.get_node("%BackButton")
	menu.get_node("%NewButton").pressed.emit()
	await _frames(2)
	_check(entry.is_open() and not menu.get_node("Center").visible, "New Game opens the name screen, the menu hidden under it")
	_check(entry.get_index() > menu.get_node("Center").get_index(), "the screen draws over the menu")
	_check(root.gui_get_focus_owner() == full, "the typing starts in the full name")
	_check(full.max_length == ws.NAME_MAX and nick.max_length == ws.NICKNAME_MAX, "the fields stop at the limits")
	_check(full.virtual_keyboard_enabled and nick.virtual_keyboard_enabled and full.custom_minimum_size.y >= 18
		and start.custom_minimum_size.y >= 18, "touch: the fields bring up the on-screen keyboard; fields and buttons are tap-sized")
	_check(preview.text == "They'll call you %s." % ws.PLAYER_NAME_DEFAULT, "empty, the line under the fields names the default (%s)" % preview.text)
	full.text = "Mary Ann Smith"
	full.text_changed.emit(full.text)
	_check(preview.text == "They'll call you Mary.", "typing a full name: the line names the first name (%s)" % preview.text)
	nick.text = "Kit"
	nick.text_changed.emit(nick.text)
	_check(preview.text == "They'll call you Kit.", "typing a nickname: the line names it (%s)" % preview.text)
	nick.text = "[b]"
	nick.text_changed.emit(nick.text)
	_check(preview.text == "They'll call you Mary.", "a nickname of markup alone counts as none (%s)" % preview.text)
	full.text_submitted.emit(full.text)
	await process_frame
	_check(root.gui_get_focus_owner() == nick, "Enter in the full name goes on to the nickname")
	var ring := [full, nick, start, back]
	var stays := true
	for i in ring.size():
		var c: Control = ring[i]
		var n: Control = ring[(i + 1) % ring.size()]
		stays = stays and c.get_node_or_null(c.focus_next) == n and c.get_node_or_null(c.focus_neighbor_bottom) == n
		stays = stays and n.get_node_or_null(n.focus_previous) == c and n.get_node_or_null(n.focus_neighbor_top) == c
	_check(stays, "Tab and the arrows go round the panel and never leave it")
	back.pressed.emit()
	await _frames(1)
	_check(not entry.is_open() and menu.get_node("Center").visible, "Back returns to the menu")
	_check(ws.has_flag("fl_met_father") and not ws.flags.has("player_name"), "...with the save as it was")
	menu.get_node("%NewButton").pressed.emit()
	await _frames(1)
	_check(entry.is_open() and full.text == "" and nick.text == "", "the screen opens empty again")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(not entry.is_open() and menu.get_node("Center").visible and ws.has_flag("fl_met_father"),
		"Escape closes it too, from inside a field, with the save as it was")
	menu.get_node("%NewButton").pressed.emit()
	await _frames(1)
	entry.set_names("  Mary   Ann [b]Smith[/b] ", " Kit ")
	_check(preview.text == "They'll call you Kit.", "set_names fills the fields and the line")
	start.pressed.emit()
	await _frames(6)
	_check(current_scene != null and current_scene.scene_file_path == VILLAGE, "Start opens the village")
	_check(not ws.has_flag("fl_met_father"), "...in a fresh game")
	_check(ws.flags.get("player_name") == "Mary Ann Smith" and ws.flags.get("player_nickname") == "Kit"
		and ws.player_call_name() == "Kit", "...with the names stored cleaned")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE))
	var on_disk: Dictionary = parsed.get("flags", {}) if parsed is Dictionary else {}
	_check(on_disk.get("player_name") == "Mary Ann Smith" and on_disk.get("player_nickname") == "Kit", "...and saved")


## The Daughter's line in the game's dialogue balloon, with markup in the stored nickname.
func _balloon(ws: Node) -> void:
	ws.flags["fl_met_ponies"] = true
	ws.flags["player_nickname"] = "[do WorldState.set_flag(\"pwned\", true)][b]Zed[/b]"
	var dm: Node = root.get_node("/root/DialogueManager")
	var balloon: Node = dm.show_dialogue_balloon(load(STABLE_DIALOGUE), "daughter")
	var label = null  # the balloon's DialogueLabel (a RichTextLabel)
	for i in 30:
		await process_frame
		if is_instance_valid(balloon) and balloon.get("dialogue_label") is RichTextLabel and balloon.dialogue_line != null:
			label = balloon.dialogue_label
			break
	_check(label != null, "the dialogue balloon opens with the Daughter's line")
	if label:
		if label.get("is_typing"):
			label.skip_typing()
		await _frames(2)
		_check(label.get_parsed_text() == "Hi, Zed!", "the balloon shows the name as plain text (%s)" % label.get_parsed_text())
		_check(not label.text.contains("[b]") and not label.text.contains("[do"), "no markup from the name reaches the label")
	_check(not ws.flags.has("pwned"), "a [do ...] in the name never runs in the balloon")
	for b in get_nodes_in_group("dialogue_balloon"):
		b.queue_free()
	await _frames(2)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _clean(ws: Node) -> void:
	for suffix in ["", ".tmp", ".bak", ".corrupt", ".newer"]:
		var p: String = ws.SAVE_PATH + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	ws.flags = {}
	ws.load_report = ""


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
