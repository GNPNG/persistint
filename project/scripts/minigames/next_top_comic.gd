extends Control
## Next Top Comic — stand-up on the dialogue system in Monkey Island insult-sword-fighting
## structure (DESIGN.md §2), hosted by Sarah Silverman, introduced by Chelsea Clinton.
## Setups and punchlines from Amy Schumer, Sarah Silverman and Hannah Gadsby are mixed into
## one shared pool (data/quotes/<id>.json "jokes"); Silverman and the player draw from the same
## lines, fully randomized, so a pairing that happens to fit doesn't matter. Silverman throws a
## setup and the player picks a punchline; then the player throws a setup and Silverman answers.
## The women in the audience laugh after every exchange. Lines are used up as they are thrown;
## Choosing an interjection or opener instead gets boos and docked points. When the setups run out the set ends. Also in the punchline pool: data "interjections".
## The conversation is dialogue/next_top_comic.dialogue; this node is its game state.
## After the set, the Name It beat follows. Results go to WorldState: comic_done, comic_points.

const DATA_PATH := "res://data/next_top_comic.json"
const EMCEE_PATH := "res://data/emcee.json"
const QUOTES_DIR := "res://data/quotes/"
const DIALOGUE_PATH := "res://dialogue/next_top_comic.dialogue"
const GAME_ID := "next_top_comic"
const MAX_SLOTS := 40  # response slots in the .dialogue file

var data: Dictionary = {}
var emcee: Dictionary = {}
var autostart := true
var pool: Array = []  # [{setup, punchline, by, source, url}]
var setups: Array = []
var punchlines: Array = []
var host_turn := true
var current := ""
var answer := ""
var picks: Array = []
var stole := false


func _ready() -> void:
	data = _load(DATA_PATH)
	emcee = _load(EMCEE_PATH)
	for id: String in data.get("sources", []):
		for joke: Dictionary in _load(QUOTES_DIR + id + ".json").get("jokes", []):
			var entry := joke.duplicate()
			entry["by"] = id
			pool.append(entry)
	if autostart:
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
		var balloon := DialogueManager.show_dialogue_balloon(load(DIALOGUE_PATH), "start", [self])
		# The dialogue has fixed response slots; only the filled ones are shown.
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
	setups = pool.map(func(j: Dictionary) -> String: return j["setup"])
	punchlines = pool.map(func(j: Dictionary) -> String: return j["punchline"])
	punchlines.append_array(data.get("interjections", []))
	setups.append_array(data.get("openers", []))
	host_turn = true
	picks = []


func set_done() -> bool:
	return setups.is_empty()


func player_turn() -> bool:
	return not host_turn


func current_setup() -> String:
	return current


## Silverman throws a random setup.
func deliver_setup() -> void:
	current = setups.pop_at(randi() % setups.size())
	Voice.speak(current, 1.2)


func punchline(slot: int) -> String:
	return punchlines[slot] if slot < punchlines.size() else ""


func has_punchline(slot: int) -> bool:
	return slot < punchlines.size()


func setup(slot: int) -> String:
	return setups[slot] if slot < setups.size() else ""


func has_setup(slot: int) -> bool:
	return slot < setups.size()


func pick(slot: int) -> void:
	var line: String = punchlines.pop_at(slot)
	picks.append(line)
	_judge(line, data.get("interjections", []))


## The player throws a setup; Silverman answers with a random punchline.
func pick_setup(slot: int) -> void:
	current = setups.pop_at(slot)
	_judge(current, data.get("openers", []))
	answer = punchlines.pop_at(randi() % punchlines.size())
	Voice.speak(answer, 1.2)


## The player's own choice of an interjection or opener is stealing from Amy Schumer.
func _judge(line: String, stolen: Array) -> void:
	stole = stolen.has(line)
	if stole:
		WorldState.set_flag("comic_points", int(WorldState.get_flag("comic_points", 0)) - int(data.get("steal_penalty", 1)))


func stole_joke() -> bool:
	return stole


func audience_boo() -> String:
	Voice.speak("boo", 0.8)
	return "[audience boos]"


func judges_dock() -> String:
	return "[judges dock you points for stealing jokes from %s]" % Cast.full("schumer")


func host_punchline() -> String:
	return answer


## The women in the audience think it's hilarious, whatever was said.
func audience_laugh() -> String:
	Voice.speak("hahaha", 1.6)
	return "[audience laughs riotously]"


func next_turn() -> void:
	host_turn = not host_turn


func finish() -> void:
	WorldState.set_flag("comic_done", true)
	NameIt.start(GAME_ID)  # the pedagogy loop; a beat the author hasn't set stays off


func _on_dialogue_ended(_resource: Resource) -> void:
	SceneRouter.goto_map(data.get("return_map", "res://scenes/maps/village.tscn"))


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
