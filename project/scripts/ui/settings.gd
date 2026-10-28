extends Control
## The settings screen: a slider per audio level (Master, Music, Voices, Effects), applied as it
## moves and saved by AudioSettings; Done (or Escape, or the dimmed background) closes it. In play
## it is the pause menu (GC-03): the title reads Paused, Done reads Resume, and Quit to Menu shows.
## Three small hearts at the bottom unlock playtest mode, and a Playtest row then shows (bd dhn2).

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VOICE_REVIEW := "res://scenes/playtest/voice_review.tscn"
const MainMenu := preload("res://scripts/ui/main_menu.gd")  # its static fullscreen helpers
const TextDownload := preload("res://scripts/util/text_download.gd")

var _sliders: Dictionary = {}


func _ready() -> void:
	$Dim.gui_input.connect(_on_dim_input)
	%DoneButton.pressed.connect(_close)
	var quit := Button.new()
	quit.name = "QuitToMenuButton"
	quit.text = "Quit to Menu"
	quit.pressed.connect(AudioSettings.quit_to_menu)
	%DoneButton.add_sibling(quit)
	var rows: VBoxContainer = %Rows
	for which: String in ["master", "music", "voice", "sfx"]:
		var row := HBoxContainer.new()
		row.name = which.capitalize()
		var label := Label.new()
		label.text = AudioSettings.LABELS[which]
		label.custom_minimum_size = Vector2(72, 0)
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(160, 20)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(v: float) -> void: AudioSettings.set_level(which, v))
		row.add_child(slider)
		rows.add_child(row)
		_sliders[which] = slider
	_sliders["master"].add_to_group(PadFocus.DEFAULT)  # a pad starts on the first slider (QA-13)
	_add_text_row(rows)
	_add_screen_row(rows)
	_add_save_row(rows)
	_add_playtest_row(rows)
	_add_hearts(%DoneButton.get_parent())
	refresh()


## Screen (GC-04): a Fullscreen toggle, and Controls… opens the key remapping panel over this one.
var _fullscreen: CheckButton
var _controls: PanelContainer


func _add_screen_row(rows: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Screen"
	var label := Label.new()
	label.text = "Screen"
	label.custom_minimum_size = Vector2(72, 0)
	row.add_child(label)
	_fullscreen = CheckButton.new()
	_fullscreen.name = "Fullscreen"
	_fullscreen.text = "Fullscreen"
	_fullscreen.toggled.connect(func(on: bool) -> void:
		if on != MainMenu.is_fullscreen():
			MainMenu.toggle_fullscreen())
	row.add_child(_fullscreen)
	var controls := Button.new()
	controls.name = "ControlsButton"
	controls.text = "Controls…"
	controls.pressed.connect(open_controls)
	row.add_child(controls)
	rows.add_child(row)


## Shows the key remapping panel in place of the settings panel.
func open_controls() -> void:
	if _controls == null:
		_controls = preload("res://scripts/ui/controls_panel.gd").new()
		_controls.closed.connect(func() -> void: $Center/Panel.show())
		$Center.add_child(_controls)
	_controls.refresh()
	_controls.show()
	$Center/Panel.hide()


func controls_panel() -> PanelContainer:
	return _controls


## Text size (QA-06): Normal, Large, Larger (TextSize); the name shows beside the slider.
var _text_slider: HSlider
var _text_name: Label


func _add_text_row(rows: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Text"
	var label := Label.new()
	label.text = "Text"
	label.custom_minimum_size = Vector2(72, 0)
	row.add_child(label)
	_text_slider = HSlider.new()
	_text_slider.name = "Slider"
	_text_slider.min_value = 0
	_text_slider.max_value = TextSize.STEPS.size() - 1
	_text_slider.step = 1
	_text_slider.tick_count = TextSize.STEPS.size()
	_text_slider.ticks_on_borders = true
	_text_slider.custom_minimum_size = Vector2(110, 20)
	_text_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_slider.value_changed.connect(func(v: float) -> void:
		TextSize.set_step(int(v))
		_text_name.text = TextSize.step_name())
	row.add_child(_text_slider)
	_text_name = Label.new()
	_text_name.custom_minimum_size = Vector2(46, 0)
	row.add_child(_text_name)
	rows.add_child(row)


## --- Save file (GC-13): Export save hands the save over as a file (a download in the browser, a
## file in the user data folder on a desktop); Import save loads one (the browser's file picker, or
## a file dialog). The status line under the buttons says what happened. ---

var _save_status: Label
var _web_file_cb: JavaScriptObject  # kept, or the browser callback is freed before it fires


func _add_save_row(rows: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "SaveFile"
	var label := Label.new()
	label.text = "Your save"
	label.custom_minimum_size = Vector2(72, 0)
	row.add_child(label)
	for pair: Array in [["ExportButton", "Export save", export_save], ["ImportButton", "Import save", import_save]]:
		var b := Button.new()
		b.name = pair[0]
		b.text = pair[1]
		b.pressed.connect(pair[2])
		row.add_child(b)
	rows.add_child(row)
	_save_status = Label.new()
	_save_status.name = "SaveStatus"
	_save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_status.custom_minimum_size = Vector2(240, 0)
	_save_status.add_theme_font_size_override("font_size", 8)
	_save_status.text = WorldState.persistence_warning_text()
	rows.add_child(_save_status)


func save_status() -> String:
	return _save_status.text


func export_save() -> void:
	var text := WorldState.export_text()
	var file_name := WorldState.export_file_name()
	var where := TextDownload.save(file_name, text)
	if OS.has_feature("web"):
		_save_status.text = ("Downloaded %s. Keep it somewhere safe; Import save brings it back." % file_name) if where != "" else "The download didn't start. Try again, or allow downloads for this page."
	elif where == "":
		_save_status.text = "Couldn't write %s." % ProjectSettings.globalize_path("user://" + file_name)
	else:
		_save_status.text = "Saved a copy as %s." % where


func import_save() -> void:
	if OS.has_feature("web"):
		_web_file_cb = JavaScriptBridge.create_callback(_on_web_file)
		JavaScriptBridge.get_interface("window").persistintSaveFile = _web_file_cb
		JavaScriptBridge.eval("(function(){var i=document.createElement('input');i.type='file';i.accept='.json,application/json';i.onchange=function(){var f=i.files&&i.files[0];if(f){f.text().then(function(t){window.persistintSaveFile(t);});}};i.click();})()", true)
		return
	var dialog := FileDialog.new()
	dialog.name = "ImportDialog"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; PERSISTINT save"])
	dialog.current_dir = ProjectSettings.globalize_path("user://")
	dialog.file_selected.connect(func(path: String) -> void:
		import_from_text(FileAccess.get_file_as_string(path))
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered_ratio(0.8)


func _on_web_file(args: Array) -> void:
	import_from_text(str(args[0]) if args.size() > 0 else "")


## Loads a save file's text. On success the game goes back to the main menu (Continue picks the
## save up, and the menu says it loaded); otherwise the status line says why and nothing changes.
func import_from_text(text: String) -> void:
	var err := WorldState.import_text(text)
	if err != "":
		_save_status.text = err
		return
	_save_status.text = WorldState.load_report_text()
	GameClock.restore()  # the day and phase come from the loaded save
	AudioSettings.close()
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU)


## --- Playtest (bd dhn2): a row that shows only in playtest mode (the Playtest autoload). Voice
## review opens the voice review; Export playtest hands its verdicts back as one file, the way
## Export save hands back the save; Playtest off turns the mode off. It sits above the save status
## line, which says what happened for both rows. ---

var _playtest_row: HBoxContainer


func _add_playtest_row(rows: VBoxContainer) -> void:
	_playtest_row = HBoxContainer.new()
	_playtest_row.name = "Playtest"
	_playtest_row.visible = false
	var label := Label.new()
	label.text = "Playtest"
	label.custom_minimum_size = Vector2(72, 0)
	_playtest_row.add_child(label)
	for pair: Array in [["VoiceReviewButton", "Voice review", open_voice_review],
			["ExportPlaytestButton", "Export playtest", export_playtest],
			["PlaytestOffButton", "Playtest off", playtest_off]]:
		var b := Button.new()
		b.name = pair[0]
		b.text = pair[1]
		b.pressed.connect(pair[2])
		_playtest_row.add_child(b)
	rows.add_child(_playtest_row)
	rows.move_child(_playtest_row, _save_status.get_index())


func playtest_row() -> HBoxContainer:
	return _playtest_row


## Turns playtest mode on or off (the hearts, or Playtest off), shows or hides the row, and says so.
func set_playtest(on: bool) -> void:
	Playtest.set_enabled(on)
	_playtest_row.visible = on
	_save_status.text = "Playtest mode on" if on else "Playtest mode off"


func playtest_off() -> void:
	set_playtest(false)


## Voice review: closes the settings (ending the pause, in play) and opens the review, whose Back
## button goes to the main menu.
func open_voice_review() -> void:
	AudioSettings.close()
	get_tree().call_deferred("change_scene_to_file", VOICE_REVIEW)


func export_playtest() -> void:
	var file_name: String = Playtest.export_file_name()
	var where := TextDownload.save(file_name, Playtest.export_text())
	if OS.has_feature("web"):
		_save_status.text = ("Downloaded %s." % file_name) if where != "" else "The download didn't start. Try again, or allow downloads for this page."
	elif where == "":
		_save_status.text = "Couldn't write %s." % ProjectSettings.globalize_path("user://" + file_name)
	else:
		_save_status.text = "Saved a copy as %s." % where


## --- The hearts (bd dhn2): three small hearts at the very bottom, pastel red, green and blue, with
## no label, so they read as decoration. Tapped red, green, blue, blue, green, red, each tap within
## HEART_GAP_MS of the one before, they turn playtest mode on, and the same again turns it off. A
## wrong heart starts the code over (a red one counts as the first of the next try), and so does a
## longer gap. The code is written plainly on purpose (author 2026-10-28: "That would be hard to
## guess even if we left it in."). Pointer and touch only, like the gear: no focus. ---

const HEART_CODE := ["r", "g", "b", "b", "g", "r"]
const HEART_GAP_MS := 5000
const HEART_COLORS := {"r": Color("#f4a6ad"), "g": Color("#a8dcb2"), "b": Color("#a9c6f0")}
const HEART_OUTLINE := Color("#593859")  # the minimap's plum
## A heart's touch target (px of the 640x360 view). An iPad in landscape draws the view at 1.6x
## or more (1024 pt wide and up), so 28 px is at least 44 pt.
const HEART_TOUCH := 28.0
## The row's own height: the touch targets reach into the gap above and the panel's margin below.
const HEART_ROW := 14.0
const HEART_HALF_WIDTH := 6.0  # the drawn heart is 12 px wide

## The clock the taps are timed on (ms); tests put their own here so they never wait.
var now_msec: Callable = Callable(Time, "get_ticks_msec")
var _hearts: Control
var _code_at := 0  # hearts of HEART_CODE matched so far
var _code_last := 0  # now_msec at the last tap
var _pulses := {}  # heart -> its running pulse


func _add_hearts(box: VBoxContainer) -> void:
	_hearts = Control.new()
	_hearts.name = "Hearts"
	_hearts.custom_minimum_size = Vector2(HEART_TOUCH * 3.0, HEART_ROW)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for which: String in ["r", "g", "b"]:
		var h := Button.new()
		h.name = "Heart" + which.to_upper()
		h.flat = true
		h.focus_mode = Control.FOCUS_NONE
		h.size = Vector2(HEART_TOUCH, HEART_TOUCH)
		h.pivot_offset = h.size / 2.0
		h.pressed.connect(tap_heart.bind(which))
		h.draw.connect(_draw_heart.bind(h, HEART_COLORS[which]))
		_hearts.add_child(h)
	_hearts.resized.connect(_place_hearts)
	box.add_child(_hearts)


func heart(which: String) -> Button:
	return _hearts.get_node("Heart" + which.to_upper()) as Button


## One tap on a heart ("r", "g" or "b"): it pulses, and the code moves on, starts over, or, at its
## last heart, turns playtest mode on or off.
func tap_heart(which: String) -> void:
	var now: int = now_msec.call()
	if _code_at > 0 and now - _code_last > HEART_GAP_MS:
		_code_at = 0
	_code_last = now
	if which == HEART_CODE[_code_at]:
		_code_at += 1
	else:
		_code_at = 1 if which == HEART_CODE[0] else 0
	_pulse(heart(which))
	if _code_at == HEART_CODE.size():
		_code_at = 0
		set_playtest(not Playtest.enabled())


## Centres the hearts in their row, each touch target HEART_TOUCH square.
func _place_hearts() -> void:
	var x := (_hearts.size.x - HEART_TOUCH * 3.0) / 2.0
	for h: Control in _hearts.get_children():
		h.position = Vector2(x, (_hearts.size.y - HEART_TOUCH) / 2.0)
		x += HEART_TOUCH


## The minimap's heart curve, centred on the button, pastel with a plum line.
func _draw_heart(h: Control, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * float(i) / 24.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(h.size / 2.0 + Vector2(x, y - 4.6) * (HEART_HALF_WIDTH / 16.0))
	h.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	h.draw_polyline(pts, HEART_OUTLINE, 1.0, true)


## A small pulse on a tap: up a third and back, on a tween that runs while the game is paused.
func _pulse(h: Control) -> void:
	var old: Tween = _pulses.get(h)
	if old and old.is_valid():
		old.kill()
	h.scale = Vector2.ONE
	var tw := h.create_tween()
	tw.tween_property(h, "scale", Vector2.ONE * 1.35, 0.08)
	tw.tween_property(h, "scale", Vector2.ONE, 0.14)
	_pulses[h] = tw


## Pulls the current levels into the sliders (opening the screen, or after a load), and resets the
## save status line to the persistence warning (empty when the browser keeps saves).
func refresh() -> void:
	for which: String in _sliders:
		var s: HSlider = _sliders[which]
		s.set_value_no_signal(AudioSettings.level(which))
	if _save_status:
		_save_status.text = WorldState.persistence_warning_text()
	if _fullscreen:
		_fullscreen.set_pressed_no_signal(MainMenu.is_fullscreen())
	if _controls and _controls.visible:
		_controls.close()
	if _text_slider:
		_text_slider.set_value_no_signal(TextSize.step)
		_text_name.text = TextSize.step_name()
	# Playtest mode (its autoload loads after this screen is built, so this runs on each opening).
	if _playtest_row:
		_playtest_row.visible = Playtest.enabled()
	_code_at = 0
	# In play this is the pause menu (GC-03): Paused, Resume, Quit to Menu.
	var playing := AudioSettings.in_play()
	$Center/Panel/VBox/Title.text = "Paused" if playing else "Settings"
	%DoneButton.text = "Resume" if playing else "Done"
	$Center/Panel/VBox/QuitToMenuButton.visible = playing


func slider(which: String) -> HSlider:
	return _sliders.get(which)


func _close() -> void:
	AudioSettings.close()


func _on_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		_close()
