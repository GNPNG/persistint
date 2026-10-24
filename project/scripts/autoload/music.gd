extends Node
## Music — one looping track per scene, crossfaded, on the "Music" bus; stingers one-shot on
## their moments (STYLE.md section 9). Which track a scene plays lives in data/music.json:
## "scenes" (scene path -> track id, "" for silence, or a default with GameClock "when" rules,
## re-checked on every phase and day change); "tracks"/"stingers" (id -> res:// path) are
## generated from the music prompts' front matter by tools/gen_music_map.py.
## A track whose file is not there yet (not rendered and synced) plays nothing and is logged
## once at verbose level; once tools/sync_rendered_assets.py drops the file in, it plays —
## imported, or read straight from the .mp3 when the editor has not imported it yet.
## The music volume is a player setting, kept in user://settings.cfg (not the save game,
## which New Game wipes).

signal track_changed(track_id: String)

const DATA_PATH := "res://data/music.json"
const BUS := "Music"
const SETTINGS_SECTION := "audio"
const SETTINGS_KEY := "music_volume"
const DUCK_SECONDS := 0.4
const SILENT := 0.00001

## A var so headless tests can point it at a temp file instead of the player's real settings.
var SETTINGS_PATH := "user://settings.cfg"

var data: Dictionary = {}
var crossfade_seconds := 2.0
var duck_db := -12.0
## The track the current scene asks for ("" is silence); it may be missing and so not audible.
var current := ""

var _players: Array[AudioStreamPlayer] = []
var _fade: Array[float] = [0.0, 0.0]
var _target: Array[float] = [0.0, 0.0]
var _active := 0
var _stinger: AudioStreamPlayer
var _duck := 1.0
var _streams: Dictionary = {}  # res path -> AudioStream (found files and injected streams)
var _logged: Dictionary = {}  # message -> true, so each verbose note prints once
var _scene := ""
var _volume := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		data = parsed
	crossfade_seconds = float(data.get("crossfade_seconds", crossfade_seconds))
	duck_db = float(data.get("duck_db", duck_db))
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Loop%d" % i
		p.bus = BUS
		p.volume_db = linear_to_db(SILENT)
		add_child(p)
		_players.append(p)
	_stinger = AudioStreamPlayer.new()
	_stinger.name = "Stinger"
	_stinger.bus = BUS
	add_child(_stinger)
	load_settings()
	get_tree().scene_changed.connect(_on_scene_changed)
	var clock := get_node_or_null("/root/GameClock")
	if clock:
		clock.phase_changed.connect(func(_p: String) -> void: refresh())
		clock.day_changed.connect(func(_d: int) -> void: refresh())
	_on_scene_changed.call_deferred()  # the main scene is already in when autoloads start


# --- Scenes -------------------------------------------------------------------------------

func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	enter_scene(scene.scene_file_path if scene else "")


## Plays what `scene_path` asks for. A scene music.json doesn't list keeps the current music.
func enter_scene(scene_path: String) -> void:
	_scene = scene_path
	if scene_path == "":
		return
	var track: Variant = track_for_scene(scene_path)
	if track == null:
		_note("Music: no entry for scene %s; keeping %s" % [scene_path, current if current != "" else "silence"])
		return
	play(track)


## Re-resolves the current scene's track (its "when" rules may now pick another one).
func refresh() -> void:
	var track: Variant = track_for_scene(_scene)
	if track != null:
		play(track)


func has_scene(scene_path: String) -> bool:
	return data.get("scenes", {}).has(scene_path)


## The track id a scene plays right now, "" for silence, null if the scene isn't listed.
func track_for_scene(scene_path: String) -> Variant:
	var scenes: Dictionary = data.get("scenes", {})
	if not scenes.has(scene_path):
		return null
	var entry: Variant = scenes[scene_path]
	if entry is String:
		return entry
	if entry is Dictionary:
		var clock := get_node_or_null("/root/GameClock")
		for rule: Dictionary in entry.get("when", []):
			if clock and clock.matches_when(rule.get("when", {})):
				return String(rule.get("track", ""))
		return String(entry.get("track", ""))
	return ""


## Every track id a scene can play (its default and each rule's), for checks.
func scene_tracks(scene_path: String) -> Array[String]:
	var out: Array[String] = []
	var entry: Variant = data.get("scenes", {}).get(scene_path)
	if entry is String:
		out.append(entry)
	elif entry is Dictionary:
		out.append(String(entry.get("track", "")))
		for rule: Dictionary in entry.get("when", []):
			out.append(String(rule.get("track", "")))
	return out


# --- Loop tracks --------------------------------------------------------------------------

func track_path(track_id: String) -> String:
	return String(data.get("tracks", {}).get(track_id, ""))


## Crossfades to `track_id` ("" fades to silence). The track already playing keeps playing.
func play(track_id: String) -> void:
	var live := _players[_active]
	if track_id == current and (track_id == "" or (live.playing and _target[_active] > 0.0)):
		return
	current = track_id
	var stream: AudioStream = null
	if track_id != "":
		var path := track_path(track_id)
		if path == "":
			_note("Music: unknown track id '%s'" % track_id)
		else:
			stream = _load(path, true)
	_target[_active] = 0.0
	if stream:
		_active = 1 - _active
		var p := _players[_active]
		p.stop()
		p.stream = stream
		_fade[_active] = 0.0
		_target[_active] = 1.0
		_apply_volumes()
		p.play()
	track_changed.emit(track_id)


func stop() -> void:
	play("")


## The stream that is (or is fading in to be) audible, null for silence.
func playing_stream() -> AudioStream:
	var p := _players[_active]
	return p.stream if p.playing and _target[_active] > 0.0 else null


## Makes `track_id` play `stream` (tests inject generated audio; also usable for a debug cue).
func register_track(track_id: String, stream: AudioStream) -> void:
	var tracks: Dictionary = data.get_or_add("tracks", {})
	if not tracks.has(track_id):
		tracks[track_id] = "memory://music/%s" % track_id
	_streams[tracks[track_id]] = stream


# --- Stingers -----------------------------------------------------------------------------

func stinger_path(stinger_id: String) -> String:
	return String(data.get("stingers", {}).get(stinger_id, ""))


## Plays a one-shot stinger; the loop ducks under it.
func play_stinger(stinger_id: String) -> void:
	var path := stinger_path(stinger_id)
	if path == "":
		_note("Music: unknown stinger id '%s'" % stinger_id)
		return
	var stream := _load(path, false)
	if stream == null:
		return
	_stinger.stop()
	_stinger.stream = stream
	_stinger.play()


func stinger_playing() -> bool:
	return _stinger.playing


## A game moment with a stinger in music.json "events" (e.g. "name_it").
func event(event_name: String) -> void:
	var id := String(data.get("events", {}).get(event_name, ""))
	if id != "":
		play_stinger(id)


## The time-jump card of the chapter being left plays that chapter's stinger, if it has one.
func chapter_end(chapter_id: String) -> void:
	var id := String(data.get("chapter_end_stingers", {}).get(chapter_id, ""))
	if id != "":
		play_stinger(id)


func register_stinger(stinger_id: String, stream: AudioStream) -> void:
	var stingers: Dictionary = data.get_or_add("stingers", {})
	if not stingers.has(stinger_id):
		stingers[stinger_id] = "memory://stingers/%s" % stinger_id
	_streams[stingers[stinger_id]] = stream


# --- Fades --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	step(delta)


## Advances crossfades and ducking by `delta` seconds (called every frame; tests call it directly).
func step(delta: float) -> void:
	var rate := delta / maxf(crossfade_seconds, 0.001)
	for i in 2:
		_fade[i] = move_toward(_fade[i], _target[i], rate)
		if _fade[i] <= 0.0 and _target[i] <= 0.0 and _players[i].playing:
			_players[i].stop()
	var duck_to := db_to_linear(duck_db) if _stinger.playing else 1.0
	_duck = move_toward(_duck, duck_to, delta / DUCK_SECONDS)
	_apply_volumes()


func _apply_volumes() -> void:
	for i in 2:
		_players[i].volume_db = linear_to_db(maxf(_fade[i] * _duck, SILENT))


## Fade level 0..1 of each loop player, and which one is the live one (for checks).
func fade_levels() -> Array[float]:
	return _fade.duplicate()


func active_player() -> AudioStreamPlayer:
	return _players[_active]


func players() -> Array[AudioStreamPlayer]:
	return _players.duplicate()


# --- Files --------------------------------------------------------------------------------

## The stream at `path`, or null (logged once) while the file isn't there.
func _load(path: String, loop: bool) -> AudioStream:
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		elif FileAccess.file_exists(path):
			# Synced in but not imported yet: read the file itself.
			match path.get_extension().to_lower():
				"mp3":
					stream = AudioStreamMP3.load_from_file(path)
				"ogg":
					stream = AudioStreamOggVorbis.load_from_file(path)
		if stream == null:
			_note("Music: %s is not there yet (not rendered); playing nothing" % path)
			return null
		_streams[path] = stream
	# Area loops loop and stingers don't, whatever the import settings say.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	return stream


func is_logged(message_part: String) -> bool:
	for m: String in _logged:
		if m.contains(message_part):
			return true
	return false


func _note(message: String) -> void:
	if _logged.has(message):
		return
	_logged[message] = true
	print_verbose(message)


# --- Bus and volume -----------------------------------------------------------------------

## default_bus_layout.tres defines the bus; make it anyway if a layout without it is loaded.
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, "Master")


## Music volume 0..1 (linear), applied to the Music bus and saved to the settings file.
func set_volume(linear: float) -> void:
	_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_volume()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other settings in the file
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, _volume)
	cfg.save(SETTINGS_PATH)


func volume() -> float:
	return _volume


func load_settings() -> void:
	var cfg := ConfigFile.new()
	_volume = 1.0
	if cfg.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, 1.0)), 0.0, 1.0)
	_apply_bus_volume()


func _apply_bus_volume() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, _volume <= 0.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(_volume, SILENT)))
