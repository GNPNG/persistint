extends SceneTree
## A conversation holds the move keys only while it is up (bd d15.84): during a dialogue the keys do
## not move the player; when the balloon goes away without the dialogue ending (freed, as on a
## scene change mid-conversation) the keys work again; a scene change mid-conversation leaves the
## next map's player free to move.
## Run: godot --headless --path project -s tests/test_dialogue_lock.gd
## The test run uses WorldState's test save (QA-04).

const VILLAGE := "res://scenes/maps/village.tscn"
const TEMPLE := "res://scenes/maps/temple.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	change_scene_to_file(VILLAGE)
	await _frames(4)
	var player := get_first_node_in_group("player") as Node2D

	# --- During a conversation the keys do not move the player. ---
	current_scene.get_node("Initiate").interact()
	await _frames(4)
	_check(player.in_dialogue() and not get_nodes_in_group("dialogue_balloon").is_empty(), "a conversation is up")
	_check(await _moved(player) < 2.0, "the keys do not move the player during it")

	# --- The balloon goes away without the dialogue ending: the keys work again. ---
	for b in get_nodes_in_group("dialogue_balloon"):
		b.queue_free()
	await _frames(3)
	_check(not player.in_dialogue(), "the player is free once the balloon is gone")
	_check(await _moved(player) > 10.0, "the keys move the player again")

	# --- A scene change in the middle of a conversation. ---
	current_scene.get_node("Initiate").interact()
	await _frames(4)
	_check(player.in_dialogue(), "a second conversation is up")
	change_scene_to_file(TEMPLE)
	await _frames(6)
	player = get_first_node_in_group("player") as Node2D
	_check(player != null and not player.in_dialogue(), "after a scene change mid-conversation the new map's player is free")
	for b in get_nodes_in_group("dialogue_balloon"):
		b.queue_free()  # the old balloon, if it outlived its scene
	await _frames(2)
	_check(await _moved(player) > 10.0, "and the keys move it")

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


## How far a held move key takes the player (it is put back afterwards).
func _moved(player: Node2D) -> float:
	var home := player.global_position
	var best := 0.0
	for action: String in ["move_right", "move_left", "move_down", "move_up"]:
		Input.action_press(action)
		for i in 20:
			await physics_frame
		Input.action_release(action)
		await physics_frame
		best = maxf(best, player.global_position.distance_to(home))
		player.global_position = home
		if best > 10.0:
			break
	return best


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
