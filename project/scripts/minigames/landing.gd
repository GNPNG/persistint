extends Control
## The Landing — Spaceteam-style coordinated-panic bridge game as the ship comes down
## (DESIGN.md §2), with Among Us-flavored crew tasks at stations around the ship.
## Story Structure, Camera 1 / opening scene: the dead cruise ship drifts through fog toward
## the island; Cap'n Kate is trying not to crash a dead ship; systems failing, chaos on deck,
## the first mate yelling for the captain. A command missed in time is a system failing.
## Data: data/landing.json. Result goes to WorldState: landing_done, landing_score,
## landing_failed (stations whose systems failed), landing_tasks_done (crew task ids done).

const DATA_PATH := "res://data/landing.json"
const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")

var data: Dictionary = {}
var queue: Array = []
var current: Dictionary = {}
var station := ""
var failed: Array[String] = []
var tasks_done: Array[String] = []
var score := 0
var time_left := 0.0
var running := false

var _shout: Label
var _timer_bar: ProgressBar
var _ship: Control
var _tasks: VBoxContainer
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
	for st: Dictionary in data.get("stations", []):
		if not names.has(st["name"]):
			names.append(st["name"])
	for c: Dictionary in data.get("commands", []):
		if not names.has(c["station"]):
			names.append(c["station"])
	return names


## Crew tasks (data-defined) at a station: [{id, text}].
func tasks_at(name: String) -> Array:
	for st: Dictionary in data.get("stations", []):
		if st["name"] == name:
			return st.get("tasks", [])
	return []


func _station_pos(name: String) -> Vector2:
	for st: Dictionary in data.get("stations", []):
		if st["name"] == name and st.has("pos"):
			return Vector2(st["pos"][0], st["pos"][1])
	return Vector2(0.5, 0.5)


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
	_ship = Control.new()
	_ship.custom_minimum_size = Vector2(0, 160)
	_ship.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_ship)
	for name: String in station_names():
		var b := Button.new()
		b.text = name
		b.pressed.connect(go_to.bind(name))
		_ship.add_child(b)
		var p := _station_pos(name)
		b.anchor_left = p.x
		b.anchor_right = p.x
		b.anchor_top = p.y
		b.anchor_bottom = p.y
		b.grow_horizontal = Control.GROW_DIRECTION_BOTH
		b.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tasks = VBoxContainer.new()
	box.add_child(_tasks)
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
	for child in _tasks.get_children():
		child.queue_free()
	for t: Dictionary in tasks_at(name):
		var tb := Button.new()
		tb.text = t["text"]
		tb.disabled = tasks_done.has(t["id"])
		tb.pressed.connect(do_task.bind(t["id"]))
		_tasks.add_child(tb)
	_update_status()


## Do a crew task at the current station.
func do_task(id: String) -> void:
	for t: Dictionary in tasks_at(station):
		if t["id"] == id and not tasks_done.has(id):
			tasks_done.append(id)
			go_to(station)
			return


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
	WorldState.set_flag("landing_tasks_done", tasks_done.duplicate())
	var back := Button.new()
	back.text = "OK"
	back.pressed.connect(go_back)
	_controls.get_parent().add_child(back)


## Where OK goes: back to where a cruise flashback was started from, otherwise return_map.
func return_target() -> Dictionary:
	return Flashbacks.return_target(data.get("return_map", "res://scenes/maps/village.tscn"))


func go_back() -> void:
	var to := Flashbacks.leave(data.get("return_map", "res://scenes/maps/village.tscn"))
	SceneRouter.goto_map(to["scene"], to["spawn"])
