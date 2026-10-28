extends SceneTree
## The map card and the zoom figures (bd ctw): in a map, M or the map sticker opens an overhead
## map of the whole area in the top left with a heart pin for every door, named with where it
## leads, a dot for the player and a frame for what the screen shows, which grows when the view
## zooms out; tapping a pin walks the player to that door; M or the sticker closes it. Beside the
## magnifier two paper-cutout figures show the zoom: the big one solid at the normal view, the
## small one solid one level out, and tapping one goes to its zoom.
## The names on the pins (cc-srv's review of the first renders): in every map of scenes/maps,
## scenes/ruins and scenes/florida, at Normal and at Larger text, every pin's name shows, says where
## the door leads (or its short name), lies inside the card and its miniature and is clear of every
## other name; no door's own name shows from under the card (the Service Spine's "...e Deck" stuck
## out past its edge), and it comes back when the card closes.
## Run: godot --headless --path project -s tests/test_minimap.gd

const VILLAGE := "res://scenes/maps/village.tscn"
const CORRIDOR := "res://scenes/ruins/ruins_corridor.tscn"
const DIRS := ["res://scenes/maps", "res://scenes/ruins", "res://scenes/florida"]
const MAP_SCRIPT := "res://scripts/map.gd"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	change_scene_to_file(VILLAGE)
	await _frames(4)
	var map: Node = current_scene
	var player: Node2D = get_first_node_in_group("player")
	_check(not map.minimap_open(), "the map card starts closed")

	# --- M opens it. ---
	_key(KEY_M)
	await _frames(3)
	_check(map.minimap_open(), "M opens the map card")
	var card: Control = map.minimap()
	if card == null:
		_finish()
		return
	_check(card.mini_size.x > 0.0 and card.mini_size.x <= card.MAX_SIZE.x + 0.5 and card.mini_size.y <= card.MAX_SIZE.y + 0.5,
		"the miniature fits its box (%s)" % card.mini_size)
	var ratio: float = card.mini_size.x / card.mini_size.y
	var want: float = map.map_size.x / map.map_size.y
	_check(absf(ratio - want) < 0.05, "and keeps the map's shape (%.2f, map %.2f)" % [ratio, want])

	# --- On screen, clear of the clock, the stickers and the gear. ---
	var screen := root.get_visible_rect()
	var rect := card.get_global_rect()
	_check(screen.encloses(rect), "the card is on screen (%s)" % rect)
	var clock: Control = map.get_node("HUD/Clock")
	_check(not rect.intersects(clock.get_global_rect()), "and clear of the clock tag")
	var gear: Control = root.get_node("/root/AudioSettings")._gear
	_check(not rect.intersects(Rect2(gear.position, gear.size)), "and of the gear")
	for n in ["WardrobeSticker", "JournalSticker", "ZoomSticker", "HelpSticker", "MapSticker", "ZoomFigures"]:
		var c := map.get_node_or_null("HUD/" + n) as Control
		_check(c != null and not rect.intersects(c.get_global_rect()), "and of %s" % n)

	# --- A pin for every door, named with where it leads. ---
	var doors: Array[Node2D] = []
	for n in get_nodes_in_group("doors"):
		if map.is_ancestor_of(n) and (n as Node2D).is_visible_in_tree():
			doors.append(n)
	var pins: Array = card.waypoints()
	_check(doors.size() > 0 and pins.size() == doors.size(), "one pin per door (%d pins, %d doors)" % [pins.size(), doors.size()])
	var names: PackedStringArray = card.waypoint_names()
	for d in doors:
		_check(names.has(d.destination_name()), "a pin says \"%s\"" % d.destination_name())
		var p: Vector2 = card.mini_point(d.global_position)
		_check(Rect2(Vector2.ZERO, card.mini_size).grow(1.0).has_point(p), "and sits inside the miniature (%s)" % p)
	_check(Rect2(Vector2.ZERO, card.mini_size).has_point(card.mini_point(player.global_position)), "the player's dot is inside the miniature")

	# --- The frame of what the screen shows grows when the view zooms out. ---
	var near: Rect2 = card.view_frame()
	_check(near.has_area(), "the screen's frame shows (%s)" % near)
	map.set_zoom_level(1)
	await create_timer(0.4).timeout
	var far: Rect2 = card.view_frame()
	_check(far.size.x > near.size.x + 1.0 or far.size.y > near.size.y + 1.0, "and grows one level out (%s -> %s)" % [near.size, far.size])
	map.set_zoom_level(0)
	await create_timer(0.4).timeout

	# --- Tapping a pin walks the player to that door; a tap on bare map does not. ---
	_check(card.tap(Vector2(-50, -50)) == null, "a tap away from every pin takes none")
	var door: Node2D = doors[0]
	var got: Node2D = card.tap(card.mini_point(door.global_position) + Vector2(2, 1))
	_check(got == door and player.get("_interact_target") == door, "tapping %s's pin walks the player there" % door.name)
	player.set("_interact_target", null)  # stay in the village
	player.nav.target_position = player.global_position
	await physics_frame

	# --- M and the sticker close and open it. ---
	_key(KEY_M)
	await _frames(3)
	_check(not map.minimap_open(), "M closes it")
	var sticker: TextureButton = map.get_node("HUD/MapSticker")
	_check(sticker.texture_normal.resource_path.ends_with("map.png"), "the map sticker shows the map")
	sticker.pressed.emit()
	await _frames(3)
	_check(map.minimap_open(), "the map sticker opens it")
	sticker.pressed.emit()
	await _frames(3)
	_check(not map.minimap_open(), "and closes it")

	# --- The zoom figures. ---
	var figs: Node = map.get_node("HUD/ZoomFigures")
	var big: TextureButton = figs.get_node("Near")
	var small: TextureButton = figs.get_node("Far")
	_check(big.modulate.a > 0.9 and small.modulate.a < 0.6, "at the normal view the big figure is solid and the small one faint")
	_check(screen.encloses(figs.get_global_rect()) and not figs.get_global_rect().intersects(map.get_node("HUD/ZoomSticker").get_global_rect()),
		"the figures sit on screen beside the magnifier (%s)" % figs.get_global_rect())
	small.pressed.emit()
	await create_timer(0.4).timeout
	_check(map.zoom_level == 1 and small.modulate.a > 0.9 and big.modulate.a < 0.6, "tapping the small one zooms out, and it is the solid one now")
	_key(KEY_EQUAL)
	await create_timer(0.4).timeout
	_check(map.zoom_level == 0 and big.modulate.a > 0.9, "+ zooms back in and the big one is solid again")
	small.pressed.emit()
	await create_timer(0.4).timeout
	big.pressed.emit()
	await create_timer(0.4).timeout
	_check(map.zoom_level == 0, "tapping the big one zooms in")

	# --- A ruins room: its doors are pins too, and a door's own name never shows from under the card. ---
	root.get_node("/root/SceneRouter").next_spawn = "spawn_default"  # beside the Promenade Deck door
	change_scene_to_file(CORRIDOR)
	await _frames(4)
	map = current_scene
	var wreck: Label = map.get_node("WreckDoor/NameLabel")
	_check(wreck.visible, "in the corridor the Promenade Deck door names itself beside the player")
	map.toggle_minimap()
	await _frames(3)
	card = map.minimap()
	var room_doors := 0
	for n in get_nodes_in_group("doors"):
		if map.is_ancestor_of(n) and (n as Node2D).is_visible_in_tree():
			room_doors += 1
	_check(card != null and room_doors > 0 and card.waypoints().size() == room_doors,
		"in the corridor too, one pin per door (%d)" % room_doors)
	if card:
		_check(card.waypoint_names().has("To the Reliquary Core"), "named with where they lead (%s)" % ", ".join(card.waypoint_names()))
		_check(not wreck.visible, "with the card open over it, the door's own name is hidden (its end showed past the card's edge)")
		map.toggle_minimap()
		await _frames(3)
		_check(wreck.visible, "and it shows again once the card is closed")

	# --- Every map, at Normal and at Larger text: the names on the pins. ---
	var ts: Node = root.get_node("/root/TextSize")
	var maps := _map_scenes()
	_check(maps.size() >= 12, "every map is checked (%d)" % maps.size())
	for step: int in [0, 2]:
		ts.set_step(step)
		for path: String in maps:
			await _check_names(path, ts.step_name())
	ts.set_step(0)
	if current_scene:
		current_scene.queue_free()
	await process_frame

	_finish()


## Opens the map with its card and checks every pin's name: it shows, says where its door leads
## (or the short name), lies inside the card and the miniature and is clear of every other name;
## and no door's own name shows from under the card.
func _check_names(path: String, text_size: String) -> void:
	if current_scene:
		current_scene.free()
	var m: Node = load(path).instantiate()
	root.add_child(m)
	current_scene = m
	await _frames(3)
	m.toggle_minimap()
	await _frames(3)
	var what := "%s at %s text" % [path.get_file().get_basename(), text_size]
	var card: Control = m.minimap()
	if card == null:
		_check(false, "%s: the map card opens" % what)
		return
	var box := card.get_global_rect().grow(0.05)
	var mini: Rect2 = (card.get_node("Miniature") as Control).get_global_rect().grow(0.05)
	var labels: Array[Label] = card.waypoint_labels()
	var names: PackedStringArray = card.waypoint_names()
	var bad := PackedStringArray()
	for i in labels.size():
		var l := labels[i]
		var r := l.get_global_rect()
		if not l.visible:
			bad.append("\"%s\" is hidden" % names[i])
			continue
		if l.text != names[i] and l.text != card.short_name(names[i]):
			bad.append("\"%s\" says \"%s\"" % [names[i], l.text])
		if not (box.encloses(r) and mini.encloses(r)):
			bad.append("\"%s\" %s is outside the miniature %s" % [l.text, r, mini])
		for j in range(i + 1, labels.size()):
			var o := labels[j]
			if o.visible and r.intersects(o.get_global_rect()):
				bad.append("\"%s\" is over \"%s\"" % [l.text, o.text])
	_check(labels.size() == card.waypoints().size() and labels.size() == names.size() and bad.is_empty(),
		"%s: all %d names show inside the card, none over another%s" % [what, labels.size(), "" if bad.is_empty() else " (" + "; ".join(bad) + ")"])
	var on_screen: Rect2 = card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size)
	for n in get_nodes_in_group("doors"):
		var l := (n as Node).get_node_or_null("NameLabel") as Label
		if m.is_ancestor_of(n) and l != null and l.visible:
			_check(not _text_on_screen(l).intersects(on_screen), "%s: %s's own name is clear of the card" % [what, n.name])


## Where a door name's one line of text is drawn on screen: centred across, on its bottom edge
## (door.tscn; as test_door_labels).
func _text_on_screen(l: Label) -> Rect2:
	var font := l.get_theme_font("font")
	var fsize := l.get_theme_font_size("font_size")
	var w := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var h := font.get_height(fsize)
	return l.get_global_transform_with_canvas() * Rect2((l.size.x - w) / 2.0, l.size.y - h, w, h)


## True when the script is map.gd or extends it (as test_door_labels).
func _runs_map(script: Script) -> bool:
	while script != null:
		if script.resource_path == MAP_SCRIPT:
			return true
		script = script.get_base_script()
	return false


func _map_scenes() -> Array:
	var out := []
	for dir: String in DIRS:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".tscn"):
				continue
			var path: String = dir + "/" + f
			var inst: Node = load(path).instantiate()
			if _runs_map(inst.get_script()):
				out.append(path)
			inst.free()
	return out


func _finish() -> void:
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
