extends CharacterBody2D
## Player — click-to-walk via NavigationAgent2D, click-on-things to approach & interact;
## arrow keys (and WASD) walk directly and cancel a click-walk. Keys do nothing while a
## dialogue is open, so the arrows stay free for choosing responses.
## Paper-doll: layered sprites (Body/Hair/Dress/Accessory) driven by WorldState outfit flags.
## Florida pony stable: while riding (WorldState fl_riding) a PonyDoll (Mount) is drawn under the
## doll and click-to-move is faster (Ponies.speed_multiplier); H or the button hops down.

const SPEED := 130.0
const INTERACT_DISTANCE := 34.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var mount_doll: PonyDoll = $Mount

var _interact_target: Node2D = null
var _speed := SPEED
var _ride_ui: CanvasLayer
var _in_dialogue := false

const MOVE_KEYS := {
	"move_left": [KEY_LEFT, KEY_A],
	"move_right": [KEY_RIGHT, KEY_D],
	"move_up": [KEY_UP, KEY_W],
	"move_down": [KEY_DOWN, KEY_S],
}


func _ready() -> void:
	add_to_group("player")
	_ensure_move_actions()
	var dm := get_node_or_null("/root/DialogueManager")
	if dm:
		dm.dialogue_started.connect(func(_r) -> void: _in_dialogue = true)
		dm.dialogue_ended.connect(func(_r) -> void: _in_dialogue = false)
	WorldState.flag_changed.connect(_on_flag_changed)
	refresh_outfit()
	refresh_mount()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H and is_mounted():
		Ponies.dismount()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_interact_target = null
		nav.target_position = get_global_mouse_position()


## Walk toward a node; call its interact() on arrival. (NPCs/mirrors call this on click.)
func approach(target: Node2D) -> void:
	_interact_target = target
	nav.target_position = target.global_position


## Keyboard movement actions (arrows + WASD), added to the InputMap once if missing.
static func _ensure_move_actions() -> void:
	for action: String in MOVE_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in MOVE_KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


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
	for sprite: Sprite2D in [$Body, $Dress, $Hair, $Accessory]:
		sprite.position = Vector2(0, -24) if id != "" else Vector2(0, -8)
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


func _on_flag_changed(key: String, _value: Variant) -> void:
	if key.begins_with("outfit_"):
		refresh_outfit()
	elif key == "fl_riding" or (key == "fl_ponies" and is_mounted()):
		refresh_mount()


func refresh_outfit() -> void:
	var outfit := {
		$Body: WorldState.get_flag("outfit_body", PaperDoll.DEFAULT_OUTFIT["body"]),
		$Dress: WorldState.get_flag("outfit_dress", PaperDoll.DEFAULT_OUTFIT["dress"]),
		$Hair: WorldState.get_flag("outfit_hair", PaperDoll.DEFAULT_OUTFIT["hair"]),
		$Accessory: WorldState.get_flag("outfit_accessory", PaperDoll.DEFAULT_OUTFIT["accessory"]),
	}
	# Same art set for every layer (canon when it has all worn parts, as the wardrobe does).
	var pattern := PaperDoll.art_dir_for(outfit.values())
	for sprite: Sprite2D in outfit:
		var item: String = outfit[sprite]
		var path := PaperDoll.part_path(pattern, item)
		sprite.texture = load(path) if item != "none" and ResourceLoader.exists(path) else null
		# Scale the doll to 48 px tall (NPC height) with its feet on the collision circle.
		var h := float(sprite.texture.get_height()) if sprite.texture else 48.0
		sprite.scale = Vector2.ONE * (48.0 / h)
		sprite.position = Vector2(0, -24) if is_mounted() else Vector2(0, -8)
