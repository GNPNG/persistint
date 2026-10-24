extends SceneTree
## Music: every scene the game changes to has a track in data/music.json; every track and
## stinger id resolves to the `game:` path its prompt declares (prompts/audio/**); the village
## follows the clock (night, the Festival of the Fourteenth, the quiet days); crossfades and
## same-track continuity work on generated audio; a track whose file isn't rendered yet plays
## nothing and doesn't crash; stingers duck the loop; the volume setting persists.
## Run: godot --headless --path project -s tests/test_music.gd
## The player's real settings (user://settings.cfg) are not touched.

const MAP_SCRIPT := "res://scripts/map.gd"
const MAP_DIRS := ["res://scenes/maps", "res://scenes/florida", "res://scenes/ruins"]
const WHOLE_DIRS := ["res://scenes/minigames", "res://scenes/chapters"]
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"
const TEMPLE := "res://scenes/maps/temple.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var music: Node = root.get_node("/root/Music")
	var data: Dictionary = music.data
	_check(not data.is_empty() and data.has("scenes"), "data/music.json loads")

	# --- Track ids resolve to the prompts' game: paths, both ways. ---
	var prompts := ProjectSettings.globalize_path("res://").path_join("../prompts/audio")
	var music_prompts := _prompt_table(prompts.path_join("music"))
	var stinger_prompts := _prompt_table(prompts.path_join("stingers"))
	_check(music_prompts.size() == 18, "18 music prompts found (%d)" % music_prompts.size())
	_check(stinger_prompts.size() == 2, "2 stinger prompts found (%d)" % stinger_prompts.size())
	_check(data["tracks"] == music_prompts, "music.json tracks == the music prompts' id -> game: paths")
	_check(data["stingers"] == stinger_prompts, "music.json stingers == the stinger prompts' id -> game: paths")
	var used := {}
	for scene: String in data["scenes"]:
		for t: String in music.scene_tracks(scene):
			_check(t == "" or music_prompts.has(t), "%s: track '%s' is a music prompt id" % [scene, t])
			used[t] = true
	for t: String in music_prompts:
		_check(used.has(t), "music prompt %s is played by some scene" % t)
	for chapter: String in data["chapter_end_stingers"]:
		_check(stinger_prompts.has(data["chapter_end_stingers"][chapter]), "chapter %s end stinger is a prompt id" % chapter)
	for ev: String in data["events"]:
		_check(stinger_prompts.has(data["events"][ev]), "event %s stinger is a prompt id" % ev)
	_check(data["chapter_end_stingers"].get("island") == "chapter_end_before_the_wreck", "leaving the island plays Before the Wreck")
	_check(data["events"].get("name_it") == "name_it_sting", "Name It plays its sting")

	# --- Every scene the game goes to has an entry. ---
	var scenes: Array[String] = [MAIN_MENU, ProjectSettings.get_setting("application/run/main_scene")]
	for dir: String in MAP_DIRS:
		for path in _scenes_in(dir):
			var node: Node = load(path).instantiate()
			if _extends_map(node.get_script()):
				scenes.append(path)
			node.free()
	for dir: String in WHOLE_DIRS:
		scenes.append_array(_scenes_in(dir))
	scenes.append_array(_destinations())
	var seen := {}
	for s in scenes:
		if seen.has(s):
			continue
		seen[s] = true
		_check(music.has_scene(s), "%s has a music entry" % s)
	_check(seen.size() >= 21, "found the game's scenes (%d)" % seen.size())

	# --- The picks. ---
	var picks := {
		MAIN_MENU: "title_theme", TEMPLE: "temple",
		"res://scenes/florida/stable.tscn": "pony_stable",
		"res://scenes/florida/beach.tscn": "florida_beach",
		"res://scenes/florida/garden.tscn": "florida_garden",
		"res://scenes/florida/aquarium.tscn": "florida_aquarium",
		"res://scenes/minigames/next_top_comic.tscn": "next_top_comic",
		"res://scenes/minigames/interview.tscn": "the_interview",
		"res://scenes/minigames/landing.tscn": "the_landing",
		"res://scenes/minigames/hottest_of_the_hot.tscn": "hottest_of_the_hot",
		"res://scenes/minigames/hottest_chains.tscn": "hottest_of_the_hot",
		"res://scenes/minigames/ritual_puzzle.tscn": "ritual_puzzle",
		"res://scenes/ruins/ruins_wreck.tscn": "ruins_wreck",
		"res://scenes/ruins/ruins_corridor.tscn": "ruins_colony",
		"res://scenes/ruins/ruins_core.tscn": "ruins_colony",
		"res://scenes/ruins/ruins_clone_hall.tscn": "bunker_clone_lab",
		"res://scenes/chapters/chapter_end.tscn": "",
	}
	for s: String in picks:
		_check(music.track_for_scene(s) == picks[s], "%s plays '%s'" % [s.get_file(), picks[s]])
	_check(music.track_for_scene("res://scenes/ui/nowhere.tscn") == null, "an unlisted scene has no entry")

	# --- The village follows the clock. ---
	var clock: Node = root.get_node("/root/GameClock")
	var saved_day: int = clock.day
	var saved_phase: int = clock.phase_index
	var cases := [[1, 0, "island_village"], [1, 2, "island_village"], [1, 3, "island_night"],
		[14, 1, "festival_fourteenth"], [14, 3, "island_night"], [16, 0, "island_night"],
		[21, 1, "island_village"], [42, 0, "festival_fourteenth"]]
	for c: Array in cases:
		clock.day = c[0]
		clock.phase_index = c[1]
		_check(music.track_for_scene(VILLAGE) == c[2], "village day %d %s plays %s" % [c[0], clock.phase(), c[2]])
	clock.day = saved_day
	clock.phase_index = saved_phase

	# --- Buses. ---
	var music_bus := AudioServer.get_bus_index("Music")
	_check(music_bus > 0 and AudioServer.get_bus_send(music_bus) == "Master", "Music bus exists and sends to Master")
	for p: AudioStreamPlayer in music.players():
		_check(p.bus == "Music", "%s is on the Music bus" % p.name)
	_check(music.get_node("Stinger").bus == "Music", "stingers are on the Music bus")
	var voice_bus := AudioServer.get_bus_index("Voice")
	_check(voice_bus > 0 and AudioServer.get_bus_send(voice_bus) == "Master", "Voice bus exists and sends to Master")

	# --- Missing files: nothing plays, nothing breaks, logged once. ---
	music.stop()
	music.step(10.0)
	var title_path: String = music.track_path("title_theme")
	var rendered := ResourceLoader.exists(title_path) or FileAccess.file_exists(title_path)
	music.play("title_theme")
	music.play("title_theme")
	if not rendered:
		_check(music.current == "title_theme" and music.playing_stream() == null, "missing title_theme: wanted, nothing plays")
		_check(music.is_logged(title_path), "missing file is noted (verbose)")
		var n := 0
		for m: String in music._logged:
			n += int(m.contains(title_path))
		_check(n == 1, "noted once")
	music.chapter_end("island")
	music.event("name_it")
	music.play_stinger("no_such_stinger")
	music.play("no_such_track")
	_check(music.playing_stream() == null, "unknown ids play nothing")
	music.chapter_end("cruise")  # no stinger for the cruise: nothing happens
	# Synced in but not imported yet (no .import beside it): read straight from the .mp3.
	var raw := "user://test_music_unimported.mp3"
	var f := FileAccess.open(raw, FileAccess.WRITE)
	for i in 40:  # silent MPEG-1 Layer III frames, 128 kbps, 44.1 kHz
		f.store_buffer(PackedByteArray([0xFF, 0xFB, 0x90, 0x64]))
		var pad := PackedByteArray()
		pad.resize(413)
		f.store_buffer(pad)
	f.close()
	var raw_stream: AudioStream = music._load(raw, true)
	_check(raw_stream is AudioStreamMP3 and raw_stream.loop and raw_stream.get_length() > 0.5,
		"an unimported .mp3 loads from the file and loops")
	music._streams.erase(raw)
	_check(not (music._load(raw, false) as AudioStreamMP3).loop, "a stinger's .mp3 doesn't loop")
	music._streams.erase(raw)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(raw))
	music.stop()
	music.step(10.0)

	# --- Crossfade on generated audio. ---
	var a := _tone(440.0, 0.5, true)
	var b := _tone(660.0, 0.5, true)
	music.register_track("test_a", a)
	music.register_track("test_b", b)
	music.crossfade_seconds = 1.0
	music.play("test_a")
	var pa: AudioStreamPlayer = music.active_player()
	_check(pa.stream == a and pa.playing and music.playing_stream() == a, "test_a starts on a loop player")
	music.step(0.5)
	_check(is_equal_approx(music.fade_levels()[music._active], 0.5), "fading in: half way at 0.5 s")
	music.step(0.6)
	_check(is_equal_approx(music.fade_levels()[music._active], 1.0), "faded in after the crossfade time")
	music.play("test_b")
	var pb: AudioStreamPlayer = music.active_player()
	_check(pb != pa and pb.stream == b and pb.playing, "test_b starts on the other player")
	_check(pa.playing, "test_a keeps playing while it fades out")
	music.step(0.5)
	var lv: Array[float] = music.fade_levels()
	_check(lv[0] > 0.0 and lv[0] < 1.0 and lv[1] > 0.0 and lv[1] < 1.0, "both audible mid-crossfade")
	music.step(0.6)
	_check(not pa.playing and pb.playing and is_equal_approx(music.fade_levels()[music._active], 1.0),
		"crossfade done: test_a stopped, test_b full")
	music.play("test_b")
	_check(music.active_player() == pb and pb.playing and is_equal_approx(music.fade_levels()[music._active], 1.0),
		"the same track again keeps playing (no restart)")
	music.play("")
	music.step(1.1)
	_check(not pa.playing and not pb.playing and music.playing_stream() == null, "\"\" fades to silence")

	# --- Scene switches through the data (a real track id, injected audio). ---
	var temple_path: String = music.track_path("temple")
	var t := _tone(330.0, 0.5, true)
	music._streams[temple_path] = t
	music.enter_scene(TEMPLE)
	_check(music.current == "temple" and music.playing_stream() == t, "entering the temple plays temple")
	music.step(1.1)
	music.enter_scene("res://scenes/ui/nowhere.tscn")
	_check(music.current == "temple" and music.playing_stream() == t, "an unlisted scene keeps the music")
	music.enter_scene("res://scenes/chapters/chapter_end.tscn")
	music.step(1.1)
	_check(music.current == "" and music.playing_stream() == null, "the chapter card fades the loop out")
	music._streams.erase(temple_path)

	# --- Stingers duck the loop. ---
	music.register_track("test_a", a)
	music.play("test_a")
	music.step(1.1)
	var full_db: float = music.active_player().volume_db
	music.register_stinger("test_sting", _tone(880.0, 2.0, false))
	music.play_stinger("test_sting")
	_check(music.stinger_playing(), "stinger plays")
	music.step(0.5)
	_check(music.active_player().volume_db < full_db - 6.0, "loop ducks under the stinger")
	music.get_node("Stinger").stop()
	music.step(0.5)
	_check(is_equal_approx(music.active_player().volume_db, full_db), "loop comes back after the stinger")
	music.stop()
	music.step(10.0)

	# --- Real scene changes drive it. ---
	music.crossfade_seconds = 0.05
	change_scene_to_file(MAIN_MENU)
	await process_frame
	await process_frame
	_check(music.current == "title_theme", "changing to the main menu asks for title_theme")
	change_scene_to_file(TEMPLE)
	await process_frame
	await process_frame
	_check(music.current == "temple", "changing to the temple asks for temple")

	# --- Volume persists in the settings file. ---
	var real_path: String = music.SETTINGS_PATH
	music.SETTINGS_PATH = "user://test_music_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(music.SETTINGS_PATH))
	music.load_settings()
	_check(is_equal_approx(music.volume(), 1.0), "no settings file: full volume")
	music.set_volume(0.5)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.5)), "volume sets the Music bus")
	var cfg := ConfigFile.new()
	_check(cfg.load(music.SETTINGS_PATH) == OK and is_equal_approx(float(cfg.get_value("audio", "music_volume")), 0.5),
		"volume saved to the settings file")
	music._volume = 1.0
	music.load_settings()
	_check(is_equal_approx(music.volume(), 0.5), "volume restored from the settings file")
	music.set_volume(0.0)
	_check(AudioServer.is_bus_mute(music_bus), "volume 0 mutes the Music bus")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(music.SETTINGS_PATH))
	music.SETTINGS_PATH = real_path
	music.load_settings()

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit()


## id -> res:// path from every prompt's front matter under `dir`.
func _prompt_table(dir: String) -> Dictionary:
	var out := {}
	for path in _files(dir, "md"):
		var text := FileAccess.get_file_as_string(path)
		var id := _front(text, "id")
		var game := _front(text, "game")
		if id != "" and game.begins_with("project/"):
			out[id] = "res://" + game.trim_prefix("project/")
	return out


func _front(text: String, key: String) -> String:
	var re := RegEx.create_from_string("(?m)^%s: (.*)$" % key)
	var m := re.search(text)
	return m.get_string(1).strip_edges() if m else ""


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), ext))
	for f in d.get_files():
		if f.get_extension() == ext:
			out.append(dir.path_join(f))
	return out


func _scenes_in(dir: String) -> Array[String]:
	return _files(dir, "tscn")


func _extends_map(script: Script) -> bool:
	while script:
		if script.resource_path == MAP_SCRIPT:
			return true
		script = script.get_base_script()
	return false


## Every scene a door, chapter or flashback sends the player to.
func _destinations() -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("target_scene = \"(res://[^\"]+)\"")
	for path in _files("res://scenes", "tscn"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			out.append(m.get_string(1))
	var chapters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	for c: Dictionary in chapters["chapters"].values():
		for k in ["entry_scene", "return_scene"]:
			if c.get(k, "") != "":
				out.append(c[k])
	var flashbacks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/flashbacks.json"))
	for f: Dictionary in flashbacks["flashbacks"]:
		out.append(f["entry_scene"])
	return out


## A short 16-bit mono sine, looping or not: stands in for a rendered track.
func _tone(hz: float, seconds: float, loop: bool) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		bytes.encode_s16(i * 2, int(sin(TAU * hz * i / rate) * 8000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = frames
	return w


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: ", what)
