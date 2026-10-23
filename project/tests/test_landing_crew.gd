extends SceneTree
## Headless check of the Landing ship layout and crew tasks.
## Run: godot --headless --path project -s tests/test_landing_crew.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var n: Control = load("res://scenes/minigames/landing.tscn").instantiate()
	root.add_child(n)
	await process_frame
	_check(n.station_names().has("Promenade"), "station on ship layout")
	_check(n.station_names().size() >= 8, "ship has many stations")
	_check(n.data["commands"].size() >= 40, "many commands")
	_check(float(n.data["seconds_per_command"]) >= 6.0, "real seconds_per_command")
	var ok_data := true
	for st: Dictionary in n.data["stations"]:
		if st["tasks"].size() < 2 or not st.has("pos"):
			ok_data = false
	_check(ok_data, "every station has a position and tasks")
	var ok_cmds := true
	for c: Dictionary in n.data["commands"]:
		if not n.station_names().has(c["station"]) or c["text"].is_empty():
			ok_cmds = false
	_check(ok_cmds, "commands name known stations")
	_check(n.data["commands"].any(func(c: Dictionary) -> bool: return c["text"] == "Align the Promenade Stabilizers!"), "design command kept")
	var tid: String = n.tasks_at("Promenade")[0]["id"]
	n.go_to("Promenade")
	n.do_task(tid)
	_check(n.tasks_done == [tid], "task done recorded")
	n.queue.clear()
	n._finish()
	var ws: Node = root.get_node("/root/WorldState")
	_check(ws.get_flag("landing_done") == true, "landing_done kept")
	_check(ws.get_flag("landing_tasks_done") == [tid], "tasks flag set")
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	quit(_failures)
