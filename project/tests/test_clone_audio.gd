extends SceneTree
## The clone hall's sounds play side by side (the author, 2026-10-27: the zombie noises "cut off,
## like one starts playing and the other one stops playing"). Each clone speaks from its own
## positional player (Voice.speak_at, an AudioStreamPlayer2D on the Clones bus): two clones
## vocalizing at once both keep playing; a cast line through Voice.speak plays while the clones
## vocalize and neither stops the other; a clone mid-line doesn't restart itself; ambient barks
## respect the cap and the per-clone cooldown (data/ruins.json clone_children.voices); only cast
## lines duck the music.
## Run: godot --headless --path project -s tests/test_clone_audio.gd

const GROAN := "[Uuunnngh.] [Grrrr.]"  # two vocalizations, no words: audio/sfx groan_*, growl

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	var voice: Node = root.get_node("/root/Voice")
	var music: Node = root.get_node_or_null("/root/Music")
	var ws: Node = root.get_node("/root/WorldState")
	var had_save := FileAccess.file_exists(ws.SAVE_PATH)
	var backup := FileAccess.get_file_as_string(ws.SAVE_PATH) if had_save else ""
	ws.reset()
	voice._player.stop()
	voice._queue.clear()
	voice._duck(false)

	var hall: Node = load("res://scenes/ruins/ruins_clone_hall.tscn").instantiate()
	root.add_child(hall)
	await process_frame
	var zs: Array = hall.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool: return n.is_in_group("zombie_clones"))
	_check(zs.size() >= 4, "clone hall has clones (%d)" % zs.size())
	var a: Node2D = zs[0]
	var b: Node2D = zs[1]
	var c: Node2D = zs[2]
	var d: Node2D = zs[3]
	a.global_position = Vector2(200, 400)
	b.global_position = Vector2(600, 400)

	# --- Each clone has its own positional player on the Clones bus, its falloff from data.
	var pa: AudioStreamPlayer2D = a.get_node_or_null(voice.VOICE_AT)
	var pb: AudioStreamPlayer2D = b.get_node_or_null(voice.VOICE_AT)
	var v: Dictionary = a.voices()
	_check(pa != null and pb != null and pa != pb and pa != voice._player, "each clone has its own VoiceAt player")
	_check(pa != null and pa.bus == &"Clones" and is_equal_approx(pa.max_distance, float(v.get("max_distance", -1.0))) \
		and is_equal_approx(pa.attenuation, float(v.get("attenuation", -1.0))), "the player is on Clones with the data's falloff")
	_check(int(v.get("max_at_once", 0)) >= 2 and float(v.get("cooldown", 0.0)) > 0.0, "voices cap and cooldown are in data")

	# --- Two clones vocalizing at once: both keep playing, the first is not restarted.
	_check(voice.speak_at(a, GROAN, a.original, "Clones"), "clone A starts its groan")
	var a_stream: AudioStream = pa.stream
	await process_frame
	_check(voice.speak_at(b, GROAN, b.original, "Clones"), "clone B starts its groan while A's plays")
	await process_frame
	await process_frame
	_check(pa.playing and pa.stream == a_stream, "A keeps playing after B starts (%s)" % pa.playing)
	_check(pb.playing, "B is playing alongside A")
	_check(voice.voices_at() == 2, "two clone lines play at once (%d)" % voice.voices_at())
	_check(not voice.speak_at(a, GROAN, a.original, "Clones") and pa.playing and pa.stream == a_stream,
		"a clone mid-line doesn't restart itself")
	_check(music == null or not music.voice_ducking(), "clone noises don't duck the music")

	# --- A cast line while the zombies vocalize: neither stops the other.
	voice.speak("[Uuunnngh.]", 1.0, "gloria")
	await process_frame
	await process_frame
	_check(voice._player.playing and voice._player.bus == &"Voice", "the cast line plays on the Voice bus")
	_check(pa.playing and pa.stream == a_stream and pb.playing, "both clones keep playing under the cast line")
	_check(music == null or music.voice_ducking(), "the cast line ducks the music")
	# a clone finishing its line doesn't un-duck the music under the cast line, or stop it
	pb.stop()
	voice._at[pb]["queue"].clear()
	voice._next_at(pb)
	_check(voice.voices_at() == 1 and voice._player.playing and pa.playing, "B finishing leaves the cast line and A playing")
	_check(music == null or music.voice_ducking(), "B finishing doesn't un-duck the music under the cast line")
	# and a new clone groan doesn't cut the cast line
	_check(voice.speak_at(b, GROAN, b.original, "Clones"), "B groans again during the cast line")
	await process_frame
	_check(voice._player.playing and pa.playing and pb.playing, "cast line, A and B all play together")

	# --- The cap: an ambient line waits when max_voices lines already play.
	c.global_position = Vector2(400, 300)
	_check(not voice.speak_at(c, GROAN, c.original, "Clones", 2), "a capped line is skipped at the cap (2 playing)")
	var pc: AudioStreamPlayer2D = c.get_node_or_null(voice.VOICE_AT)
	_check(pc != null and not pc.playing and pa.playing and pb.playing, "nobody is cut off for the capped line")
	_check(voice.speak_at(c, GROAN, c.original, "Clones"), "an uncapped line (a click) still plays")
	await process_frame
	_check(pa.playing and pb.playing and pc.playing, "three clones play together")

	# --- Ambient barks: the cap and the per-clone cooldown; a click still answers.
	var cap := int(v.get("max_at_once", 3))
	_check(voice.voices_at() >= cap or d.may_vocalize(), "may_vocalize follows the cap")
	d._quiet_until_ms = Time.get_ticks_msec() + 60000
	_check(not d.may_vocalize() and d.bark("barks", true) == "" and not d.bubble.visible, "in its cooldown a clone skips an ambient bark")
	_check(d.bark("barks") != "" and d.bubble.visible, "a click on it still barks")
	d._talking = false
	d._quiet_until_ms = 0
	for z: Node2D in [a, b, c]:
		var p: AudioStreamPlayer2D = z.get_node(voice.VOICE_AT)
		p.stop()
		if voice._at.has(p):
			voice._at[p]["queue"].clear()
			voice._next_at(p)
	if voice.speaking_at(d):
		var pd: AudioStreamPlayer2D = d.get_node(voice.VOICE_AT)
		pd.stop()
		voice._at.erase(pd)
	_check(voice.voices_at() == 0 and d.may_vocalize(), "out of its cooldown with nothing playing, it may vocalize")

	# --- A clone eaten mid-line drops out of the count.
	_check(voice.speak_at(a, GROAN, a.original, "Clones") and voice.voices_at() == 1, "A groans")
	a.get_eaten()
	await process_frame
	_check(voice.voices_at() == 0, "an eaten clone's line leaves the count")

	voice._player.stop()
	voice._queue.clear()
	voice._duck(false)
	hall.queue_free()
	await process_frame
	if had_save:
		var f := FileAccess.open(ws.SAVE_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ws.SAVE_PATH))
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
