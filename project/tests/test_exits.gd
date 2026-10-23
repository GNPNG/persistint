extends SceneTree
## Every exit in every map can be seen, clicked and walked through: for each door in
## scenes/maps, scenes/ruins, scenes/florida and scenes/chapters the test loads the map,
## puts the player a short walk away, clicks the door through the real viewport input
## (so a full-screen Control eating clicks fails here), steps physics until the player
## arrives and the scene changes, then checks the target scene and its arrival spawn.
## Static checks per map: doors have a visible marker or prop and a destination name, sit
## within reach of the navmesh, and no spawn marker sits inside a door (instant bounce).
## Run: godot --headless --path project -s tests/test_exits.gd

const DIRS := ["res://scenes/maps", "res://scenes/ruins", "res://scenes/florida", "res://scenes/chapters"]
const DOOR_SCRIPT := "res://scripts/door.gd"
const MAP_SCRIPT := "res://scripts/map.gd"
const BODY_OFFSET := Vector2(0, 8)  # player.tscn Collision position
const BODY_RADIUS := 8.0
const REACH := 34.0  # player.gd INTERACT_DISTANCE

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""

	for path in _map_scenes():
		var doors := _door_names(path)
		await _static_checks(path)
		for door_name in doors:
			ws.reset()
			await _walk_through(path, door_name)

	if current_scene:
		current_scene.queue_free()
	await process_frame
	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## True when the script is map.gd or extends it (e.g. the Florida stable).
func _runs_map(script: Script) -> bool:
	while script != null:
		if script.resource_path == MAP_SCRIPT:
			return true
		script = script.get_base_script()
	return false


## Every scene in DIRS whose root runs map.gd (chapter_end is a card, not a map: no doors).
func _map_scenes() -> Array:
	var out := []
	for dir in DIRS:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tscn"):
				continue
			var path: String = dir + "/" + f
			var inst: Node = load(path).instantiate()
			var is_map := _runs_map(inst.get_script())
			if not is_map:
				_check(_doors(inst).is_empty(), "%s is not a map and has no doors" % path)
			else:
				out.append(path)
			inst.free()
	_check(out.size() >= 11, "found the island, ruins and tropical maps (%d)" % out.size())
	return out


func _doors(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Area2D", true, false):
		if c.get_script() and c.get_script().resource_path == DOOR_SCRIPT:
			out.append(c)
	return out


func _door_names(path: String) -> Array:
	var inst: Node = load(path).instantiate()
	var out := []
	for d in _doors(inst):
		out.append(inst.get_path_to(d))
	inst.free()
	return out


func _load(path: String, spawn := "spawn_default") -> Node:
	if current_scene:
		current_scene.free()
	root.get_node("/root/SceneRouter").next_spawn = spawn
	var m: Node = load(path).instantiate()
	root.add_child(m)
	current_scene = m
	for i in 3:
		await physics_frame
	await _nav_ready(m.get_node("Nav"))
	return m


## Navigation syncs on worker threads; wait until the map answers with this region's polygons.
func _nav_ready(region: NavigationRegion2D) -> void:
	var map := region.get_navigation_map()
	var poly := region.navigation_polygon
	var first := poly.get_polygon(0)
	var probe := Vector2.ZERO
	for i in first:
		probe += poly.vertices[i] / first.size()
	probe = region.global_transform * probe
	for i in 600:
		if NavigationServer2D.region_get_iteration_id(region.get_rid()) > 0 \
				and NavigationServer2D.map_get_closest_point(map, probe).distance_to(probe) < 1.0:
			return
		await physics_frame


func _door_rect(d: Area2D) -> Rect2:
	var cs: CollisionShape2D = d.get_node("CollisionShape2D")
	var size: Vector2 = (cs.shape as RectangleShape2D).size
	return Rect2(cs.global_position - size / 2, size)


## The player's body circle at a position touches the door rect.
func _body_in(rect: Rect2, pos: Vector2) -> bool:
	var c := pos + BODY_OFFSET
	var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return nearest.distance_to(c) < BODY_RADIUS


func _static_checks(path: String) -> void:
	var m := await _load(path)
	var map: RID = m.get_node("Nav").get_navigation_map()
	var doors := _doors(m)
	var markers := m.find_children("spawn_*", "Marker2D", true, false)
	for d: Area2D in doors:
		var label := "%s %s" % [path.get_file(), d.name]
		_check(d.show_marker or d.get_parent().get_children().any(
				func(n: Node) -> bool: return n is Sprite2D and n.global_position.distance_to(d.global_position) < 24),
			"%s is visible (marker or prop)" % label)
		_check(d.destination_name() != "" and d.get_node("NameLabel").text == d.destination_name(),
			"%s names its destination (%s)" % [label, d.destination_name()])
		var closest := NavigationServer2D.map_get_closest_point(map, d.global_position)
		_check(closest.distance_to(d.global_position) <= REACH or _body_in(_door_rect(d), closest),
			"%s is within reach of the navmesh" % label)
		for c in m.find_children("*", "Control", true, false):
			var ctl := c as Control
			if ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE and ctl.get_global_rect().has_point(d.global_position) \
					and not _in_canvas_layer(ctl):
				_check(false, "%s is not covered by click-eating %s" % [label, ctl.name])
	for mk: Marker2D in markers:
		var on_nav := NavigationServer2D.map_get_closest_point(map, mk.global_position).distance_to(mk.global_position) < 2.0
		_check(on_nav, "%s %s is on the navmesh" % [path.get_file(), mk.name])
		for d: Area2D in doors:
			_check(not _body_in(_door_rect(d), mk.global_position),
				"%s %s does not sit inside %s" % [path.get_file(), mk.name, d.name])


func _in_canvas_layer(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is CanvasLayer:
			return true
		p = p.get_parent()
	return false


func _walk_through(path: String, door_path: NodePath) -> void:
	var m := await _load(path)
	var d: Area2D = m.get_node(door_path)
	var label := "%s %s" % [path.get_file(), d.name]
	var player: CharacterBody2D = get_first_node_in_group("player")
	var map: RID = m.get_node("Nav").get_navigation_map()
	# Start a short walk away, on the route a player takes from the map's default spawn.
	player.global_position = _before(map, m.get_node("spawn_default").global_position, d.global_position, 72.0)
	for i in 4:
		await physics_frame
	await process_frame  # camera follows on process frames; the click maps through it
	await process_frame
	var target_scene: String = d.target_scene
	var target_spawn: String = d.target_spawn
	var entered := [false]
	d.body_entered.connect(func(b: Node2D) -> void: entered[0] = entered[0] or b == player)
	var router: Node = root.get_node("/root/SceneRouter")
	router.next_spawn = "__unset__"

	_click(d.global_position)
	await physics_frame
	await physics_frame
	_check(player.get("_interact_target") == d, "%s: clicking it walks the player there (target %s, door %s, mouse %s)"
		% [label, player.get_node("NavigationAgent2D").target_position, d.global_position, m.get_global_mouse_position()])

	var arrived := false
	for i in 900:
		await physics_frame
		if current_scene != m and current_scene != null:
			arrived = true
			break
	_check(arrived, "%s: walking there changes the scene (player ended at %s, door %s)" % [label,
		player.global_position if is_instance_valid(player) else Vector2.INF, d.global_position if is_instance_valid(d) else Vector2.INF])
	if not arrived:
		return
	_check(router.next_spawn == target_spawn, "%s: SceneRouter got spawn %s" % [label, target_spawn])
	var target := current_scene
	_check(target != null and target.scene_file_path == target_scene, "%s: landed in %s" % [label, target_scene])
	if target == null or target.get_script() == null or target.get_script().resource_path != MAP_SCRIPT:
		return  # mini-game or chapter card: no spawn markers
	var spawn: Node2D = target.find_child(target_spawn, true, false)
	_check(spawn != null, "%s: %s has spawn %s" % [label, target_scene.get_file(), target_spawn])
	var p2: Node2D = get_first_node_in_group("player")
	_check(spawn != null and p2 != null and p2.global_position == spawn.global_position, "%s: player placed at the spawn" % label)
	for i in 20:
		await physics_frame
	_check(current_scene == target, "%s: no bounce back out on arrival" % label)


## The point `back` px before the end of the navmesh path from a to b.
func _before(map: RID, a: Vector2, b: Vector2, back: float) -> Vector2:
	var path := NavigationServer2D.map_get_path(map, a, b, true)
	if path.is_empty():
		return a
	var left := back
	for i in range(path.size() - 1, 0, -1):
		var seg := path[i].distance_to(path[i - 1])
		if seg >= left:
			return path[i].move_toward(path[i - 1], left)
		left -= seg
	return path[0]


## A left click on a world position, pushed through the viewport like a real mouse.
func _click(world: Vector2) -> void:
	var screen: Vector2 = root.get_canvas_transform() * world
	var mm := InputEventMouseMotion.new()
	mm.position = screen
	mm.global_position = screen
	root.push_input(mm, true)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = screen
	ev.global_position = screen
	root.push_input(ev, true)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	root.push_input(up, true)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
