extends Label
## BarkBubble — the one speech bubble every character barks in (scenes/ui/bark_bubble.tscn:
## theme BarkBubble, a white rounded box from assets/ui/chrome/bubble.png with the
## bubble_tail.png tail under it). Instance it as a character's "BarkBubble" child and set
## `bottom` to just over the character's head (characters stand with their origin on their
## feet, so it is minus their height).
## Whenever its text changes it fits itself to the text: one line up to max_width, wrapped
## beyond that, centred on the speaker and growing upward from `bottom`; it slides sideways, and
## down from the top edge, to stay inside the camera's view.
## Bubbles up at the same time keep clear of each other (bd wso.3: in the clone hall a clone's
## five-line bubble covered a polar bear cub's beside it). Of two that would overlap, the bubble of
## the speaker further back (higher on the y-sorted map, so drawn behind) goes up over the one in
## front, or under it when there is no room above inside the view; with no room either way the two
## overlap. The bubble in front stays over its speaker; the tail of the one that moved still points
## at its own.

## Widest a line gets before the text wraps (world px).
@export var max_width := 64.0
## Local y of the bubble's bottom edge (the tail hangs below it).
@export var bottom := -54.0

## The group every bubble joins, so bubbles up at once can keep clear of each other.
const GROUP := &"bark_bubbles"
## Space kept between two bubbles (world px).
const GAP := 2.0
## How far the tail hangs under the bubble (bark_bubble.tscn: Tail, offset_bottom 5).
const TAIL := 5.0

var _fitted := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20  # over the props and characters it overlaps on a y-sorted map
	add_to_group(GROUP)


## Shows `line` in the bubble.
func say(line: String) -> void:
	text = line
	show()
	fit()


func _process(_delta: float) -> void:
	if not visible:
		return
	# The font follows the camera's zoom (bd wso.4); a swap lays the bubble out again.
	if WorldText.fit(self) or text != _fitted:
		fit()
	_keep_on_screen()


## Sizes the bubble to its text. The font goes in first, the one the text is drawn in at the
## screen's resolution under the camera's zoom (WorldText, bd wso.4), so the measuring and the
## sizing come after any swap of it.
func fit() -> void:
	WorldText.fit(self)
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
	# A Label keeps the minimum size it worked out before its wrap changed (Label.set_autowrap_mode
	# does not drop it), and a size under the minimum does not take. Unwrapped, that minimum is the
	# whole longest line: showing the text (and a font swap, WorldText) works it out before the wrap
	# is set, and the bubble stayed that wide (bd wso.4: 244 px for 104 in the clone hall).
	update_minimum_size()
	var text_h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, inner, fsize).y
	var w := ceilf(inner + pad.x)
	var h := ceilf(text_h + pad.y)
	custom_minimum_size = Vector2.ZERO
	size = Vector2(w, h)
	# A Label draws only the lines its height holds, and spaces them (the theme's line_spacing)
	# where the font's measure does not: it grows until every line shows.
	for _more in 16:
		var lines := get_line_count()  # shapes the text at the bubble's width first
		if get_visible_line_count() >= lines:
			break
		h += 1.0
		size = Vector2(w, h)
	update_minimum_size()
	size = Vector2(w, h)
	position = Vector2(-w / 2.0, bottom - size.y)  # its bottom on `bottom`, at the height it took
	_aim_tail()


## The tail points down at the speaker even when the bubble has slid sideways.
func _aim_tail() -> void:
	var tail := get_node_or_null("Tail") as Control
	if tail:
		var x := clampf(-position.x, 6.0, maxf(6.0, size.x - 6.0))
		tail.position.x = x - tail.size.x / 2.0


## Slides the bubble sideways so all of it stays inside the camera's view, and down when its top
## would be over the top of the view: a speaker near the top edge (the player walking up to them
## from below, a speaker at the top of the map) still shows the line, over their head. Then it
## keeps clear of the bubbles in front of it.
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
	position.y += _clear_of_front(center.y - half.y + 2.0, center.y + half.y - 2.0)
	_aim_tail()


## How far this bubble moves down (up when negative) to keep clear of the bubbles of speakers in
## front of it, staying between `view_top` and `view_bottom` (global y).
func _clear_of_front(view_top: float, view_bottom: float) -> float:
	# The bubbles up in front of this one, found once rather than on every pass (bd nmz: this runs
	# every frame a bubble shows); with none, the bubble stays where it is.
	var front: Array[Node] = []
	for other in get_tree().get_nodes_in_group(GROUP):
		if other != self and other.is_visible_in_tree() and _in_front(other):
			front.append(other)
	if front.is_empty():
		return 0.0
	var me := _reach()
	var was := me.position.y
	for _pass in 4:  # enough for a stack of a few
		var moved := false
		for other in front:
			var r: Rect2 = other._reach()
			if not me.intersects(r):
				continue
			var up := r.position.y - GAP - me.size.y
			var down := r.end.y + GAP
			if up >= view_top:
				me.position.y = up
			elif down + me.size.y <= view_bottom:
				me.position.y = down
			else:
				continue
			moved = true
		if not moved:
			break
	return me.position.y - was


## True when `other` is the bubble of a speaker standing in front of this one's (further down the
## map; on a tie, the later one) on the same canvas: this bubble keeps clear of it.
func _in_front(other: Node) -> bool:
	var mine := get_parent() as Node2D
	var theirs := other.get_parent() as Node2D
	if mine == null or theirs == null or (other as CanvasItem).get_canvas() != get_canvas():
		return false
	var a := mine.global_position.y
	var b := theirs.global_position.y
	return b > a or (b == a and other.get_instance_id() > get_instance_id())


## The bubble with its tail, in global coordinates.
func _reach() -> Rect2:
	var r := get_global_rect()
	r.size.y += TAIL
	return r
