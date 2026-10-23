extends Area2D
## NPC — clickable villager with state-reactive barks (data/barks.json) and an
## optional Dialogue Manager tree for story conversations.
## Bark selection: first entry whose "if" flags all match WorldState and whose
## optional "when" (cycle day, festival, phase...; see GameClock.matches_when) holds wins.

const BARKS_PATH := "res://data/barks.json"

static var _barks: Dictionary = {}

@export var npc_id := ""
@export var display_name := ""
@export var caste := "initiate"  # mother | priestess | initiate | drone | barren
@export var sprite_texture := ""  # assets/placeholder texture name
@export var dialogue_path := ""  # e.g. res://dialogue/offering.dialogue
@export var dialogue_title := "start"
@export var voice_pitch := 1.0
## Presence by flag: shown only once show_if_flag is set; gone once hide_if_flag is set
## (e.g. the Daughter leaves the beach for the stable after inviting you to the horses).
@export var show_if_flag := ""
@export var hide_if_flag := ""

@onready var bubble: Label = $BarkBubble


func _ready() -> void:
	if display_name == "":
		display_name = Cast.full(npc_id)
	if _barks.is_empty():
		var f := FileAccess.open(BARKS_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_barks = parsed
	if sprite_texture != "":
		# Canon art (cut from the NotebookLM sheets) wins over the placeholders.
		for dir in ["canon", "placeholder"]:
			var path := "res://assets/%s/%s.png" % [dir, sprite_texture]
			if ResourceLoader.exists(path):
				$Sprite2D.texture = load(path)
				break
	bubble.hide()
	input_event.connect(_on_input_event)
	$Proximity.body_entered.connect(_on_proximity_entered)
	$Proximity.body_exited.connect(_on_proximity_exited)
	_apply_presence()
	if show_if_flag != "" or hide_if_flag != "":
		WorldState.flag_changed.connect(_on_flag_changed)


## True when the flags say this NPC is here right now.
func is_present() -> bool:
	if show_if_flag != "" and not WorldState.has_flag(show_if_flag):
		return false
	return hide_if_flag == "" or not WorldState.has_flag(hide_if_flag)


func _on_flag_changed(key: String, _value: Variant) -> void:
	if key == show_if_flag or key == hide_if_flag:
		_apply_presence.call_deferred()


## Absent NPCs are hidden and can't be clicked or bark at the player walking past.
func _apply_presence() -> void:
	var here := is_present()
	visible = here
	input_pickable = here
	$CollisionShape2D.set_deferred("disabled", not here)
	$Proximity.set_deferred("monitoring", here)
	if not here:
		bubble.hide()


func current_bark() -> String:
	for entry: Dictionary in _barks.get(npc_id, []):
		if WorldState.matches(entry.get("if", {})) and GameClock.matches_when(entry.get("when", {})):
			return entry.get("text", "")
	return "..."


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


func interact() -> void:
	if dialogue_path != "" and ResourceLoader.exists(dialogue_path):
		DialogueManager.show_dialogue_balloon(load(dialogue_path), dialogue_title)
	else:
		_show_bubble(current_bark())


func _on_proximity_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_show_bubble(current_bark())


func _on_proximity_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		bubble.hide()


func _show_bubble(text: String) -> void:
	bubble.text = text
	bubble.show()
