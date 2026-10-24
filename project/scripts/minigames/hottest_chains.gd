extends Control
## Hottest of the HOT, get-ready chains (DESIGN.md §2): makeover / hair-salon / get-ready-for-the-
## fashion-show tasks chained across the ship, Day of the Tentacle style. A task may need items
## from other stations and tasks done first; doing it can hand over an item and dress the shared
## paper doll (judged framing: the makeover is done to the passenger). Finishing the chain leads
## into the judging show (scenes/minigames/hottest_of_the_hot.tscn).
## Data: data/hottest_chains.json. Result goes to WorldState: hottest_chain_done (task ids),
## hottest_chain_items, hottest_prep_outfit (the doll's outfit when the show starts).

const DATA_PATH := "res://data/hottest_chains.json"
const OUTFITS_PATH := "res://data/outfits.json"
const PAPER_DOLL := preload("res://scripts/systems/paper_doll.gd")
## Layout: the doll at the vanity mirror (screen x), its height, margins and the row's gap.
const VANITY_X := 320.0
const DOLL_HEIGHT := 192.0
const MARGIN := 8
const ROW_GAP := 10

var data: Dictionary = {}
var done: Array[String] = []
var items: Array[String] = []
var station := ""
var doll: Control

var _box: VBoxContainer
var _status: Label
var _stations: HFlowContainer
var _tasks: VBoxContainer
var _go: Button
var _station_label: Label


func _ready() -> void:
	data = _load(DATA_PATH)
	var options := _load(OUTFITS_PATH)
	for id: String in WorldState.get_flag("hottest_chain_done", []):
		done.append(id)
	for id: String in WorldState.get_flag("hottest_chain_items", []):
		items.append(id)
	# Cabin backdrop (scene); the stations along the top, the doll at the vanity in the middle,
	# the station's tasks, what is in hand and the way to the show in a panel on the right.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	margin.add_child(_box)
	var top := PanelContainer.new()
	top.theme_type_variation = &"HudPanel"
	_box.add_child(top)
	_stations = HFlowContainer.new()
	_stations.alignment = FlowContainer.ALIGNMENT_CENTER
	top.add_child(_stations)
	for name: String in station_names():
		var b := Button.new()
		b.text = name
		b.pressed.connect(go_to.bind(name))
		_stations.add_child(b)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", ROW_GAP)
	_box.add_child(row)
	doll = PAPER_DOLL.new()
	doll.display_height = DOLL_HEIGHT
	doll.size_flags_vertical = Control.SIZE_SHRINK_END
	# The doll stands at the vanity, the cabin's centrepiece (tools/gen_ui_art.py ship_cabin,
	# centred on the screen); the bed and porthole show to the left, the panel sits right.
	var spacer := Control.new()
	spacer.custom_minimum_size.x = VANITY_X - doll.custom_minimum_size.x / 2.0 - MARGIN - ROW_GAP
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	row.add_child(doll)
	var outfit: Dictionary = WorldState.get_flag("hottest_prep_outfit", {}).duplicate()
	if outfit.is_empty():
		outfit = {"body": "body_base"}
		for slot: String in options:
			outfit[slot] = options[slot][0]
	doll.set_outfit(outfit)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 5)
	panel.add_child(side)
	_station_label = Label.new()
	_station_label.theme_type_variation = &"HeaderLabel"
	_station_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.add_child(_station_label)
	_tasks = VBoxContainer.new()
	_tasks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tasks.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_tasks)
	_status = Label.new()
	_status.theme_type_variation = &"SubtleLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_status)
	_go = Button.new()
	_go.text = "Go to the show"
	_go.pressed.connect(start_show)
	side.add_child(_go)
	var names := station_names()
	go_to(names[0] if not names.is_empty() else "")


func station_names() -> Array[String]:
	var names: Array[String] = []
	for s: String in data.get("stations", []):
		names.append(s)
	for t: Dictionary in data.get("tasks", []):
		if not names.has(t.get("station", "")) and t.get("station", "") != "":
			names.append(t["station"])
	return names


func task_by_id(id: String) -> Dictionary:
	for t: Dictionary in data.get("tasks", []):
		if t.get("id", "") == id:
			return t
	return {}


## A task can be done once its prerequisite tasks are done and the needed items are in hand.
func available(id: String) -> bool:
	var t := task_by_id(id)
	if t.is_empty() or done.has(id):
		return false
	for req: String in t.get("requires", []):
		if not done.has(req):
			return false
	for need: String in t.get("needs", []):
		if not items.has(need):
			return false
	return true


func go_to(name: String) -> void:
	station = name
	_station_label.text = name
	_station_label.visible = name != ""
	for child in _tasks.get_children():
		child.queue_free()
	for t: Dictionary in data.get("tasks", []):
		if t.get("station", "") != name:
			continue
		var b := Button.new()
		b.text = t.get("text", "")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not available(t["id"])
		b.pressed.connect(do_task.bind(t["id"]))
		_tasks.add_child(b)
	_update()


## Do one task: consumes the items it needs, hands over its item, dresses the doll.
func do_task(id: String) -> bool:
	if not available(id):
		return false
	var t := task_by_id(id)
	for need: String in t.get("needs", []):
		items.erase(need)
	if t.get("gives", "") != "":
		items.append(t["gives"])
	var outfit: Dictionary = t.get("outfit", {})
	for slot: String in outfit:
		doll.set_part(slot, outfit[slot])
	done.append(id)
	WorldState.set_flag("hottest_chain_done", done.duplicate())
	WorldState.set_flag("hottest_chain_items", items.duplicate())
	WorldState.set_flag("hottest_prep_outfit", doll.outfit.duplicate())
	go_to(station)
	return true


## The chain is finished when there are tasks and every one is done.
func chain_complete() -> bool:
	var tasks: Array = data.get("tasks", [])
	if tasks.is_empty():
		return false
	for t: Dictionary in tasks:
		if not done.has(t.get("id", "")):
			return false
	return true


func start_show() -> void:
	if not chain_complete():
		return
	WorldState.set_flag("hottest_prep_outfit", doll.outfit.duplicate())
	get_tree().call_deferred("change_scene_to_file", data.get("show_scene", ""))


func _update() -> void:
	var names: Dictionary = data.get("items", {})
	var held: Array[String] = []
	for id: String in items:
		held.append(names.get(id, id))
	_status.text = ", ".join(held)
	_go.disabled = not chain_complete()


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
