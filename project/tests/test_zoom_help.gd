extends SceneTree
## Zoom and help (bd ctw): in a map, - (or the wheel, a pad shoulder, a pinch) zooms the camera
## out one level and + back in, and the magnifier sticker toggles it and shows which way it goes;
## the "?" sticker or F1 opens a help panel that lists the current keys, Escape or Close shuts it,
## and a pad lands on its Close button.
## Run: godot --headless --path project -s tests/test_zoom_help.gd

const VILLAGE := "res://scenes/maps/village.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	change_scene_to_file(VILLAGE)
	await _frames(4)
	var map: Node = current_scene
	var cam: Camera2D = get_first_node_in_group("player").get_node("Camera2D")
	var z0: float = map.ZOOMS[0]
	var z1: float = map.ZOOMS[1]
	_check(is_equal_approx(cam.zoom.x, z0), "the camera starts at the normal zoom (%.2f)" % cam.zoom.x)

	# --- Keys. ---
	_key(KEY_MINUS)
	await create_timer(0.4).timeout
	_check(map.zoom_level == 1 and is_equal_approx(cam.zoom.x, z1), "- zooms out one level (%.2f)" % cam.zoom.x)
	_key(KEY_MINUS)
	await create_timer(0.4).timeout
	_check(map.zoom_level == 1, "and no further")
	_key(KEY_EQUAL)
	await create_timer(0.4).timeout
	_check(map.zoom_level == 0 and is_equal_approx(cam.zoom.x, z0), "+ zooms back in")

	# --- The sticker. ---
	var s: TextureButton = map.get_node("HUD/ZoomSticker")
	_check(s.texture_normal.resource_path.ends_with("zoom_out.png"), "the magnifier shows - at the normal zoom")
	s.pressed.emit()
	await create_timer(0.4).timeout
	_check(map.zoom_level == 1 and s.texture_normal.resource_path.ends_with("zoom_in.png"), "the magnifier zooms out and then shows +")
	s.pressed.emit()
	await create_timer(0.4).timeout
	_check(map.zoom_level == 0, "and zooms back in")

	# --- A pinch (two fingers apart = in, together = out) and a trackpad magnify. ---
	_touch(0, Vector2(300, 180), true)
	_touch(1, Vector2(400, 180), true)  # 100 px apart
	_drag(1, Vector2(330, 180))  # 30 px apart: fingers closer, zoom out
	await create_timer(0.4).timeout
	_check(map.zoom_level == 1, "pinching in zooms out")
	_drag(1, Vector2(480, 180))  # 180 px apart: zoom in
	await create_timer(0.4).timeout
	_check(map.zoom_level == 0, "spreading the fingers zooms in")
	_touch(0, Vector2.ZERO, false)
	_touch(1, Vector2.ZERO, false)
	var g := InputEventMagnifyGesture.new()
	g.factor = 0.8
	root.push_input(g)
	await create_timer(0.4).timeout
	_check(map.zoom_level == 1, "a trackpad pinch zooms out")
	map.set_zoom_level(0)

	# --- Help. ---
	_key(KEY_F1)
	await _frames(2)
	_check(map.help_open(), "F1 opens the help")
	var body: Label = map._help._body if map._help else null
	_check(body != null and "E" in body.text and "Zoom" in body.text, "it lists the keys, E to talk and the zoom")
	var pf: Node = root.get_node("/root/PadFocus")
	var t: Control = pf.topmost()
	_check(t != null and t.name == "CloseButton", "a pad lands on Close (%s)" % (t.name if t else "none"))
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(not map.help_open() and not root.get_node("/root/AudioSettings").is_open(), "Escape shuts the help (and does not open the pause menu)")
	map.get_node("HUD/HelpSticker").pressed.emit()
	await _frames(2)
	_check(map.help_open(), "the ? sticker opens it too")
	map.find_child("CloseButton", true, false).pressed.emit()
	await _frames(2)
	_check(not map.help_open(), "Close shuts it")

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	var up := ev.duplicate()
	up.pressed = false
	root.push_input(up)


func _touch(i: int, at: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = i
	t.position = at
	t.pressed = down
	root.push_input(t)


func _drag(i: int, at: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.index = i
	d.position = at
	root.push_input(d)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
