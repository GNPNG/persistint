extends Control
## The settings screen: a slider per audio level (Master, Music, Voices, Effects), applied as it
## moves and saved by AudioSettings; Done (or Escape, or the dimmed background) closes it.

var _sliders: Dictionary = {}


func _ready() -> void:
	$Dim.gui_input.connect(_on_dim_input)
	%DoneButton.pressed.connect(_close)
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
	refresh()


## Pulls the current levels into the sliders (opening the screen, or after a load).
func refresh() -> void:
	for which: String in _sliders:
		var s: HSlider = _sliders[which]
		s.set_value_no_signal(AudioSettings.level(which))


func slider(which: String) -> HSlider:
	return _sliders.get(which)


func _close() -> void:
	AudioSettings.close()


func _on_dim_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		accept_event()
		_close()
