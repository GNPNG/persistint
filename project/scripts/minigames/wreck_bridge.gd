extends Control
## Wreck Bridge — Spaceteam-style coordinated panic as the ship comes down (DESIGN.md §2).
## A command is shouted; the player hits the matching control before the timer runs out.
## Misses cost hull. Commands, timing and hull live in data/wreck_bridge.json.
## Result goes to WorldState: wreck_bridge_done, wreck_bridge_score.

const DATA_PATH := "res://data/wreck_bridge.json"

var data: Dictionary = {}
var current: Dictionary = {}
var time_left := 0.0
var hull := 0
var round_index := 0
var score := 0
var running := false

var _command_label: Label
var _timer_bar: ProgressBar
var _status_label: Label
var _controls: GridContainer


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed
	hull = int(data.get("hull", 3))
	_build_ui()
	_next_command()


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_command_label = Label.new()
	_command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_command_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_command_label)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(_timer_bar)
	_controls = GridContainer.new()
	_controls.columns = 3
	box.add_child(_controls)
	for control: String in _control_names():
		var b := Button.new()
		b.text = control
		b.custom_minimum_size = Vector2(96, 40)
		b.pressed.connect(_on_control.bind(control))
		_controls.add_child(b)
	_status_label = Label.new()
	box.add_child(_status_label)


func _control_names() -> Array[String]:
	var names: Array[String] = []
	for c: Dictionary in data.get("commands", []):
		if not names.has(c["control"]):
			names.append(c["control"])
	return names


func _next_command() -> void:
	var commands: Array = data.get("commands", [])
	if commands.is_empty() or round_index >= int(data.get("rounds", 8)) or hull <= 0:
		_finish()
		return
	round_index += 1
	current = commands.pick_random()
	time_left = float(data.get("seconds_per_command", 6.0))
	_timer_bar.max_value = time_left
	_command_label.text = current["text"]
	Voice.speak(current["text"], randf_range(1.1, 1.4))
	running = true
	_update_status()


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	_timer_bar.value = time_left
	if time_left <= 0.0:
		_miss()


func _on_control(control: String) -> void:
	if not running:
		return
	if control == current.get("control", ""):
		score += 1
		Voice.speak("ok", 1.3)
		_next_command()
	else:
		_miss()


func _miss() -> void:
	hull -= 1
	Voice.speak("no", 0.7)
	_next_command()


func _update_status() -> void:
	_status_label.text = "Hull %d   %d/%d" % [hull, round_index, int(data.get("rounds", 8))]


func _finish() -> void:
	running = false
	_update_status()
	WorldState.set_flag("wreck_bridge_done", true)
	WorldState.set_flag("wreck_bridge_score", score)
	var back := Button.new()
	back.text = "OK"
	back.pressed.connect(func() -> void:
		SceneRouter.goto_map(data.get("return_map", "res://scenes/maps/village.tscn")))
	_controls.get_parent().add_child(back)
