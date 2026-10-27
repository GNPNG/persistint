extends SceneTree
## A door's name, shown when the player arrives next to it, can be read (bd wso): for every spawn
## marker within the door's NEAR_DISTANCE in every map of scenes/maps, scenes/ruins and
## scenes/florida, the map is opened with the player on that marker and the door's name label is
## checked once it shows: its text is all inside the camera's view across (the temple's way into
## the ruins sits at x 24 and named itself "...to the Ruins of Utopia" with the start cut off) and
## it is not drawn over the player standing there (the aquarium's arrival spawn put "Back to the
## Beach" across her skirt). In a ruins room the name is in the ruins captions' colours, lilac-white
## on a dark plum outline (STYLE.md 6.3; bd wso.1: plum on a white outline came out plum on grey
## over the dark walls).
## Run: godot --headless --path project -s tests/test_door_labels.gd

const DIRS := ["res://scenes/maps", "res://scenes/ruins", "res://scenes/florida"]
const DOOR_SCRIPT := "res://scripts/door.gd"
const MAP_SCRIPT := "res://scripts/map.gd"
const DECOR_SCRIPT := "res://scripts/ruins/ruins_decor.gd"
const NEAR := 72.0  # door.gd NEAR_DISTANCE: the name shows when the player is this close
## The paper doll's drawn box from her feet (shot walk: 42 px of hair to hem, about 28 across).
const BODY := Rect2(-14, -42, 28, 42)

var _failures := 0
var _pairs := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for path in _map_scenes():
		var m := await _open(path, "spawn_default")
		var pairs := []  # [spawn name, door path]
		for mk: Marker2D in m.find_children("spawn_*", "Marker2D", true, false):
			for d: Area2D in _doors(m):
				if mk.global_position.distance_to(d.global_position) <= NEAR:
					pairs.append([String(mk.name), m.get_path_to(d)])
		for pair: Array in pairs:
			await _check_pair(path, pair[0], pair[1])
	_check(_pairs >= 20, "checked the arrival spawns next to a door (%d)" % _pairs)
	if current_scene:
		current_scene.queue_free()
	await process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


## Opens a map with the player arriving on a spawn marker (SceneRouter.next_spawn, as a door does).
func _open(path: String, spawn: String) -> Node:
	if current_scene:
		current_scene.free()
	root.get_node("/root/SceneRouter").next_spawn = spawn
	var m: Node = load(path).instantiate()
	root.add_child(m)
	current_scene = m
	for i in 3:
		await physics_frame
	return m


func _check_pair(path: String, spawn: String, door_path: NodePath) -> void:
	var m := await _open(path, spawn)
	var player := get_first_node_in_group("player") as Node2D
	var cam := root.get_camera_2d()
	if player == null or cam == null:
		_check(false, "%s %s: a player with a camera" % [path.get_file(), spawn])
		return
	cam.reset_smoothing()
	cam.force_update_scroll()
	for i in 3:
		await process_frame
	var d: Node = m.get_node(door_path)
	var l: Label = d.get_node("NameLabel")
	var what := "%s %s by %s (%s)" % [path.get_file(), spawn, door_path, l.text]
	if not l.visible:  # the map put the player just past NEAR_DISTANCE: nothing to read here
		print("SKIP %s: the door's name is not showing (player %s)" % [what, player.global_position])
		return
	_pairs += 1
	var half := root.get_visible_rect().size / cam.zoom / 2.0
	var view := Rect2(cam.get_screen_center_position() - half, half * 2.0)
	var text := _text_rect(l)
	_check(text.position.x >= view.position.x and text.end.x <= view.end.x,
		"%s: the name is inside the view across (text %.0f..%.0f, view %.0f..%.0f)" % [what, text.position.x, text.end.x, view.position.x, view.end.x])
	var body := Rect2(player.global_position + BODY.position, BODY.size)
	_check(not text.intersects(body), "%s: the name is not over the player (text %s, player %s)" % [what, text, body])
	if path.begins_with("res://scenes/ruins/"):
		var caption: Dictionary = (load(DECOR_SCRIPT) as Script).get_script_constant_map()
		var fill := l.get_theme_color("font_color")
		var edge := l.get_theme_color("font_outline_color")
		_check(fill == caption["CAPTION_TEXT"] and edge == caption["CAPTION_PLUM"],
			"%s: the name is lilac-white on a dark plum outline (%s on %s)" % [what, fill.to_html(false), edge.to_html(false)])


## Where a label's one line of text is drawn: centred across, on its bottom edge (door.tscn).
func _text_rect(l: Label) -> Rect2:
	var font := l.get_theme_font("font")
	var fsize := l.get_theme_font_size("font_size")
	var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var h := font.get_height(fsize)
	var r := l.get_global_rect()
	return Rect2(r.position.x + (r.size.x - w) / 2.0, r.end.y - h, w, h)


## True when the script is map.gd or extends it (as test_exits).
func _runs_map(script: Script) -> bool:
	while script != null:
		if script.resource_path == MAP_SCRIPT:
			return true
		script = script.get_base_script()
	return false


func _map_scenes() -> Array:
	var out := []
	for dir in DIRS:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tscn"):
				continue
			var path: String = dir + "/" + f
			var inst: Node = load(path).instantiate()
			if _runs_map(inst.get_script()):
				out.append(path)
			inst.free()
	return out


func _doors(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Area2D", true, false):
		if c.get_script() and c.get_script().resource_path == DOOR_SCRIPT:
			out.append(c)
	return out


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
