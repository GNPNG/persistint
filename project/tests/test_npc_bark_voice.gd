extends SceneTree
## Villager barks (speech bubbles) are spoken through Voice with the villager's name and pitch.
func _initialize() -> void:
	change_scene_to_file("res://scenes/maps/village.tscn")
	await process_frame
	await process_frame
	var heard: Array = []
	root.get_node("/root/Voice").spoke.connect(func(speaker: String, text: String) -> void: heard.append([speaker, text]))
	var npc: Node = null
	var npc_script := load("res://scripts/npc.gd")
	for n in current_scene.find_children("*", "", true, false):
		if n.get_script() == npc_script and n.is_present():
			npc = n
			break
	var player: Node2D = current_scene.get_tree().get_first_node_in_group("player")
	npc._on_proximity_exited(player)  # the player can spawn beside her, bubble already up
	heard.clear()
	npc._on_proximity_entered(player)
	var ok: bool = heard.size() == 1 and heard[0][0] == npc.display_name and heard[0][1] == npc.current_bark()
	npc._on_proximity_entered(player)  # bubble already showing the same line: not repeated
	ok = ok and heard.size() == 1
	# A conversation takes over from the walk-by bark (bd wso): talking to a villager hides her
	# bubble, and walking up to her again while the balloon is up does not bark.
	var talker: Node = null
	for n in current_scene.find_children("*", "", true, false):
		if n.get_script() == npc_script and n.is_present() and n.dialogue_path != "":
			talker = n
			break
	var talks := talker != null
	if talks:
		var bark: String = talker.current_bark()
		talker._on_proximity_entered(player)
		talker.interact()
		talks = not talker.bubble.visible
		for i in 3:
			await process_frame
		heard.clear()
		talker._on_proximity_exited(player)
		talker._on_proximity_entered(player)
		talks = talks and not talker.bubble.visible and get_first_node_in_group("dialogue_balloon") != null \
			and heard.filter(func(h: Array) -> bool: return h[1] == bark).is_empty()
	ok = ok and talks
	print("RESULT: ", "PASS" if ok else "FAIL", " heard=", heard, " talker=", talker.name if talker else "none", " talks=", talks)
	quit()
