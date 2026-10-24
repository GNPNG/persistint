extends SceneTree
## No art renders at its source resolution by accident (a 440 px tall NPC): every scene the
## screenshot tool shoots is loaded and every Sprite2D / AnimatedSprite2D in a map is checked
## against the size it is shown at (texture frame x global scale). Characters and props must be
## shorter than MAX_HEIGHT world px; ground art (backgrounds drawn from the top-left corner,
## centered = false) is exempt. Characters must also stand on their origin: an NPC's, the
## player's, a critter's and a clone's feet line is within FEET_SLACK px of the node's origin.
## Run: godot --headless --path project -s tests/test_sprite_sizes.gd

const SCENES := [
	"res://scenes/maps/village.tscn", "res://scenes/maps/temple.tscn",
	"res://scenes/ruins/ruins_wreck.tscn", "res://scenes/ruins/ruins_corridor.tscn",
	"res://scenes/ruins/ruins_core.tscn", "res://scenes/ruins/ruins_bunker_lift.tscn",
	"res://scenes/ruins/ruins_clone_hall.tscn", "res://scenes/ruins/ruins_records.tscn",
	"res://scenes/florida/beach.tscn", "res://scenes/florida/garden.tscn",
	"res://scenes/florida/stable.tscn", "res://scenes/florida/aquarium.tscn",
]
## The tallest standing thing on a map is the ship wreck (150 px) and the village's main house.
const MAX_HEIGHT := 200.0
const FEET_SLACK := 3.0
const CHARACTER_SCRIPTS := ["npc.gd", "player.gd", "critter.gd", "zombie_child.gd", "polar_cub.gd", "pony.gd"]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)


func _run() -> void:
	await process_frame
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()
	var checked := 0
	var characters := 0
	for path: String in SCENES:
		change_scene_to_file(path)
		for i in 4:
			await process_frame
		var scene := current_scene
		for n in scene.find_children("*", "", true, false):
			if not (n is Sprite2D or n is AnimatedSprite2D) or not (n as CanvasItem).is_visible_in_tree():
				continue
			var item := n as Node2D
			if item.get("centered") == false:
				continue  # ground art from the top-left corner
			var size := SpriteFit.frame_size(item) * item.global_scale.abs()
			checked += 1
			_check(size.y <= MAX_HEIGHT, "%s %s shows %.0f px tall (texture at native size?)" % [path.get_file(), scene.get_path_to(item), size.y])
		for n in scene.find_children("*", "", true, false):
			var sc: Script = n.get_script()
			if sc == null or not sc.resource_path.get_file() in CHARACTER_SCRIPTS or not (n as CanvasItem).visible:
				continue
			var bottom := _art_bottom(n as Node2D)
			if is_nan(bottom):
				continue
			characters += 1
			_check(absf(bottom - (n as Node2D).global_position.y) <= FEET_SLACK + _feet_gap(n as Node2D),
				"%s %s: art bottom %.1f vs origin %.1f (origin not at the feet)" % [path.get_file(), n.name, bottom, (n as Node2D).global_position.y])
	_check(checked > 100, "only %d sprites checked" % checked)
	_check(characters > 30, "only %d characters checked" % characters)
	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("checked %d sprites, %d characters" % [checked, characters])
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## Lowest edge (global y) of a character's visible frames, NAN when it draws none.
func _art_bottom(c: Node2D) -> float:
	var bottom := NAN
	for n in c.find_children("*", "", true, false):
		if not (n is Sprite2D or n is AnimatedSprite2D) or not (n as CanvasItem).visible:
			continue
		var item := n as Node2D
		var fr := SpriteFit.frame_size(item)
		if fr.y <= 0.0:
			continue
		var off: Vector2 = item.get("offset")
		var local_bottom := off.y + (fr.y / 2.0 if item.get("centered") else fr.y)
		var y := item.global_position.y + local_bottom * item.global_scale.y
		bottom = y if is_nan(bottom) else maxf(bottom, y)
	return bottom


## Rigs that keep a strip of ground under the feet (npc.gd RIG_FEET: 2 of 52 px).
func _feet_gap(c: Node2D) -> float:
	var rig := c.get_node_or_null("Rig") as AnimatedSprite2D
	if rig and rig.sprite_frames and rig.sprite_frames.has_animation("idle_down"):
		return 52.0 * (1.0 - 50.0 / 52.0)
	return 0.0
