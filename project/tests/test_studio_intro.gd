extends SceneTree
## Studio intro: it is the main scene; the G|P|G video loads with sound and plays; a key press
## skips to the main menu; so does the video's end.
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

	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
