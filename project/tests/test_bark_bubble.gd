extends SceneTree
## A bark bubble stays inside the camera's view (bd wso): over a speaker near the top edge of the
## view (the player walking up to them from below: the Priestess on her dais, any NPC whose
## proximity fires 52 px under them) it comes down under the top of the view instead of being
## drawn above it; over a speaker in the middle of the view it sits where it fits, its bottom on
## `bottom`, centred on the speaker. Bubbles of speakers standing close keep clear of each other
## (bd wso.3: a clone's bubble covered a polar bear cub's): the one further back goes up over the
## one in front, or under it at the top of the view, and comes back once the front one is gone.
## A bubble's text is drawn at the screen's resolution (bd wso.4: under the 2x camera it was drawn
## at half of it): its font is rasterized at the viewport's oversampling times the camera's zoom,
## at the game's zoom and one level out, and measures what the theme's font does, so the bubble
## keeps its size; with no zoom over it, it keeps the theme's font.
## Run: godot --headless --path project -s tests/test_bark_bubble.gd

const BUBBLE := "res://scenes/ui/bark_bubble.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var world := Node2D.new()
	root.add_child(world)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)  # the game's view: 320 x 180 world px
	world.add_child(cam)
	cam.make_current()
	var half := root.get_visible_rect().size / cam.zoom / 2.0

	var high := _speaker(world, Vector2(0, -half.y + 40.0))  # its head just inside the top edge
	var mid := _speaker(world, Vector2(0, 40))
	await _frames(3)
	var view_top := cam.get_screen_center_position().y - half.y
	var hb: Control = high.get_node("BarkBubble")
	var high_top := high.global_position.y + hb.position.y
	_check(high_top >= view_top + 1.0, "a speaker's bubble near the top edge is inside the view (top %.1f, view top %.1f)" % [high_top, view_top])
	_check(high_top < high.global_position.y, "and still over the speaker's feet")
	var mb: Control = mid.get_node("BarkBubble")
	_check(is_equal_approx(mb.position.y, float(mb.get("bottom")) - mb.size.y),
		"a speaker's bubble in the middle of the view sits on its bottom (%.1f, %.1f)" % [mb.position.y, float(mb.get("bottom")) - mb.size.y])
	_check(is_equal_approx(mb.position.x, -mb.size.x / 2.0), "centred on the speaker")
	high.free()
	mid.free()

	# Two speakers standing close, in the middle of the view: the cub further back, the clone in front.
	var back := _speaker(world, Vector2(-8, 40), "Polar bear clone, batch 1\nMrrf!")
	var front := _speaker(world, Vector2(16, 60))
	await _frames(3)
	var bb: Control = back.get_node("BarkBubble")
	var fb: Control = front.get_node("BarkBubble")
	_check(not _reach(bb).intersects(_reach(fb)), "two speakers' bubbles do not overlap (%s, %s)" % [_reach(bb), _reach(fb)])
	_check(is_equal_approx(fb.position.y, float(fb.get("bottom")) - fb.size.y), "the front one stays on its bottom")
	_check(_reach(bb).end.y <= fb.get_global_rect().position.y, "the one further back goes up over it")
	_check(_reach(bb).position.y >= view_top + 1.0, "inside the view")
	fb.hide()
	await _frames(2)
	_check(is_equal_approx(bb.position.y, float(bb.get("bottom")) - bb.size.y), "with the front one gone it is back on its bottom")
	back.free()
	front.free()

	# The same pair at the top of the view: no room above, so the one further back goes under.
	back = _speaker(world, Vector2(-8, -half.y + 40), "Polar bear clone, batch 1\nMrrf!")
	front = _speaker(world, Vector2(16, -half.y + 60))
	await _frames(3)
	bb = back.get_node("BarkBubble")
	fb = front.get_node("BarkBubble")
	_check(not _reach(bb).intersects(_reach(fb)), "at the top of the view they do not overlap (%s, %s)" % [_reach(bb), _reach(fb)])
	_check(_reach(bb).position.y >= fb.get_global_rect().end.y, "the one further back goes under the front one")
	_check(fb.get_global_rect().position.y >= view_top + 1.0 and _reach(bb).end.y <= view_top + half.y * 2.0 - 1.0, "both inside the view")
	back.free()
	front.free()

	# Drawn at the screen's resolution, at the game's zoom and one level out (map.gd ZOOMS).
	var sp := _speaker(world, Vector2(0, 40))
	var sbub: Label = sp.get_node("BarkBubble")
	for z: float in [2.0, 1.25]:
		cam.zoom = Vector2(z, z)
		await _frames(2)
		var font := sbub.get_theme_font("font") as FontFile
		var want := root.get_oversampling() * z
		_check(font != null and absf(font.oversampling - want) <= 0.125,
			"at zoom %.2f a bubble's font is rasterized at the screen's px (oversampling %.2f for %.2f)" % [z, font.oversampling if font else 0.0, want])
		_check(font != null and font.data.size() > 0, "and has the default font's data")
		var fsize := sbub.get_theme_font_size("font_size")
		var fallback := ThemeDB.fallback_font
		_check(font != null and font.get_string_size(sbub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).is_equal_approx(fallback.get_string_size(sbub.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize))
			and is_equal_approx(font.get_height(fsize), fallback.get_height(fsize)), "and measures what the theme's font does")
	cam.zoom = Vector2.ONE
	await _frames(2)
	_check(not sbub.has_theme_font_override("font"), "with no zoom over it a bubble keeps the theme's font")
	sp.free()

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _speaker(world: Node2D, at: Vector2, line := "A line that is long enough to wrap onto a second line.") -> Node2D:
	var s := Node2D.new()
	s.position = at
	world.add_child(s)
	var b: Node = (load(BUBBLE) as PackedScene).instantiate()
	b.name = "BarkBubble"
	b.set("bottom", -54.0)
	s.add_child(b)
	b.call("say", line)
	return s


## A bubble with its tail under it (bark_bubble.tscn: the tail hangs 5 px).
func _reach(b: Control) -> Rect2:
	var r := b.get_global_rect()
	r.size.y += 5.0
	return r


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
