extends Node
## PadFocus — menus work with a gamepad alone (QA-13). When a pad button or stick moves and no
## visible control has the keyboard focus, the topmost visible focusable control gets it: the
## settings or pause menu over the game, the Controls panel over the settings, the dialogue's
## answers, the credits, the wardrobe, the main menu's buttons. From there the d-pad or stick moves
## between controls (ui_up/down/left/right) and A presses (ui_accept), as Godot does for focus.
## In play with no menu up there is nothing focusable, so the pad walks the player.

const DEFAULT := "pad_default"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu is a menu too


func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner and owner.is_visible_in_tree():
		return
	var target := topmost()
	if target:
		target.grab_focus()
		get_viewport().set_input_as_handled()  # this press only lands the focus


## The focusable control a pad should start from: on the highest canvas layer, inside the panel
## drawn on top of that layer (its last top-level child with something focusable, e.g. the
## credits over the main menu), the first control in reading order; null when nothing is
## focusable (plain play).
func topmost() -> Control:
	var best: Control = null
	var best_key := [-1000000, -1]
	# A menu can name where a pad starts (group pad_default); otherwise any focusable control.
	var pool: Array = get_tree().get_nodes_in_group(DEFAULT).filter(func(n: Node) -> bool:
		return n is Control and n.is_visible_in_tree())
	if pool.is_empty():
		pool = get_tree().root.find_children("*", "Control", true, false)
	for c in pool:
		var ctl := c as Control
		if ctl.focus_mode != Control.FOCUS_ALL or not ctl.is_visible_in_tree():
			continue
		if ctl is BaseButton and ctl.disabled:
			continue
		var key := [_layer_of(ctl), _panel_index(ctl)]
		if best == null or key[0] > best_key[0] or (key[0] == best_key[0] and key[1] > best_key[1]):
			best = ctl  # the first one found in a new best panel is its first in tree order
			best_key = key
	return best


func _layer_of(n: Node) -> int:
	var p := n.get_parent()
	while p:
		if p is CanvasLayer:
			return p.layer
		p = p.get_parent()
	return 0


## Index of n's top-level panel: its ancestor right under the nearest CanvasLayer, the current
## scene or the root.
func _panel_index(n: Node) -> int:
	var scene := get_tree().current_scene
	var a := n
	while a.get_parent() and not (a.get_parent() is CanvasLayer or a.get_parent() == scene or a.get_parent() == get_tree().root):
		a = a.get_parent()
	return a.get_index()
