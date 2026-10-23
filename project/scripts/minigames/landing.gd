extends Control
## The Landing — Spaceteam-style coordinated-panic bridge game as the ship comes down
## (DESIGN.md §2), with Among Us-flavored crew tasks at stations around the ship.
## Story Structure, Camera 1 / opening scene: the dead cruise ship drifts through fog toward
## the island; Cap'n Kate is trying not to crash a dead ship; systems failing, chaos on deck,
## the first mate yelling for the captain. A command missed in time is a system failing.
## Data: data/landing.json. Result goes to WorldState: landing_done, landing_score,
## landing_failed (stations whose systems failed).

const DATA_PATH := "res://data/landing.json"

var data: Dictionary = {}
var queue: Array = []
var current: Dictionary = {}
var station := ""
var failed: Array[String] = []
var score := 0
var time_left := 0.0
var running := false

var _shout: Label
var _timer_bar: ProgressBar
var _stations: HBoxContainer
var _controls: GridContainer
var _status: Label


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed
	queue = data.get("commands", []).duplicate()
	queue.shuffle()
	_build_ui()
	var names := station_names()
	go_to(names[0] if not names.is_empty() else "")
	_next_command()


func captain_name() -> String:
	return Cast.full(data.get("captain", ""))


func station_names() -> Array[String]:
	var names: Array[String] = []
	for c: Dictionary in data.get("commands", []):
		if not names.has(c["station"]):
			names.append(c["station"])
	return names


func _build_ui() -> void:
	var fog := ColorRect.new()
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.color = Color(0.92, 0.93, 0.95, 0.55)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var captain := Label.new()
	captain.text = captain_name()
	box.add_child(captain)
	_shout = Label.new()
	_shout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shout.add_theme_font_size_override("font_size", 18)
	box.add_child(_shout)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(_timer_bar)
	_stations = HBoxContainer.new()
	box.add_child(_stations)
	for name: String in station_names():
		var b := Button.new()
		b.text = name
		b.pressed.connect(go_to.bind(name))
		_stations.add_child(b)
	_controls = GridContainer.new()
	_controls.columns = 3
	box.add_child(_controls)
	_status = Label.new()
	box.add_child(_status)


## Move to a crew station around the ship; only its controls are in reach.
func go_to(name: String) -> void:
	station = name
	for child in _controls.get_children():
		child.queue_free()
	for c: Dictionary in data.get("commands", []):
		if c["station"] != name:
			continue
		var b := Button.new()
		b.text = c["control"]
		b.custom_minimum_size = Vector2(96, 40)
		b.disabled = failed.has(name)
		b.pressed.connect(press.bind(c["control"]))
		_controls.add_child(b)
	_update_status()


func _next_command() -> void:
	if queue.is_empty():
		_finish()
		return
	current = queue.pop_back()
	time_left = float(data.get("seconds_per_command", 6.0))
	_timer_bar.max_value = time_left
	_shout.text = "%s: %s" % [data.get("first_mate", ""), current["text"]]
	Voice.speak(current["text"], 1.0, data.get("first_mate", ""))
	running = true
	_update_status()


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	_timer_bar.value = time_left
	if time_left <= 0.0:
		_system_fails()


## Press a control at the current station.
func press(control: String) -> void:
	if not running or failed.has(station):
		return
	if station == current.get("station", "") and control == current.get("control", ""):
		score += 1
		_next_command()


func _system_fails() -> void:
	var where: String = current.get("station", "")
	if not failed.has(where):
		failed.append(where)
	go_to(station)
	_next_command()


func _update_status() -> void:
	_status.text = "%s   %s" % [station, ("systems failing: " + ", ".join(failed)) if not failed.is_empty() else ""]


## The ship comes down on the island.
func _finish() -> void:
	running = false
	WorldState.set_flag("landing_done", true)
	WorldState.set_flag("landing_score", score)
	WorldState.set_flag("landing_failed", failed.duplicate())
	var back := Button.new()
	back.text = "OK"
	back.pressed.connect(func() -> void:
		SceneRouter.goto_map(data.get("return_map", "res://scenes/maps/village.tscn")))
	_controls.get_parent().add_child(back)
