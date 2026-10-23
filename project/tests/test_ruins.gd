extends SceneTree
## Headless check of the Ruins of Utopia dungeon crawl: every ruins map loads, doors
## connect (wreck <-> corridor <-> core, exit to temple) with existing spawns, pieces are
## defined in data/ruins.json, and recovery lands in WorldState and survives save/load.
## Run: godot --headless --path project -s tests/test_ruins.gd

const FK := preload("res://scripts/ruins/forbidden_knowledge.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()

	var data := FK.data()
	var scenes: Array = []
	for room: String in data["rooms"]:
		scenes.append(data["rooms"][room]["scene"])
	var pickups_in_scenes := []
	var packed := {}
	for path: String in scenes:
		packed[path] = load(path)
		_check(packed[path] != null, "%s loads" % path)
	for path: String in scenes:
		var inst: Node = packed[path].instantiate()
		for door in _find_all(inst, "Door"):
			var target: String = door.target_scene
			if target == "":
				continue
			_check(packed.has(target) or ResourceLoader.exists(target), "%s door -> %s exists" % [path, target])
			if packed.has(target):
				var other: Node = packed[target].instantiate()
				_check(other.find_child(door.target_spawn, true, false) != null,
					"%s spawn %s exists in %s" % [path, door.target_spawn, target])
				other.free()
		for pickup in _find_all(inst, "KnowledgePickup"):
			pickups_in_scenes.append(pickup.piece_id)
			_check(FK.pieces().has(pickup.piece_id), "piece %s defined in ruins.json" % pickup.piece_id)
		inst.free()
	for id: String in FK.pieces():
		_check(pickups_in_scenes.has(id), "piece %s is placed in a ruins map" % id)

	_check(FK.all().is_empty(), "nothing recovered at start")
	_check(FK.recover("fk_wreck_1"), "first recovery succeeds")
	_check(not FK.recover("fk_wreck_1"), "second recovery of same piece is a no-op")
	_check(not FK.recover("nonexistent"), "unknown piece rejected")
	FK.recover("fk_core_1")
	_check(FK.all() == ["fk_wreck_1", "fk_core_1"], "list is in recovery order")
	ws.flags = {}
	ws.load_save()
	_check(FK.has("fk_wreck_1") and FK.has("fk_core_1") and not FK.has("fk_wreck_2"), "recovered list survives save/load")

	# A recovered pickup is gone when its map loads again.
	var wreck: Node = packed["res://scenes/ruins/ruins_wreck.tscn"].instantiate()
	root.add_child(wreck)
	await process_frame
	await process_frame
	var left := 0
	for p in _find_all(wreck, "KnowledgePickup"):
		if not p.is_queued_for_deletion():
			left += 1
	_check(left == 1, "recovered pickup removed from map on reload (left=%d)" % left)
	wreck.queue_free()

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _find_all(node: Node, node_class: String) -> Array:
	var out := []
	for child in node.find_children("*", "Area2D", true, false):
		var script: Script = child.get_script()
		if script and script.resource_path.get_file().replace(".gd", "").to_pascal_case() == node_class:
			out.append(child)
	return out


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
