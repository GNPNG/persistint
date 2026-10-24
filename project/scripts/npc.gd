extends Area2D
## NPC — clickable villager with state-reactive barks (data/barks.json) and an
## optional Dialogue Manager tree for story conversations.
## Bark selection: first entry whose "if" flags all match WorldState and whose
## optional "when" (cycle day, festival, phase...; see GameClock.matches_when) holds wins.

const BARKS_PATH := "res://data/barks.json"
## Directional rig made from the canon front/side/back cuts by tools/gen_npc_rigs.py:
## 8 columns x 3 rows of frames at the cuts' full resolution (frame = sheet size / (8, 3)),
## rows down/left/up, columns 0-3 idle and 4-7 walk, feet at 50/52 of the frame height.
## Shown RIG_HEIGHT world px tall, downsampled smoothly (mipmaps).
const RIG_PATH := "res://assets/characters/%s_rig.png"
const RIG_HEIGHT := 52.0
const RIG_FEET := 50.0 / 52.0
## Within this distance the NPC turns to look at the player.
const LOOK_DISTANCE := 96.0

static var _barks: Dictionary = {}
static var _rigs: Dictionary = {}  # sheet path -> SpriteFrames

var rig: AnimatedSprite2D

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
	if sprite_texture != "" and ResourceLoader.exists(RIG_PATH % sprite_texture):
		_build_rig()
	elif sprite_texture != "":
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


func _build_rig() -> void:
	## The rig replaces the single still sprite; its feet land where the still's feet were.
	$Sprite2D.hide()
	rig = AnimatedSprite2D.new()
	rig.name = "Rig"
	rig.sprite_frames = rig_frames(RIG_PATH % sprite_texture)
	rig.centered = false
	var frame := rig_frame_size(load(RIG_PATH % sprite_texture))
	var k := RIG_HEIGHT / frame.y
	rig.scale = Vector2(k, k)
	rig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rig.position = Vector2(-frame.x * k / 2.0, 24 - RIG_HEIGHT * RIG_FEET)
	add_child(rig)
	move_child(rig, $Sprite2D.get_index() + 1)
	rig.play("idle_down")


## Frame size of a rig sheet: 8 columns, 3 rows.
static func rig_frame_size(sheet: Texture2D) -> Vector2:
	return Vector2(sheet.get_width() / 8.0, sheet.get_height() / 3.0)


## SpriteFrames for a rig sheet (idle_/walk_ + down/left/up), built once per sheet.
static func rig_frames(path: String) -> SpriteFrames:
	if _rigs.has(path):
		return _rigs[path]
	var sheet: Texture2D = load(path)
	var fr := rig_frame_size(sheet)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row: int in 3:
		var dir: String = ["down", "left", "up"][row]
		for state: String in ["idle", "walk"]:
			var anim := "%s_%s" % [state, dir]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, 3.0 if state == "idle" else 8.0)
			for i in 4:
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(((0 if state == "idle" else 4) + i) * fr.x, row * fr.y, fr.x, fr.y)
				sf.add_frame(anim, at)
	_rigs[path] = sf
	return sf


func _process(_delta: float) -> void:
	if rig == null or not visible:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var dir := "down"
	var flip := false
	if player and player.global_position.distance_to(global_position) <= LOOK_DISTANCE:
		var d := player.global_position - global_position
		if absf(d.x) > absf(d.y) * 1.2:
			dir = "left"
			flip = d.x > 0.0
		elif d.y < 0.0:
			dir = "up"
	rig.flip_h = flip
	if rig.animation != "idle_" + dir:
		rig.play("idle_" + dir)


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
