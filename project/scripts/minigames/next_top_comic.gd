extends Control
## America's Next Top Comic — stand-up on the dialogue system in Monkey Island insult-sword-fighting
## structure (DESIGN.md §2). Sarah Silverman hosts; Chelsea Clinton introduces it. The player is
## the contestant: each exchange they pick a setup, then a punchline, from one shared pool of
## lines (Amy Schumer, Sarah Silverman, Hannah Gadsby: data/quotes/<id>.json "jokes"), fully
## randomized, so a pairing that happens to fit doesn't matter. The women in the audience laugh
## after every exchange. Picking an interjection or opener instead gets boos and docked points.
## Lines are used up as they are told; when the setups run out the set ends.
## The conversation is dialogue/next_top_comic.dialogue; this node is its game state.
## After the set, the Name It beat follows. Results go to WorldState: comic_done, comic_points.

const DATA_PATH := "res://data/next_top_comic.json"
const EMCEE_PATH := "res://data/emcee.json"
const QUOTES_DIR := "res://data/quotes/"
const DIALOGUE_PATH := "res://dialogue/next_top_comic.dialogue"
const GAME_ID := "next_top_comic"
const MAX_SLOTS := 40  # response slots in the .dialogue file
const Flashbacks := preload("res://scripts/chapters/flashbacks.gd")

var data: Dictionary = {}
var emcee: Dictionary = {}
var autostart := true
var pool: Array = []  # [{setup, punchline, by, source, url}]
var setups: Array = []
var punchlines: Array = []
var picks: Array = []
var stole := false


func _ready() -> void:
	data = _load(DATA_PATH)
	emcee = _load(EMCEE_PATH)
	for id: String in data.get("sources", []):
		for joke: Dictionary in _load(QUOTES_DIR + id + ".json").get("jokes", []):
			if joke.get("verified") != true:
				continue  # only jokes checked verbatim against their source (tests/test_quotes_vv.gd)
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
	setups.shuffle()  # fully randomized: the punchlines offered rarely belong to the setup told
	punchlines.shuffle()
	picks = []


func set_done() -> bool:
	return setups.is_empty()


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


func pick_setup(slot: int) -> void:
	var line: String = setups.pop_at(slot)
	_judge(line, data.get("openers", []))


## The player's own choice of an interjection or opener is stealing from Amy Schumer.
func _judge(line: String, stolen: Array) -> void:
	if stolen.has(line):
		stole = true
		WorldState.set_flag("comic_points", int(WorldState.get_flag("comic_points", 0)) - int(data.get("steal_penalty", 1)))


func stole_joke() -> bool:
	return stole


func audience_boo() -> String:
	Voice.speak("boo", 0.8)
	return "[audience boos]"


func judges_dock() -> String:
	return "[judges dock you points for stealing jokes from %s]" % Cast.full("schumer")


## The women in the audience think it's hilarious, whatever was said.
func audience_laugh() -> String:
	Voice.speak("hahaha", 1.6)
	return "[audience laughs riotously]"


func next_turn() -> void:
	stole = false


func finish() -> void:
	WorldState.set_flag("comic_done", true)
	NameIt.start(GAME_ID)  # the pedagogy loop; a beat the author hasn't set stays off


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
