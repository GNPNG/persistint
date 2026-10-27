extends Label
## BarkBubble — the one speech bubble every character barks in (scenes/ui/bark_bubble.tscn:
## theme BarkBubble, a white rounded box from assets/ui/chrome/bubble.png with the
## bubble_tail.png tail under it). Instance it as a character's "BarkBubble" child and set
## `bottom` to just over the character's head (characters stand with their origin on their
## feet, so it is minus their height).
## Whenever its text changes it fits itself to the text: one line up to max_width, wrapped
## beyond that, centred on the speaker and growing upward from `bottom`; it slides sideways, and
## down from the top edge, to stay inside the camera's view.

## Widest a line gets before the text wraps (world px).
@export var max_width := 64.0
## Local y of the bubble's bottom edge (the tail hangs below it).
@export var bottom := -54.0

var _fitted := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20  # over the props and characters it overlaps on a y-sorted map


## Shows `line` in the bubble.
func say(line: String) -> void:
	text = line
	show()
	fit()


func _process(_delta: float) -> void:
	if not visible:
		return
	if text != _fitted:
		fit()
	_keep_on_screen()


func fit() -> void:
	_fitted = text
	var font := get_theme_font("font")
	var fsize := get_theme_font_size("font_size")
	var style := get_theme_stylebox("normal")
	var pad := style.get_minimum_size() if style else Vector2.ZERO
	var widest := 0.0
	for one in text.split("\n"):
		widest = maxf(widest, font.get_string_size(one, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	var inner := minf(ceilf(widest) + 1.0, max_width)
	autowrap_mode = TextServer.AUTOWRAP_OFF if widest <= max_width else TextServer.AUTOWRAP_WORD_SMART
	var text_h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, inner, fsize).y
	var w := ceilf(inner + pad.x)
	var h := ceilf(text_h + pad.y)
	custom_minimum_size = Vector2.ZERO
	position = Vector2(-w / 2.0, bottom - h)
	size = Vector2(w, h)
	_aim_tail()


## The tail points down at the speaker even when the bubble has slid sideways.
func _aim_tail() -> void:
	var tail := get_node_or_null("Tail") as Control
	if tail:
		var x := clampf(-position.x, 6.0, maxf(6.0, size.x - 6.0))
		tail.position.x = x - tail.size.x / 2.0


## Slides the bubble sideways so all of it stays inside the camera's view, and down when its top
## would be over the top of the view: a speaker near the top edge (the player walking up to them
## from below, a speaker at the top of the map) still shows the line, over their head.
func _keep_on_screen() -> void:
	var cam := get_viewport().get_camera_2d()
	var speaker := get_parent() as Node2D
	if cam == null or speaker == null:
		return
	var half := get_viewport().get_visible_rect().size / cam.zoom / 2.0
	var center := cam.get_screen_center_position()
	var w := size.x
	var anchor := speaker.global_position.x - w / 2.0
	var lo := center.x - half.x + 2.0
	var hi := maxf(lo, center.x + half.x - w - 2.0)
	position.x = -w / 2.0 + clampf(anchor, lo, hi) - anchor
	var top := speaker.global_position.y + bottom - size.y
	position.y = bottom - size.y + maxf(0.0, center.y - half.y + 2.0 - top)
	_aim_tail()
