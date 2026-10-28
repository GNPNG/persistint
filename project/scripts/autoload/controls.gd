extends Node
## Controls — key remapping (GC-04): the player can give any action in REMAPPABLE a different key
## from the settings screen's Controls panel. The keys are kept in user://settings.cfg [input]
## (action = physical keycode) and put into the InputMap at start; mouse and gamepad bindings of
## an action are left alone. A key taken from another action is removed there, so one key never
## does two things. Reset puts the project's bindings back.

signal changed(action: String)

const SECTION := "input"
## In the order the Controls panel lists them, with the names it shows.
const REMAPPABLE := [
	["move_up", "Walk up"],
	["move_down", "Walk down"],
	["move_left", "Walk left"],
	["move_right", "Walk right"],
	["interact", "Talk / use"],
	["toggle_wardrobe", "Wardrobe"],
	["toggle_journal", "Journal"],
	["dismount", "Get off the pony"],
	["toggle_fullscreen", "Fullscreen"],
	["zoom_out", "Zoom out"],
	["zoom_in", "Zoom in"],
	["toggle_help", "Help"],
	["toggle_map", "Map"],
]

## A var so headless tests can point it at a temp file instead of the player's real settings.
var SETTINGS_PATH := "user://settings.cfg"

var _defaults := {}  # action -> Array[InputEvent] from project settings


func _ready() -> void:
	if WorldState.running_tests():  # QA-04: the test settings file Music emptied at start
		SETTINGS_PATH = WorldState.TEST_SETTINGS_PATH
	for pair: Array in REMAPPABLE:
		_defaults[pair[0]] = InputMap.action_get_events(pair[0]).duplicate()
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK or not cfg.has_section(SECTION):
		return
	for pair: Array in REMAPPABLE:
		var codes: Variant = cfg.get_value(SECTION, pair[0], null)
		if codes is Array and not codes.is_empty():
			_set_keys(pair[0], codes)


## The keys an action answers to, as the player would read them ("W, Up").
func key_text(action: String) -> String:
	var names: Array[String] = []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			names.append(_key_name(e))
	return ", ".join(names) if not names.is_empty() else "—"


## Gives `action` the one key in `event` (its other keys go); the key leaves any other action.
func rebind(action: String, event: InputEventKey) -> void:
	var code := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	for pair: Array in REMAPPABLE:
		if pair[0] != action and _keys(pair[0]).has(code):
			var rest := _keys(pair[0])
			rest.erase(code)
			_set_keys(pair[0], rest)
			changed.emit(pair[0])
	_set_keys(action, [code])
	_save()
	changed.emit(action)


## Back to the project's own bindings.
func reset() -> void:
	for action: String in _defaults:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		for e in _defaults[action]:
			if e is InputEventKey:
				InputMap.action_add_event(action, e)
		changed.emit(action)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
		cfg.save(SETTINGS_PATH)


func _keys(action: String) -> Array:
	var out := []
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			out.append(int(e.physical_keycode if e.physical_keycode != 0 else e.keycode))
	return out


func _set_keys(action: String, codes: Array) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	for code in codes:
		var e := InputEventKey.new()
		e.physical_keycode = int(code)
		InputMap.action_add_event(action, e)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep the other settings in the same file
	for pair: Array in REMAPPABLE:
		cfg.set_value(SECTION, pair[0], _keys(pair[0]))
	cfg.save(SETTINGS_PATH)


func _key_name(e: InputEventKey) -> String:
	if e.physical_keycode != 0:
		var shown := DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
		return OS.get_keycode_string(shown if shown != 0 else e.physical_keycode)
	return OS.get_keycode_string(e.keycode)
