extends Label
## A bark speech bubble (theme BarkBubble: white rounded box with a tail, assets/ui/chrome
## bubble.png / bubble_tail.png). Whenever its text changes it fits itself to the text: one
## line up to MAX_WIDTH, wrapped beyond that, centred on the speaker and growing upward from
## its bottom edge (the offset_bottom set in the scene).

const MAX_WIDTH := 64.0

var _fitted := ""


func _process(_delta: float) -> void:
	if visible and text != _fitted:
		fit()


func fit() -> void:
	_fitted = text
	var style := get_theme_stylebox("normal")
	var pad := style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) if style else 0.0
	var line := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
	autowrap_mode = TextServer.AUTOWRAP_OFF if line <= MAX_WIDTH else TextServer.AUTOWRAP_WORD_SMART
	var width := ceilf(minf(line, MAX_WIDTH) + pad)
	var bottom := offset_bottom
	offset_left = -width / 2.0
	offset_right = width / 2.0
	size = Vector2(width, 0)
	var height := get_minimum_size().y
	offset_top = bottom - height
	offset_bottom = bottom
