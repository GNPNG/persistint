extends SceneTree
## Headless check of The Interview: answers allocate stats (clamped), the result lands in
## WorldState and survives save/load, and the shipped (empty) data finishes cleanly.
## Run: godot --headless --path project -s tests/test_interview.gd
## The player's real save (user://save.json) is backed up and restored.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()

	_check(load("res://dialogue/interview.dialogue") != null, "interview.dialogue compiles")
	_check(root.get_node("/root/Cast").full("oprah") == "Oprah Winfrey", "host name comes from cast.json")

	var iv: Control = load("res://scenes/minigames/interview.tscn").instantiate()
	iv.autostart = false
	root.add_child(iv)
	await process_frame

	# Shipped content: every Oprah line is a verbatim quote from oprah.json.
	iv.begin_interview()
	_check(not iv.interview_done() and iv.stats.size() == 7, "shipped content: questions and 7 stats")
	var quotes: Array = []
	for q: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/quotes/oprah.json"))["quotes"]:
		quotes.append(q["text"])
	var ok: bool = iv.data["intro"].size() > 0
	for line: String in iv.data["intro"]:
		ok = ok and quotes.has(line)
	for q: Dictionary in iv.data["questions"]:
		ok = ok and quotes.has(q["prompt"]) and q["answers"].size() >= 4
	_check(ok, "intro and prompts are Oprah quotes; 4+ answers each")
	iv.finish()
	_check(ws.get_flag("interview_done") == true and ws.get_flag("stats").size() == 7, "shipped content: result written")

	# Synthetic content.
	iv.data = {"host": "oprah", "base": 5, "min": 1, "max": 10,
		"stats": [{"id": "a"}, {"id": "b"}],
		"questions": [
			{"prompt": "q1", "answers": [{"text": "x", "stats": {"a": 2, "b": -1}}, {"text": "y", "stats": {"b": 3}}]},
			{"prompt": "q2", "answers": [{"text": "z", "stats": {"a": 9, "nope": 1}}]},
		]}
	ws.reset()
	iv.begin_interview()
	_check(iv.stats == {"a": 5, "b": 5}, "stats start at base")
	_check(iv.current_prompt() == "q1" and iv.has_answer(1) and not iv.has_answer(2), "question 1 slots")
	iv.pick(0)
	_check(iv.stats == {"a": 7, "b": 4}, "answer applies deltas")
	_check(iv.current_prompt() == "q2" and iv.answer(0) == "z", "advances to question 2")
	iv.pick(0)
	_check(iv.stats["a"] == 10, "stat clamped to max; unknown stat ignored")
	_check(iv.interview_done(), "interview done after last question")
	iv.finish()
	ws.flags = {}
	ws.load_save()
	_check(int(ws.get_flag("stats")["a"]) == 10 and int(ws.get_flag("stats")["b"]) == 4 and ws.has_flag("interview_done"), "stats survive save/load")
	_check(ws.get_flag("interview_answers") == ["x", "z"], "answers recorded")

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
