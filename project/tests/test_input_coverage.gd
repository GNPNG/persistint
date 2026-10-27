extends SceneTree
## Input coverage (QA-07, sops/09): the slice plays keyboard-only and mouse-only.
## Keyboard: E next to the Initiate walks over and opens the conversation, and Enter plays it
## through (the response menu takes the keyboard focus); E with nothing near does nothing; P and J
## open the wardrobe and journal (also in test_first_minutes). Mouse and touch: the hanger and
## book stickers sit under the settings gear, on screen and clear of it, and open the wardrobe and
## the journal; people, doors and the gear take clicks (test_exits, test_pause_menu).
## Run: godot --headless --path project -s tests/test_input_coverage.gd

const VILLAGE := "res://scenes/maps/village.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	change_scene_to_file(VILLAGE)
	await _frames(4)
	var player := get_first_node_in_group("player") as Node2D
	var npc := current_scene.get_node("Initiate") as Node2D
	var dm: Node = root.get_node("/root/DialogueManager")
	var ws: Node = root.get_node("/root/WorldState")

	# --- Keyboard: E with nothing near does nothing. ---
	player.global_position = npc.global_position + Vector2(400, 400)
	await _frames(2)
	_check(player.interact_nearest() == null, "E with nothing near does nothing")

	# --- Keyboard: E next to the Initiate opens the conversation. ---
	player.global_position = npc.global_position + Vector2(30, 10)
	await _frames(2)
	var ended := [false]
	dm.dialogue_ended.connect(func(_r: Variant) -> void: ended[0] = true)
	_key(KEY_E)
	for i in 90:
		await physics_frame
		if not get_nodes_in_group("dialogue_balloon").is_empty():
			break
	_check(not get_nodes_in_group("dialogue_balloon").is_empty(), "E next to the Initiate walks over and opens the conversation")

	# --- Keyboard: Enter plays it through. ---
	var presses := 0
	while not ended[0] and presses < 40:
		_key(KEY_ENTER)
		await create_timer(0.25).timeout  # the balloon types in real time; Enter skips nothing while it types
		presses += 1
	_check(ended[0], "Enter plays the conversation through to its end (%d presses)" % presses)
	_check(ws.has_flag("quest_offering_accepted") or ws.has_flag("refused_offering") or ws.has_flag("questioned_ritual"), "a keyboard answer was taken")

	# --- Mouse and touch: the stickers. ---
	var gear: Control = root.get_node("/root/AudioSettings")._gear
	var screen := root.get_visible_rect()
	for pair: Array in [["WardrobeSticker", "_wardrobe", "wardrobe"], ["JournalSticker", "_journal", "journal"]]:
		var s := current_scene.get_node_or_null("HUD/" + pair[0]) as Control
		_check(s != null and s.is_visible_in_tree(), "the %s sticker shows" % pair[2])
		if s == null:
			continue
		var rect := Rect2(s.position, s.size)
		_check(screen.encloses(rect) and not rect.intersects(Rect2(gear.position, gear.size)), "the %s sticker is on screen and clear of the gear" % pair[2])
		s.pressed.emit()
		await _frames(3)
		var open: Variant = current_scene.get(pair[1])
		_check(open != null and is_instance_valid(open), "the %s sticker opens the %s" % [pair[2], pair[2]])
		s.pressed.emit()
		await _frames(3)
		var closed: Variant = current_scene.get(pair[1])
		_check(closed == null or not is_instance_valid(closed), "and closes it again")

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
