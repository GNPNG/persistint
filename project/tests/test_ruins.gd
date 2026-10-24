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

	for room: String in data["rooms"]:
		var r: Dictionary = data["rooms"][room]
		_check(r["title"] != "" and not r["ambient"].is_empty() and r["props"].size() >= 5, "room %s has title, ambient lines and props" % room)
	for id: String in FK.pieces():
		_check(FK.pieces()[id]["title"] != "" and FK.pieces()[id]["text"] != "", "piece %s has title and text" % id)
	for room: String in ["bunker_lift", "clone_hall", "records"]:
		_check(data["rooms"].has(room), "bunker room %s defined" % room)
	var core_targets := []
	for door in _find_all(packed["res://scenes/ruins/ruins_core.tscn"].instantiate(), "Door"):
		core_targets.append(door.target_scene)
	_check(core_targets.has("res://scenes/ruins/ruins_bunker_lift.tscn"), "bunker is reached from the core")

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

	await _check_clones(data, packed)

	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


## The failed clone children (zombies) and the polar bear cub batch: placed in the bunker
## rooms inside the walkable floor, with barks, Cast names, and the cubs' pounce.
func _check_clones(data: Dictionary, packed: Dictionary) -> void:
	var cast: Node = root.get_node("/root/Cast")
	var cc: Dictionary = data.get("clone_children", {})
	_check(not cc.get("barks", []).is_empty() and not cc.get("bump_barks", []).is_empty(), "zombie clones have barks and bump barks")
	_check(not cc["cubs"].get("barks", []).is_empty() and not cc["cubs"].get("nom", []).is_empty(), "polar cubs have bear sounds and noms")
	for id: String in cc.get("originals", {}).keys() + [cc["cubs"]["cast"]]:
		_check(cast.full(id) != id, "clone original %s is named in cast.json" % id)
	for piece: Dictionary in data["knowledge"]:
		_check(not FK.fill(piece["text"]).contains("{"), "piece %s names filled from cast" % piece["id"])
	for sfx: String in cc["pounce"]["sfx"] + [cc["pounce"]["nap_sfx"]]:
		_check(ResourceLoader.exists("res://audio/sfx/%s.wav" % sfx), "sfx %s exists" % sfx)

	for room: String in ["clone_hall", "bunker_lift", "records"]:
		var inst: Node = packed[data["rooms"][room]["scene"]].instantiate()
		var outline: PackedVector2Array = inst.get_node("Nav").navigation_polygon.get_outline(0)
		var zs := _find_all(inst, "ZombieChild")
		var cubs := _find_all(inst, "PolarCub")
		_check(not zs.is_empty(), "zombie clones wander the %s" % room)
		if room == "clone_hall":
			var originals := {}
			for z in zs:
				originals[z.original] = true
			_check(originals.size() == cc["originals"].size(), "every original has a batch in the clone hall")
			_check(cubs.size() >= 2, "polar bear cubs in the clone hall")
		for c in zs + cubs:
			var r: Rect2 = c.wander
			var inside := Geometry2D.is_point_in_polygon(c.position, outline)
			for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
				inside = inside and Geometry2D.is_point_in_polygon(corner, outline)
			for i in 50:
				inside = inside and Geometry2D.is_point_in_polygon(c.pick_target(), outline)
			_check(inside, "%s %s stays in nav bounds" % [room, c.name])
		inst.free()

	var hall: Node = packed["res://scenes/ruins/ruins_clone_hall.tscn"].instantiate()
	root.add_child(hall)
	await process_frame
	var zs := _find_all(hall, "ZombieChild")
	var cubs := _find_all(hall, "PolarCub")
	var z: Node2D = zs[0]
	_check(z.designation() == "%s clone, batch %d" % [cast.short(z.original), z.batch], "zombie designation reads the name through Cast (%s)" % z.designation())
	_check(z.bark() != "" and z.bubble.visible and z.bubble.text.begins_with(z.designation()), "zombie barks in its bubble")
	_check(z.sprite.sprite_frames != null and z.sprite.sprite_frames.has_animation("walk_side") \
			and cubs[0].sprite.sprite_frames != null and cubs[0].sprite.sprite_frames.has_animation("nap"), "clone and cub rigs load")
	_check(cubs[0].say("Mrrf!") != "" and cubs[0].bubble.text.contains(cast.full("polar_bear_clone")), "cub makes a bear sound")

	var lab: Node = hall.get_node("CloneLab")
	var cub: Node2D = cubs[1]
	var victim: Node2D = zs[1]
	var key := "%s_batch_%d" % [victim.original, victim.batch]
	var before: int = lab.eaten_count(key)
	_check(lab.pounce(cub, victim) == key, "pounce returns the eaten batch key")
	_check(lab.eaten_count(key) == before + 1, "eaten clone counted in WorldState (%s)" % key)
	_check(not victim.is_in_group("zombie_clones"), "eaten zombie leaves the clone group")
	var particles: Array = lab.gore.find_children("*", "CPUParticles2D", false, false)
	_check(particles.size() >= 3 and lab.gore.get_node_or_null("Puddle") != null, "kawaii gore splatter, hearts, sparkles and puddle spawn")
	_check(cub.sfx.stream != null, "pounce sfx set on the cub")
	_check(cub.current_animation() in ["chomp", "smeared"], "cub has a pink muzzle after eating (%s)" % cub.current_animation())
	await process_frame
	await process_frame
	_check(not is_instance_valid(victim), "eaten zombie removed from the hall")
	var fresh: Node2D = lab.restock({"original": "bill_gates", "batch": 5, "wander": Rect2(200, 300, 100, 100)})
	_check(fresh.is_in_group("zombie_clones") and fresh.get_parent() == hall, "eaten batch restocks from a tank")
	var near: Node2D = lab.zombies()[0]
	cubs[0].global_position = near.global_position + Vector2(20, 0)
	var total: int = lab.eaten_count()
	_check(lab.try_pounce() and lab.eaten_count() == total + 1, "a free cub near a zombie pounces")
	hall.queue_free()
	await process_frame


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
