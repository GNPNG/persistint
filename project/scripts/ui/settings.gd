extends Control
## The settings screen: a slider per audio level (Master, Music, Voices, Effects), applied as it
## moves and saved by AudioSettings; Done (or Escape, or the dimmed background) closes it. In play
## it is the pause menu (GC-03): the title reads Paused, Done reads Resume, and Quit to Menu shows.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"

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
	_add_text_row(rows)
	_add_save_row(rows)
	refresh()


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
	if OS.has_feature("web"):
		var js := "(function(){var s=%s;var b=new Blob([s],{type:'application/json'});var u=URL.createObjectURL(b);var a=document.createElement('a');a.href=u;a.download=%s;document.body.appendChild(a);a.click();a.remove();setTimeout(function(){URL.revokeObjectURL(u)},2000);return 'ok';})()" % [JSON.stringify(text), JSON.stringify(file_name)]
		var ok := str(JavaScriptBridge.eval(js, true)) == "ok"
		_save_status.text = ("Downloaded %s. Keep it somewhere safe; Import save brings it back." % file_name) if ok else "The download didn't start. Try again, or allow downloads for this page."
		return
	var path := "user://" + file_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_save_status.text = "Couldn't write %s." % ProjectSettings.globalize_path(path)
		return
	f.store_string(text)
	f.close()
	_save_status.text = "Saved a copy as %s." % ProjectSettings.globalize_path(path)


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


## Pulls the current levels into the sliders (opening the screen, or after a load), and resets the
## save status line to the persistence warning (empty when the browser keeps saves).
func refresh() -> void:
	for which: String in _sliders:
		var s: HSlider = _sliders[which]
		s.set_value_no_signal(AudioSettings.level(which))
	if _save_status:
		_save_status.text = WorldState.persistence_warning_text()
	if _text_slider:
		_text_slider.set_value_no_signal(TextSize.step)
		_text_name.text = TextSize.step_name()
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
