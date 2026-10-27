extends SceneTree
## Studio intro: it is the main scene; the G|P|G video loads with sound and plays; a key press, a click
## or a tap skips to the main menu; so does the video's end, and the intro ends on its own soon after
## the clip even when the player never reports the end (bd b4m). On the web build a "tap to start"
## gate comes first and waits for input (the browser keeps the page silent until then); the first
## input starts the sting, the same tap does not also skip it, and after it the intro still ends
## on its own and still skips on a tap.
## Run: godot --headless --path project -s tests/test_studio_intro.gd

const INTRO := "res://scenes/ui/studio_intro.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const Intro := preload("res://scripts/ui/studio_intro.gd")
## Input in the sting's first moments is ignored (one tap is a touch and an emulated click).
const GRACE := 0.45

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


func _on_menu() -> bool:
	return current_scene != null and current_scene.scene_file_path == MAIN_MENU


func _tap() -> void:
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = root.get_visible_rect().size / 2.0
	root.push_input(tap)


func _click() -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_visible_rect().size / 2.0
	click.global_position = click.position
	root.push_input(click)


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == INTRO, "the intro is the main scene")
	var stream: Variant = load("res://assets/video/studio_intro.ogv")
	_check(stream is VideoStreamTheora, "studio_intro.ogv loads as Theora")
	_check(Intro.gate_mode == -1, "the gate is on for the web build only by default")

	# A key press skips to the main menu.
	change_scene_to_file(INTRO)
	await _frames(3)
	var video: VideoStreamPlayer = current_scene.get_node("Video")
	_check(video.stream != null and video.is_playing(), "the video plays")
	_check(not current_scene.gated and not current_scene.get_node("Gate").visible, "no tap-to-start gate off the web build")
	await create_timer(GRACE).timeout
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key)
	await _frames(4)
	_check(_on_menu(), "a key press goes to the main menu")

	# The video's end goes to the main menu too.
	change_scene_to_file(INTRO)
	await _frames(3)
	current_scene.get_node("Video").finished.emit()
	await _frames(4)
	_check(_on_menu(), "the end of the video goes to the main menu")

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
	await create_timer(GRACE).timeout
	_click()
	await _frames(4)
	_check(_on_menu(), "a click on the picture goes to the main menu")

	# So does a tap.
	change_scene_to_file(INTRO)
	await _frames(3)
	await create_timer(GRACE).timeout
	_tap()
	await _frames(4)
	_check(_on_menu(), "a tap goes to the main menu")

	# The intro ends on its own even when the player never reports the end (the web build).
	change_scene_to_file(INTRO)
	await _frames(3)
	var intro: Node = current_scene
	_check(intro.max_seconds > 7.0 and intro.max_seconds < 10.0, "it ends on its own about a second after the 7 s clip (max_seconds %.1f)" % intro.max_seconds)
	intro.get_node("Video").finished.disconnect(intro._finish)
	intro.max_seconds = 0.3
	await create_timer(0.8).timeout
	await _frames(2)
	_check(_on_menu(), "with no finished signal it still goes to the main menu")

	# --- The web build's tap-to-start gate (forced on here; headless is not the web build) ---
	Intro.gate_mode = 1
	change_scene_to_file(INTRO)
	await _frames(3)
	intro = current_scene
	var gate: Control = intro.get_node("Gate")
	_check(intro.gated and gate.visible, "the gate shows")
	_check(gate.get_index() > intro.get_node("Video").get_index(), "the gate draws over the video")
	_check(String(intro.get_node("Gate/Prompt").text).contains("tap"), "the gate says tap to start")
	_check(intro.get_node("Gate/Splash").texture != null, "the gate shows the boot splash")
	video = intro.get_node("Video")
	_check(not video.is_playing() and video.stream == null, "the sting (and its sound) has not started behind the gate")
	# The gate waits: well past the sting's length it is still there.
	intro.max_seconds = 0.3
	await create_timer(1.0).timeout
	_check(current_scene == intro and intro.gated, "the gate waits for input, it does not time out")
	# The first tap (a touch plus the click the touch screen emulates) starts the sting, not the menu.
	_tap()
	_click()
	await _frames(4)
	_check(current_scene == intro and not intro.gated and not gate.visible, "the first tap opens the gate")
	_check(video.stream != null and video.is_playing(), "after the gate the sting plays")
	_check(intro.max_seconds > 7.0, "the sting gets its full length after the gate (%.1f)" % intro.max_seconds)
	# After the gate, a tap still skips it...
	await create_timer(GRACE).timeout
	_tap()
	await _frames(4)
	_check(_on_menu(), "after the gate a tap skips to the main menu")
	# ...and it still ends on its own.
	change_scene_to_file(INTRO)
	await _frames(3)
	intro = current_scene
	var key2 := InputEventKey.new()
	key2.keycode = KEY_ENTER
	key2.pressed = true
	root.push_input(key2)
	await _frames(3)
	_check(not intro.gated and intro.get_node("Video").is_playing(), "a key opens the gate too")
	intro.get_node("Video").finished.disconnect(intro._finish)
	intro.max_seconds = 0.3
	await create_timer(0.8).timeout
	await _frames(2)
	_check(_on_menu(), "after the gate the sting ends on its own")
	Intro.gate_mode = -1

	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
