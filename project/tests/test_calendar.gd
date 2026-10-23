extends SceneTree
## Headless check of the Calendar of Blood: cycle counting, festival, "when"
## conditions for barks/signals/schedules, and NPC bark selection by calendar.
## Run: godot --headless --path project -s tests/test_calendar.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var clock: Node = root.get_node("/root/GameClock")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()
	clock.restore()

	_check(clock.cycle_number() == 1 and clock.cycle_day() == 1, "day 1 is cycle 1 day 1")
	clock.day = 28
	_check(clock.cycle_number() == 1 and clock.cycle_day() == 28, "day 28 closes cycle 1")
	clock.day = 29
	_check(clock.cycle_number() == 2 and clock.cycle_day() == 1, "day 29 opens cycle 2")
	clock.day = 14
	_check(clock.is_festival() and clock.days_until_festival() == 0, "day 14 is the Festival of the Fourteenth")
	clock.day = 42
	_check(clock.is_festival() and clock.cycle_number() == 2, "festival recurs on day 42")
	clock.day = 15
	_check(not clock.is_festival() and clock.days_until_festival() == 27, "day 15: 27 days to the next festival")

	clock.day = 14
	_check(clock.matches_when({"festival": true}), "when festival: true")
	_check(not clock.matches_when({"festival": false}), "when festival: false fails on festival")
	_check(clock.matches_when({"cycle_day_min": 10, "cycle_day_max": 14}), "when cycle_day range")
	_check(not clock.matches_when({"cycle": 2}), "when cycle mismatch")
	_check(clock.matches_when({"phase": "morning"}), "when phase")
	_check(not clock.matches_when({"nonsense": 1}), "unknown when key never matches")

	# Barks: calendar-gated entries override the default only inside their window.
	var npc: Node = load("res://scripts/npc.gd").new()
	npc.npc_id = "initiate"
	npc._barks = {"initiate": [
		{"when": {"festival": true}, "text": "FEST"},
		{"if": {"x": true}, "when": {"cycle_min": 2}, "text": "LATE"},
		{"text": "PLAIN"}]}
	clock.day = 14
	_check(npc.current_bark() == "FEST", "festival bark on day 14")
	clock.day = 13
	_check(npc.current_bark() == "PLAIN", "default bark off-festival")
	clock.day = 30
	_check(npc.current_bark() == "PLAIN", "flag-gated bark needs its flag")
	ws.flags["x"] = true
	_check(npc.current_bark() == "LATE", "cycle_min + flag bark in cycle 2")
	npc.free()
	clock.calendar_data = {
		"cohort_signals": [{"id": "s", "when": {"cycle_day": 3}}],
		"schedules": {"drone": [{"when": {"phase": "night"}, "location": "compound"}]}}
	clock.day = 3
	_check(clock.active_cohort_signals().size() == 1, "cohort signal active on its day")
	clock.day = 4
	_check(clock.active_cohort_signals().is_empty(), "cohort signal inactive otherwise")
	clock.phase_index = 3
	_check(clock.schedule_for("drone").get("location", "") == "compound", "schedule matches phase")
	clock.phase_index = 0
	_check(clock.schedule_for("drone").is_empty(), "no schedule entry outside its window")
	clock._load_calendar()
	_check(clock.calendar_data.has("cohort_signals"), "data/calendar.json loads")
	_check("Cycle 1, day 1/28" in _status(clock), "status text shows cycle number")

	ws.reset()
	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _status(clock: Node) -> String:
	clock.day = 1
	return clock.status_text()



func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
