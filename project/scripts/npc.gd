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
## Leaving a map (leave_via): the walk to the door in world px per second (a calm walk, about half
## the player's 130), and the fade, in seconds, when the map has no door to where it's going.
const LEAVE_SPEED := 70.0
const LEAVE_FADE := 0.6

static var _barks: Dictionary = {}

@export var npc_id := ""
@export var display_name := ""
@export var caste := "initiate"  # mother | priestess | initiate | drone | barren
@export var sprite_texture := ""  # art name: a rigged <name>.tres sheet or a <name>.png, see _load_art
## Art shown while sprite_texture has none in the tree yet (a cast sheet still to be drawn), looked
## up the same way: the NPC's own sheet replaces it as soon as that sheet is there.
@export var fallback_texture := ""
@export var dialogue_path := ""  # e.g. res://dialogue/offering.dialogue
@export var dialogue_title := "start"
@export var voice_pitch := 1.0
## Presence by flag: shown only once show_if_flag is set; gone once hide_if_flag is set
## (e.g. the Daughter leaves the beach for the stable after inviting you to the horses, and the
## Father for the garden when he's done talking; at the stable and in the garden the same flag is
## their show_if_flag).
@export var show_if_flag := ""
@export var hide_if_flag := ""
## Where the NPC goes when hide_if_flag is set while it's here (a res:// map: the stable, the
## garden): it walks to this map's door to there and is gone at it (leave_via), not on the spot.
@export var leave_to := ""
## Off for the second of a pair who share one npc_id and its barks (the beach psychologists): walking
## past, only the first one barks; talking to either opens their conversation.
@export var walk_by_bark := true

@onready var bubble: Label = $BarkBubble  # scenes/ui/bark_bubble.tscn

## The rigged sheet when the art has one; see _load_art.
var rig: AnimatedSprite2D
## The rig's baked paper shadow (PaperBake), when it has one.
var _shadow: AnimatedSprite2D
var _baked := false
var _last_position := Vector2.ZERO
## Set while the NPC walks off the map or fades out (leave_via).
var _leaving := false


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
	if sprite_texture != "" and not _load_art(sprite_texture) and fallback_texture != "":
		_load_art(fallback_texture)
	var art: Node2D = rig if rig else $Sprite2D
	if _baked:
		bubble.bottom = -RIG_HEIGHT - 2.0  # over the head (the baked frame is padded)
	elif SpriteFit.frame_size(art).y > 0.0:
		bubble.bottom = -SpriteFit.frame_size(art).y * art.scale.y - 2.0  # over the head
	if rig and not _baked:  # a Florida sheet: its paper look, the bubble over the unpadded art
		PaperBake.dress_frames(rig)  # (tools/bake_paper.sh florida_cast)
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
## False when `art` has none of them.
func _load_art(art: String) -> bool:
	if ResourceLoader.exists(RIG_PATH % art):
		_build_rig(art)
		return true
	for dir in ["canon", "florida", "placeholder"]:
		var frames_path := "res://assets/%s/%s.tres" % [dir, art]
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
			return true
		var path := "res://assets/%s/%s.png" % [dir, art]
		if ResourceLoader.exists(path):
			$Sprite2D.texture = load(path)
			SpriteFit.fit($Sprite2D, STILL_HEIGHT)
			return true
	return false


func _build_rig(art: String) -> void:
	## The rig replaces the single still sprite; its feet stand on the origin. With a paper bake
	## (PaperBake, assets/paper/) it is the bordered sheet, drawn over its baked soft shadow.
	$Sprite2D.hide()
	rig = AnimatedSprite2D.new()
	rig.name = "Rig"
	var src := RIG_PATH % art
	var bake := PaperBake.name_of(src)
	var edge := PaperBake.sheet(bake, PaperBake.EDGE)
	_baked = edge != ""
	rig.sprite_frames = RigSheet.frames(edge if _baked else src)
	add_child(rig)
	move_child(rig, $Sprite2D.get_index() + 1)
	rig.play("idle_down")
	if not _baked:
		SpriteFit.fit(rig, RIG_HEIGHT, RIG_FEET)
		return
	var h := PaperBake.padded_height(bake, RIG_HEIGHT)
	var feet := PaperBake.padded_feet(bake, RIG_FEET)
	SpriteFit.fit(rig, h, feet)
	var shadow_path := PaperBake.sheet(bake, PaperBake.SHADOW)
	if shadow_path == "":
		return
	_shadow = AnimatedSprite2D.new()
	_shadow.name = "PaperShadow"
	_shadow.sprite_frames = RigSheet.frames(shadow_path)
	_shadow.animation = "idle_down"
	add_child(_shadow)
	move_child(_shadow, rig.get_index())
	SpriteFit.fit(_shadow, h, feet)
	PaperBake.style_shadow(_shadow)
	# The shadow never plays on its own: it takes the rig's frame when that changes.
	rig.frame_changed.connect(_sync_shadow)
	rig.animation_changed.connect(_sync_shadow)


func _sync_shadow() -> void:
	_shadow.flip_h = rig.flip_h
	if _shadow.animation != rig.animation:
		_shadow.animation = rig.animation
	_shadow.frame = rig.frame


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
		var facing := "side" if side else ("back" if d.y < 0.0 else "front")
		anim = "%s_%s" % [state, facing]
		if not rig.sprite_frames.has_animation(anim):  # a sheet with no walk frames walks on its idle ones
			anim = "idle_" + facing
		rig.flip_h = side and d.x < 0.0
	if rig.sprite_frames.has_animation(anim) and rig.animation != anim:
		rig.play(anim)


## True when the flags say this NPC is here right now.
func is_present() -> bool:
	if show_if_flag != "" and not WorldState.has_flag(show_if_flag):
		return false
	return hide_if_flag == "" or not WorldState.has_flag(hide_if_flag)


## hide_if_flag set while the NPC is here: it leaves on foot (leave_via), never on the spot. Any
## other change of its flags shows or hides it (a map opened with the flag set has it gone already).
func _on_flag_changed(key: String, _value: Variant) -> void:
	if _leaving:
		return
	if key == hide_if_flag and WorldState.has_flag(key) and is_visible_in_tree():
		leave_via(leave_to)
	elif key == show_if_flag or key == hide_if_flag:
		_apply_presence.call_deferred()


## Absent NPCs are hidden and can't be clicked or bark at the player walking past.
func _apply_presence() -> void:
	_set_here(is_present())


func _set_here(here: bool) -> void:
	visible = here
	input_pickable = here
	$CollisionShape2D.set_deferred("disabled", not here)
	$Proximity.set_deferred("monitoring", here)
	if not here:
		bubble.hide()


## Leaves the map on foot: walks to `where` (a door, or the res:// map a door here leads to;
## leave_to when null) over the walkable area at LEAVE_SPEED, facing the way it goes (_process),
## and is gone on reaching it. With no such door it fades out over LEAVE_FADE instead. It sets
## hide_if_flag first (WorldState saves it), so a map left mid-walk and come back to has it gone.
## On the way it can't be clicked, used (the E key) or barked at, and it blocks nothing: an NPC is
## an Area2D, which neither stops the player nor sets off a door (a door goes for the player's
## body). Returns the door it walks to; null when it fades (or is already leaving).
func leave_via(where: Variant = null) -> Node2D:
	if _leaving:
		return null
	if typeof(where) == TYPE_NIL:
		where = leave_to
	_leaving = true
	input_pickable = false
	$CollisionShape2D.set_deferred("disabled", true)
	$Proximity.set_deferred("monitoring", false)
	bubble.hide()
	if hide_if_flag != "" and not WorldState.has_flag(hide_if_flag):
		WorldState.set_flag(hide_if_flag, true)
	var door: Node2D = where as Node2D if where is Node2D else exit_door(str(where))
	var tw := create_tween()
	if door == null:
		tw.tween_property(self, "modulate:a", 0.0, LEAVE_FADE)
	else:
		var from := global_position
		for point: Vector2 in leave_path(door.global_position):
			tw.tween_property(self, "global_position", point, from.distance_to(point) / LEAVE_SPEED)
			from = point
	tw.tween_callback(_gone)
	return door


## True while the NPC walks off the map or fades out (leave_via).
func is_leaving() -> bool:
	return _leaving


## The end of leave_via: at the door (or faded out) the NPC is gone.
func _gone() -> void:
	_set_here(false)
	modulate.a = 1.0
	_leaving = false


## The door on this NPC's map (in the "doors" group, under the same map node) whose target_scene is
## `scene`, the nearest if there are several; null when there is none.
func exit_door(scene: String) -> Node2D:
	if scene == "" or not is_inside_tree():
		return null
	var map: Node = self
	while map.get_parent() != null and map.get_parent() != get_tree().root:
		map = map.get_parent()
	var best: Node2D = null
	for n: Node in get_tree().get_nodes_in_group("doors"):
		var door := n as Node2D
		if door == null or not map.is_ancestor_of(door) or str(door.get("target_scene")) != scene:
			continue
		if best == null or global_position.distance_to(door.global_position) < global_position.distance_to(best.global_position):
			best = door
	return best


## The way from here to `to` over the map's walkable area (its NavigationRegion2D, the one the
## player's clicks walk), as the points to walk through; straight there when the map has none or
## its navigation isn't ready yet.
func leave_path(to: Vector2) -> PackedVector2Array:
	var nav_map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(nav_map) > 0:
		var path := NavigationServer2D.map_get_path(nav_map, global_position, to, true)
		if path.size() >= 2:
			path[path.size() - 1] = to
			return path
	return PackedVector2Array([to])


func current_bark() -> String:
	for entry: Dictionary in _barks.get(npc_id, []):
		if WorldState.matches(entry.get("if", {})) and GameClock.matches_when(entry.get("when", {})):
			return entry.get("text", "")
	return "..."


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("click"):
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


func interact() -> void:
	if _leaving:
		return  # on the way out (leave_via)
	if dialogue_path != "" and ResourceLoader.exists(dialogue_path):
		bubble.hide()  # the conversation takes over from the walk-by bark
		DialogueManager.show_dialogue_balloon(load(dialogue_path), dialogue_title)
	else:
		_show_bubble(current_bark())


## Walking up barks, except while a conversation is up (its balloon says the lines then).
func _on_proximity_entered(body: Node2D) -> void:
	if walk_by_bark and body.is_in_group("player") and get_tree().get_first_node_in_group("dialogue_balloon") == null:
		_show_bubble(current_bark())


func _on_proximity_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		bubble.hide()


func _show_bubble(text: String) -> void:
	if bubble.visible and bubble.text == text:
		return
	bubble.say(text)
	Voice.speak(text, voice_pitch, display_name)
