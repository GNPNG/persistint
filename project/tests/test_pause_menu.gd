extends SceneTree
## Pause menu and main menu (GC-02, GC-03, sops/09): in play, Escape opens the settings screen as
## the pause menu (the game pauses, the title reads Paused, Done reads Resume, Quit to Menu shows,
## the player cannot move); Resume or Escape closes it and play goes on; Quit to Menu returns to
## the main menu unpaused. On the main menu the screen is plain Settings (no pause, no Quit to
## Menu), and the menu has New Game, Continue only with a save, Settings, Fullscreen, Credits and,
## off the web, Quit.
## Run: godot --headless --path project -s tests/test_pause_menu.gd

const MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var settings: Node = root.get_node("/root/AudioSettings")
	var ws: Node = root.get_node("/root/WorldState")
	var screen: Node = settings._overlay

	# --- The main menu of a fresh start. ---
	change_scene_to_file(MENU)
	await _frames(3)
	var box: Node = current_scene.get_node("Center/Panel/VBox")
	_check(box.get_node("NewButton").visible and not box.get_node("BeginButton").visible, "New Game shows, Continue does not without a save")
	for name: String in ["SettingsButton", "FullscreenButton", "QuitButton"]:
		_check(box.get_node_or_null(name) != null and box.get_node(name).visible, "the menu has %s" % name)
	_check(current_scene.get_node("Colophon/CreditsButton").visible, "the menu has Credits")
	var panel: Control = current_scene.get_node("Center/Panel")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "the menu panel fits on screen (%s)" % panel.get_global_rect())
	settings.open()
	await _frames(2)
	_check(not paused and screen.get_node("Center/Panel/VBox/Title").text == "Settings" and not screen.get_node("Center/Panel/VBox/QuitToMenuButton").visible, "on the main menu Settings does not pause and has no Quit to Menu")
	settings.close()

	# --- In play: Escape is the pause menu. ---
	change_scene_to_file(VILLAGE)
	await _frames(4)
	var player := get_first_node_in_group("player") as Node2D
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(settings.is_open() and paused and settings.is_paused(), "Escape in play opens the pause menu and pauses the game")
	_check(screen.get_node("Center/Panel/VBox/Title").text == "Paused" and screen.get_node("%DoneButton").text == "Resume" and screen.get_node("Center/Panel/VBox/QuitToMenuButton").visible, "it reads Paused, with Resume and Quit to Menu")
	var at := player.global_position
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	_check(player.global_position.distance_to(at) < 1.0, "the player does not move while paused")
	screen.get_node("%DoneButton").pressed.emit()
	await _frames(3)
	_check(not settings.is_open() and not paused, "Resume closes it and play goes on")
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.distance_to(at) > 10.0, "the player moves again")

	# --- Quit to Menu. ---
	ws.set_flag("_location", {"scene": VILLAGE, "spawn": "spawn_default"})
	settings.open()
	await _frames(2)
	screen.get_node("Center/Panel/VBox/QuitToMenuButton").pressed.emit()
	await _frames(4)
	_check(current_scene.scene_file_path == MENU and not paused and not settings.is_open(), "Quit to Menu returns to the main menu, unpaused")
	_check(current_scene.get_node("Center/Panel/VBox/BeginButton").visible, "and Continue shows for the game in progress")

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
