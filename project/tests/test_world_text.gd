extends SceneTree
## World text keeps its layout while its font follows the camera's zoom (bd wso.4). WorldText gives
## a label in the world its font rasterized at the screen's px (the viewport's oversampling times
## the zoom); the swap must never change how a bubble sizes itself. In the clone hall (the shot
## walk's ruins-clone_hall-bark), a zombie clone's bubble says each of the clones' barks and the
## longest of its original's quotes, as bark() puts them, longest first, at the game's zoom, one
## level out and with no zoom: it is drawn at the screen's px, no wider than its max_width with
## the box's padding, wraps when the text is wider, shows every line, and is the size a bubble
## laid out in the theme's own font is (one on a screen layer, with no zoom over it). In the
## render of 2239a4e the clone's bubble had its whole lines unwrapped, past the right edge of the
## view, with its last line cut off. The window is 1280x720 as in the game
## (root.oversampling_override = 2: a headless root is much smaller).
## Run: godot --headless --path project -s tests/test_world_text.gd

const MAP := "res://scenes/ruins/ruins_clone_hall.tscn"
const CLONE := "ZombieEpstein4"
const BUBBLE := "res://scenes/ui/bark_bubble.tscn"
const ZOOMS := [2.0, 1.25, 1.0]  # map.gd ZOOMS, and none

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.oversampling_override = 2.0  # the 1280x720 window's stretch
	await process_frame
	root.get_node("/root/SceneRouter").next_spawn = "spawn_default"
	var m: Node = load(MAP).instantiate()
	root.add_child(m)
	current_scene = m
	for i in 3:
		await physics_frame
	var player := get_first_node_in_group("player") as Node2D
	var cam := root.get_camera_2d()
	var z := m.find_child(CLONE, true, false) as Node2D
	if player == null or cam == null or z == null:
		_check(false, "the clone hall has a player with a camera, and %s" % CLONE)
		await _end()
		return
	player.global_position = Vector2(440, 360)  # where the shot stands her
	z.set("_talking", true)  # its own barks keep out of the way
	var bubble: Label = z.get_node("BarkBubble")
	# The same bubble on a screen layer: no zoom over it, so it keeps the theme's font.
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var holder := Node2D.new()
	holder.position = Vector2(320, 300)
	layer.add_child(holder)
	var ref: Label = (load(BUBBLE) as PackedScene).instantiate()
	ref.name = "BarkBubble"
	ref.set("max_width", bubble.get("max_width"))
	ref.set("bottom", bubble.get("bottom"))
	holder.add_child(ref)
	var lines := _lines(z)
	_check(lines.size() >= 10, "the clone has its barks to say (%d lines)" % lines.size())
	for zoom: float in ZOOMS:
		cam.zoom = Vector2(zoom, zoom)
		cam.reset_smoothing()
		cam.force_update_scroll()
		await process_frame
		for line: String in lines:
			bubble.call("say", line)
			ref.call("say", line)
			await process_frame
			await process_frame
			_check_bubble(bubble, ref, line, zoom)
	layer.queue_free()
	await _end()


## Every bark of the clones with the longest of the clone's original's quotes, and alone, as
## ZombieChild.bark() puts them (designation, the bark without its brackets, the quote), longest
## first.
func _lines(z: Node) -> Array:
	var voice: Node = root.get_node("/root/Voice")
	var data: Dictionary = z.call("data")
	var quotes: Array = z.call("quote_pool", z.get("original"))
	var longest := ""
	for q: String in quotes:
		if q.length() > longest.length():
			longest = q
	var out := []
	for bark: String in data.get("barks", []):
		var said := "%s\n%s" % [z.call("designation"), voice.call("display_text", bark)]
		out.append(said)
		if longest != "":
			out.append(said + "\n\"%s\"" % longest)
	out.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	return out


func _check_bubble(b: Label, ref: Label, line: String, zoom: float) -> void:
	var what := "zoom %.2f, \"%s\"" % [zoom, line.get_slice("\n", 1).left(28)]
	var font := b.get_theme_font("font")
	var drawn: float = (font as FontFile).oversampling if font is FontFile and (font as FontFile).oversampling > 0.0 else root.get_oversampling()
	var info := "size %s, the theme font's %s, min %s, autowrap %d, %d of %d lines showing, %s at %.2f" % [
		b.size, ref.size, b.get_combined_minimum_size(), b.autowrap_mode, b.get_visible_line_count(), b.get_line_count(),
		font.get_class() if font else "no font", drawn]
	if b.text != line:
		_check(false, "%s: the bubble says the line (%s)" % [what, b.text.get_slice("\n", 1)])
		return
	var want := root.get_oversampling() * zoom
	_check(absf(drawn - want) <= 0.125, "%s: drawn at the screen's px (oversampling %.2f for %.2f)" % [what, drawn, want])
	var pad := b.get_theme_stylebox("normal").get_minimum_size()
	var max_w := float(b.get("max_width"))
	_check(b.size.x <= max_w + pad.x + 1.0, "%s: no wider than its max_width (%s)" % [what, info])
	_check(b.size.is_equal_approx(ref.size), "%s: the size the theme's font makes it (%s)" % [what, info])
	var fsize := b.get_theme_font_size("font_size")
	var own := ref.get_theme_font("font")  # the bubble's own font, the theme's, as the one on the screen layer has it
	_check(own == WorldText.base_of(font), "%s: the font it is drawn in is made from its own (%s, from %s)" % [what, font, WorldText.base_of(font)])
	var widest := 0.0
	for one in line.split("\n"):
		widest = maxf(widest, own.get_string_size(one, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	_check((b.autowrap_mode != TextServer.AUTOWRAP_OFF) == (widest > max_w), "%s: wraps when the text is wider (%s)" % [what, info])
	_check(b.get_visible_line_count() == b.get_line_count(), "%s: every line shows (%s)" % [what, info])


func _end() -> void:
	if current_scene:
		current_scene.queue_free()
	await process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
