extends SceneTree
## Headless check of the vertical-slice verification items:
##   quest branches -> save -> reload -> NPC barks differ per branch,
##   paper-doll outfit survives save/load, puzzle completion reaches an NPC bark.
## Run: godot --headless --path project -s tests/verify_slice.gd
## The player's real save (user://save.json) is backed up and restored.

const BARKS_PATH := "res://data/barks.json"
const NPCS := ["maren", "ondine", "pip", "vess"]

var _barks: Dictionary = {}
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node_or_null("/root/WorldState")
	if ws == null:
		print("FAIL WorldState autoload not available")
		quit(2)
		return
	_barks = JSON.parse_string(FileAccess.get_file_as_string(BARKS_PATH))
	var backup := ""
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	if had_save:
		backup = FileAccess.get_file_as_string(ws.SAVE_PATH)

	var branches := {
		"accept_deliver": {"quest_offering_accepted": true, "offering_delivered": true,
			"puzzle_ritual_done": true, "outfit_top": "robe_white"},
		"refuse": {"refused_offering": true, "outfit_top": "tunic_plain"},
		"question_deliver": {"quest_offering_accepted": true, "questioned_ritual": true,
			"offering_delivered": true},
	}
	var results := {}
	for name: String in branches:
		ws.reset()
		for key: String in branches[name]:
			ws.set_flag(key, branches[name][key])
		ws.flags = {}  # simulate a fresh launch
		ws.load_save()
		var barks := {}
		for npc: String in NPCS:
			barks[npc] = _bark(ws, npc)
		results[name] = barks
		print("%s -> %s" % [name, barks])
		for key: String in branches[name]:
			_check(ws.get_flag(key) == branches[name][key],
				"%s: flag %s survives save/load" % [name, key])

	_check(results["accept_deliver"] != results["refuse"], "barks differ: accept vs refuse")
	_check(results["question_deliver"]["maren"] != results["accept_deliver"]["maren"]
		or results["question_deliver"] != results["refuse"], "barks differ: question branch")
	_check(results["accept_deliver"]["vess"].contains("icons"), "puzzle result referenced by Vess")

	# Clock and location survive save/load; New Game resets the clock.
	var clock: Node = root.get_node("/root/GameClock")
	ws.reset()
	clock.restore()
	for i in 5:  # 5 phases -> Day 2, midday
		clock._advance_phase()
	ws.set_flag("_location", {"scene": "res://scenes/maps/temple.tscn", "spawn": "spawn_door"})
	ws.flags = {}
	ws.load_save()
	clock.day = 99
	clock.restore()
	_check(clock.day == 2 and clock.phase() == "midday",
		"clock survives save/load (got day %d %s)" % [clock.day, clock.phase()])
	var loc: Variant = ws.get_flag("_location")
	_check(loc is Dictionary and loc["scene"].ends_with("temple.tscn") and loc["spawn"] == "spawn_door",
		"last map and spawn survive save/load")
	ws.reset()
	clock.restore()
	_check(clock.day == 1 and clock.phase() == "morning", "New Game resets clock to Day 1 morning")

	# Names come only from data/cast.json, including dialogue speaker names.
	var cast: Node = root.get_node("/root/Cast")
	var cast_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast.json"))
	_check(cast.full("ondine") == cast_data["ondine"]["name"], "Cast.full reads cast.json")
	var dm: Node = root.get_node("/root/DialogueManager")
	ws.reset()
	var line = await dm.get_next_dialogue_line(load("res://dialogue/priestess.dialogue"), "start")
	_check(line != null and line.character == cast_data["ondine"]["name"],
		"dialogue speaker resolves from cast.json (got %s)" % (line.character if line else "null"))
	ws.reset()
	line = await dm.get_next_dialogue_line(load("res://dialogue/offering.dialogue"), "start")
	_check(line != null and line.character == cast_data["maren"]["name"],
		"offering speaker resolves from cast.json (got %s)" % (line.character if line else "null"))

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _bark(ws: Node, npc: String) -> String:
	for entry: Dictionary in _barks.get(npc, []):
		if ws.matches(entry.get("if", {})):
			return entry.get("text", "")
	return "..."


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
