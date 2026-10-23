extends SceneTree
## Headless check of the Hottest of the HOT get-ready chains.
## Run: godot --headless --path project -s tests/test_hottest_chains.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()

	var scene: Control = load("res://scenes/minigames/hottest_chains.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.data.get("tasks", null) is Array and scene.data.get("stations", null) is Array,
		"chains: data file loads")
	_check(not scene.chain_complete(), "chains: chain starts incomplete")
	_check_real_chain(scene.data)

	# Synthetic chain: salon needs a ticket from the deck, dresses the doll, then the show.
	scene.data["tasks"] = [
		{"id": "t1", "station": "A", "text": "", "gives": "ticket"},
		{"id": "t2", "station": "B", "text": "", "needs": ["ticket"], "requires": ["t1"],
			"outfit": {"hair": "hair_crown"}},
	]
	_check(scene.available("t1") and not scene.available("t2"), "chains: later task is locked")
	_check(not scene.do_task("t2"), "chains: locked task cannot be done")
	_check(scene.do_task("t1") and scene.items.has("ticket"), "chains: task hands over its item")
	_check(scene.available("t2") and not scene.available("t1"), "chains: item unlocks the next station")
	_check(scene.do_task("t2") and not scene.items.has("ticket"), "chains: task consumes the item")
	_check(scene.doll.outfit["hair"] == "hair_crown", "chains: task dresses the shared paper doll")
	_check(scene.chain_complete(), "chains: complete when every task is done")
	_check(ws.get_flag("hottest_chain_done") == ["t1", "t2"], "chains: progress written to WorldState")
	_check(ws.get_flag("hottest_prep_outfit")["hair"] == "hair_crown", "chains: prepared outfit written")
	scene.queue_free()

	# The show starts on the doll as dressed by the chain.
	var show: Control = load("res://scenes/minigames/hottest_of_the_hot.tscn").instantiate()
	root.add_child(show)
	await process_frame
	_check(show.doll.outfit["hair"] == "hair_crown", "show: starts in the outfit prepared by the chain")
	show.queue_free()

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## The shipped chain: every task reachable in some order, every needed item given, parts exist.
func _check_real_chain(data: Dictionary) -> void:
	var tasks: Array = data.get("tasks", [])
	var parts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/paperdoll_parts.json"))["parts"]
	_check(tasks.size() >= 8 and data.get("stations", []).size() >= 5, "chains: shipped chain has stations and tasks")
	var ids := {}
	var given := {}
	var ok_text := true
	var ok_parts := true
	for t: Dictionary in tasks:
		ids[t["id"]] = true
		ok_text = ok_text and t.get("text", "") != "" and data["stations"].has(t["station"])
		if t.get("gives", "") != "":
			given[t["gives"]] = true
			ok_text = ok_text and data["items"].has(t["gives"])
		for slot: String in t.get("outfit", {}):
			ok_parts = ok_parts and parts.has(t["outfit"][slot])
	_check(ids.size() == tasks.size(), "chains: task ids are unique")
	_check(ok_text and ok_parts, "chains: texts, stations, item names and outfit parts all exist")
	var needs_ok := true
	for t: Dictionary in tasks:
		for n: String in t.get("needs", []):
			needs_ok = needs_ok and given.has(n)
		for r: String in t.get("requires", []):
			needs_ok = needs_ok and ids.has(r)
	_check(needs_ok, "chains: every needed item is handed over somewhere, every prerequisite exists")
	var held: Array = []
	var finished: Array = []
	var progress := true
	while progress:
		progress = false
		for t: Dictionary in tasks:
			if finished.has(t["id"]):
				continue
			var can := true
			for r: String in t.get("requires", []):
				can = can and finished.has(r)
			for n: String in t.get("needs", []):
				can = can and held.has(n)
			if can:
				for n: String in t.get("needs", []):
					held.erase(n)
				if t.get("gives", "") != "":
					held.append(t["gives"])
				finished.append(t["id"])
				progress = true
	_check(finished.size() == tasks.size(), "chains: the whole chain can be finished in order")


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
