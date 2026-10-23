extends Control
## Hottest of the HOT — Tyra Banks's top-model judging show (DESIGN.md §2). Chelsea Clinton
## introduces it, the passenger is dressed on the same paper doll as the island wardrobe,
## then judged with negative framing and passive-aggressive language. A Name It beat follows.
## Data: data/hottest_of_the_hot.json (verdicts), data/emcee.json (Chelsea's intro lines).
## Result goes to WorldState: hottest_done, hottest_outfit.

const DATA_PATH := "res://data/hottest_of_the_hot.json"
const EMCEE_PATH := "res://data/emcee.json"
const OUTFITS_PATH := "res://data/outfits.json"
const PAPER_DOLL := preload("res://scripts/systems/paper_doll.gd")
const GAME_ID := "hottest_of_the_hot"
const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")

var data: Dictionary = {}
var emcee: Dictionary = {}
var options: Dictionary = {}
var doll: Control

var _box: VBoxContainer
var _say: Label


func _ready() -> void:
	data = _load(DATA_PATH)
	emcee = _load(EMCEE_PATH)
	options = _load(OUTFITS_PATH)
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_box)
	var title := Label.new()
	title.text = data.get("title", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_say = Label.new()
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(_say)
	var row := HBoxContainer.new()
	_box.add_child(row)
	doll = PAPER_DOLL.new()
	doll.custom_minimum_size = Vector2(110, 150)
	row.add_child(doll)
	var pickers := VBoxContainer.new()
	row.add_child(pickers)
	var outfit := {"body": "body_base"}
	for slot: String in options:
		outfit[slot] = options[slot][0]
		var b := Button.new()
		b.text = slot.capitalize()
		b.pressed.connect(_cycle.bind(slot))
		pickers.add_child(b)
	outfit.merge(WorldState.get_flag("hottest_prep_outfit", {}), true)
	doll.set_outfit(outfit)
	var walk_button := Button.new()
	walk_button.text = "Walk"
	walk_button.pressed.connect(walk)
	pickers.add_child(walk_button)
	_introduce()


func emcee_name() -> String:
	return Cast.full(emcee.get("emcee", ""))


func host_name() -> String:
	return Cast.full(data.get("host", ""))


## Chelsea Clinton opens the show with her lines for this game (or her default lines).
func _introduce() -> void:
	var intros: Dictionary = emcee.get("intros", {})
	var lines: Array = intros.get(GAME_ID, intros.get("_default", []))
	_say.text = "%s: %s" % [emcee_name(), " ".join(lines)] if not lines.is_empty() else emcee_name()
	for line: String in lines:
		Voice.speak(line, 1.0, emcee_name())


func choose(slot: String, part_id: String) -> void:
	doll.set_part(slot, part_id)


func _cycle(slot: String) -> void:
	var items: Array = options.get(slot, [])
	var idx := wrapi(items.find(doll.outfit.get(slot, "")) + 1, 0, items.size())
	choose(slot, items[idx])


## The passenger walks; Tyra Banks judges. Returns the verdict.
func walk() -> String:
	var verdicts: Array = data.get("verdicts", [])
	var verdict: String = verdicts.pick_random() if not verdicts.is_empty() else ""
	_say.text = "%s: %s" % [host_name(), verdict]
	Voice.speak(verdict, 1.0, host_name())
	WorldState.set_flag("hottest_done", true)
	WorldState.set_flag("hottest_outfit", doll.outfit.duplicate())
	NameIt.start("hottest_verdict")
	var back := Button.new()
	back.text = "OK"
	back.pressed.connect(go_back)
	_box.add_child(back)
	return verdict


## Where OK goes: back to where a cruise flashback was started from, otherwise return_map.
func return_target() -> Dictionary:
	return Flashbacks.return_target(data.get("return_map", "res://scenes/maps/village.tscn"))


func go_back() -> void:
	var to := Flashbacks.leave(data.get("return_map", "res://scenes/maps/village.tscn"))
	SceneRouter.goto_map(to["scene"], to["spawn"])


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
