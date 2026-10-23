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
@export var sprite_texture := ""  # art name: a rigged <name>.tres sheet or a <name>.png, see _load_art
@export var dialogue_path := ""  # e.g. res://dialogue/offering.dialogue
@export var dialogue_title := "start"
@export var voice_pitch := 1.0
## Presence by flag: shown only once show_if_flag is set; gone once hide_if_flag is set
## (e.g. the Daughter leaves the beach for the stable after inviting you to the horses).
@export var show_if_flag := ""
@export var hide_if_flag := ""

@onready var bubble: Label = $BarkBubble

## The rigged sheet when the art has one (idle_front / idle_side / idle_back, side faces right).
var rig: AnimatedSprite2D
var _player_near: Node2D


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
		_load_art()
	bubble.z_index = 20
	bubble.hide()
	input_event.connect(_on_input_event)
	$Proximity.body_entered.connect(_on_proximity_entered)
	$Proximity.body_exited.connect(_on_proximity_exited)
	_apply_presence()
	if show_if_flag != "" or hide_if_flag != "":
		WorldState.flag_changed.connect(_on_flag_changed)


## Canon art (cut from the canon sheets) wins over area art, which wins over the placeholders.
## In each folder a SpriteFrames <name>.tres (a rigged sheet) is used before a still <name>.png.
func _load_art() -> void:
	for dir in ["canon", "florida", "placeholder"]:
		var frames_path := "res://assets/%s/%s.tres" % [dir, sprite_texture]
		if ResourceLoader.exists(frames_path):
			rig = AnimatedSprite2D.new()
			rig.name = "Rig"
			rig.sprite_frames = load(frames_path)
			add_child(rig)
			move_child(rig, $Sprite2D.get_index())
			$Sprite2D.hide()
			rig.play("idle_front")
			rig.frame = randi() % rig.sprite_frames.get_frame_count("idle_front")
			return
		var path := "res://assets/%s/%s.png" % [dir, sprite_texture]
		if ResourceLoader.exists(path):
			$Sprite2D.texture = load(path)
			return


## A rigged NPC turns to look at the player standing near it.
func _process(_delta: float) -> void:
	if rig == null or _player_near == null:
		return
	var d := _player_near.global_position - global_position
	var anim := "idle_side"
	if absf(d.y) > absf(d.x) * 1.2:
		anim = "idle_front" if d.y > 0 else "idle_back"
	rig.flip_h = anim == "idle_side" and d.x < 0
	if rig.animation != anim:
		rig.play(anim)


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
		_player_near = body
		_show_bubble(current_bark())


func _on_proximity_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = null
		if rig:
			rig.flip_h = false
			rig.play("idle_front")
		bubble.hide()


func _show_bubble(text: String) -> void:
	bubble.text = text
	bubble.show()
