extends Control
## The Interview — character creation as a talk show segment (DESIGN.md §2). Oprah interviews
## the player about themselves; the answers drive SPECIAL-style stat allocation.
## The conversation lives in dialogue/interview.dialogue; this node is its game state.
## Data: data/interview.json (stats, base/min/max, questions: [{prompt, answers: [{text, stats}]}]).
## Result goes to WorldState: stats (stat id -> value), interview_answers, interview_done.

const DATA_PATH := "res://data/interview.json"
const DIALOGUE_PATH := "res://dialogue/interview.dialogue"

var data: Dictionary = {}
var autostart := true
var index := 0
var stats: Dictionary = {}
var chosen: Array = []


func _ready() -> void:
	data = _load(DATA_PATH)
	if autostart:
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		var balloon := DialogueManager.show_dialogue_balloon(load(DIALOGUE_PATH), "start", [self])
		# The dialogue has fixed answer slots; only the ones this question fills are shown.
		for menu in balloon.find_children("*", "DialogueResponsesMenu", true, false):
			menu.hide_failed_responses = true


func host_name() -> String:
	return Cast.full(data.get("host", ""))


func begin_interview() -> void:
	index = 0
	chosen = []
	stats = {}
	for stat: Dictionary in data.get("stats", []):
		stats[stat["id"]] = int(data.get("base", 0))


func interview_done() -> bool:
	return index >= data.get("questions", []).size()


func current_prompt() -> String:
	return data["questions"][index]["prompt"] if not interview_done() else ""


## Oprah asks the question in her own voice.
func ask() -> void:
	Voice.speak(current_prompt(), 1.0, data.get("host", ""))


func answer(slot: int) -> String:
	var all := _answers()
	return all[slot]["text"] if slot < all.size() else ""


func has_answer(slot: int) -> bool:
	return slot < _answers().size()


## Applies the answer's stat deltas (clamped to min/max) and moves on to the next question.
func pick(slot: int) -> void:
	var all := _answers()
	if slot >= all.size():
		return
	var deltas: Dictionary = all[slot].get("stats", {})
	for id: String in deltas:
		if stats.has(id):
			stats[id] = clampi(stats[id] + int(deltas[id]), int(data.get("min", 0)), int(data.get("max", 10)))
	chosen.append(all[slot]["text"])
	index += 1


func finish() -> void:
	WorldState.set_flag("stats", stats.duplicate())
	WorldState.set_flag("interview_answers", chosen.duplicate())
	WorldState.set_flag("interview_done", true)


func _answers() -> Array:
	return data["questions"][index].get("answers", []) if not interview_done() else []


func _on_dialogue_ended(_resource: Resource) -> void:
	SceneRouter.goto_map(data.get("return_map", "res://scenes/maps/village.tscn"))


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
