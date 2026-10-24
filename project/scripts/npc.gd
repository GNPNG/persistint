extends Area2D
## NPC — clickable villager with state-reactive barks (data/barks.json) and an
## optional Dialogue Manager tree for story conversations. The node's origin is the NPC's
## feet, so a y-sorted map orders it with the props by where it stands.
## Bark selection: first entry whose "if" flags all match WorldState and whose
## optional "when" (cycle day, festival, phase...; see GameClock.matches_when) holds wins.

const BARKS_PATH := "res://data/barks.json"
## Directional rig made from the canon front/side/back cuts by tools/gen_npc_rigs.py:
## 8 columns x 3 rows of frames at the cuts' full resolution (frame = sheet size / (8, 3)),
## rows down/left/up, columns 0-3 idle and 4-7 walk, feet at 50/52 of the frame height.
## Shown RIG_HEIGHT world px tall (SpriteFit), downsampled smoothly (mipmaps).
const RIG_PATH := "res://assets/characters/%s_rig.png"
const RIG_HEIGHT := 52.0
const RIG_FEET := 50.0 / 52.0
## A still sprite (an NPC without a rig) is shown this tall, feet on the origin.
const STILL_HEIGHT := 48.0
## Within this distance the NPC turns to look at the player.
const LOOK_DISTANCE := 96.0
## Moving faster than this (world px per second), the NPC plays its walk.
const WALK_SPEED_MIN := 4.0

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

@onready var bubble: Label = $BarkBubble  # scenes/ui/bark_bubble.tscn

## The rigged sheet when the art has one; see _load_art.
var rig: AnimatedSprite2D
var _last_position := Vector2.ZERO


func _ready() -> void:
	if display_name == "":
		display_name = Cast.full(npc_id)
	if _barks.is_empty():
		var f := FileAccess.open(BARKS_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_barks = parsed
	_last_position = global_position
	if sprite_texture != "":
		_load_art()
	var art: Node2D = rig if rig else $Sprite2D
	if SpriteFit.frame_size(art).y > 0.0:
		bubble.bottom = -SpriteFit.frame_size(art).y * art.scale.y - 2.0  # over the head
	bubble.hide()
	input_event.connect(_on_input_event)
	$Proximity.body_entered.connect(_on_proximity_entered)
	$Proximity.body_exited.connect(_on_proximity_exited)
	_apply_presence()
	if show_if_flag != "" or hide_if_flag != "":
		WorldState.flag_changed.connect(_on_flag_changed)


## Art lookup, first match wins: a caste rig sheet (assets/characters/<name>_rig.png), then in
## canon, florida and placeholder a SpriteFrames <name>.tres (a rigged sheet) before a still
## <name>.png. Canon art (cut from the canon sheets) wins over area art and placeholders.
func _load_art() -> void:
	if ResourceLoader.exists(RIG_PATH % sprite_texture):
		_build_rig()
		return
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
			# The sheet states its resolution (display_scale, tools/florida_draw.py).
			SpriteFit.fit_sheet(rig)
			return
		var path := "res://assets/%s/%s.png" % [dir, sprite_texture]
		if ResourceLoader.exists(path):
			$Sprite2D.texture = load(path)
			SpriteFit.fit($Sprite2D, STILL_HEIGHT)
			return


func _build_rig() -> void:
	## The rig replaces the single still sprite; its feet stand on the origin.
	$Sprite2D.hide()
	rig = AnimatedSprite2D.new()
	rig.name = "Rig"
	rig.sprite_frames = RigSheet.frames(RIG_PATH % sprite_texture)
	add_child(rig)
	move_child(rig, $Sprite2D.get_index() + 1)
	rig.play("idle_down")
	SpriteFit.fit(rig, RIG_HEIGHT, RIG_FEET)


## A rigged NPC walks when it moves (whatever moves it: its node's position changing between
## frames) facing the way it goes, and otherwise stands and turns to look at the player near it.
func _process(delta: float) -> void:
	if rig == null or not visible:
		return
	var moved := global_position - _last_position
	_last_position = global_position
	var d := Vector2.ZERO
	var state := "idle"
	if delta > 0.0 and moved.length() / delta > WALK_SPEED_MIN:
		d = moved
		state = "walk"
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and player.global_position.distance_to(global_position) <= LOOK_DISTANCE:
			d = player.global_position - global_position
	var side := absf(d.x) > absf(d.y) * 1.2
	var anim: String
	if rig.sprite_frames.has_animation("idle_down"):
		var f := RigSheet.facing(d, state)
		anim = f[0]
		rig.flip_h = f[1]
	else:
		anim = "idle_side" if side else ("idle_back" if d.y < 0.0 else "idle_front")
		rig.flip_h = side and d.x < 0.0
	if rig.sprite_frames.has_animation(anim) and rig.animation != anim:
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
		_show_bubble(current_bark())


func _on_proximity_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		bubble.hide()


func _show_bubble(text: String) -> void:
	bubble.say(text)
