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
	_check(n.tasks_at("Promenade").is_empty(), "tasks ship empty")
	n.data["stations"][0]["tasks"] = [{"id": "t1", "text": "x"}]
	n.go_to("Promenade")
	n.do_task("t1")
	_check(n.tasks_done == ["t1"], "task done recorded")
	n.queue.clear()
	n._finish()
	var ws: Node = root.get_node("/root/WorldState")
	_check(ws.get_flag("landing_done") == true, "landing_done kept")
	_check(ws.get_flag("landing_tasks_done") == ["t1"], "tasks flag set")
	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	quit(_failures)
