extends Control
## Next Top Comic — stand-up in Monkey Island insult-sword-fighting structure (DESIGN.md §2),
## hosted by Sarah Silverman, introduced by Chelsea Clinton. A setup is fired at the player;
## the player answers with a punchline they know. Every pairing is horrible and unfunny,
## but the women in the audience think the "correct" one is hilarious. As in Monkey Island,
## a punchline the player gets beaten with is learned and usable from then on.
## Data: data/next_top_comic.json. Learned punchlines persist in WorldState comic_known.
## Result goes to WorldState: comic_done, comic_laughs.

const DATA_PATH := "res://data/next_top_comic.json"
const EMCEE_PATH := "res://data/emcee.json"
const GAME_ID := "next_top_comic"

var data: Dictionary = {}
var emcee: Dictionary = {}
var current := -1
var laughs := 0
var audience_laughing := false

var _say: Label
var _audience: Label
var _choices: VBoxContainer


func _ready() -> void:
	data = _load(DATA_PATH)
	emcee = _load(EMCEE_PATH)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var title := Label.new()
	title.text = data.get("title", "")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_say = Label.new()
	_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_say)
	_audience = Label.new()
	box.add_child(_audience)
	_choices = VBoxContainer.new()
	box.add_child(_choices)
	var intros: Dictionary = emcee.get("intros", {})
	var lines: Array = intros.get(GAME_ID, intros.get("_default", []))
	_say.text = "%s: %s" % [Cast.full(emcee.get("emcee", "")), " ".join(lines)]
	if not data.get("pairs", []).is_empty():
		fire_setup(randi() % data["pairs"].size())


func host_name() -> String:
	return Cast.full(data.get("host", ""))


## Punchlines the player can answer with: the starting set plus every one learned.
func known() -> Array:
	var learned: Array = WorldState.get_flag("comic_known", [])
	var all: Array = data.get("starting_punchlines", []).duplicate()
	for p: String in learned:
		if not all.has(p):
			all.append(p)
	return all


func fire_setup(index: int) -> void:
	current = index
	audience_laughing = false
	_audience.text = ""
	_say.text = "%s: %s" % [host_name(), data["pairs"][index]["setup"]]
	Voice.speak(data["pairs"][index]["setup"], 1.2)
	for child in _choices.get_children():
		child.queue_free()
	for p: String in known():
		var b := Button.new()
		b.text = p
		b.pressed.connect(func() -> void: answer(p))
		_choices.add_child(b)
	if known().is_empty():
		var b := Button.new()
		b.text = "..."
		b.pressed.connect(func() -> void: answer(""))
		_choices.add_child(b)


## Answer the current setup. Returns true when the women in the audience laugh.
func answer(punchline: String) -> bool:
	var correct: String = data["pairs"][current]["punchline"]
	if punchline == correct:
		laughs += 1
		audience_laughing = true
		_audience.text = "♥ ♥ ♥"
		Voice.speak("hahaha", 1.6)
	else:
		audience_laughing = false
		_audience.text = ""
		_say.text = "%s: %s" % [host_name(), correct]
		var learned: Array = WorldState.get_flag("comic_known", []).duplicate()
		if not learned.has(correct):
			learned.append(correct)
		WorldState.set_flag("comic_known", learned)
	for child in _choices.get_children():
		child.queue_free()
	if laughs >= int(data.get("wins_needed", 3)):
		_finish()
	else:
		var next := Button.new()
		next.text = "Next"
		next.pressed.connect(func() -> void: fire_setup(randi() % data["pairs"].size()))
		_choices.add_child(next)
	return audience_laughing


func _finish() -> void:
	WorldState.set_flag("comic_done", true)
	WorldState.set_flag("comic_laughs", laughs)
	for child in _choices.get_children():
		child.queue_free()
	var back := Button.new()
	back.text = "OK"
	back.pressed.connect(func() -> void:
		SceneRouter.goto_map(data.get("return_map", "res://scenes/maps/village.tscn")))
	_choices.add_child(back)


func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
