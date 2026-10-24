extends RefCounted
## SheetRig — SpriteFrames for the ruins' rigged sheets (tools/gen_clone_children.py documents
## each sheet's frame size and rows), and the facing a walk from one point to another takes.

## A clone child: 192x272 frames (24x34 world px at 8 texels each); rows front/side/back; columns 0-1 idle, 2-5 walk.
const CLONE := {"size": Vector2i(192, 272), "anims": {
	"idle_down": [0, 0, 2, 2.0], "walk_down": [0, 2, 4, 6.0],
	"idle_side": [1, 0, 2, 2.0], "walk_side": [1, 2, 4, 6.0],
	"idle_up": [2, 0, 2, 2.0], "walk_up": [2, 2, 4, 6.0]}}
## A polar bear cub: 192x176 frames (24x22 world px); rows front/side/back (idle 0-1, walk 2-5), smeared
## (idle 0-1, chomp 2-3) and nap (0-1).
const CUB := {"size": Vector2i(192, 176), "anims": {
	"idle_down": [0, 0, 2, 2.0], "walk_down": [0, 2, 4, 8.0],
	"idle_side": [1, 0, 2, 2.0], "walk_side": [1, 2, 4, 8.0],
	"idle_up": [2, 0, 2, 2.0], "walk_up": [2, 2, 4, 8.0],
	"smeared": [3, 0, 2, 2.0], "chomp": [3, 2, 2, 8.0], "nap": [4, 0, 2, 1.2]}}


## Every animation in `rig` cut from `sheet`, all looping.
static func frames(sheet: Texture2D, rig: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var size: Vector2i = rig["size"]
	for anim: String in rig["anims"]:
		var a: Array = rig["anims"][anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, a[3])
		sf.set_animation_loop(anim, true)
		for i in int(a[2]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(Vector2((int(a[1]) + i) * size.x, int(a[0]) * size.y), size)
			sf.add_frame(anim, at)
	return sf


## "down", "up" or "side" for a step along `delta` (side frames face right; flip for left).
static func facing(delta: Vector2) -> String:
	if absf(delta.x) >= absf(delta.y) * 0.8:
		return "side"
	return "down" if delta.y > 0 else "up"


## A speech bubble: `label` (a Label in world space, styled in its scene) shows `text`,
## sized to the text up to `max_width` and sitting with its bottom edge at `bottom_y`.
static func say(label: Label, text: String, bottom_y: float, max_width := 96.0) -> void:
	label.text = text
	var font := label.get_theme_font("font")
	var fsize := label.get_theme_font_size("font_size")
	var box := label.get_theme_stylebox("normal")
	var pad := box.get_minimum_size() if box else Vector2.ZERO
	var widest := 0.0
	for line in text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	var w := minf(max_width, widest + pad.x + 1.0)
	label.size = Vector2(w, 0)
	label.custom_minimum_size = Vector2(w, 0)
	label.reset_size()
	label.size.x = w
	label.position = Vector2(-w / 2.0, bottom_y - label.get_combined_minimum_size().y)
	keep_on_screen(label)


## Slides a bubble sideways so all of it stays inside the camera's view.
static func keep_on_screen(label: Label) -> void:
	if not label.is_inside_tree():
		return
	var cam := label.get_viewport().get_camera_2d()
	if cam == null:
		return
	var half := label.get_viewport().get_visible_rect().size / cam.zoom / 2.0
	var center := cam.get_screen_center_position()
	var w := label.size.x
	var anchor: float = (label.get_parent() as Node2D).global_position.x - w / 2.0
	var lo := center.x - half.x + 2.0
	var hi := maxf(lo, center.x + half.x - w - 2.0)
	label.position.x = -w / 2.0 + clampf(anchor, lo, hi) - anchor
