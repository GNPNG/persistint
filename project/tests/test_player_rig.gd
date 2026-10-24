extends SceneTree
## The paper-doll player is rigged: every worn part has a directional sheet on the same frame
## grid (tools/gen_player_rig.py), the layers play the same animation frame, she walks while she
## moves (facing the way she goes, the side view flipped for right) and stands when she stops.
## NPC caste rigs have a real walk too (their walk frames differ from their idle frames).
## Run: godot --headless --path project -s tests/test_player_rig.gd

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var size := Vector2.ZERO
	var dir := DirAccess.open("res://assets/characters/player")
	var sheets := 0
	for f in dir.get_files():
		if not f.ends_with("_rig.png"):
			continue
		var t: Texture2D = load("res://assets/characters/player/" + f)
		if size == Vector2.ZERO:
			size = t.get_size()
		_check(t.get_size() == size, "%s is on the shared frame grid" % f)
		sheets += 1
	_check(sheets >= 9, "a rig for every canon part (%d)" % sheets)

	change_scene_to_file("res://scenes/maps/village.tscn")
	for i in 3:
		await process_frame
	var p: CharacterBody2D = current_scene.get_tree().get_first_node_in_group("player")
	var layers: Array = [p.get_node("Body"), p.get_node("Dress"), p.get_node("Hair")]
	_check(String(layers[0].animation).begins_with("idle_"), "she stands still at first")
	Input.action_press("move_right")
	for i in 10:
		await physics_frame
		await process_frame
	_check(layers[0].animation == &"walk_left" and layers[0].flip_h, "walking right plays the side walk, flipped")
	var same := true
	for l: AnimatedSprite2D in layers:
		same = same and l.animation == layers[0].animation and l.frame == layers[0].frame and l.flip_h == layers[0].flip_h
	_check(same, "every layer on the same frame")
	Input.action_release("move_right")
	Input.action_press("move_up")
	for i in 6:
		await physics_frame
		await process_frame
	_check(layers[0].animation == &"walk_up", "walking up plays the back walk")
	Input.action_release("move_up")
	for i in 6:
		await physics_frame
		await process_frame
	_check(layers[0].animation == &"idle_up", "stopping stands, still facing up")

	var npc_sheet: Texture2D = load("res://assets/characters/npc_priestess_rig.png")
	# The source PNG, not the imported texture: big sheets import lossy (tools/set_texture_imports.py)
	# and a compressed texture has no pixels to read under the headless renderer.
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/npc_priestess_rig.png"))
	var fr := RigSheet.frame_size(npc_sheet)
	var idle := img.get_region(Rect2i(0, 0, int(fr.x), int(fr.y)))
	var walk := img.get_region(Rect2i(int(fr.x) * 4, 0, int(fr.x), int(fr.y)))
	_check(idle.get_data() != walk.get_data(), "NPC walk frames move (not the idle frame)")
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
