extends SceneTree
## Headless check of The Landing's command slots and escalation (M4).
## Run: godot --headless --path project -s tests/test_landing_m4.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "FAIL ") + msg)
	if not ok:
		_failures += 1


func _make() -> Control:
	var n: Control = load("res://scenes/minigames/landing.tscn").instantiate()
	root.add_child(n)
	return n


func _cmd(n: Control, control: String, text: String = "") -> Dictionary:
	for c: Dictionary in n.data["commands"]:
		if c["control"] == control and (text.is_empty() or c["text"] == text):
			return c
	return {}


func _run() -> void:
	await process_frame
	var n := _make()
	await process_frame
	_check(is_equal_approx(n.seconds_for(0), 8.0), "seconds_for(0) is 8")
	_check(is_equal_approx(n.seconds_for(12), 6.0), "seconds_for(12) is 6")
	_check(is_equal_approx(n.seconds_for(24), 4.0), "seconds_for(24) is 4")
	_check(is_equal_approx(n.seconds_for(100), 4.0), "seconds_for(100) stays 4")
	_check(n.active_slot_count(7) == 1, "one slot before 8 resolved")
	_check(n.active_slot_count(8) == 2, "two slots from 8 resolved")
	_check(n.slots.size() == 1, "one slot after _ready")
	_check(n.slots[0]["who"] == n.data["first_mate"], "slot 0 is the first mate")
	_check(n.running, "running after _ready")

	n.resolved = 8
	n.fill_slots()
	_check(n.slots.size() == 2, "second slot opens at 8 resolved")
	_check(n.slots[1]["who"] == n.captain_name(), "slot 1 is the captain")
	_check(n.slots[0]["cmd"]["control"] != n.slots[1]["cmd"]["control"], "slots hold different controls")
	n.queue_free()
	await process_frame

	# press: the right control scores, a wrong one changes nothing
	n = _make()
	await process_frame
	n.slots[0]["cmd"] = _cmd(n, "Promenade Stabilizers", "Align the Promenade Stabilizers!")
	n.go_to("Promenade")
	n.press("Deck Chair Gyro")
	_check(n.score == 0 and n.resolved == 0, "wrong control changes nothing")
	n.press("Promenade Stabilizers")
	_check(n.score == 1 and n.resolved == 1, "right control scores and resolves")
	n.queue_free()
	await process_frame

	# Review Focus 1: two slots at one station, one press resolves one
	n = _make()
	await process_frame
	n.resolved = 8
	n.fill_slots()
	n.slots[0]["cmd"] = _cmd(n, "Helm Gyroscope")
	n.slots[1]["cmd"] = _cmd(n, "Fog Horn")
	n.go_to("Bridge")
	n.press("Fog Horn")
	_check(n.resolved == 9 and n.score == 1, "one press resolves exactly one slot")
	var helm := false
	for s: Dictionary in n.slots:
		if s["cmd"].get("control", "") == "Helm Gyroscope":
			helm = true
	_check(helm, "the other command keeps running")
	n.queue_free()
	await process_frame

	# timeout fails the station; Review Focus 4: its buttons disable at once
	n = _make()
	await process_frame
	n.slots[0]["cmd"] = _cmd(n, "Chandelier Counterweight")
	n.go_to("Atrium")
	n._process(100.0)
	await process_frame
	_check(n.failed.has("Atrium"), "timeout fails the station")
	_check(n.resolved == 1 and n.score == 0, "timeout resolves without a score")
	var live := 0
	var all_off := true
	for b: Button in n._controls.get_children():
		if b.is_queued_for_deletion():
			continue
		live += 1
		if not b.disabled:
			all_off = false
	_check(live > 0 and all_off, "controls at the failed station are disabled")
	n.queue_free()
	await process_frame

	# Review Focus 3: the queue running dry does not end the run
	n = _make()
	await process_frame
	n.queue.clear()
	n.fill_slots()
	var full: bool = n.running
	for s: Dictionary in n.slots:
		if s["cmd"].is_empty():
			full = false
	_check(full, "empty queue refills and the run goes on")
	n.queue_free()
	await process_frame

	# R4: the outcome comes from the systems lost
	n = _make()
	await process_frame
	_check(n.outcome() == "smooth", "no failed stations is a smooth landing")
	n.failed.assign(["Bridge", "Spa"])
	_check(n.outcome() == "rough", "two failed stations is a rough landing")
	n.failed.assign(["Bridge", "Spa", "Galley"])
	_check(n.outcome() == "rough", "three failed stations is still rough")
	n.failed.assign(["Bridge", "Spa", "Galley", "Atrium"])
	_check(n.outcome() == "hard", "four failed stations is a hard landing")
	n.queue_free()
	await process_frame

	# R3: the ship lands after 24 resolved commands; Review Focus 2: the end is final
	n = _make()
	await process_frame
	var foot: Node = n._status.get_parent()
	var labels_before := 0
	for ch in foot.get_children():
		if ch is Label:
			labels_before += 1
	n.go_to("Promenade")
	n.slots[0]["cmd"] = _cmd(n, "Promenade Stabilizers", "Align the Promenade Stabilizers!")
	n.press("Promenade Stabilizers")
	_check(n._descent.max_value == 24.0 and n._descent.value == 1.0, "descent bar follows resolved after a press")
	while n.resolved < 24:
		n._resolve(0)
	_check(not n.running, "the run stops at 24 resolved")
	_check(root.get_node("/root/WorldState").get_flag("landing_done", false) == true, "landing_done is set")
	_check(root.get_node("/root/WorldState").get_flag("landing_outcome", "") == n.outcome(), "landing_outcome matches outcome()")
	_check(n._descent.value == 24.0, "descent bar is full at the landing")
	var fail_before: int = n.failed.size()
	var score_before: int = n.score
	n._process(100.0)
	n.press("Promenade Stabilizers")
	_check(n.failed.size() == fail_before, "no more systems fail after landing")
	_check(n.score == score_before, "no more score after landing")
	n._finish()
	var oks := 0
	var labels_after := 0
	for ch in n._controls.get_parent().get_children():
		if ch is Button and ch.text == "OK":
			oks += 1
	for ch in foot.get_children():
		if ch is Label:
			labels_after += 1
	_check(oks == 1, "_finish twice leaves exactly one OK button")
	_check(labels_after == labels_before, "empty end_card text adds no label")
	n.queue_free()
	await process_frame

	# R5: a crew task at a failed station saves its system
	n = _make()
	await process_frame
	var prom_tasks: Array = n.tasks_at("Promenade")
	var task_id: String = prom_tasks[0]["id"]
	n.failed.assign(["Promenade", "Spa"])
	n.go_to("Promenade")
	n.do_task(task_id)
	await process_frame
	_check(not n.failed.has("Promenade") and n.failed.has("Spa"), "a task at a failed station removes only that station from failed")
	_check(n.saved == ["Promenade"], "the saved station is recorded")
	_check(n.tasks_done.has(task_id), "the task is recorded as done")
	var enabled := 0
	for b: Button in n._controls.get_children():
		if not b.is_queued_for_deletion() and not b.disabled:
			enabled += 1
	_check(enabled > 0, "a Promenade control is enabled again")
	n.do_task(task_id)
	_check(n.saved == ["Promenade"] and n.tasks_done.count(task_id) == 1, "the same task done twice saves nothing further")
	n.queue_free()
	await process_frame

	# a task at a station that has not failed is just recorded
	n = _make()
	await process_frame
	n.go_to("Promenade")
	n.do_task(n.tasks_at("Promenade")[0]["id"])
	_check(n.tasks_done.size() == 1 and n.saved.is_empty() and n.failed.is_empty(), "a task at a healthy station saves nothing")
	n.queue_free()
	await process_frame

	# Review Focus 5: a Promenade command can be pressed right after Promenade is saved
	n = _make()
	await process_frame
	n.failed.assign(["Promenade"])
	n.slots[0]["cmd"] = _cmd(n, "Promenade Stabilizers", "Align the Promenade Stabilizers!")
	n.go_to("Promenade")
	n.press("Promenade Stabilizers")
	_check(n.score == 0, "a failed station's control does nothing")
	n.do_task(n.tasks_at("Promenade")[0]["id"])
	n.press("Promenade Stabilizers")
	_check(n.score == 1 and n.resolved == 1, "a held Promenade command scores right after Promenade is saved")
	n.queue_free()
	await process_frame

	# landing_saved is set at the landing
	n = _make()
	await process_frame
	n.failed.assign(["Promenade"])
	n.go_to("Promenade")
	n.do_task(n.tasks_at("Promenade")[0]["id"])
	while n.resolved < 24:
		n._resolve(0)
	var got: Array = root.get_node("/root/WorldState").get_flag("landing_saved", [])
	_check(got == ["Promenade"], "landing_saved is [Promenade] after the landing")
	n.queue_free()
	await process_frame

	print("RESULT: " + ("PASS" if _failures == 0 else "FAIL"))
	quit(_failures)
