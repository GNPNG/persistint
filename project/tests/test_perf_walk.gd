extends SceneTree
## Walking perf check (bd nmz: the Windows playtest of v0.2.1 had the village at a locked 16.7 ms
## standing and 212 of 972 frames over 33 ms walking). It opens the village, lets it stand for
## IDLE_FRAMES frames, then walks the player across it for WALK_FRAMES frames: click-walks (the
## navigation agent, as a tap or click on the ground) past the three NPCs, who bark at her, and by
## two door names, then arrow-key legs. Each frame it records the wall time since the last frame,
## Performance TIME_PROCESS and TIME_PHYSICS_PROCESS, and over each phase the calls worth watching:
## WorldText.fit calls and fonts made (bd wso.4), RigSheet sheets cut, PaperBake dress calls, lines
## spoken (Voice.spoke), track changes (Music.track_changed), and how the object, resource and node
## counts moved (still climbing while she walks: something allocates per frame).
## It measures and always passes: compare the numbers from two builds (main before a change, the
## branch after it). Frames are capped at 60 per second (Engine.max_fps), as the browser's display
## caps them, so a frame over budget shows as one over 16.7 ms. Headless there is no renderer:
## the wall times are script, physics and engine work only; run it under a display (Xvfb, as
## tools/shot_walk.sh does) to see the drawing as well.
## The counters are read by name from each script, so this runs on a build without them (they
## print as n/a there). Doors are kept from leaving the village (their _gone set), so walking by
## or over one never changes scene. Nothing here preloads a script that names an autoload.
## Run: godot --headless --path project -s tests/test_perf_walk.gd [-- --frames=N --idle=N]

const MAP := "res://scenes/maps/village.tscn"
const IDLE_FRAMES := 240
const WALK_FRAMES := 1200  # 20 s at 60 fps, as the playtest's window
const OVER_MS := 33.0
## Frames to wait after the village opens before measuring: Music loads its tracks one a frame.
const SETTLE_MAX := 900
## Where the walk goes, in order (world px; each snapped onto the navigation mesh): by the Back
## to the Cruise door's name, past the Initiate, the Barren, the To the Ruins door's name and the
## Drone, and back near the spawn.
const ROUTE: Array[Vector2] = [Vector2(560, 372), Vector2(660, 470), Vector2(600, 600),
	Vector2(656, 730), Vector2(330, 540), Vector2(624, 430)]
## Physics frames a click-walk gets to reach its point before the walk moves on.
const LEG_FRAMES := 600
## The arrow-key legs: action and physics frames held.
const KEY_LEGS := [["move_right", 45], ["move_down", 45], ["move_left", 45], ["move_up", 45]]
const COUNTERS := [["res://scripts/util/world_text.gd", "fit_calls"],
	["res://scripts/util/world_text.gd", "fonts_made"],
	["res://scripts/util/rig_sheet.gd", "sheets_built"],
	["res://scripts/util/paper_bake.gd", "dress_calls"]]

var _idle := IDLE_FRAMES
var _walk := WALK_FRAMES
var _sampling := false
var _last_us := 0
var _wall := PackedFloat64Array()
var _proc := PackedFloat64Array()
var _phys := PackedFloat64Array()
var _spoke := 0
var _tracks := 0
var _player: Node2D


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_walk = maxi(1, int(a.trim_prefix("--frames=")))
		elif a.begins_with("--idle="):
			_idle = maxi(1, int(a.trim_prefix("--idle=")))
	_run.call_deferred()


func _run() -> void:
	root.oversampling_override = 2.0  # the 1280x720 window's stretch, as the game's world text sees it
	Engine.max_fps = 60
	process_frame.connect(_sample)
	await process_frame
	root.get_node("/root/SceneRouter").next_spawn = "spawn_default"
	var voice := root.get_node_or_null("/root/Voice")
	if voice and voice.has_signal("spoke"):
		voice.spoke.connect(func(_who: String, _text: String) -> void: _spoke += 1)
	var music := root.get_node_or_null("/root/Music")
	if music and music.has_signal("track_changed"):
		music.track_changed.connect(func(_id: String) -> void: _tracks += 1)
	change_scene_to_file(MAP)
	for i in 3:
		await process_frame
	var m := current_scene
	_player = get_first_node_in_group("player") as Node2D
	if m == null or _player == null:
		print("FAIL the village opened with a player")
		await _end()
		return
	for d in get_nodes_in_group("doors"):
		d.set("_gone", true)  # walking over a door never leaves the village
	await _nav_ready(m.get_node_or_null("Nav") as NavigationRegion2D)
	await _settle(music)
	print("PERF display %s, adapter %s, %d idle and %d walking frames, max_fps %d" % [
		DisplayServer.get_name(), RenderingServer.get_video_adapter_name(), _idle, _walk, Engine.max_fps])

	var before := _counts()
	await _phase(_idle, _stand)
	_report("idle", before)
	before = _counts()
	var start := _player.global_position
	var walked := [0.0]
	await _phase(_walk, _walk_route.bind(walked))
	_report("walk", before)
	print("PERF walked %.0f px (from %s to %s)" % [walked[0], start, _player.global_position])
	await _end()


## Records one frame: wall ms since the last, and the process and physics times (ms).
func _sample() -> void:
	var now := Time.get_ticks_usec()
	if _sampling and _last_us > 0:
		_wall.append((now - _last_us) / 1000.0)
		_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_last_us = now


## Runs `body` while sampling `frames` frames (the body is stopped when they are in).
func _phase(frames: int, body: Callable) -> void:
	_wall.clear()
	_proc.clear()
	_phys.clear()
	_last_us = 0
	_sampling = true
	var running := [true]
	body.call(running)
	while _wall.size() < frames:
		await process_frame
	running[0] = false
	_sampling = false
	_release_keys()
	var nav: NavigationAgent2D = _player.get("nav")
	nav.target_position = _player.global_position  # she stops where she is
	await physics_frame


func _stand(_running: Array) -> void:
	pass


## Click-walks the route, then the arrow-key legs, over and over until the frames are in.
func _walk_route(running: Array, walked: Array) -> void:
	var nav: NavigationAgent2D = _player.get("nav")
	var map := nav.get_navigation_map()
	var last := _player.global_position
	while running[0]:
		for p: Vector2 in ROUTE:
			if not running[0]:
				return
			nav.target_position = NavigationServer2D.map_get_closest_point(map, p)
			for i in LEG_FRAMES:
				await physics_frame
				walked[0] += _player.global_position.distance_to(last)
				last = _player.global_position
				if not running[0] or nav.is_navigation_finished():
					break
		for leg: Array in KEY_LEGS:
			if not running[0]:
				return
			Input.action_press(leg[0])
			for i in int(leg[1]):
				await physics_frame
				walked[0] += _player.global_position.distance_to(last)
				last = _player.global_position
				if not running[0]:
					break
			Input.action_release(leg[0])


func _release_keys() -> void:
	for leg: Array in KEY_LEGS:
		Input.action_release(leg[0])


## The counters now: each script counter (null when the script has none), lines, tracks, objects.
func _counts() -> Dictionary:
	var out := {}
	for c: Array in COUNTERS:
		var script := load(c[0]) as Script
		out[c[1]] = script.get(c[1]) if script else null
	out["lines_spoken"] = _spoke
	out["track_changes"] = _tracks
	out["objects"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	out["resources"] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	out["nodes"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	out["orphan_nodes"] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	return out


func _report(phase: String, before: Dictionary) -> void:
	for pair: Array in [["wall", _wall], ["process", _proc], ["physics", _phys]]:
		print("PERF %s %-8s %s" % [phase, pair[0], _stats(pair[1])])
	var after := _counts()
	var parts := PackedStringArray()
	for k: String in after:
		var a: Variant = after[k]
		var b: Variant = before.get(k)
		parts.append("%s %s" % [k, "n/a" if a == null or b == null else "%+d" % (int(a) - int(b))])
	print("PERF %s counts   %s" % [phase, ", ".join(parts)])


## n, mean, p50, p95, max (ms) and how many are over OVER_MS.
func _stats(v: PackedFloat64Array) -> String:
	if v.is_empty():
		return "no frames"
	var s := v.duplicate()
	s.sort()
	var total := 0.0
	var over := 0
	for x in s:
		total += x
		if x > OVER_MS:
			over += 1
	return "n %d  mean %.2f  p50 %.2f  p95 %.2f  max %.2f  over_%dms %d" % [s.size(), total / s.size(),
		s[int(0.5 * (s.size() - 1))], s[int(0.95 * (s.size() - 1))], s[s.size() - 1], int(OVER_MS), over]


## Waits until the village's navigation map answers (it syncs on worker threads).
func _nav_ready(region: NavigationRegion2D) -> void:
	if region == null:
		return
	var map := region.get_navigation_map()
	for i in 600:
		if NavigationServer2D.region_get_iteration_id(region.get_rid()) > 0 \
				and NavigationServer2D.map_get_iteration_id(map) > 0:
			return
		await physics_frame


## Waits until Music has loaded every track it loads at start (one a frame), so the loads are not
## measured as the village's frames; at most SETTLE_MAX frames.
func _settle(music: Node) -> void:
	var count := -1
	var steady := 0
	for i in SETTLE_MAX:
		await process_frame
		var now: int = music.call("preloaded_count") if music and music.has_method("preloaded_count") else 0
		steady = steady + 1 if now == count else 0
		count = now
		if steady >= 30:
			return


func _end() -> void:
	_release_keys()
	var voice := root.get_node_or_null("/root/Voice")
	if voice and voice.has_method("shutdown"):
		await voice.shutdown()
	if current_scene:
		current_scene.queue_free()
	await process_frame
	print("RESULT: PASS (a measurement: compare the PERF lines of two builds)")
	quit(0)
