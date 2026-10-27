extends SceneTree
## First minutes, headless (QA-16 groundwork, sops/09): the parts of the first-ten-minutes smoke
## test a script can play. A fresh start: the studio intro shows and a click skips it; the main
## menu shows with no save notice and no Continue; New Game opens the village with the player, a
## camera and visible art, and the village music playing; the player walks by keys and by a click;
## an NPC talks; the journal, the wardrobe and Settings open and close by key; after each of these
## the keys still move the player; a door takes the player to the temple; then a "reload" (the save
## read back from disk, the main menu built again) shows Continue, which returns to the temple.
## Between steps the player keeps walking for SOAK_SECONDS of real time, or for --minutes=N when
## given (godot --headless --path project -s tests/test_first_minutes.gd -- --minutes=10).
## What it cannot see (QA-16 still needs a person in each target browser): pixels on screen
## (black or blank canvas), sound reaching the speakers, browser input focus, IndexedDB.
## Run: godot --headless --path project -s tests/test_first_minutes.gd
## The test run uses WorldState's test save (QA-04); the player's real save is never touched.

const MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"
const TEMPLE := "res://scenes/maps/temple.tscn"
const SOAK_SECONDS := 2.0

var _failures := 0
var _soak := SOAK_SECONDS


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--minutes="):
			_soak = maxf(float(arg.get_slice("=", 1)) * 60.0 / 6.0, SOAK_SECONDS)  # six soaks in all
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var music: Node = root.get_node("/root/Music")
	var settings: Node = root.get_node("/root/AudioSettings")
	_check(ws.SAVE_PATH == ws.TEST_SAVE_PATH and ws.flags.is_empty(), "a fresh start: the test save, empty")

	# --- The intro, skipped by a click. ---
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _frames(3)
	_check(current_scene != null and current_scene.visible and current_scene.get_node("Video").is_playing(), "the studio intro shows and plays")
	_click(root.get_visible_rect().size / 2.0)
	await _frames(4)
	_check(_scene() == MENU, "a click skips the intro to the main menu")

	# --- The main menu of a fresh start. ---
	_check(current_scene.get_node("Center").visible and current_scene.get_node_or_null("SaveNotice") == null, "the main menu shows, with no save notice")
	_check(not current_scene.get_node("%BeginButton").visible, "no Continue on a fresh start")

	# --- New Game: the village, the player, the music. ---
	current_scene.get_node("%NewButton").pressed.emit()
	await _frames(6)
	_check(_scene() == VILLAGE, "New Game opens the village")
	var player := get_first_node_in_group("player") as Node2D
	_check(player != null and player.is_visible_in_tree(), "the player is there and visible")
	_check(root.get_camera_2d() != null, "a camera follows")
	_check(_visible_art(current_scene) >= 10, "the village has art showing (%d visible sprites)" % _visible_art(current_scene))
	_check(music.current == "island_village" and music.playing_stream() != null, "the village music is playing (%s)" % music.current)
	_check((ws.get_flag("_location", {}) as Dictionary).get("scene") == VILLAGE, "the location is saved")
	await _keys_still_move(player, "after New Game")
	await _soak_walk(player)

	# --- Walking by a click. ---
	var from := player.global_position
	_click(_screen_of(player.global_position + Vector2(-60, 0)))
	await _physics(45)
	_check(player.global_position.distance_to(from) > 15.0, "a click walks the player (%.0f px)" % player.global_position.distance_to(from))
	_go_home(player, from)

	# --- An NPC talks. ---
	var npc: Node = current_scene.get_node("Initiate")
	var dm: Node = root.get_node("/root/DialogueManager")
	var ended := [false]
	var on_end := func(_r: Variant) -> void: ended[0] = true
	dm.dialogue_ended.connect(on_end)
	npc.interact()
	await _frames(6)
	_check(_find_balloon() != null, "the Initiate talks when approached (a dialogue balloon opens)")
	# Played through as a click on the balloon would (headless, pushed events skip GUI picking, so
	# the balloon's own handlers are called): skip the typing, go on, and at a choice take the
	# first answer ("Of course.").
	var steps := 0
	while not ended[0] and steps < 40:
		var b := _find_balloon()
		if b and is_instance_valid(b.dialogue_line):
			if b.dialogue_label.is_typing:
				b.dialogue_label.skip_typing()
			elif b.dialogue_line.responses.size() > 0:
				b._on_responses_menu_response_selected(b.dialogue_line.responses[0])
			elif b.is_waiting_for_input:
				b.next(b.dialogue_line.next_id)
		await _frames(4)
		steps += 1
	_check(ended[0] and _find_balloon() == null, "the conversation plays through to its end (%d steps)" % steps)
	_check(ws.has_flag("quest_offering_accepted"), "the first answer takes the offering quest")
	dm.dialogue_ended.disconnect(on_end)
	await _keys_still_move(player, "after talking")
	await _soak_walk(player)

	# --- Journal, wardrobe, settings by key. ---
	for pair: Array in [[KEY_J, "_journal", "journal"], [KEY_P, "_wardrobe", "wardrobe"]]:
		_key(pair[0])
		await _frames(3)
		var open: Variant = current_scene.get(pair[1])
		_check(open != null and is_instance_valid(open), "%s opens by key" % pair[2])
		_key(pair[0])
		await _frames(3)
		var closed: Variant = current_scene.get(pair[1])
		_check(closed == null or not is_instance_valid(closed), "%s closes by key" % pair[2])
		await _keys_still_move(player, "after the %s" % pair[2])
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(settings.is_open(), "Escape opens Settings in play")
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(not settings.is_open(), "Escape closes Settings")
	await _keys_still_move(player, "after Settings")
	await _soak_walk(player)

	# --- Through a door. ---
	current_scene.get_node("TempleDoor").interact()
	await _frames(8)
	_check(_scene() == TEMPLE, "the temple door leads to the temple")
	player = get_first_node_in_group("player") as Node2D
	_check(player != null and player.is_visible_in_tree() and _visible_art(current_scene) >= 5, "the temple shows with the player in it")
	_check(music.playing_stream() != null, "music plays in the temple (%s)" % music.current)
	await _keys_still_move(player, "in the temple")
	await _soak_walk(player)
	await _soak_walk(player)

	# --- Reload: the save read back from disk, the menu again, Continue. ---
	var saved_flags: Dictionary = ws.flags.duplicate(true)
	ws.flags = {}
	ws.load_save()
	_check(ws.load_report == "" and (ws.get_flag("_location", {}) as Dictionary).get("scene") == TEMPLE, "the save reads back from disk with the temple as the location")
	_check(ws.flags.size() == saved_flags.size(), "every flag came back (%d)" % ws.flags.size())
	change_scene_to_file(MENU)
	await _frames(4)
	var begin: Button = current_scene.get_node("%BeginButton")
	_check(begin.visible, "after a reload the main menu offers Continue")
	begin.pressed.emit()
	await _frames(8)
	_check(_scene() == TEMPLE, "Continue returns to the temple")
	player = get_first_node_in_group("player") as Node2D
	await _keys_still_move(player, "after Continue")
	await _soak_walk(player)

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _scene() -> String:
	return current_scene.scene_file_path if current_scene else ""


## Holds a move key for a moment; the player has to move.
func _keys_still_move(player: Node2D, when: String) -> void:
	if player == null:
		_check(false, "no player %s" % when)
		return
	var home := player.global_position
	var best := 0.0
	for action: String in ["move_right", "move_left", "move_down", "move_up"]:
		var from := player.global_position
		Input.action_press(action)
		await _physics(20)
		Input.action_release(action)
		await _physics(2)
		best = maxf(best, player.global_position.distance_to(from))
		_go_home(player, home)
		if best > 10.0:
			break
	_check(best > 10.0, "the keys still move the player %s (%.0f px)" % [when, best])


## Walks back and forth for _soak seconds of real time, put back where it started after each leg
## so it never wanders into a door and out of the scene.
func _soak_walk(player: Node2D) -> void:
	if player == null:
		return
	var home := player.global_position
	var until := Time.get_ticks_msec() + int(_soak * 1000.0)
	var dirs := ["move_right", "move_left", "move_down", "move_up"]
	var i := 0
	while Time.get_ticks_msec() < until:
		Input.action_press(dirs[i % 4])
		await _physics(10)
		Input.action_release(dirs[i % 4])
		_go_home(player, home)
		i += 1


## Puts the player back (and stops any click-to-move walk) without leaving the scene.
func _go_home(player: Node2D, home: Vector2) -> void:
	player.global_position = home
	if player.get("nav") != null:
		player.nav.target_position = home


func _visible_art(n: Node) -> int:
	var count := 0
	for c in n.find_children("*", "", true, false):
		if (c is Sprite2D or c is AnimatedSprite2D or c is TileMapLayer or c is TextureRect) and c.is_visible_in_tree():
			count += 1
	return count


## The dialogue balloon, wherever Dialogue Manager put it (under the current scene by default).
func _find_balloon() -> Node:
	for c in root.find_children("*", "", true, false):
		if c.scene_file_path.ends_with("dialogue_balloon.tscn"):
			return c
	return null


func _bubble_showing(npc: Node) -> bool:
	for c in npc.find_children("*", "", true, false):
		if c.get_script() and String(c.get_script().resource_path).ends_with("bark_bubble.gd") and c.is_visible_in_tree():
			return true
	return false


func _screen_of(world: Vector2) -> Vector2:
	return root.get_canvas_transform() * world


func _click(at: Vector2) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	click.global_position = at
	root.push_input(click)
	var up := click.duplicate()
	up.pressed = false
	root.push_input(up)


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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
