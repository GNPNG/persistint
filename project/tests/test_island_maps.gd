extends SceneTree
## Island maps: required nodes, spawns, exits, collision and walkable routes.
## Run: godot --headless --path project -s tests/test_island_maps.gd

const VILLAGE := "res://scenes/maps/village.tscn"
const TEMPLE := "res://scenes/maps/temple.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _village()
	await _temple()
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


func _load(path: String) -> Node:
	var m: Node = load(path).instantiate()
	root.add_child(m)
	for i in 4:
		await physics_frame
	return m


func _village() -> void:
	var m := await _load(VILLAGE)
	for n in ["Ground", "Nav", "Player", "Initiate", "Drone", "Barren", "TempleDoor", "Mirror",
			"spawn_default", "spawn_from_temple", "Exit_Ruins", "Exit_Cruise", "Exit_Tropical"]:
		_check(m.get_node_or_null(n) != null, "village has " + n)
	_check(m.get_node("Initiate").npc_id == "initiate" and m.get_node("Initiate").dialogue_path.ends_with("offering.dialogue"),
		"village Initiate keeps npc_id and dialogue")
	_check(m.get_node("TempleDoor").target_scene == TEMPLE and m.get_node("TempleDoor").target_spawn == "spawn_from_village",
		"village TempleDoor leads to temple spawn_from_village")
	_check(m.get_node("Exit_Ruins").target_scene == "res://scenes/ruins/ruins_wreck.tscn" and m.get_node("Exit_Ruins").target_spawn == "spawn_default"
			and not m.get_node("Exit_Ruins").locked, "village Exit_Ruins leads to the ruins wreck")
	_check(m.get_node("Exit_Tropical").target_scene == "res://scenes/florida/beach.tscn" and m.get_node("Exit_Tropical").target_spawn == "spawn_default"
			and not m.get_node("Exit_Tropical").locked, "village Exit_Tropical leads to the Florida beach")
	_check(m.get_node_or_null("spawn_from_tropical") != null and m.get_node_or_null("spawn_from_ruins") != null,
		"village has spawns for returns from the beach and the ruins")
	var beach: Node = load("res://scenes/florida/beach.tscn").instantiate()
	var back: Node = beach.get_node_or_null("VillageDoor")
	_check(back != null and back.target_scene == VILLAGE and back.target_spawn == "spawn_from_tropical",
		"beach VillageDoor leads back to village spawn_from_tropical")
	beach.free()
	_check(m.get_node("Ground").get_used_cells().size() == 40 * 38, "village ground tiles cover the map")
	_check(_has_collision(m.get_node("Ground"), Vector2i(0, 5)) and not _has_collision(m.get_node("Ground"), Vector2i(19, 12)),
		"village walls collide, plaza does not")
	var from: Vector2 = m.get_node("spawn_default").position
	var region: NavigationRegion2D = m.get_node("Nav")
	for n in ["TempleDoor", "Initiate", "Drone", "Barren", "Mirror", "Exit_Ruins", "Exit_Cruise", "Exit_Tropical", "spawn_from_temple", "spawn_from_tropical"]:
		_check(_reaches(region, from, m.get_node(n).position), "village: walkable route from spawn to " + n)
	var drone: Node2D = m.get_node("Drone")
	var beds: Vector2i = m.get_node("Ground").get_cell_atlas_coords(m.get_node("Ground").local_to_map(drone.position + Vector2(0, -48)))
	_check(beds.x in [5, 6], "village Drone stands in the garden beds")
	m.queue_free()
	await process_frame


func _temple() -> void:
	var m := await _load(TEMPLE)
	for n in ["Ground", "Nav", "Player", "Priestess", "ExitDoor", "RitualTable", "RuinsDoor",
			"spawn_default", "spawn_from_village", "spawn_from_puzzle"]:
		_check(m.get_node_or_null(n) != null, "temple has " + n)
	_check(m.get_node("ExitDoor").target_spawn == "spawn_from_temple" and not m.get_node("RuinsDoor").locked
			and m.get_node("RuinsDoor").target_scene == "res://scenes/ruins/ruins_wreck.tscn",
		"temple exits: back to village spawn_from_temple, Ruins door leads to the wreck")
	_check(m.get_node("RitualTable").target_scene.ends_with("ritual_puzzle.tscn"), "temple RitualTable leads to the puzzle")
	var from: Vector2 = m.get_node("spawn_default").position
	var region: NavigationRegion2D = m.get_node("Nav")
	for n in ["Priestess", "ExitDoor", "RitualTable", "RuinsDoor", "spawn_from_village", "spawn_from_puzzle"]:
		_check(_reaches(region, from, m.get_node(n).position), "temple: walkable route from spawn to " + n)
	m.queue_free()
	await process_frame


func _has_collision(layer: TileMapLayer, cell: Vector2i) -> bool:
	var td := layer.get_cell_tile_data(cell)
	return td != null and td.get_collision_polygons_count(0) > 0


## True when the navmesh path from a to b ends within 20 px of b.
func _reaches(region: NavigationRegion2D, a: Vector2, b: Vector2) -> bool:
	NavigationServer2D.map_force_update(region.get_navigation_map())
	var path := NavigationServer2D.map_get_path(region.get_navigation_map(), a, b, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(b) < 20.0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
