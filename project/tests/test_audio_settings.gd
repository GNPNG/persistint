extends SceneTree
## Audio settings: Master, Music, Voices and Effects levels persist in the settings file and set
## their buses (Music through Music.set_volume, so music_volume is one value); the settings screen
## opens and closes; the floating gear shows in play but not on the main menu; the cubs' sounds
## are on the SFX bus; the music loop ducks under a voice line and comes back; a track starting
## from silence is up within FADE_IN_SECONDS rather than a whole crossfade.
## Run: godot --headless --path project -s tests/test_audio_settings.gd
## The player's real settings (user://settings.cfg) are not touched.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(2)
	var settings: Node = root.get_node("/root/AudioSettings")
	var music: Node = root.get_node("/root/Music")

	# --- Buses exist. ---
	for b in ["Master", "Music", "Voice", "Clones", "SFX"]:
		_check(AudioServer.get_bus_index(b) != -1, "bus %s exists" % b)
	var cub: PackedScene = load("res://scenes/ruins/polar_cub.tscn")
	var cub_node: Node = cub.instantiate()
	_check(String(cub_node.get_node("Sfx").bus) == "SFX", "the cub's sounds play on the SFX bus")
	cub_node.free()

	# --- Levels persist and set their buses. ---
	var real_path: String = settings.SETTINGS_PATH
	var real_music_path: String = music.SETTINGS_PATH
	var test_path := "user://test_audio_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	settings.SETTINGS_PATH = test_path
	music.SETTINGS_PATH = test_path
	settings.load_settings()
	music.load_settings()
	for which in ["master", "music", "voice", "sfx"]:
		_check(is_equal_approx(settings.level(which), 1.0), "no settings file: %s at full" % which)
	settings.set_level("voice", 0.5)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice")), linear_to_db(0.5)), "Voices sets the Voice bus")
	settings.set_level("sfx", 0.25)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.25)), "Effects sets the SFX bus")
	settings.set_level("master", 0.75)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.75)), "Master sets the Master bus")
	settings.set_level("music", 0.6)
	_check(is_equal_approx(music.volume(), 0.6), "Music level goes through Music.set_volume")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.6)), "Music level sets the Music bus")
	var cfg := ConfigFile.new()
	_check(cfg.load(test_path) == OK, "settings file written")
	_check(is_equal_approx(float(cfg.get_value("audio", "voice_volume", -1.0)), 0.5), "voice_volume saved")
	_check(is_equal_approx(float(cfg.get_value("audio", "sfx_volume", -1.0)), 0.25), "sfx_volume saved")
	_check(is_equal_approx(float(cfg.get_value("audio", "master_volume", -1.0)), 0.75), "master_volume saved")
	_check(is_equal_approx(float(cfg.get_value("audio", "music_volume", -1.0)), 0.6), "music_volume saved (one key for Music and the slider)")
	settings._levels = {"master": 1.0, "music": 1.0, "voice": 1.0, "sfx": 1.0}
	settings.load_settings()
	_check(is_equal_approx(settings.level("voice"), 0.5) and is_equal_approx(settings.level("music"), 0.6), "levels restored from the file")
	settings.set_level("sfx", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "level 0 mutes the bus")
	settings.set_level("voice", 1.0)

	# --- The screen and the gear. ---
	change_scene_to_file(MAIN_MENU)
	await _frames(3)
	_check(not settings.gear_visible(), "no gear on the main menu (it has a Settings button)")
	_check(current_scene.get_node("%SettingsButton") != null, "the main menu has a Settings button")
	settings.open()
	_check(settings.is_open(), "the settings screen opens")
	var overlay: Control = settings._overlay
	_check(overlay.slider("music") != null and is_equal_approx(overlay.slider("music").value, 0.6), "the Music slider shows the level")
	overlay.slider("sfx").value = 0.8
	_check(is_equal_approx(settings.level("sfx"), 0.8), "moving a slider sets the level")
	settings.close()
	_check(not settings.is_open(), "the settings screen closes")
	change_scene_to_file(VILLAGE)
	await _frames(3)
	_check(settings.gear_visible(), "the gear shows in play")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	root.push_unhandled_input(esc)
	await _frames(2)
	_check(settings.is_open(), "Escape opens the settings in play")
	_check(not settings.gear_visible(), "the gear hides while the screen is open")
	root.push_unhandled_input(esc)
	await _frames(2)
	_check(not settings.is_open(), "Escape closes it again")

	# --- Ducking under speech, and the fast fade-in from silence. ---
	music.crossfade_seconds = 2.0
	music.register_track("test_duck", _tone(220.0, 4.0, true))
	music.stop()
	music.step(10.0)
	music.play("test_duck")
	music.step(0.35)
	_check(music.fade_levels()[music._active] >= 0.99, "a track starting from silence is up within %.1f s" % music.FADE_IN_SECONDS)
	var full_db: float = music.active_player().volume_db
	music.duck_voice(true)
	music.step(0.5)
	_check(music.active_player().volume_db < full_db - 5.0, "the loop ducks under a voice line (about %d dB)" % int(music.voice_duck_db))
	music.duck_voice(false)
	music.step(0.5)
	_check(is_equal_approx(music.active_player().volume_db, full_db), "the loop comes back after the line")
	music.register_track("test_cross", _tone(330.0, 4.0, true))
	music.play("test_cross")
	music.step(0.35)
	_check(music.fade_levels()[music._active] < 0.5, "a crossfade between two tracks still takes the crossfade time")
	music.stop()
	music.step(10.0)
	_check(music.preloaded_count() >= 1, "tracks are preloaded into memory")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	settings.SETTINGS_PATH = real_path
	music.SETTINGS_PATH = real_music_path
	settings.load_settings()
	music.load_settings()
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)


func _tone(hz: float, seconds: float, loop: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(seconds * rate)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := int(sin(TAU * hz * i / rate) * 12000.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	s.loop_end = n
	return s


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)
