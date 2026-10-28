extends Control
## The name screen of New Game (bd 1ce), over the main menu like the credits: the player's full
## name and an optional nickname, and the line under them saying what the characters will call
## her (WorldState.call_name_of: the nickname, else the first name, else the default). Both
## fields stop at WorldState.NAME_MAX / NICKNAME_MAX characters; what is stored is cleaned
## (WorldState.clean_name). Start (or Enter in the nickname) emits `confirmed`; Enter in the full
## name goes on to the nickname. Back, Escape or a pad's B closes it and emits `cancelled`, and the
## save is left as it was. Keyboard: it opens with the typing in the full name; Tab and the arrows
## stay inside the panel. Touch: tapping a field brings up the on-screen keyboard. Pad (QA-13): a
## pad cannot type, so after a pad press it opens on Start; leaving both empty is fine.

signal confirmed(full_name: String, nickname: String)
signal cancelled

## True when the last press came from a pad.
var _pad := false


func _ready() -> void:
	%FullName.max_length = WorldState.NAME_MAX
	%Nickname.max_length = WorldState.NICKNAME_MAX
	%FullName.text_changed.connect(func(_t: String) -> void: _refresh())
	%Nickname.text_changed.connect(func(_t: String) -> void: _refresh())
	%FullName.text_submitted.connect(func(_t: String) -> void: _type_in(%Nickname))
	%Nickname.text_submitted.connect(func(_t: String) -> void: start())
	%StartButton.pressed.connect(start)
	%BackButton.pressed.connect(close)
	%StartButton.add_to_group(PadFocus.DEFAULT)  # where a pad starts (QA-13)
	_chain_focus([%FullName, %Nickname, %StartButton, %BackButton])
	_refresh()


## Up/down and Tab go round the panel's controls in order (left/right between the two buttons),
## so the focus never lands on the menu under the panel.
func _chain_focus(order: Array) -> void:
	for i in order.size():
		var c: Control = order[i]
		var next: Control = order[(i + 1) % order.size()]
		var prev: Control = order[(i - 1 + order.size()) % order.size()]
		c.focus_next = c.get_path_to(next)
		c.focus_previous = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(next)
		c.focus_neighbor_top = c.get_path_to(prev)
	%StartButton.focus_neighbor_right = %StartButton.get_path_to(%BackButton)
	%StartButton.focus_neighbor_left = %StartButton.get_path_to(%BackButton)
	%BackButton.focus_neighbor_right = %BackButton.get_path_to(%StartButton)
	%BackButton.focus_neighbor_left = %BackButton.get_path_to(%StartButton)


## Opens the screen empty: the typing in the full name, or the focus on Start after a pad press.
func open() -> void:
	set_names("", "")
	visible = true
	if _pad:
		%StartButton.grab_focus()
		return
	_type_in(%FullName)


## The focus and the typing in `field`: a LineEdit that only has the focus (from code or Tab) does
## not take letters until it is editing, and a phone shows its keyboard then.
func _type_in(field: LineEdit) -> void:
	field.grab_focus()
	if field.has_method("edit"):
		field.edit()


func close() -> void:
	if not visible:
		return
	visible = false
	cancelled.emit()


func is_open() -> bool:
	return visible


## Fills the fields (the shot walk and tests use it) and updates the line under them.
func set_names(full_name: String, nickname: String) -> void:
	%FullName.text = full_name
	%Nickname.text = nickname
	_refresh()


## The full name and nickname as they will be stored.
func entered() -> Dictionary:
	return {"full": WorldState.clean_name(%FullName.text, WorldState.NAME_MAX),
		"nickname": WorldState.clean_name(%Nickname.text, WorldState.NICKNAME_MAX)}


## What the characters will call the player with the names as typed.
func call_name() -> String:
	return WorldState.call_name_of(%FullName.text, %Nickname.text)


func start() -> void:
	if not visible:
		return
	var names := entered()
	visible = false
	confirmed.emit(names["full"], names["nickname"])


func _refresh() -> void:
	%Preview.text = "They'll call you %s." % call_name()


## Notes whether the last press was a pad's. Escape and a pad's B close the screen even while a
## field has the keyboard (a field would keep the first press), so this listens before the
## controls do.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) >= 0.5):
		_pad = true
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch:
		_pad = false
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
