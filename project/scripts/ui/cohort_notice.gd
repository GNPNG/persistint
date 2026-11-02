extends PanelContainer
## CohortNotice: the morning notice of the day's cohort signals (data/calendar.json
## "cohort_signals", GameClock.active_cohort_signals) on the island maps' HUD (map.gd). It
## shows once a day (WorldState "_notice_day"), again from the village notice board
## (scripts/notice_board.gd), and goes away on its own after SHOW_SECONDS, on its x, or on any
## click/E/Esc. It never keeps the input for itself: the panel and its labels ignore the mouse,
## the x takes no focus, and a click or key that shuts it still reaches the game (nothing is
## marked handled), so walking, E-talking and Esc-Settings are untouched while it is up.

## Seconds the notice stays up before it goes away on its own.
const SHOW_SECONDS := 14.0

var _body: Label
var _status: Label
var _hide_tween: Tween


func _ready() -> void:
	name = "CohortNotice"
	theme_type_variation = &"HudPanel"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 6.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "Cohort signals"  # _draft
	heading.theme_type_variation = &"HeaderLabel"
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(heading)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(300, 0)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)
	_status = Label.new()
	_status.name = "Status"
	_status.theme_type_variation = &"SubtleLabel"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.hide()
	box.add_child(_status)
	var close := Button.new()
	close.name = "Close"
	close.text = "x"
	close.tooltip_text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(shut)
	row.add_child(close)
	hide()


## Shows the given cohort signals (data order), plus the day/phase line when the notice board
## asked (with_status), and restarts the auto-hide.
func show_signals(signals: Array, with_status := false) -> void:
	var lines: Array[String] = []
	for entry: Dictionary in signals:
		lines.append(str(entry.get("text", "")))
	_body.text = "\n".join(lines)
	_status.visible = with_status
	if with_status:
		_status.text = GameClock.status_text()
	show()
	if _hide_tween and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(SHOW_SECONDS)
	_hide_tween.tween_callback(shut)


func shut() -> void:
	hide()


## A click, E or Esc shuts the notice, but the input is never marked handled: the click still
## walks, E still talks, Esc still opens Settings (test_first_minutes, test_input_coverage).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("click") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		shut()
