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
var slots: Array[Dictionary] = []
var resolved := 0
var station := ""
var failed: Array[String] = []
var tasks_done: Array[String] = []
var score := 0
var running := false

var _shouts: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _descent: ProgressBar
var _landed := false
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
	fill_slots()


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


const FOG_ART := preload("res://assets/ui/backdrops/fog_sea.png")
const SHIP_ART := preload("res://assets/ui/backdrops/ship_cutaway.png")


## Fog over the sea; the captain and the first mate's shout with the countdown on top; the ship
## cutaway with its stations in the middle; the station's crew tasks and controls below.
func _build_ui() -> void:
	var fog := TextureRect.new()
	fog.texture = FOG_ART
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var head := PanelContainer.new()
	head.theme_type_variation = &"HudPanel"
	box.add_child(head)
	var head_box := VBoxContainer.new()
	head.add_child(head_box)
	var captain := Label.new()
	captain.text = captain_name()
	captain.theme_type_variation = &"SubtleLabel"
	head_box.add_child(captain)
	for i in 2:     # one shout line and timer per command slot; slot 1 is hidden until it opens
		var shout := Label.new()
		shout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shout.add_theme_font_size_override("font_size", 11)
		shout.visible = false
		head_box.add_child(shout)
		_shouts.append(shout)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.visible = false
		head_box.add_child(bar)
		_bars.append(bar)
	_descent = ProgressBar.new()
	_descent.show_percentage = false
	_descent.custom_minimum_size = Vector2(0, 4)
	head_box.add_child(_descent)
	_ship = Control.new()
	_ship.custom_minimum_size = Vector2(0, 120)
	_ship.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_ship)
	var ship_art := TextureRect.new()
	ship_art.texture = SHIP_ART
	ship_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship_art.stretch_mode = TextureRect.STRETCH_SCALE
	ship_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ship_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ship.add_child(ship_art)
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
	var foot := PanelContainer.new()
	box.add_child(foot)
	var foot_box := VBoxContainer.new()
	foot.add_child(foot_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	foot_box.add_child(row)
	_tasks = VBoxContainer.new()
	_tasks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tasks)
	_controls = GridContainer.new()
	_controls.columns = 2
	row.add_child(_controls)
	_status = Label.new()
	_status.theme_type_variation = &"SubtleLabel"
	foot_box.add_child(_status)


## Move to a crew station around the ship; only its controls are in reach.
func go_to(name: String) -> void:
	station = name
	for child in _controls.get_children():
		child.queue_free()
	var shown := {}
	for c: Dictionary in data.get("commands", []):
		if c["station"] != name or shown.has(c["control"]):
			continue
		shown[c["control"]] = true     # several commands share a control; one button for each
		var b := Button.new()
		b.text = c["control"]
		b.custom_minimum_size = Vector2(72, 18)
		b.disabled = failed.has(name)
		b.pressed.connect(press.bind(c["control"]))
		_controls.add_child(b)
	for child in _tasks.get_children():
		child.queue_free()
	for t: Dictionary in tasks_at(name):
		var tb := Button.new()
		tb.text = t["text"]
		tb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


## Command time after n resolved commands: falls linearly from seconds_per_command to
## seconds_min over commands_to_land, never below seconds_min.
func seconds_for(n: int) -> float:
	var start := float(data.get("seconds_per_command", 8.0))
	var low := float(data.get("seconds_min", 4.0))
	var span := maxf(1.0, float(data.get("commands_to_land", 24)))
	return lerpf(start, low, clampf(float(n) / span, 0.0, 1.0))


## How many commands run at once after n are resolved.
func active_slot_count(n: int) -> int:
	return 2 if n >= int(data.get("two_at_once_after", 8)) else 1


## Slot 0 is the first mate's voice, slot 1 the captain's.
func _speaker(i: int) -> String:
	return str(data.get("first_mate", "")) if i == 0 else captain_name()


## The next command from the queue (reshuffled from all commands when it runs dry), skipping
## any whose control another slot already holds.
func _pick(taken: Array[String]) -> Dictionary:
	var held: Array = []
	var picked: Dictionary = {}
	var tries: int = 2 * data.get("commands", []).size() + 2
	while picked.is_empty() and tries > 0:
		tries -= 1
		if queue.is_empty():
			queue = data.get("commands", []).duplicate()
			queue.shuffle()
			if queue.is_empty():
				break
		var c: Dictionary = queue.pop_back()
		if taken.has(c["control"]):
			held.append(c)
		else:
			picked = c
	queue.append_array(held)
	return picked


## Open slots up to active_slot_count(resolved) and give every empty slot a command.
func fill_slots() -> void:
	var want := active_slot_count(resolved)
	while slots.size() < want:
		slots.append({"who": _speaker(slots.size()), "cmd": {}, "time_left": 0.0, "max": 0.0})
	for i in slots.size():
		if not slots[i]["cmd"].is_empty():
			continue
		var taken: Array[String] = []
		for j in slots.size():
			if j != i and not slots[j]["cmd"].is_empty():
				taken.append(slots[j]["cmd"]["control"])
		var cmd := _pick(taken)
		if cmd.is_empty():
			continue
		var secs := seconds_for(resolved)
		slots[i]["cmd"] = cmd
		slots[i]["time_left"] = secs
		slots[i]["max"] = secs
		Voice.speak(cmd["text"], 1.0, slots[i]["who"])
	running = not slots.is_empty()
	_show_slots()
	_update_status()


func _show_slots() -> void:
	_show_descent()
	for i in _shouts.size():
		var open: bool = i < slots.size() and not slots[i]["cmd"].is_empty()
		_shouts[i].visible = open
		_bars[i].visible = open
		if open:
			_shouts[i].text = "%s: %s" % [slots[i]["who"], slots[i]["cmd"]["text"]]
			_bars[i].max_value = slots[i]["max"]
			_bars[i].value = slots[i]["time_left"]


func _process(delta: float) -> void:
	if not running:
		return
	for i in slots.size():
		if not running:
			return
		slots[i]["time_left"] -= delta
		_bars[i].value = slots[i]["time_left"]
		if slots[i]["time_left"] <= 0.0:
			_slot_times_out(i)


## Press a control at the current station; it resolves the first slot that asks for it.
func press(control: String) -> void:
	if not running or failed.has(station):
		return
	for i in slots.size():
		var cmd: Dictionary = slots[i]["cmd"]
		if station == cmd.get("station", "") and control == cmd.get("control", ""):
			score += 1
			_resolve(i)
			return


## A command resolved, pressed or timed out: the next one fills its slot, or the ship lands.
func _resolve(i: int) -> void:
	resolved += 1
	slots[i]["cmd"] = {}
	_show_descent()
	if resolved >= int(data.get("commands_to_land", 24)):
		_finish()
	else:
		fill_slots()


## A slot's time ran out: its station's system fails.
func _slot_times_out(i: int) -> void:
	var where: String = slots[i]["cmd"].get("station", "")
	if not failed.has(where):
		failed.append(where)
	go_to(station)
	_resolve(i)


func _update_status() -> void:
	_status.text = "%s   %s" % [station, ("systems failing: " + ", ".join(failed)) if not failed.is_empty() else ""]


## How the landing went, from the systems lost: "smooth", "rough" or "hard".
func outcome() -> String:
	if failed.is_empty():
		return "smooth"
	return "rough" if failed.size() <= int(data.get("rough_max_failed", 3)) else "hard"


func _show_descent() -> void:
	_descent.max_value = int(data.get("commands_to_land", 24))
	_descent.value = resolved


## The ship comes down on the island. Runs once; the end card shows only the author's text.
func _finish() -> void:
	if _landed:
		return
	_landed = true
	running = false
	_show_descent()
	WorldState.set_flag("landing_done", true)
	WorldState.set_flag("landing_score", score)
	WorldState.set_flag("landing_failed", failed.duplicate())
	WorldState.set_flag("landing_tasks_done", tasks_done.duplicate())
	WorldState.set_flag("landing_outcome", outcome())
	var card := str(data.get("end_card", {}).get(outcome(), ""))
	if not card.is_empty():
		var end_label := Label.new()
		end_label.text = card
		end_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_status.get_parent().add_child(end_label)
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
