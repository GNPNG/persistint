extends SceneTree
## Shot walk (bd wso): renders the screenshots a shot list describes and saves each one as
## <out_dir>/<name>.png, for the visual passes. A shot list is a JSON file: per shot, a scene and
## the steps that set it up (open a dialogue line, a UI screen, move the player or the camera).
## Needs a display (not --headless). tools/shot_walk.sh checks the list (tools/check_shots.py) and
## runs this under Xvfb, one Godot process per shot:
##   godot --path project -s scripts/test/shot_walk.gd -- <shots.json> <out_dir> [--only=a,b] [--list]
## --only renders just the named shots (comma-separated). --list renders nothing: it prints
## "SHOT <name>" for every shot and "BAD <name>: <why>" for one whose name, scene or dialogue file
## is wrong. Lives in scripts/test/, which the Web preset leaves out of the player build.
##
## The run never writes the player's save or settings: WorldState saves to SAVE_FILE and the
## settings autoloads to SETTINGS_FILE (tools/shot_walk.sh also points user:// at a scratch
## directory, so they read none of the player's either). Music is off. Nothing here preloads a
## script that names an autoload: game scripts load after the first frame, from the steps.
##
## The file: {"seed": {flags}, "settle": frames, "shots": [shot, ...]}
## A shot:
##   name     "<area>-<scene>-<state>" in a-z, 0-9 and _; the PNG is <name>.png
##   scene    the res:// scene it opens
##   note     what the shot is for (for the reviewer; not read here)
##   flags    WorldState flags over the seed's, the state the scene opens with ("_clock" is the day)
##   spawn    SceneRouter.next_spawn: the Marker2D a map puts the player on (default spawn_default)
##   before   steps run before the scene opens; steps: steps run after it opens
##   settle   frames between the last step and the shot (default the file's settle, else 60)
##   typing   true leaves a dialogue line typing; otherwise the line is finished for the shot
## Steps, {"do": <kind>, ...}. A node is a path from the open scene ("Father", "Ponies/pony_daisy"),
## "/root/<Autoload>/..." or "group:<name>" (the first node in that group):
##   wait {frames}                       let the game run
##   flags {set: {...}}                  WorldState.set_flag for each (listeners redraw)
##   call {node, method, args}           node.method(args...)
##   interact {node}                     node.interact(), then its dialogue line if it opens one
##   set {node, prop, value}             node.prop = value
##   set_static {script, prop, value}    a static var of a script (the studio intro's gate_mode)
##   player_to {node or pos, offset}     put the player (and the camera on it) there
##   camera {zoom, center}               zoom: a number, or "fit" (the scene's whole map_size in view,
##                                       centred on it); center: "map", [x, y] or a node. A centre
##                                       stops the camera following the player.
##   dialogue {file, title}              DialogueManager.show_dialogue_balloon
##   dialogue_text {text, title}         the same from text (create_resource_from_text)
##   dialogue_next {count}               finish the line and go to the next one, count times
##   dialogue_until {speaker, contains, responses, max}
##                                       go on until a line has that speaker, contains that text
##                                       and/or offers responses (at most max lines, default 40)
##   dialogue_choose {index or contains} pick a response (index counts the allowed ones)
##   press {action}                      an InputEventAction press and release
## A step that can't be done (no such node or method, the dialogue never gets there) fails the
## shot: no PNG, a "SHOT FAIL <name>: <why>" line, and the run exits 1. A saved shot prints
## "SHOT OK <name> <file> <size>".

const SAVE_FILE := "user://shot_walk_save.json"
const SETTINGS_FILE := "user://shot_walk_settings.cfg"
## The autoloads with a SETTINGS_PATH var (each falls back to user://settings.cfg).
const SETTINGS_OWNERS := ["AudioSettings", "Music", "TextSize", "Controls"]
const DEFAULT_SETTLE := 60
## Frames to wait for a dialogue line to show or to move on.
const LINE_WAIT := 120
const NAME_PATTERN := "^[a-z0-9_]+(-[a-z0-9_]+){2,}$"
const STEP_KINDS := ["wait", "flags", "call", "interact", "set", "set_static", "player_to", "camera",
	"dialogue", "dialogue_text", "dialogue_next", "dialogue_until", "dialogue_choose", "press"]

## Why the current shot failed; "" while it is going fine.
var _why := ""
var _name_re := RegEx.create_from_string(NAME_PATTERN)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # the autoloads are in the tree from here on
	var files: Array[String] = []
	var only := PackedStringArray()
	var list_only := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",", false)
		elif a == "--list":
			list_only = true
		else:
			files.append(a)
	if files.size() < (1 if list_only else 2):
		printerr("usage: godot --path project -s scripts/test/shot_walk.gd -- <shots.json> <out_dir> [--only=a,b] [--list]")
		quit(2)
		return
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(files[0]))
	if not (spec is Dictionary and spec.get("shots") is Array):
		printerr("shot_walk: %s is not a shot list (a JSON object with a \"shots\" array)" % files[0])
		quit(2)
		return
	var shots: Array = []
	var seen := {}
	for s: Variant in spec["shots"]:
		var shot_name := String(s.get("name", "")) if s is Dictionary else ""
		if only.is_empty() or shot_name in only:
			shots.append(s)
		seen[shot_name] = true
	var failed: Array[String] = []
	for n: String in only:
		if not seen.has(n):
			print("SHOT FAIL %s: no such shot in %s" % [n, files[0]])
			failed.append(n)
	if list_only:
		quit(1 if _list(shots) > 0 or not failed.is_empty() else 0)
		return

	var out_dir := files[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _quiet()
	var saved := 0
	for s: Variant in shots:
		var shot_name := String(s.get("name", "?")) if s is Dictionary else "?"
		var why := _problem(s)
		if why == "":
			why = await _shoot(spec, s, out_dir)
		if why == "":
			saved += 1
		else:
			print("SHOT FAIL %s: %s" % [shot_name, why])
			failed.append(shot_name)
		await _teardown()
	print("SHOT_WALK: %d saved, %d failed%s" % [saved, failed.size(),
		"" if failed.is_empty() else " (%s)" % ", ".join(PackedStringArray(failed))])
	quit(1 if not failed.is_empty() else 0)


## --list: prints each shot's name, or what is wrong with it; returns how many are wrong.
func _list(shots: Array) -> int:
	var bad := 0
	var names := {}
	for s: Variant in shots:
		var shot_name := String(s.get("name", "?")) if s is Dictionary else "?"
		var why := _problem(s)
		if why == "" and names.has(shot_name):
			why = "the name is used twice"
		names[shot_name] = true
		if why == "":
			print("SHOT %s" % shot_name)
		else:
			print("BAD %s: %s" % [shot_name, why])
			bad += 1
	return bad


## What is wrong with a shot before it runs (its name, scene, step kinds, dialogue and script
## files); "" when nothing is.
func _problem(s: Variant) -> String:
	if not s is Dictionary:
		return "a shot is not a JSON object"
	if _name_re.search(String(s.get("name", ""))) == null:
		return "the name is not <area>-<scene>-<state> in a-z, 0-9 and _"
	var scene := String(s.get("scene", ""))
	if not scene.ends_with(".tscn") or not ResourceLoader.exists(scene):
		return "no scene %s" % scene
	for key: String in ["before", "steps"]:
		if not s.get(key, []) is Array:
			return "%s is not a list of steps" % key
		for step: Variant in s.get(key, []):
			if not step is Dictionary or not String(step.get("do", "")) in STEP_KINDS:
				return "unknown step %s" % [step]
			if step["do"] == "dialogue" and not ResourceLoader.exists(String(step.get("file", ""))):
				return "no dialogue %s" % step.get("file", "")
			if step["do"] == "set_static" and not ResourceLoader.exists(String(step.get("script", ""))):
				return "no script %s" % step.get("script", "")
	return ""


## Points the save and the settings files away from the player's and turns the music off (with
## the dummy audio driver a crossfade's stream swap can stall the run).
func _quiet() -> void:
	root.get_node("WorldState").set("SAVE_PATH", SAVE_FILE)
	for n: String in SETTINGS_OWNERS:
		var node := root.get_node_or_null(n)
		if node != null and "SETTINGS_PATH" in node:
			node.set("SETTINGS_PATH", SETTINGS_FILE)
	var music := root.get_node_or_null("Music")
	if music != null:
		music.call("stop")
		music.set("data", {})
	await _wait(5)


## Sets up and takes one shot; returns why it failed, or "".
func _shoot(spec: Dictionary, s: Dictionary, out_dir: String) -> String:
	_why = ""
	var seed_flags: Variant = spec.get("seed", {})
	var shot_flags: Variant = s.get("flags", {})
	var flags: Dictionary = seed_flags.duplicate(true) if seed_flags is Dictionary else {}
	if shot_flags is Dictionary:
		flags.merge(shot_flags.duplicate(true), true)
	root.get_node("WorldState").set("flags", flags)
	root.get_node("GameClock").call("restore")
	root.get_node("SceneRouter").set("next_spawn", String(s.get("spawn", "spawn_default")))
	var before: Array = s.get("before", [])
	for i in before.size():
		await _step(before[i])
		if _why != "":
			return "before step %d (%s): %s" % [i + 1, before[i].get("do"), _why]
	var path := String(s["scene"])
	var err := change_scene_to_file(path)
	if err != OK:
		return "could not open %s (%s)" % [path, error_string(err)]
	for i in 60:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			break
	if current_scene == null or current_scene.scene_file_path != path:
		return "%s did not open" % path
	await _wait(10)
	var steps: Array = s.get("steps", [])
	for i in steps.size():
		await _step(steps[i])
		if _why != "":
			return "step %d (%s): %s" % [i + 1, steps[i].get("do"), _why]
	await _wait(int(s.get("settle", spec.get("settle", DEFAULT_SETTLE))))
	if not bool(s.get("typing", false)):
		await _finish_typing()
	await RenderingServer.frame_post_draw
	if current_scene == null or current_scene.scene_file_path != path:
		return "the game moved on to %s before the shot" % (current_scene.scene_file_path if current_scene else "no scene")
	var img := root.get_texture().get_image()
	var file := out_dir.path_join("%s.png" % s["name"])
	err = img.save_png(file)
	if err != OK:
		return "could not save %s (%s)" % [file, error_string(err)]
	print("SHOT OK %s %s %s" % [s["name"], file, img.get_size()])
	return ""


## Between shots in one process: closes the settings screen (it pauses play) and frees the
## layers left on the root (dialogue balloons), sparing the autoloads.
func _teardown() -> void:
	var settings := root.get_node_or_null("AudioSettings")
	if settings != null and bool(settings.call("is_open")):
		settings.call("close")
	paused = false
	var autoloads := {}
	for p: Dictionary in ProjectSettings.get_property_list():
		if String(p["name"]).begins_with("autoload/"):
			autoloads[String(p["name"]).trim_prefix("autoload/")] = true
	for c in root.get_children():
		if c is CanvasLayer and not autoloads.has(String(c.name)):
			c.queue_free()
	root.get_node("SceneRouter").set("next_spawn", "spawn_default")
	await _wait(2)


func _step(step: Dictionary) -> void:
	var kind := String(step.get("do", ""))
	match kind:
		"wait":
			await _wait(int(step.get("frames", 1)))
		"flags":
			var ws := root.get_node("WorldState")
			var values: Dictionary = step.get("set", {})
			for k: String in values:
				ws.call("set_flag", k, _arg(values[k]))
		"call", "interact":
			var n := _node(String(step.get("node", "")))
			var method := "interact" if kind == "interact" else String(step.get("method", ""))
			if n == null:
				_why = "no node %s" % step.get("node", "")
				return
			if not n.has_method(method):
				_why = "%s has no method %s" % [step.get("node", ""), method]
				return
			var args: Array = []
			for a: Variant in step.get("args", []):
				args.append(_arg(a))
			n.callv(method, args)
			if kind == "interact":
				await _await_line(20, false)
		"set":
			var n := _node(String(step.get("node", "")))
			var prop := String(step.get("prop", ""))
			if n == null:
				_why = "no node %s" % step.get("node", "")
				return
			if not (prop in n):
				_why = "%s has no property %s" % [step.get("node", ""), prop]
				return
			n.set(prop, _arg(step.get("value")))
		"set_static":
			var target: Script = load(String(step.get("script", "")))
			var prop := String(step.get("prop", ""))
			var value: Variant = _arg(step.get("value"))
			if target == null:
				_why = "could not load %s" % step.get("script", "")
				return
			target.set(prop, value)
			if target.get(prop) != value:
				_why = "%s has no static var %s" % [step.get("script", ""), prop]
		"player_to":
			_player_to(step)
		"camera":
			_camera(step)
		"dialogue", "dialogue_text":
			var dm := root.get_node("DialogueManager")
			var res: Resource
			if kind == "dialogue":
				res = load(String(step.get("file", "")))
			else:
				res = dm.call("create_resource_from_text", String(step.get("text", "")))
			if res == null:
				_why = "no dialogue resource"
				return
			dm.call("show_dialogue_balloon", res, String(step.get("title", "start")))
			await _await_line(LINE_WAIT, true)
		"dialogue_next":
			for i in int(step.get("count", 1)):
				await _advance()
				if _why != "":
					return
		"dialogue_until":
			await _until(step)
		"dialogue_choose":
			await _choose(step)
		"press":
			var action := String(step.get("action", ""))
			if not InputMap.has_action(action):
				_why = "no input action %s" % action
				return
			for pressed: bool in [true, false]:
				var ev := InputEventAction.new()
				ev.action = action
				ev.pressed = pressed
				Input.parse_input_event(ev)
				await process_frame
		_:
			_why = "unknown step %s" % kind


func _wait(frames: int) -> void:
	for i in maxi(frames, 0):
		await process_frame


## JSON numbers are floats; a whole one goes in as an int (an int parameter takes it, and a float
## one converts it back).
func _arg(v: Variant) -> Variant:
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	return v


func _vec(v: Variant) -> Vector2:
	if v is Array and v.size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	_why = "%s is not [x, y]" % [v]
	return Vector2.ZERO


func _node(path: String) -> Node:
	if path.begins_with("group:"):
		return get_first_node_in_group(path.trim_prefix("group:"))
	if path.begins_with("/root"):
		return root.get_node_or_null(NodePath(path))
	if current_scene == null:
		return null
	if path == "" or path == ".":
		return current_scene
	return current_scene.get_node_or_null(NodePath(path))


func _player_to(step: Dictionary) -> void:
	var player := get_first_node_in_group("player") as Node2D
	if player == null:
		_why = "no player in the scene"
		return
	var at := Vector2.ZERO
	if step.has("pos"):
		at = _vec(step["pos"])
	else:
		var n := _node(String(step.get("node", ""))) as Node2D
		if n == null:
			_why = "no node %s" % step.get("node", "")
			return
		at = n.global_position
	if step.has("offset"):
		at += _vec(step["offset"])
	if _why != "":
		return
	player.global_position = at
	if "velocity" in player:
		player.set("velocity", Vector2.ZERO)
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.reset_smoothing()
		cam.force_update_scroll()


func _camera(step: Dictionary) -> void:
	var player := get_first_node_in_group("player")
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player != null else null
	if cam == null:
		cam = root.get_camera_2d()
	if cam == null:
		_why = "no Camera2D"
		return
	var view := Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width", 640)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 360)))
	var map_size := Vector2.ZERO
	if current_scene != null and "map_size" in current_scene:
		map_size = current_scene.get("map_size")
	var center: Variant = step.get("center", null)
	if step.has("zoom"):
		if String(step["zoom"]) == "fit":
			if map_size == Vector2.ZERO:
				_why = "zoom fit needs the scene's map_size"
				return
			var z := minf(view.x / map_size.x, view.y / map_size.y)
			cam.zoom = Vector2(z, z)
			if center == null:
				center = "map"
		else:
			cam.zoom = Vector2.ONE * float(step["zoom"])
	if center != null:
		var at := Vector2.ZERO
		if center is String and center == "map":
			if map_size == Vector2.ZERO:
				_why = "center map needs the scene's map_size"
				return
			at = map_size / 2.0
		elif center is Array:
			at = _vec(center)
		else:
			var n := _node(String(center)) as Node2D
			if n == null:
				_why = "no node %s" % center
				return
			at = n.global_position
		if _why != "":
			return
		cam.top_level = true
		cam.limit_left = -10000000
		cam.limit_top = -10000000
		cam.limit_right = 10000000
		cam.limit_bottom = 10000000
		cam.global_position = at
	cam.reset_smoothing()
	cam.force_update_scroll()


# --- dialogue ---------------------------------------------------------------------------------

func _balloon() -> Node:
	return get_first_node_in_group("dialogue_balloon")


func _line() -> Object:
	var b := _balloon()
	return b.get("dialogue_line") if b != null else null


## Waits up to `frames` for a balloon with a line; with `need`, not getting one fails the shot.
func _await_line(frames: int, need: bool) -> void:
	for i in frames:
		if _line() != null:
			return
		await process_frame
	if need:
		_why = "no dialogue line showed"


## Shows the whole line at once; the responses come up when it has finished typing.
func _finish_typing() -> void:
	var b := _balloon()
	if b == null:
		return
	var label: Object = b.get("dialogue_label")
	if label != null and bool(label.get("is_typing")):
		label.call("skip_typing")
	await _wait(3)


func _advance() -> void:
	var b := _balloon()
	if b == null:
		_why = "no dialogue balloon"
		return
	await _finish_typing()
	var line := _line()
	if line == null:
		_why = "no dialogue line"
		return
	if not (line.get("responses") as Array).is_empty():
		_why = "the line offers responses (use dialogue_choose): %s" % line.get("text")
		return
	b.call("next", String(line.get("next_id")))
	await _await_change(b, line)


func _await_change(b: Node, old: Object) -> void:
	for i in LINE_WAIT:
		await process_frame
		if not is_instance_valid(b):
			_why = "the dialogue ended"
			return
		var line: Object = b.get("dialogue_line")
		if line != null and line != old:
			return
	_why = "the dialogue did not move on"


func _until(step: Dictionary) -> void:
	var most := int(step.get("max", 40))
	await _await_line(LINE_WAIT, true)
	if _why != "":
		return
	for i in most + 1:
		var line := _line()
		if line == null:
			_why = "no dialogue line"
			return
		if _matches(line, step):
			return
		if i == most:
			break
		await _advance()
		if _why != "":
			return
	_why = "no line matched in %d lines" % most


func _matches(line: Object, step: Dictionary) -> bool:
	if step.has("speaker") and String(line.get("character")) != String(step["speaker"]):
		return false
	if step.has("contains") and not String(line.get("text")).contains(String(step["contains"])):
		return false
	if bool(step.get("responses", false)) and (line.get("responses") as Array).is_empty():
		return false
	return true


func _choose(step: Dictionary) -> void:
	await _await_line(LINE_WAIT, true)
	if _why != "":
		return
	await _finish_typing()
	var b := _balloon()
	var line := _line()
	if b == null or line == null:
		_why = "no dialogue line"
		return
	var allowed: Array = []
	for r: Variant in line.get("responses"):
		var ok: Variant = r.get("is_allowed")
		if ok == null or bool(ok):
			allowed.append(r)
	var pick: Variant = null
	if step.has("contains"):
		for r: Variant in allowed:
			if String(r.get("text")).contains(String(step["contains"])):
				pick = r
				break
	elif int(step.get("index", 0)) < allowed.size():
		pick = allowed[int(step.get("index", 0))]
	if pick == null:
		_why = "no such response among %d (%s)" % [allowed.size(), line.get("text")]
		return
	b.call("next", String(pick.get("next_id")))
	await _await_change(b, line)
