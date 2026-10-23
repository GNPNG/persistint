extends Control
## Next Top Comic — stand-up on the dialogue system in Monkey Island insult-sword-fighting
## structure (DESIGN.md §2). Sarah Silverman delivers each setup, the player picks a punchline,
## and whatever is picked the women in the audience think it's hilarious. When the setups run
## out the set ends. Chelsea Clinton introduces it like every celebrity mini-game.
## The conversation lives in dialogue/next_top_comic.dialogue; this node is its game state.
## Data: data/next_top_comic.json (setups: [{setup, punchlines}]), data/emcee.json.
## After the set, the Name It beat follows. Result goes to WorldState: comic_done.

const DATA_PATH := "res://data/next_top_comic.json"
const EMCEE_PATH := "res://data/emcee.json"
const DIALOGUE_PATH := "res://dialogue/next_top_comic.dialogue"
const GAME_ID := "next_top_comic"
const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")

var data: Dictionary = {}
var emcee: Dictionary = {}
var autostart := true
var index := 0
var picks: Array = []


func _ready() -> void:
	data = _load(DATA_PATH)
	emcee = _load(EMCEE_PATH)
	if autostart:
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		var balloon := DialogueManager.show_dialogue_balloon(load(DIALOGUE_PATH), "start", [self])
		# The dialogue has fixed punchline slots; only the ones this setup fills are shown.
		for menu in balloon.find_children("*", "DialogueResponsesMenu", true, false):
			menu.hide_failed_responses = true


func host_name() -> String:
	return Cast.full(data.get("host", ""))


func emcee_name() -> String:
	return Cast.full(emcee.get("emcee", ""))


func emcee_intro() -> String:
	var intros: Dictionary = emcee.get("intros", {})
	return " ".join(intros.get(GAME_ID, intros.get("_default", [])))


func begin_set() -> void:
	index = 0
	picks = []


func set_done() -> bool:
	return index >= data.get("setups", []).size()


func current_setup() -> String:
	return data["setups"][index]["setup"] if not set_done() else ""


## Silverman delivers the setup in her voice.
func deliver_setup() -> void:
	Voice.speak(current_setup(), 1.2)


func punchline(slot: int) -> String:
	var all := _punchlines()
	return all[slot] if slot < all.size() else ""


func has_punchline(slot: int) -> bool:
	return slot < _punchlines().size()


func pick(slot: int) -> void:
	picks.append(punchline(slot))


## The women in the audience think it's hilarious, whatever was picked.
func audience_laugh() -> String:
	Voice.speak("hahaha", 1.6)
	return "♥ ♥ ♥"


func next_setup() -> void:
	index += 1


func finish() -> void:
	WorldState.set_flag("comic_done", true)
	NameIt.start(GAME_ID)  # the pedagogy loop; a beat the author hasn't set stays off


func _punchlines() -> Array:
	return data["setups"][index].get("punchlines", []) if not set_done() else []


func _on_dialogue_ended(_resource: Resource) -> void:
	go_back()


## Where the set ends up: back to where a cruise flashback was started from, otherwise return_map.
func return_target() -> Dictionary:
	return Flashbacks.return_target(data.get("return_map", "res://scenes/maps/village.tscn"))


func go_back() -> void:
	var to := Flashbacks.leave(data.get("return_map", "res://scenes/maps/village.tscn"))
	SceneRouter.goto_map(to["scene"], to["spawn"])


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
