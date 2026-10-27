extends SceneTree
## A bark bubble stays inside the camera's view (bd wso): over a speaker near the top edge of the
## view (the player walking up to them from below: the Priestess on her dais, any NPC whose
## proximity fires 52 px under them) it comes down under the top of the view instead of being
## drawn above it; over a speaker in the middle of the view it sits where it fits, its bottom on
## `bottom`, centred on the speaker.
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

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _speaker(world: Node2D, at: Vector2) -> Node2D:
	var s := Node2D.new()
	s.position = at
	world.add_child(s)
	var b: Node = (load(BUBBLE) as PackedScene).instantiate()
	b.name = "BarkBubble"
	b.set("bottom", -54.0)
	s.add_child(b)
	b.call("say", "A line that is long enough to wrap onto a second line.")
	return s


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1
