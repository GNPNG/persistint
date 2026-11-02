extends SceneTree
## The cruise ship as a walkable place (bd ue6, eatw): data/cruise_ship.json names decks and rooms;
## tools/gen_cruise_ship.mjs built scenes/cruise/ship_section.tscn (the cross-section) and a
## room_<id>.tscn per room with a floor. Checked: the slice loads with map.gd, a navigation region,
## spawn_default at the starting room and spawn_from_<id> for every room; every room door targets
## a scene that exists (a room scene, or the minigame the data names) with a spawn marker that
## exists in it; every room scene loads and has a door back to the slice at its own spawn; the
## cruise chapter returns to the slice (data/chapters.json). Nothing is saved.
## Run: godot --headless --path project -s tests/test_cruise_ship.gd

const SHIP := "res://scenes/cruise/ship_section.tscn"

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _has_spawn(scene_path: String, spawn: String) -> bool:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return false
	var inst: Node = packed.instantiate()
	var ok := inst.find_child(spawn, true, false) != null
	inst.free()
	return ok


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cruise_ship.json"))
	_check(data.has("decks") and data["decks"].size() >= 3, "cruise_ship.json has the decks (%d)" % data.get("decks", []).size())
	var ship: Node = load(SHIP).instantiate()
	root.add_child(ship)
	await process_frame
	_check(ship.get_script() != null and ship.get("map_size") != null, "the slice is a map (map.gd, map_size)")
	_check(ship.get_node_or_null("Nav") is NavigationRegion2D, "the slice has a navigation region")
	_check(ship.get_node_or_null("spawn_default") != null, "the slice has spawn_default (her cabin)")
	var rooms := 0
	for deck: Dictionary in data["decks"]:
		for room: Dictionary in deck["rooms"]:
			rooms += 1
			var id: String = room["id"]
			_check(ship.get_node_or_null("spawn_from_%s" % id) != null, "spawn_from_%s is on the slice" % id)
			var door: Node = null
			for child in ship.get_children():
				if child.get("target_scene") != null and String(child.name).to_lower().begins_with(id.replace("_", "")):
					door = child
			_check(door != null, "%s has a door on the slice" % id)
			if door == null:
				continue
			var target: String = door.target_scene
			_check(ResourceLoader.exists(target), "%s door targets an existing scene (%s)" % [id, target])
			if not room.has("scene"):  # the minigames place the player themselves
				_check(_has_spawn(target, door.target_spawn), "%s door's spawn %s exists in %s" % [id, door.target_spawn, target.get_file()])
			if not room.has("scene"):
				var r: Node = load(target).instantiate()
				var back: Node = r.get_node_or_null("ShipDoor")
				_check(back != null and back.target_scene == SHIP and back.target_spawn == "spawn_from_%s" % id, "%s returns to the slice at its own spawn" % id)
				_check(r.get_node_or_null("Nav") is NavigationRegion2D and r.get_node_or_null("spawn_default") != null, "%s has a floor and a spawn" % id)
				r.free()
	_check(rooms >= 8, "%d rooms on the ship" % rooms)
	var chapters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var cruise: Dictionary = chapters.get("chapters", chapters).get("cruise", {})
	_check(cruise.get("return_scene", "") == SHIP, "the cruise chapter returns to the ship (%s)" % cruise.get("return_scene", ""))
	ship.queue_free()
	await process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
