extends CharacterBody2D
## Player — click-to-walk via NavigationAgent2D, click-on-things to approach & interact;
## arrow keys (and WASD) walk directly and cancel a click-walk. Keys do nothing while a
## dialogue is open, so the arrows stay free for choosing responses.
## Paper-doll: layered rigs, one per PaperDoll slot in its stack order (Body, Shoes, Bottom, Top,
## Dress, Hair, Hat, Accessory: PaperDoll.LAYERS), driven by WorldState outfit flags. Each
## worn part is a directional sheet (assets/characters/player/<part>_rig.png, tools/gen_player_rig.py:
## idle and walk facing down, left and up, all parts on one frame grid); every layer plays the same
## animation frame, chosen from her velocity, so click-walk and arrow keys both animate her.
## The node's origin is the player's feet (y-sorted maps order her with the props by it).
## Florida pony stable: while riding (WorldState fl_riding) a PonyDoll (Mount) is drawn under the
## doll and click-to-move is faster (Ponies.speed_multiplier); H or the button hops down.

const SPEED := 130.0
const INTERACT_DISTANCE := 34.0
## The doll is shown this tall (NPC height), its feet on the node's origin.
const DOLL_HEIGHT := 48.0
## Riding, the doll sits this far up, on the pony's back.
const RIDE_LIFT := 16.0
## A worn part's rig sheet; parts without one (the placeholder set) show their still picture.
const RIG_PATH := "res://assets/characters/player/%s_rig.png"
## Slower than this (world px per second) she stands.
const WALK_SPEED_MIN := 4.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var mount_doll: PonyDoll = $Mount

var _interact_target: Node2D = null
var _speed := SPEED
var _ride_ui: CanvasLayer
var _in_dialogue := false
var _facing := Vector2.DOWN
## Paper look (bd gsd, PaperBake): under the art stack, one paper ring per worn part (the
## union of the rings is the border of the whole doll) and one soft shadow, baked from the body.
## They are built once and take the body's frame with the layers; no shader, no extra work.
var _rings: Dictionary = {}  # art layer -> its ring AnimatedSprite2D
var _shadow: AnimatedSprite2D
## How near (world px) the interact key reaches.
const INTERACT_RANGE := 56.0
## The doll's nodes (_doll_nodes), listed once when the rings and shadow are built: the frame loop
## in _process walks this list instead of looking the layers up by name every frame (bd nmz).
var _doll: Array[AnimatedSprite2D] = []
## The animation and flip _process last worked out, and what it worked them out from; RigSheet.facing
## runs again only when her facing or her walking changes.
var _anim := &""
var _flip := false
var _anim_from := Vector2.INF
var _anim_moving := false


func _ready() -> void:
	add_to_group("player")
	var dm := get_node_or_null("/root/DialogueManager")
	if dm:
		dm.dialogue_started.connect(_on_dialogue_started)
		dm.dialogue_ended.connect(_on_dialogue_ended)
	get_tree().scene_changed.connect(_on_dialogue_ended.bind(null))
	WorldState.flag_changed.connect(_on_flag_changed)
	_build_paper()
	_doll = _doll_nodes()
	refresh_outfit()
	refresh_mount()


## The art layers, one per PaperDoll slot (the node named after it), in stack order.
func _layers() -> Array[AnimatedSprite2D]:
	var out: Array[AnimatedSprite2D] = []
	for slot: String in PaperDoll.LAYERS:
		out.append(get_node(slot.capitalize()) as AnimatedSprite2D)
	return out


## The ring and shadow nodes: the shadow first (under the pony too), the rings right under the art.
func _build_paper() -> void:
	_shadow = AnimatedSprite2D.new()
	_shadow.name = "PaperShadow"
	add_child(_shadow)
	move_child(_shadow, 0)
	PaperBake.style_shadow(_shadow)
	for layer in _layers():
		var ring := AnimatedSprite2D.new()
		ring.name = String(layer.name) + "Ring"
		add_child(ring)
		move_child(ring, $Body.get_index())
		_rings[layer] = ring


## Everything drawn for the doll: the art layers, their rings and the shadow.
func _doll_nodes() -> Array[AnimatedSprite2D]:
	var out: Array[AnimatedSprite2D] = _layers()
	for layer in _rings:
		out.append(_rings[layer])
	if _shadow:
		out.append(_shadow)
	return out


## Idle or walk, facing the way she moves (or last moved); every layer on the same frame.
func _process(_delta: float) -> void:
	var speed := velocity.length()
	var moving := speed > WALK_SPEED_MIN and not is_mounted()
	if speed > WALK_SPEED_MIN:
		_facing = velocity
	if _facing != _anim_from or moving != _anim_moving:
		var f := RigSheet.facing(_facing, "walk" if moving else "idle")
		_anim = StringName(f[0])
		_flip = f[1]
		_anim_from = _facing
		_anim_moving = moving
	# The body first (it is the first layer), then every other node takes the body's frame.
	var body: AnimatedSprite2D = $Body
	var synced := body.sprite_frames != null
	if synced:
		body.flip_h = _flip
		if body.animation != _anim:
			body.play(_anim)
	var frame := body.frame
	var progress := body.frame_progress
	for layer in _doll:
		if layer == body or layer.sprite_frames == null:
			continue
		layer.flip_h = _flip
		if layer.animation != _anim:
			layer.play(_anim)
		if synced:
			layer.set_frame_and_progress(frame, progress)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dismount") and is_mounted():
		Ponies.dismount()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("click"):
		_interact_target = null
		nav.target_position = get_global_mouse_position()
	elif event.is_action_pressed("interact") and not _in_dialogue:
		if interact_nearest() != null:
			get_viewport().set_input_as_handled()


## The interact key (E): the nearest thing within INTERACT_RANGE that has interact() (a person,
## the mirror, a door, a pickup, a Florida critter) is walked to and used, as a click on it would
## be, so the game plays from the keyboard alone (QA-07). What a click can't pick (input_pickable
## off: an NPC walking off the map, npc.gd leave_via) the key passes over too. Returns it, or null
## when nothing is near.
func interact_nearest() -> Node2D:
	var best: Node2D = null
	var best_d := INTERACT_RANGE
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for n in scene.find_children("*", "Area2D", true, false):
		if n == self or not n.has_method("interact") or not n.is_visible_in_tree() or not (n as Area2D).input_pickable:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best = n
			best_d = d
	if best:
		approach(best)
	return best


## Walk toward a node; call its interact() on arrival. (NPCs/mirrors call this on click.)
func approach(target: Node2D) -> void:
	_interact_target = target
	nav.target_position = target.global_position


func _key_direction() -> Vector2:
	if _in_dialogue:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _physics_process(_delta: float) -> void:
	var key_dir := _key_direction()
	if key_dir != Vector2.ZERO:
		_interact_target = null
		nav.target_position = global_position
		velocity = key_dir * current_speed()
		if is_mounted() and absf(key_dir.x) > 0.1:
			mount_doll.set_facing_left(key_dir.x < 0.0)
		move_and_slide()
		return
	if _interact_target and global_position.distance_to(_interact_target.global_position) <= INTERACT_DISTANCE:
		var t := _interact_target
		_interact_target = null
		nav.target_position = global_position
		velocity = Vector2.ZERO
		if t.has_method("interact"):
			t.interact()
		return
	if nav.is_navigation_finished():
		velocity = Vector2.ZERO
		if is_mounted():
			mount_doll.set_moving(false)
		return
	var dir := global_position.direction_to(nav.get_next_path_position())
	velocity = dir * current_speed()
	if is_mounted():
		mount_doll.set_moving(true)
		if absf(dir.x) > 0.1:
			mount_doll.set_facing_left(dir.x < 0.0)
	move_and_slide()


func current_speed() -> float:
	return _speed


func is_mounted() -> bool:
	return mount_doll.visible


## Show (or put away) the pony under the doll from WorldState fl_riding; riding is faster.
func refresh_mount() -> void:
	var id := Ponies.riding()
	mount_doll.visible = id != ""
	_speed = SPEED * Ponies.speed_multiplier()
	if id != "":
		mount_doll.set_outfit(Ponies.parts(id))
	for layer in _doll_nodes():
		layer.position = Vector2(0, -RIDE_LIFT) if id != "" else Vector2.ZERO
	if _shadow:
		_shadow.position += PaperBake.SHADOW_OFFSET
	_show_ride_ui(id != "")


func _show_ride_ui(show_it: bool) -> void:
	if not show_it:
		if _ride_ui and is_instance_valid(_ride_ui):
			_ride_ui.queue_free()
		_ride_ui = null
		return
	if _ride_ui and is_instance_valid(_ride_ui):
		return
	_ride_ui = CanvasLayer.new()
	_ride_ui.name = "RideUI"
	add_child(_ride_ui)
	var b := Button.new()
	b.name = "HopDown"
	b.text = "Hop down (H)"
	b.add_theme_font_size_override("font_size", 10)
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	b.position -= Vector2(90, 30)
	b.pressed.connect(Ponies.dismount)
	_ride_ui.add_child(b)


## Keys stop moving the player while a conversation is up. The flag clears when the dialogue ends,
## and also when its balloon leaves the tree or the scene changes, so a balloon that goes away
## without ending its dialogue (a scene change mid-conversation) cannot lock the keys (bd d15.84).
func _on_dialogue_started(_resource: Resource) -> void:
	_in_dialogue = true
	await get_tree().process_frame  # the balloon is added after the dialogue starts
	if not is_inside_tree():
		return
	for b in get_tree().get_nodes_in_group("dialogue_balloon"):
		if not b.tree_exited.is_connected(_on_balloon_gone):
			b.tree_exited.connect(_on_balloon_gone, CONNECT_ONE_SHOT)


func _on_dialogue_ended(_resource: Variant) -> void:
	_in_dialogue = false


func _on_balloon_gone() -> void:
	if is_inside_tree() and get_tree().get_nodes_in_group("dialogue_balloon").filter(
			func(b: Node) -> bool: return b.is_inside_tree()).is_empty():
		_in_dialogue = false


func in_dialogue() -> bool:
	return _in_dialogue


func _on_flag_changed(key: String, _value: Variant) -> void:
	if key.begins_with("outfit_"):
		refresh_outfit()
	elif key == "fl_riding" or (key == "fl_ponies" and is_mounted()):
		refresh_mount()


func refresh_outfit() -> void:
	var outfit := {}
	for slot: String in PaperDoll.LAYERS:
		outfit[get_node(slot.capitalize())] = WorldState.get_flag("outfit_%s" % slot, PaperDoll.DEFAULT_OUTFIT[slot])
	# Same art set for every layer (canon when it has all worn parts, as the wardrobe does).
	var pattern := PaperDoll.art_dir_for(outfit.values())
	for layer: AnimatedSprite2D in outfit:
		var item: String = outfit[layer]
		var path := PaperDoll.part_path(pattern, item)
		var ring: AnimatedSprite2D = _rings.get(layer)
		if ring:
			ring.sprite_frames = null
		if layer == $Body and _shadow:
			_shadow.sprite_frames = null
		if item == "none" or not ResourceLoader.exists(path):
			layer.sprite_frames = null
			continue
		var rig := RIG_PATH % item
		layer.sprite_frames = RigSheet.frames(rig) if ResourceLoader.exists(rig) else RigSheet.still(path)
		layer.play(RigSheet.facing(_facing, "idle")[0])
		SpriteFit.fit(layer, DOLL_HEIGHT)
		var lift := Vector2(0, -RIDE_LIFT) if is_mounted() else Vector2.ZERO
		layer.position = lift
		# The part's baked paper ring (and, for the body, the shadow), on the same frame grid.
		if not ResourceLoader.exists(rig):
			continue
		var bake := PaperBake.name_of(rig)
		var paper: Array = [[ring, PaperBake.RING, Vector2.ZERO]]
		if layer == $Body:
			paper.append([_shadow, PaperBake.SHADOW, PaperBake.SHADOW_OFFSET])
		for p: Array in paper:
			var node: AnimatedSprite2D = p[0]
			var sheet := PaperBake.sheet(bake, p[1])
			if node == null or sheet == "":
				continue
			node.sprite_frames = RigSheet.frames(sheet)
			node.play(layer.animation)
			SpriteFit.fit(node, PaperBake.padded_height(bake, DOLL_HEIGHT), PaperBake.padded_feet(bake, 1.0))
			node.position = lift + p[2]
