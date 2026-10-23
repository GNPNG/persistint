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

var data: Dictionary = {}
var done: Array[String] = []
var items: Array[String] = []
var station := ""
var doll: Control

var _box: VBoxContainer
var _status: Label
var _stations: HBoxContainer
var _tasks: VBoxContainer
var _go: Button


func _ready() -> void:
	data = _load(DATA_PATH)
	var options := _load(OUTFITS_PATH)
	for id: String in WorldState.get_flag("hottest_chain_done", []):
		done.append(id)
	for id: String in WorldState.get_flag("hottest_chain_items", []):
		items.append(id)
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_box)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_status)
	_stations = HBoxContainer.new()
	_box.add_child(_stations)
	for name: String in station_names():
		var b := Button.new()
		b.text = name
		b.pressed.connect(go_to.bind(name))
		_stations.add_child(b)
	var row := HBoxContainer.new()
	_box.add_child(row)
	doll = PAPER_DOLL.new()
	doll.custom_minimum_size = Vector2(110, 150)
	row.add_child(doll)
	var outfit: Dictionary = WorldState.get_flag("hottest_prep_outfit", {}).duplicate()
	if outfit.is_empty():
		outfit = {"body": "body_base"}
		for slot: String in options:
			outfit[slot] = options[slot][0]
	doll.set_outfit(outfit)
	_tasks = VBoxContainer.new()
	row.add_child(_tasks)
	_go = Button.new()
	_go.text = "Go to the show"
	_go.pressed.connect(start_show)
	_box.add_child(_go)
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
	for child in _tasks.get_children():
		child.queue_free()
	for t: Dictionary in data.get("tasks", []):
		if t.get("station", "") != name:
			continue
		var b := Button.new()
		b.text = t.get("text", "")
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
	_status.text = ", ".join(items)
	_go.disabled = not chain_complete()


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
