extends SceneTree
## The main menu's Quit (GC-02, desktop only) quits only once Voice has shut down (bd gkm5, y37):
## a cast line is playing when Quit is pressed, a second press and a line deferred to the end of
## the frame (as Dialogue Manager emits got_dialogue) follow it, and the tree's quit is stood in
## for (the menu's quit_tree, so the test keeps running). When the stand-in is called, Voice is
## shut down, its player stopped with no stream, and every playback the tree's players had at the
## press is freed; the deferred line started nothing; the stand-in is called once; afterwards
## Voice stays silent.
## Run: godot --headless --path project -s tests/test_menu_quit.gd

const MENU := "res://scenes/ui/main_menu.tscn"
## Real time (ms) to wait for the quit: Voice.RELEASE_MS and a margin.
const WAIT_MS := 4000

var _failures := 0
var _quits := 0
var _at_quit := {}  # what the stand-in saw when it was called
var _ids: Array[int] = []  # the playbacks the tree's players had at the press


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The instance id of a player's latest playback, in a function of its own so the test holds no
## reference to the playback across an await.
func _playback_id(p: Node) -> int:
	return (p.call("get_stream_playback") as Object).get_instance_id()


func _players() -> Array:
	var out: Array = []
	for kind: String in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		out.append_array(root.find_children("*", kind, true, false))
	return out


## A manifest line whose clip is in the tree.
func _line(voice: Node) -> Dictionary:
	var lines: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://audio/voice/manifest.json"))
	if lines is Array:
		for e: Variant in lines:
			if e is Dictionary and ResourceLoader.exists(voice.clip_path(String(e.get("speaker", "")), String(e.get("text", "")))):
				return e
	return {}


## Voice and the tree's players as the quit finds them.
func _snapshot(voice: Node) -> Dictionary:
	var held := 0
	for id: int in _ids:
		if is_instance_id_valid(id):
			held += 1
	var going := 0
	for p: Node in _players():
		if bool(p.get("playing")):
			going += 1
	return {"shut": bool(voice.get("_shut")), "playing": bool(voice._player.playing),
		"stream": voice._player.stream, "held": held, "going": going}


func _run() -> void:
	await process_frame
	var voice: Node = root.get_node("/root/Voice")
	change_scene_to_file(MENU)
	await _frames(3)
	var menu: Node = current_scene
	var quit_button := menu.get_node_or_null("Center/Panel/VBox/QuitButton") as Button
	_check(quit_button != null, "the menu has Quit (not the web build)")
	if quit_button == null:
		_finish()
		return
	menu.quit_tree = func() -> void:
		_quits += 1
		if _quits == 1:
			_at_quit = _snapshot(voice)

	# --- A cast line is playing when Quit is pressed.
	var line := _line(voice)
	_check(not line.is_empty(), "a manifest line with its clip (%s)" % line.get("key", "none"))
	var speaker := String(line.get("speaker", ""))
	var text := String(line.get("text", ""))
	voice.speak(text, 1.0, speaker)
	await process_frame
	_check(voice._player.playing, "the cast's line plays")
	for p: Node in _players():
		if p.call("has_stream_playback"):
			_ids.append(_playback_id(p))
	_check(not _ids.is_empty(), "the tree's players have %d playback(s) at the press" % _ids.size())

	# --- Quit, a second press, and a line deferred to the end of the frame.
	var spoken := [0]
	voice.spoke.connect(func(_s: String, _t: String) -> void: spoken[0] += 1)
	quit_button.pressed.emit()
	quit_button.pressed.emit()
	voice.speak.call_deferred(text, 1.0, speaker)
	_check(_quits == 0, "the tree does not quit at the press: Voice shuts down first")
	var until := Time.get_ticks_msec() + WAIT_MS
	while _quits == 0 and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(3)

	_check(_quits == 1, "the tree quits once, after Voice shuts down (%d call(s))" % _quits)
	_check(bool(_at_quit.get("shut", false)), "at the quit Voice is shut down")
	_check(_at_quit.get("playing", true) == false and _at_quit.get("stream") == null, "at the quit Voice's player is stopped and holds no stream")
	_check(int(_at_quit.get("held", -1)) == 0, "at the quit every playback the players had is freed (%s of %d held)" % [_at_quit.get("held", "?"), _ids.size()])
	_check(int(_at_quit.get("going", -1)) == 0, "at the quit no player in the tree plays (%s)" % _at_quit.get("going", "?"))
	_check(spoken[0] >= 1 and not voice._player.playing and voice._player.stream == null, "the deferred line came in (spoke %d) and started no clip" % spoken[0])
	voice.speak(text, 1.0, speaker)
	await process_frame
	_check(not voice._player.playing and voice._player.stream == null, "after the quit a cast line starts nothing")
	_finish()


func _finish() -> void:
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
