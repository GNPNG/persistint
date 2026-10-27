extends Node
## AudioSettings — the player's volume levels (Master, Music, Voices, Effects; 0..1) in
## user://settings.cfg [audio], applied to the buses at start (Music owns the Music bus and its
## music_volume key; this applies the others and keeps the slider in step). It also owns the
## settings screen (scenes/ui/settings.tscn), reachable from the main menu's Settings button,
## the Escape key in play, and a floating gear at the top right for a finger (author 2026-10-24:
## touch-first, the author tests on a touchpad with no keyboard).

signal changed(which: String, linear: float)

const SECTION := "audio"
const KEYS := {"master": "master_volume", "music": "music_volume", "voice": "voice_volume", "sfx": "sfx_volume"}
const BUSES := {"master": "Master", "music": "Music", "voice": "Voice", "sfx": "SFX"}
const LABELS := {"master": "Master", "music": "Music", "voice": "Voices", "sfx": "Effects"}
const OVERLAY := "res://scenes/ui/settings.tscn"
## Scenes with no floating gear: the intro has nothing to set, the main menu has its own button.
const NO_GEAR := ["res://scenes/ui/studio_intro.tscn", "res://scenes/ui/main_menu.tscn"]
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const SILENT := 0.00001

## A var so headless tests can point it at a temp file instead of the player's real settings.
var SETTINGS_PATH := "user://settings.cfg"

var _levels := {"master": 1.0, "music": 1.0, "voice": 1.0, "sfx": 1.0}
var _layer: CanvasLayer
var _overlay: Control
var _gear: Control
var _paused := false


func _ready() -> void:
	if WorldState.running_tests():  # QA-04: the test settings file Music emptied at start
		SETTINGS_PATH = WorldState.TEST_SETTINGS_PATH
	process_mode = Node.PROCESS_MODE_ALWAYS
	for which: String in BUSES:
		_ensure_bus(BUSES[which])
	load_settings()
	_layer = CanvasLayer.new()
	_layer.name = "SettingsLayer"
	_layer.layer = 100
	add_child(_layer)
	_gear = preload("res://scripts/ui/gear_button.gd").new()
	_gear.name = "Gear"
	_gear.pressed.connect(toggle)
	_layer.add_child(_gear)
	_overlay = load(OVERLAY).instantiate()
	_overlay.visible = false
	_layer.add_child(_overlay)
	get_tree().scene_changed.connect(_update_gear)
	_update_gear.call_deferred()


# --- Levels -------------------------------------------------------------------------------

func level(which: String) -> float:
	return float(_levels.get(which, 1.0))


## Sets a level 0..1, applies it to its bus and saves it. Music goes through Music.set_volume so
## the two never disagree about music_volume.
func set_level(which: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_levels[which] = linear
	if which == "music":
		var music := get_node_or_null("/root/Music")
		if music:
			music.SETTINGS_PATH = SETTINGS_PATH
			music.set_volume(linear)
	else:
		_apply(which)
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS_PATH)
		cfg.set_value(SECTION, KEYS[which], linear)
		cfg.save(SETTINGS_PATH)
	changed.emit(which, linear)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var ok := cfg.load(SETTINGS_PATH) == OK
	for which: String in KEYS:
		_levels[which] = clampf(float(cfg.get_value(SECTION, KEYS[which], 1.0)), 0.0, 1.0) if ok else 1.0
		if which != "music":  # Music applies its own at its _ready
			_apply(which)


func _apply(which: String) -> void:
	var idx := AudioServer.get_bus_index(BUSES[which])
	if idx == -1:
		return
	var lvl: float = _levels[which]
	AudioServer.set_bus_mute(idx, lvl <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lvl, SILENT)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1 or bus_name == "Master":
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


# --- The screen ---------------------------------------------------------------------------

## In play the settings screen is also the pause menu (GC-03): opening it pauses the game, it
## offers Resume and Quit to Menu, and closing it resumes. On the main menu it only sets levels.
func open() -> void:
	if in_play():
		get_tree().paused = true
		_paused = true
	_overlay.call("refresh")
	_overlay.visible = true
	_gear.visible = false


func close() -> void:
	_overlay.visible = false
	if _paused:
		get_tree().paused = false
		_paused = false
	_update_gear()


## True in a map or mini-game (not the intro or the main menu).
func in_play() -> bool:
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	return path != "" and path not in NO_GEAR


func is_paused() -> bool:
	return _paused


## Leaves play for the main menu from the pause menu.
func quit_to_menu() -> void:
	close()
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU)


func is_open() -> bool:
	return _overlay != null and _overlay.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func gear_visible() -> bool:
	return _gear != null and _gear.visible


func _update_gear() -> void:
	if _gear == null:
		return
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	_gear.visible = not is_open() and path != "" and path not in NO_GEAR


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene else ""
	if is_open() or (path != "" and path not in NO_GEAR):
		get_viewport().set_input_as_handled()
		toggle()
