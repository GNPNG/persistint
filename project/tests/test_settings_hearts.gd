extends SceneTree
## The hearts at the bottom of the settings screen (bd dhn2): three, pastel red, green and blue,
## the last thing on the panel, with no text, no hint and no pad focus, each a touch target of at
## least HEART_TOUCH px inside the panel and clear of the button above. Tapped R-G-B-B-G-R they
## turn playtest mode on (a tap pulses its heart), and the Playtest row shows (Voice review, Export
## playtest, Playtest off) with "Playtest mode on" on the status line. The mode is kept in the
## settings file beside the other settings and comes back on a reload; the code again, or Playtest
## off, turns it off. A wrong heart starts the code over, and a red one counts as the first of the
## next try. A gap of 5.1 s starts it over; taps 5 s apart still count (the screen's clock is the
## test's own, so nothing waits). Export playtest is one JSON file, persistint-playtest-<date>-
## <time>.json: kind, exported_at, version and the voice review's verdicts ({} before any). The
## voice review it opens ships in the player build. With the Playtest row showing, the pause menu
## fits on screen and the hearts stay clear of Quit to Menu (each heart's rect as laid out, not
## scaled mid-pulse). Before the quit the pulses end and Voice lets go of every playback.
## Run: godot --headless --path project -s tests/test_settings_hearts.gd
## The player's real settings and the author's voice review are not touched.

const MENU := "res://scenes/ui/main_menu.tscn"
const VILLAGE := "res://scenes/maps/village.tscn"
const PRESETS := "res://export_presets.cfg"
const TEST_SETTINGS := "user://test_settings_hearts.cfg"
const TEST_REVIEW := "user://test_settings_hearts_review.json"

var _failures := 0
var _clock_ms := 0  # the settings screen's clock in this test


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Taps the hearts in `code` (r, g, b), `gap_ms` apart on the screen's clock.
func _taps(screen: Node, code: String, gap_ms := 1000) -> void:
	for c in code:
		_clock_ms += gap_ms
		screen.heart(c).pressed.emit()


## A heart's touch target as laid out, in the same space as the panel's global rect: without the
## pulse a tap gives it (up a third about its centre and back, 0.22 s), which the last taps leave
## running into the pause-menu checks (cc-srv: S 30.69 there, against 28 in the main menu).
func _rest_rect(h: Control) -> Rect2:
	return h.get_parent_control().get_global_transform() * Rect2(h.position, h.size)


## Before the quit: the hearts' pulses ended and their scale put back (the last taps' run on into
## the pause menu), then Voice.shutdown with every other player in the tree, which waits until the
## audio server has freed their playbacks (bd y37, as the shot walk and test_perf_walk do), and the
## village freed. A quit with a playback still in the server's list leaves it and its stream in use
## at exit.
func _teardown(screen: Node) -> void:
	var pulses: Dictionary = screen._pulses
	for h: Variant in pulses:
		var tw: Variant = pulses[h]
		if tw is Tween and tw.is_valid():
			tw.kill()
		if is_instance_valid(h) and h is Control:
			h.scale = Vector2.ONE
	pulses.clear()
	var others: Array = []
	for kind: String in ["AudioStreamPlayer", "AudioStreamPlayer2D"]:
		others.append_array(root.find_children("*", kind, true, false))
	var voice := root.get_node_or_null("/root/Voice")
	if voice and voice.has_method("shutdown"):
		await voice.shutdown(others)
	if current_scene:
		current_scene.queue_free()
	await process_frame


func _saved_on() -> Variant:
	var cfg := ConfigFile.new()
	return cfg.get_value("playtest", "enabled", null) if cfg.load(TEST_SETTINGS) == OK else null


func _run() -> void:
	await process_frame
	var pt: Node = root.get_node("/root/Playtest")
	var settings: Node = root.get_node("/root/AudioSettings")
	var screen: Node = settings._overlay
	var real_path: String = pt.SETTINGS_PATH
	var real_review: String = pt.REVIEW_PATH
	_check(real_path == root.get_node("/root/WorldState").TEST_SETTINGS_PATH, "a test run keeps playtest mode in the test settings file, not user://settings.cfg (QA-04)")
	pt.SETTINGS_PATH = TEST_SETTINGS
	pt.REVIEW_PATH = TEST_REVIEW
	for p: String in [TEST_SETTINGS, TEST_REVIEW]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var other := ConfigFile.new()
	other.set_value("audio", "voice_volume", 0.5)
	other.save(TEST_SETTINGS)
	pt.load_settings()
	_check(not pt.enabled(), "playtest mode starts off")
	screen.now_msec = func() -> int: return _clock_ms

	# --- The hearts: three small pastel hearts at the bottom that read as decoration. ---
	change_scene_to_file(MENU)
	await _frames(3)
	settings.open()
	await _frames(2)
	var box: Node = screen.get_node("Center/Panel/VBox")
	var row: Node = screen.get_node_or_null("Center/Panel/VBox/Hearts")
	_check(row != null and row.get_index() == box.get_child_count() - 1, "the hearts are the last thing on the panel")
	var panel: Control = screen.get_node("Center/Panel")
	var done: Control = screen.get_node("%DoneButton")
	for c: String in ["r", "g", "b"]:
		var h: Button = screen.heart(c)
		var r := _rest_rect(h)
		_check(h.is_visible_in_tree() and h.text == "" and h.tooltip_text == "" and h.flat and h.focus_mode == Control.FOCUS_NONE,
			"heart %s: no text, no hint, no pad focus" % c)
		_check(r.size.x >= screen.HEART_TOUCH and r.size.y >= screen.HEART_TOUCH, "heart %s: a touch target of %s (%d px a side wanted)" % [c, r.size, screen.HEART_TOUCH])
		_check(panel.get_global_rect().encloses(r) and not r.intersects(done.get_global_rect()), "heart %s sits inside the panel, clear of Done (%s)" % [c, r])
	var cols: Dictionary = screen.HEART_COLORS
	var hues: bool = cols["r"].r > maxf(cols["r"].g, cols["r"].b) and cols["g"].g > maxf(cols["g"].r, cols["g"].b) and cols["b"].b > maxf(cols["b"].r, cols["b"].g)
	var pastel := true
	for col: Color in cols.values():
		pastel = pastel and minf(col.r, minf(col.g, col.b)) > 0.6
	_check(hues and pastel, "the hearts are pastel red, green and blue")

	# --- The code turns playtest mode on; the Playtest row shows. ---
	_check(not screen.playtest_row().visible, "no Playtest row while the mode is off")
	_taps(screen, "r")
	var pulse: Variant = screen._pulses.get(screen.heart("r"))
	_check(pulse is Tween and pulse.is_valid(), "a tap gives its heart a small pulse")
	_taps(screen, "gbbg")
	_check(not pt.enabled(), "five hearts of the six do nothing yet")
	_taps(screen, "r")
	_check(pt.enabled(), "red, green, blue, blue, green, red turns playtest mode on")
	_check(screen.playtest_row().visible and screen.save_status() == "Playtest mode on", "the Playtest row shows, and the status line says so (%s)" % screen.save_status())
	for name: String in ["VoiceReviewButton", "ExportPlaytestButton", "PlaytestOffButton"]:
		_check(screen.playtest_row().get_node_or_null(name) is Button, "the Playtest row has %s" % name)

	# --- Kept across a reload, in the settings file beside the other settings. ---
	_check(_saved_on() == true, "the mode is saved ([playtest] enabled = true)")
	var cfg := ConfigFile.new()
	_check(cfg.load(TEST_SETTINGS) == OK and is_equal_approx(float(cfg.get_value("audio", "voice_volume", -1.0)), 0.5), "the other settings in the file are kept")
	pt._on = false
	pt.load_settings()
	_check(pt.enabled(), "and the mode comes back on a reload")
	settings.close()
	settings.open()
	_check(screen.playtest_row().visible, "the Playtest row shows on the next opening")

	# --- The code again turns it off. ---
	_taps(screen, "rgbbgr")
	_check(not pt.enabled() and not screen.playtest_row().visible and screen.save_status() == "Playtest mode off", "the code again turns it off and hides the row (%s)" % screen.save_status())
	_check(_saved_on() == false, "off is saved too")
	pt.load_settings()
	_check(not pt.enabled(), "and stays off on a reload")

	# --- A wrong heart starts over; a red one is the first of the next try. ---
	screen.refresh()
	_taps(screen, "rgg")
	_taps(screen, "bbgr")
	_check(not pt.enabled(), "a wrong heart starts the code over (r g g b b g r does nothing)")
	screen.refresh()
	_taps(screen, "rgbr")
	_taps(screen, "gbbgr")
	_check(pt.enabled(), "a wrong red heart counts as the first of the next try (r g b r g b b g r turns it on)")
	screen.playtest_row().get_node("PlaytestOffButton").pressed.emit()
	_check(not pt.enabled() and not screen.playtest_row().visible and _saved_on() == false, "Playtest off turns it off and hides the row")

	# --- The gap: more than 5 s between taps starts over; 5 s does not. ---
	screen.refresh()
	_taps(screen, "rgbbg")
	_taps(screen, "r", 5100)
	_check(not pt.enabled(), "a 5.1 s gap before the last heart starts the code over")
	_taps(screen, "gbbgr")
	_check(pt.enabled(), "the red heart after the gap was the first of the next try")
	screen.playtest_off()
	screen.refresh()
	_taps(screen, "rgbbgr", 5000)
	_check(pt.enabled(), "taps 5 s apart still count")

	# --- Export playtest: one JSON file with the voice review's verdicts. ---
	var review := {"characters": {"crab": {"verdict": "sucks", "at": "2026-10-28T10:00:00Z", "name": "Crabs"}},
		"lines": {"0123abcd": {"thumb": "up", "at": "2026-10-28T10:01:00Z", "speaker": "crab", "text": "Pinch."}}}
	var f := FileAccess.open(TEST_REVIEW, FileAccess.WRITE)
	f.store_string(JSON.stringify(review))
	f.close()
	var parsed: Variant = JSON.parse_string(pt.export_text())
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var iso := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
	_check(data.get("kind") == "persistint-playtest", "the export says what it is (kind %s)" % data.get("kind"))
	_check(iso.search(str(data.get("exported_at", ""))) != null, "and when (exported_at %s)" % data.get("exported_at"))
	_check(str(data.get("version", "")) == str(ProjectSettings.get_setting("application/config/version")), "and the game's version (%s)" % data.get("version"))
	_check(data.get("voice_review") == review, "and the voice review's verdicts as the review saved them")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REVIEW))
	parsed = JSON.parse_string(pt.export_text())
	_check(parsed is Dictionary and parsed.get("voice_review") == {}, "before any review, voice_review is {}")
	var file_re := RegEx.create_from_string("^persistint-playtest-\\d{8}-\\d{4}\\.json$")
	_check(file_re.search(pt.export_file_name()) != null, "the file is named persistint-playtest-YYYYMMDD-HHMM.json (%s)" % pt.export_file_name())
	screen.export_playtest()
	var said: String = screen.save_status()
	var written := said.trim_prefix("Saved a copy as ").trim_suffix(".")
	var wrote := said.begins_with("Saved a copy as ") and FileAccess.file_exists(written)
	_check(wrote and JSON.parse_string(FileAccess.get_file_as_string(written)) is Dictionary, "Export playtest writes the file on a desktop and says where (%s)" % said)
	if wrote:
		DirAccess.remove_absolute(written)

	# --- The voice review it opens ships in the player build. ---
	var voice_review: String = screen.VOICE_REVIEW
	_check(ResourceLoader.exists(voice_review), "Voice review opens %s" % voice_review)
	var presets := ConfigFile.new()
	var exclude := ""
	if presets.load(PRESETS) == OK:
		for section: String in presets.get_sections():
			if str(presets.get_value(section, "name", "")) == "Web":
				exclude = str(presets.get_value(section, "exclude_filter", ""))
	var shipped := true
	for p: String in [voice_review.trim_prefix("res://"), "scripts/playtest/voice_review.gd"]:
		for pattern: String in exclude.split(",", false):
			if p.match(pattern):
				shipped = false
	_check(exclude != "" and shipped, "the Web preset ships the voice review (exclude_filter %s)" % exclude)

	# --- With the Playtest row showing, the pause menu fits and the hearts stay clear of Quit. ---
	settings.close()
	change_scene_to_file(VILLAGE)
	await _frames(4)
	settings.open()
	await _frames(2)
	var quit_button: Control = screen.get_node("Center/Panel/VBox/QuitToMenuButton")
	_check(settings.is_paused() and quit_button.visible and screen.playtest_row().visible, "in play: the pause menu, with Quit to Menu and the Playtest row")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "the pause menu with the Playtest row fits on screen (%s)" % panel.get_global_rect())
	for c: String in ["r", "g", "b"]:
		var r: Rect2 = _rest_rect(screen.heart(c))
		_check(panel.get_global_rect().encloses(r) and not r.intersects(quit_button.get_global_rect()), "heart %s sits inside the panel, clear of Quit to Menu (%s)" % [c, r])
	settings.close()

	screen.now_msec = Callable(Time, "get_ticks_msec")
	for p: String in [TEST_SETTINGS, TEST_REVIEW]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	pt.SETTINGS_PATH = real_path
	pt.REVIEW_PATH = real_review
	pt.load_settings()
	screen.refresh()
	await _teardown(screen)
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
