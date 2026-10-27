extends PanelContainer
## The Controls panel over the settings screen (GC-04): one row per remappable action, its keys on
## a button; press the button, then the new key (Escape keeps the old one). Reset puts the
## project's keys back; Back returns to the settings. Keys are kept by Controls.

signal closed

var _buttons := {}  # action -> Button
var _listening := ""


func _ready() -> void:
	name = "Controls"
	process_mode = Node.PROCESS_MODE_ALWAYS  # it works while the game is paused
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for pair: Array in Controls.REMAPPABLE:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = pair[1]
		label.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)
		var b := Button.new()
		b.name = pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(listen.bind(pair[0]))
		row.add_child(b)
		rows.add_child(row)
		_buttons[pair[0]] = b
		if _buttons.size() == 1:
			b.add_to_group(PadFocus.DEFAULT)  # a pad starts on the first action (QA-13)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair: Array in [["ResetButton", "Reset", _on_reset], ["BackButton", "Back", close]]:
		var b := Button.new()
		b.name = pair[0]
		b.text = pair[1]
		b.pressed.connect(pair[2])
		foot.add_child(b)
	box.add_child(foot)
	Controls.changed.connect(func(_a: String) -> void: refresh())
	refresh()


func refresh() -> void:
	for action: String in _buttons:
		_buttons[action].text = "Press a key…" if action == _listening else Controls.key_text(action)


## Waits for the next key for `action`.
func listen(action: String) -> void:
	_listening = action
	refresh()


func listening() -> String:
	return _listening


func close() -> void:
	_listening = ""
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if _listening == "" or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var action := _listening
		_listening = ""
		if not event.is_action("ui_cancel"):
			Controls.rebind(action, event)
		refresh()


func _on_reset() -> void:
	_listening = ""
	Controls.reset()
	refresh()
