extends SceneTree
## Studio intro: it is the main scene; the G|P|G video loads with sound and plays; a key press, a click
## or a tap skips to the main menu; so does the video's end, and the intro ends on its own soon after
## the clip even when the player never reports the end (bd b4m).
## Run: godot --headless --path project -s tests/test_studio_intro.gd

const INTRO := "res://scenes/ui/studio_intro.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == INTRO, "the intro is the main scene")
	var stream: Variant = load("res://assets/video/studio_intro.ogv")
	_check(stream is VideoStreamTheora, "studio_intro.ogv loads as Theora")

	# A key press skips to the main menu.
	change_scene_to_file(INTRO)
	await _frames(3)
	var video: VideoStreamPlayer = current_scene.get_node("Video")
	_check(video.stream != null and video.is_playing(), "the video plays")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key)
	await _frames(4)
	_check(current_scene != null and current_scene.scene_file_path == MAIN_MENU, "a key press goes to the main menu")

	# The video's end goes to the main menu too.
	change_scene_to_file(INTRO)
	await _frames(3)
	current_scene.get_node("Video").finished.emit()
	await _frames(4)
	_check(current_scene != null and current_scene.scene_file_path == MAIN_MENU, "the end of the video goes to the main menu")

	# A click on the picture skips it (bd b4m: the full-screen controls took clicks, only keys worked).
	# Headless, a pushed click skips GUI picking and would reach the intro anyway, so also check that
	# nothing in the intro can take a pointer event and that the intro reads input before the GUI.
	change_scene_to_file(INTRO)
	await _frames(3)
	var takers: Array[String] = []
	for c: Node in [current_scene] + current_scene.find_children("*", "Control", true, false):
		if c is Control and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			takers.append(String(c.name))
	_check(takers.is_empty(), "no control in the intro takes clicks or taps (%s)" % ", ".join(takers))
	_check(current_scene.has_method("_input") and not current_scene.has_method("_unhandled_input"), "the intro reads input before the GUI (_input)")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_visible_rect().size / 2.0
	click.global_position = click.position
	root.push_input(click)
	await _frames(4)
	_check(current_scene != null and current_scene.scene_file_path == MAIN_MENU, "a click on the picture goes to the main menu")

	# So does a tap.
	change_scene_to_file(INTRO)
	await _frames(3)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = root.get_visible_rect().size / 2.0
	root.push_input(tap)
	await _frames(4)
	_check(current_scene != null and current_scene.scene_file_path == MAIN_MENU, "a tap goes to the main menu")

	# The intro ends on its own even when the player never reports the end (the web build).
	change_scene_to_file(INTRO)
	await _frames(3)
	var intro: Node = current_scene
	_check(intro.max_seconds > 7.0 and intro.max_seconds < 10.0, "it ends on its own about a second after the 7 s clip (max_seconds %.1f)" % intro.max_seconds)
	intro.get_node("Video").finished.disconnect(intro._finish)
	intro.max_seconds = 0.3
	await create_timer(0.8).timeout
	await _frames(2)
	_check(current_scene != null and current_scene.scene_file_path == MAIN_MENU, "with no finished signal it still goes to the main menu")

	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
