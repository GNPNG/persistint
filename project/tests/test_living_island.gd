extends SceneTree
## The living island: the Calendar of Blood drives the island NPCs (data/calendar.json
## "schedules"/"places"/"schedule_hold", GameClock.location_for, npc.gd "scheduled").
##   a) every schedule location has a place; its scene loads and its spot is on the map
##   b) GameClock.location_for honours the Offering hold and the schedule
##   c) the village cast stands on the spot of its current place, per phase
##   d) the temple cast is there at morning and away at midday
##   e) on the Festival of the Fourteenth the cast gathers in the Great Hall
##   f) a phase change while a map is loaded moves the cast (walk or fade, no flags set)
##   g) every spot is reachable from spawn_default over the map's nav
## Run: godot --headless --path project -s tests/test_living_island.gd

const VILLAGE := "res://scenes/maps/village.tscn"
const TEMPLE := "res://scenes/maps/temple.tscn"
const GREAT_HALL := "res://scenes/maps/great_hall.tscn"

var _failures := 0
var _ws: Node
var _clock: Node
var _cal: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_ws = root.get_node("/root/WorldState")
	_clock = root.get_node("/root/GameClock")
	var had_save := FileAccess.file_exists(_ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(_ws.SAVE_PATH) if had_save else ""
	_ws.reset()
	_clock.restore()
	_clock.set_process(false)  # phases advance only when the test advances them
	_cal = _clock.calendar_data

	_data()
	_location_for()
	await _village()
	await _temple()
	await _great_hall()

	_ws.reset()
	if had_save:
		var f := FileAccess.open(_ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## (a) The calendar data hangs together: every schedule location has a place, and every place
## with a scene points at a loadable map. The spots themselves are checked per map in _spots.
func _data() -> void:
	var places: Dictionary = _cal.get("places", {})
	var schedules: Dictionary = _cal.get("schedules", {})
	var locations := {}
	for npc_id: String in schedules:
		for entry: Dictionary in schedules[npc_id]:
			locations[str(entry.get("location", ""))] = true
	for location: String in locations:
		_check(places.has(location), "calendar: a place for schedule location '%s'" % location)
	for location: String in places:
		var scene: Variant = (places[location] as Dictionary).get("scene")
		if scene is String and scene != "":
			_check(ResourceLoader.exists(scene), "calendar: the place '%s' scene loads (%s)" % [location, scene.get_file()])


## Per-map part of (a), run on each instantiated map: the spots of the places on this map are
## there for every NPC whose schedule uses them, and every scheduled NPC on the map has a
## schedule of her own.
func _spots(m: Node, scene: String) -> void:
	var places: Dictionary = _cal.get("places", {})
	var schedules: Dictionary = _cal.get("schedules", {})
	for location: String in places:
		var p: Dictionary = places[location]
		var spot: Variant = p.get("spot")
		if not spot is String or spot == "" or str(p.get("scene", "")) != scene:
			continue
		var spot_str := spot as String
		for npc_id: String in schedules:
			var uses := false
			for entry: Dictionary in schedules[npc_id]:
				if str(entry.get("location", "")) == location:
					uses = true
			if not uses:
				continue
			var marker := spot_str % npc_id if "%s" in spot_str else spot_str
			_check(m.find_child(marker, true, false) != null, "%s has the spot %s" % [m.name, marker])
	for c: Node in m.get_children():
		if c.get("scheduled") == true:
			var id := str(c.get("npc_id"))
			_check(schedules.has(id), "%s: the scheduled %s has a schedule" % [m.name, id])


## (b) location_for: the Offering hold keeps the Initiate in the village until the player has
## answered her; then the schedule rules, the festival included.
func _location_for() -> void:
	_ws.reset()
	_clock.day = 1
	_clock.phase_index = 0
	_check(_clock.location_for("initiate") == "village", "hold: a fresh Day 1 morning keeps the Initiate in the village")
	_check(_clock.location_for("drone") == "greenhouse", "no hold: the Drone follows his schedule")
	_ws.set_flag("quest_offering_accepted", true)
	_check(_clock.location_for("initiate") == "temple", "hold released: the temple at morning")
	_clock.phase_index = 1
	_check(_clock.location_for("initiate") == "village", "hold released: the village at midday")
	_clock.phase_index = 3
	_check(_clock.location_for("initiate") == "dormitory", "hold released: the dormitory at night")
	_clock.day = 14
	_clock.phase_index = 1
	_check(_clock.location_for("initiate") == "great_hall", "festival: the Initiate in the Great Hall")
	_check(_clock.location_for("priestess") == "great_hall" and _clock.location_for("barren") == "great_hall",
		"festival: the Priestess and a Barren in the Great Hall")
	var w: Dictionary = _clock.whereabouts("initiate")
	_check(str(w.get("location")) == "great_hall" and str((w.get("place") as Dictionary).get("name", "")) == "the Great Hall"
			and str(w.get("activity")) != "", "whereabouts: location, place and activity")
	_clock.day = 2
	_clock.phase_index = 3
	var w2: Dictionary = _clock.whereabouts("initiate")
	_check((w2.get("place") as Dictionary).get("scene", "x") == null, "whereabouts: the dormitory has no map (scene null)")


## (c) and (f) The village cast through the phases of a plain Day 2, hold released.
func _village() -> void:
	_ws.reset()
	_ws.set_flag("quest_offering_accepted", true)  # the hold released: she follows her schedule
	# Midday.
	_clock.day = 2
	_clock.phase_index = 1
	var m := await _load(VILLAGE)
	_spots(m, VILLAGE)
	_check(_present_at(m, "Drone", _marker(m, "spot_garden")), "midday: the Drone weeds the garden")
	_check(_present_at(m, "Barren", Vector2(560, 600)), "midday: a Barren labours at her yard")
	_check(_present_at(m, "Priestess", Vector2(304, 880)), "midday: the Priestess on doctrinal rounds")
	_check(_present_at(m, "Initiate", Vector2(659.2, 446.4)), "midday: the Initiate practices in the village")
	var hall_door: Node = m.get_node("GreatHallDoor")
	_check(hall_door.target_scene == GREAT_HALL and hall_door.target_spawn == "spawn_from_village",
		"the GreatHallDoor leads to the Great Hall")
	# (g) Every village spot is reachable from spawn_default over the nav.
	var from: Vector2 = m.get_node("spawn_default").position
	var region: NavigationRegion2D = m.get_node("Nav")
	for n in ["spot_well", "spot_shore", "spot_garden", "spot_greenhouse", "spot_compound",
			"GreatHallDoor", "spawn_from_great_hall"]:
		_check(_reaches(region, from, m.get_node(n).position), "village: walkable route from spawn to " + n)
	# (f) A phase change while the map is loaded: who must go leaves on foot, who must be
	# elsewhere on the map walks over; no flag is set for a schedule leave.
	var flags_before: Array = _ws.flags.keys()
	_clock._advance_phase()  # midday -> evening
	_check(await _gone_soon(m, "Priestess"), "evening: the Priestess leaves for the temple on foot")
	_check(not m.get_node("Priestess").is_present(), "evening: the Priestess is not present")
	_check(_no_new_flags(flags_before), "a schedule leave sets no flag")
	_check(await _near_soon(m, "Barren", _marker(m, "spot_shore")), "evening: a Barren walks to the shore")
	_check(await _near_soon(m, "Drone", _marker(m, "spot_greenhouse")), "evening: the Drone walks to the greenhouse")
	_clock._advance_phase()  # evening -> night
	_check(await _gone_soon(m, "Initiate"), "night: the Initiate leaves for the dormitory (away, no map)")
	_check(_no_new_flags(flags_before), "the fade leave sets no flag either")
	_check(await _near_soon(m, "Drone", _marker(m, "spot_compound")), "night: the Drone is returned to the compound")
	m.queue_free()
	await process_frame
	# Morning, read fresh off a new load.
	_clock.phase_index = 0
	m = await _load(VILLAGE)
	_check(_present_at(m, "Barren", _marker(m, "spot_well")), "morning: a Barren hauls water at the well")
	_check(_present_at(m, "Drone", _marker(m, "spot_greenhouse")), "morning: the Drone waters the seedlings")
	_check(not m.get_node("Priestess").is_present(), "morning: the Priestess is away from the village")
	_check(not m.get_node("Initiate").is_present(), "morning: the Initiate is at the temple")
	m.queue_free()
	await process_frame
	# Night.
	_clock.phase_index = 3
	m = await _load(VILLAGE)
	_check(_present_at(m, "Barren", _marker(m, "spot_shore")), "night: a Barren stands by the tide line")
	_check(_present_at(m, "Drone", _marker(m, "spot_compound")), "night: the Drone in the compound")
	_check(not m.get_node("Initiate").is_present(), "night: the Initiate is asleep in the dormitory")
	m.queue_free()
	await process_frame


## (d) The temple cast: there at morning, away at midday.
func _temple() -> void:
	_ws.reset()
	_ws.set_flag("quest_offering_accepted", true)
	_clock.day = 2
	_clock.phase_index = 0
	var m := await _load(TEMPLE)
	_spots(m, TEMPLE)
	_check(_present_at(m, "Priestess", _marker(m, "spot_temple_priestess")), "morning: the Priestess inspects initiates")
	_check(_present_at(m, "Initiate", _marker(m, "spot_temple_initiate")), "morning: the Initiate memorizes the texts")
	var from: Vector2 = m.get_node("spawn_default").position
	var region: NavigationRegion2D = m.get_node("Nav")
	for n in ["spot_temple_priestess", "spot_temple_initiate"]:
		_check(_reaches(region, from, m.get_node(n).position), "temple: walkable route from spawn to " + n)
	m.queue_free()
	await process_frame
	_clock.phase_index = 1
	m = await _load(TEMPLE)
	_check(not m.get_node("Priestess").is_present(), "midday: the Priestess is on doctrinal rounds")
	_check(not m.get_node("Initiate").is_present(), "midday: the Initiate is in the village")
	m.queue_free()
	await process_frame


## (e) The Festival of the Fourteenth gathers the cast in the Great Hall.
func _great_hall() -> void:
	_ws.reset()
	_ws.set_flag("quest_offering_accepted", true)
	_clock.day = 14
	_clock.phase_index = 1
	var m := await _load(GREAT_HALL)
	_spots(m, GREAT_HALL)
	_check(_present_at(m, "Priestess", _marker(m, "spot_great_hall_priestess")), "festival: the Priestess at the head of the hall")
	_check(_present_at(m, "Initiate", _marker(m, "spot_great_hall_initiate")), "festival: the Initiate makes offerings")
	_check(_present_at(m, "Barren", _marker(m, "spot_great_hall_barren")), "festival: a Barren carries baskets")
	var door: Node = m.get_node_or_null("ExitDoor")
	_check(door != null and door.target_scene == VILLAGE and door.target_spawn == "spawn_from_great_hall",
		"the Great Hall door leads back to the village")
	_check(m.get_node_or_null("spawn_from_village") != null, "the Great Hall has the spawn_from_village the village door aims at")
	var from: Vector2 = m.get_node("spawn_default").position
	var region: NavigationRegion2D = m.get_node("Nav")
	for n in ["spot_great_hall_priestess", "spot_great_hall_initiate", "spot_great_hall_barren", "ExitDoor", "FestivalStage"]:
		_check(_reaches(region, from, m.get_node(n).position), "great_hall: walkable route from spawn to " + n)
	m.queue_free()
	await process_frame


## Instantiates a map and waits for its nav to answer (see tests/test_island_maps.gd).
func _load(path: String) -> Node:
	var m: Node = load(path).instantiate()
	root.add_child(m)
	for i in 4:
		await physics_frame
	await _nav_ready(m.get_node("Nav"))
	return m


## Navigation regions and maps sync on worker threads: wait until the map answers with this
## region's own polygons.
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
				and NavigationServer2D.map_get_iteration_id(map) > 0 \
				and NavigationServer2D.map_get_closest_point(map, probe).distance_to(probe) < 1.0:
			return
		await physics_frame


## The world position of a spot marker on the map.
func _marker(m: Node, marker: String) -> Vector2:
	return (m.find_child(marker, true, false) as Node2D).global_position


## True when the named NPC is present and standing at pos.
func _present_at(m: Node, node_name: String, pos: Vector2) -> bool:
	var npc := m.get_node_or_null(node_name)
	return npc != null and npc.is_present() and npc.visible and npc.global_position.distance_to(pos) < 4.0


## True when the named NPC is gone within `seconds` (its leave walk or fade ends).
func _gone_soon(m: Node, node_name: String, seconds := 10.0) -> bool:
	var npc: Node2D = m.get_node(node_name)
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while npc.visible and Time.get_ticks_msec() < until:
		await process_frame
	return not npc.visible


## True when the named NPC stands at pos within `seconds` (its walk over ends).
func _near_soon(m: Node, node_name: String, pos: Vector2, seconds := 10.0) -> bool:
	var npc: Node2D = m.get_node(node_name)
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while npc.global_position.distance_to(pos) > 6.0 and Time.get_ticks_msec() < until:
		await process_frame
	return npc.visible and npc.global_position.distance_to(pos) <= 6.0


## True when no flag but the clock's own appeared since `before` (a schedule leave sets none).
func _no_new_flags(before: Array) -> bool:
	for k: String in _ws.flags.keys():
		if k != "_clock" and k not in before:
			return false
	return true


## True when the navmesh path from a to b ends within 20 px of b.
func _reaches(region: NavigationRegion2D, a: Vector2, b: Vector2) -> bool:
	NavigationServer2D.map_force_update(region.get_navigation_map())
	var path := NavigationServer2D.map_get_path(region.get_navigation_map(), a, b, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(b) < 20.0


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
