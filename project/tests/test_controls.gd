extends SceneTree
## Options (GC-04): the settings screen has a Fullscreen toggle and a Controls panel. In the
## panel, pressing an action's button and then a key gives the action that key (Escape keeps the
## old one); a key taken from another action leaves it; the keys are saved and come back after a
## reload; Reset restores the project's keys; the panel fits on screen at the largest text size.
## Run: godot --headless --path project -s tests/test_controls.gd
## The test run uses the test settings file (QA-04).

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var controls: Node = root.get_node("/root/Controls")
	var settings: Node = root.get_node("/root/AudioSettings")
	var screen: Node = settings._overlay
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await _frames(3)
	settings.open()
	await _frames(2)
	_check(screen.find_child("Fullscreen", true, false) is CheckButton, "the settings screen has a Fullscreen toggle")
	_check(screen.find_child("ControlsButton", true, false) is Button, "and a Controls button")

	# --- The panel. ---
	screen.open_controls()
	await _frames(2)
	var panel: Control = screen.controls_panel()
	_check(panel != null and panel.visible and not screen.get_node("Center/Panel").visible, "Controls opens in place of the settings panel")
	_check(controls.key_text("toggle_wardrobe") == "P", "the wardrobe is P (%s)" % controls.key_text("toggle_wardrobe"))
	_check(controls.key_text("move_left").contains("A"), "walk left lists A (%s)" % controls.key_text("move_left"))

	# --- Rebind the wardrobe to O through the panel. ---
	panel.find_child("toggle_wardrobe", true, false).pressed.emit()
	await _frames(1)
	_check(panel.listening() == "toggle_wardrobe" and panel.find_child("toggle_wardrobe", true, false).text == "Press a key…", "pressing the button waits for a key")
	_key(KEY_O)
	await _frames(2)
	_check(controls.key_text("toggle_wardrobe") == "O" and _matches(KEY_O, "toggle_wardrobe") and not _matches(KEY_P, "toggle_wardrobe"), "the wardrobe is now O, not P")

	# --- Escape keeps the old key. ---
	panel.find_child("toggle_journal", true, false).pressed.emit()
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(controls.key_text("toggle_journal") == "J" and panel.listening() == "", "Escape while waiting keeps the journal on J")

	# --- Taking a key from another action. ---
	panel.find_child("toggle_journal", true, false).pressed.emit()
	_key(KEY_O)
	await _frames(2)
	_check(_matches(KEY_O, "toggle_journal") and not _matches(KEY_O, "toggle_wardrobe"), "giving O to the journal takes it from the wardrobe")

	# --- Saved and reloaded. ---
	var cfg := ConfigFile.new()
	_check(cfg.load(controls.SETTINGS_PATH) == OK and cfg.get_value("input", "toggle_journal", []) == [KEY_O], "the keys are saved")
	controls.reset()
	_check(controls.key_text("toggle_journal") == "J" and controls.key_text("toggle_wardrobe") == "P", "Reset restores P and J")
	controls.rebind("dismount", _event(KEY_K))
	InputMap.load_from_project_settings()  # as a fresh start would have it
	controls.load_settings()
	_check(_matches(KEY_K, "dismount") and not _matches(KEY_H, "dismount"), "a remap comes back after a reload")
	_check(InputMap.action_get_events("click").size() > 0, "mouse bindings are left alone")
	controls.reset()

	# --- Fits at the largest text. ---
	root.get_node("/root/TextSize").set_step(2)
	await _frames(2)
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "the Controls panel fits on screen at Larger text (%s)" % panel.get_global_rect())
	root.get_node("/root/TextSize").set_step(0)
	panel.find_child("BackButton", true, false).pressed.emit()
	await _frames(1)
	_check(not panel.visible and screen.get_node("Center/Panel").visible, "Back returns to the settings")
	settings.close()

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _event(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func _matches(code: Key, action: String) -> bool:
	return _event(code).is_action_pressed(action)


func _key(code: Key) -> void:
	root.push_input(_event(code))
	var up := _event(code)
	up.pressed = false
	root.push_input(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
