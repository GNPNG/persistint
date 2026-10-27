extends SceneTree
## Gamepad (QA-13, sops/09): every action has a pad binding; a pad alone gets through the menus by
## focus. On the main menu the first d-pad press lands the focus on the first button, Down moves it
## and A presses it; in play the left stick walks; Start opens the pause menu, the focus lands in
## it, B closes it (and B alone does not open it, since it gets off the pony); Y and X open the
## wardrobe and the journal and the focus lands in them; the credits and the Controls panel take
## the focus when they are on top.
## Run: godot --headless --path project -s tests/test_gamepad.gd

const MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var settings: Node = root.get_node("/root/AudioSettings")
	var pf: Node = root.get_node("/root/PadFocus")

	# --- Bindings. ---
	for action: String in ["move_left", "move_right", "move_up", "move_down", "interact", "toggle_wardrobe",
			"toggle_journal", "dismount", "toggle_fullscreen", "pause", "ui_accept", "ui_cancel", "ui_up", "ui_down"]:
		var pad := InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool:
			return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		_check(not pad.is_empty(), "%s has a pad binding" % action)

	# --- Main menu by pad. ---
	change_scene_to_file(MENU)
	await _frames(3)
	_button(JOY_BUTTON_DPAD_DOWN)
	await _frames(2)
	var focus := root.gui_get_focus_owner()
	_check(focus != null and focus.name == "NewButton", "the first d-pad press lands on the first button (%s)" % (focus.name if focus else "none"))
	_button(JOY_BUTTON_DPAD_DOWN)
	await _frames(2)
	_check(root.gui_get_focus_owner() != focus, "Down moves the focus (%s)" % root.gui_get_focus_owner().name)

	# --- Credits and the Controls panel take the focus when on top. ---
	current_scene.get_node("Credits").open()
	await _frames(2)
	var t: Control = pf.topmost()
	_check(t != null and current_scene.get_node("Credits").is_ancestor_of(t), "over the menu, the credits take the focus (%s)" % (t.name if t else "none"))
	current_scene.get_node("Credits").close()
	settings.open()
	settings._overlay.open_controls()
	await _frames(2)
	t = pf.topmost()
	_check(t != null and settings._overlay.controls_panel().is_ancestor_of(t), "the Controls panel takes the focus (%s)" % (t.name if t else "none"))
	settings._overlay.controls_panel().close()
	settings.close()
	await _frames(2)

	# --- A on New Game starts the game. ---
	current_scene.get_node("Center/Panel/VBox/NewButton").grab_focus()
	_button(JOY_BUTTON_A)
	await _frames(6)
	_check(current_scene.scene_file_path == VILLAGE, "A on New Game opens the village")

	# --- The stick walks. ---
	var player := get_first_node_in_group("player") as Node2D
	var at := player.global_position
	_axis(JOY_AXIS_LEFT_X, 1.0)
	for i in 20:
		await physics_frame
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await physics_frame
	_check(player.global_position.x - at.x > 10.0, "the left stick walks the player (%.0f px)" % (player.global_position.x - at.x))

	# --- Start pauses, the focus lands in the menu, B closes; B alone does not open it. ---
	_button(JOY_BUTTON_B)
	await _frames(2)
	_check(not settings.is_open(), "B in play does not open the pause menu")
	_button(JOY_BUTTON_START)
	await _frames(2)
	_check(settings.is_open() and paused, "Start opens the pause menu")
	_button(JOY_BUTTON_DPAD_DOWN)
	await _frames(2)
	focus = root.gui_get_focus_owner()
	_check(focus != null and settings._overlay.is_ancestor_of(focus), "the focus lands in the pause menu (%s)" % (focus.name if focus else "none"))
	_button(JOY_BUTTON_B)
	await _frames(2)
	_check(not settings.is_open() and not paused, "B closes it")

	# --- Y and X: wardrobe and journal, focus inside. ---
	for pair: Array in [[JOY_BUTTON_Y, "_wardrobe", "wardrobe"], [JOY_BUTTON_X, "_journal", "journal"]]:
		_button(pair[0])
		await _frames(3)
		var screen: Variant = current_scene.get(pair[1])
		_check(screen != null and is_instance_valid(screen), "%s opens from the pad" % pair[2])
		if screen != null and is_instance_valid(screen):
			t = pf.topmost()
			_check(t == null or screen.is_ancestor_of(t), "the focus would land in the %s (%s)" % [pair[2], t.name if t else "nothing focusable"])
		_button(pair[0])
		await _frames(3)

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _button(b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventJoypadButton.new()
	up.button_index = b
	up.pressed = false
	Input.parse_input_event(up)


func _axis(a: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
