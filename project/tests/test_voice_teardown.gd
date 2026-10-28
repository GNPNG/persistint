extends SceneTree
## Voice.stop_all() lets go of every line it plays (bd y37: the shot walk's
## dialogue-temple-priestess_choices left "Resource still in use:
## res://audio/voice/2fb9c97e61f6b7d9bfe188835bcc9f04.wav (AudioStreamWAV)" and a leaked
## AudioStreamPlaybackWAV at exit). AudioStreamPlayer.stop() only marks a playback for removal: the
## audio thread drops it at its next mix, so a quit soon after stop() could leave it held.
## Here the cast's line has sounds and words queued, two nodes speak from their own players, and a
## line is deferred to the end of the frame (as Dialogue Manager emits got_dialogue); then
## stop_all(), and a few frames on: every playback those players had is freed, no player plays,
## the queues are empty, the streams dropped (Voice keeps no clip cache of its own: load() goes
## through Godot's resource cache, which holds no reference), and the deferred line started
## nothing. Voice speaks again afterwards; after shutdown() it stays silent.
## Run: godot --headless --path project -s tests/test_voice_teardown.gd

const PRIESTESS_KEY := "2fb9c97e61f6b7d9bfe188835bcc9f04"  # the clip the shot walk leaked
const SOUNDS := "[Uuunnngh.] [Mrrh.] "  # two vocalizations ahead of the words: groan_*, moan
const GROAN := "[Uuunnngh.] [Grrrr.]"  # a positional line of two parts: groan_*, growl

var _failures := 0
var _spoken := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


## The instance id of a player's latest playback, in a function of its own so the test holds no
## reference to the playback across an await.
func _playback_id(p: Node) -> int:
	return (p.call("get_stream_playback") as Object).get_instance_id()


## A manifest line whose clip is in the tree: the leaked priestess line when it is there.
func _line(voice: Node) -> Dictionary:
	var lines: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://audio/voice/manifest.json"))
	var found := {}
	if lines is Array:
		for e: Variant in lines:
			if not e is Dictionary or not ResourceLoader.exists(voice.clip_path(String(e.get("speaker", "")), String(e.get("text", "")))):
				continue
			if found.is_empty() or String(e.get("key", "")) == PRIESTESS_KEY:
				found = e
	return found


func _players() -> Array:
	var out: Array = []
	for kind: String in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		out.append_array(root.find_children("*", kind, true, false))
	return out


func _run() -> void:
	await process_frame
	var voice: Node = root.get_node("/root/Voice")
	voice._player.stop()
	voice._queue.clear()
	voice.spoke.connect(func(_speaker: String, _text: String) -> void: _spoken += 1)

	var line := _line(voice)
	_check(not line.is_empty(), "a manifest line with its clip (%s)" % line.get("key", "none"))
	var speaker := String(line.get("speaker", ""))
	var text := String(line.get("text", ""))

	# --- Several lines going: the cast's, with parts still queued, and two nodes' own.
	voice.speak(SOUNDS + text, 1.0, speaker)
	var a := Node2D.new()
	var b := Node2D.new()
	root.add_child(a)
	root.add_child(b)
	_check(voice.speak_at(a, GROAN, "clone_a", "Clones"), "node A starts its line")
	_check(voice.speak_at(b, GROAN, "clone_b", "Clones"), "node B starts its line")
	await process_frame
	var pa: AudioStreamPlayer2D = a.get_node(voice.VOICE_AT)
	var pb: AudioStreamPlayer2D = b.get_node(voice.VOICE_AT)
	_check(voice._player.playing and pa.playing and pb.playing, "the cast's line and both nodes' play")
	_check(voice.pending().size() == 2, "the cast's line has its moan and words queued (%d)" % voice.pending().size())
	_check(voice.voices_at() == 2, "two positional lines are going (%d)" % voice.voices_at())
	var ids: Array[int] = []
	for p: Node in [voice._player, pa, pb]:
		if p.call("has_stream_playback"):
			ids.append(_playback_id(p))
	_check(ids.size() == 3, "each of the three players has a playback (%d)" % ids.size())

	# --- A line deferred to the end of the frame, then stop_all with every other player in the
	# tree (as the shot walk's _teardown does).
	var spoken_before := _spoken
	voice.speak.call_deferred(text, 1.0, speaker)
	var t0 := Time.get_ticks_msec()
	await voice.stop_all(_players())
	var took := Time.get_ticks_msec() - t0
	for i in 3:
		await process_frame

	var held := ids.filter(func(id: int) -> bool: return is_instance_id_valid(id)).size()
	_check(held == 0, "every playback the players had is freed (%d of %d still held; stop_all took %d ms)" % [held, ids.size(), took])
	var going := _players().filter(func(p: Node) -> bool: return bool(p.get("playing")) or bool(p.call("has_stream_playback")))
	_check(going.is_empty(), "no player plays or holds a playback (%s)" % [going])
	_check(voice.pending().is_empty() and voice._queue.is_empty(), "the cast's queue is empty")
	_check(voice._at.is_empty() and voice.voices_at() == 0, "no positional line is left")
	_check(voice._player.stream == null and pa.stream == null and pb.stream == null, "Voice's players hold no stream")
	_check(_spoken == spoken_before + 1, "the deferred line came in during stop_all (spoke %d)" % (_spoken - spoken_before))
	_check(not voice._player.playing and voice._player.stream == null, "the deferred line started no clip")

	# --- Voice speaks again after stop_all (the shot walk's next shot).
	voice.speak(text, 1.0, speaker)
	await process_frame
	_check(voice._player.playing, "a line after stop_all plays")
	var again: Array[int] = []
	if voice._player.call("has_stream_playback"):
		again.append(_playback_id(voice._player))

	# --- shutdown(): the line freed, and Voice silent from then on (the quit).
	await voice.shutdown()
	for i in 3:
		await process_frame
	_check(again.size() == 1 and not is_instance_id_valid(again[0]), "shutdown frees the line's playback")
	_check(voice.speak_at(a, GROAN, "clone_a", "Clones") == false, "after shutdown a node's line starts nothing")
	voice.speak(text, 1.0, speaker)
	await process_frame
	_check(not voice._player.playing and voice._player.stream == null, "after shutdown a cast line starts nothing")

	a.queue_free()
	b.queue_free()
	await process_frame
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
