extends CharacterBody2D
## Player — click-to-walk via NavigationAgent2D, click-on-things to approach & interact.
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


func _ready() -> void:
	add_to_group("player")
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


func _physics_process(_delta: float) -> void:
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
		return
	var dir := global_position.direction_to(nav.get_next_path_position())
	velocity = dir * current_speed()
	if is_mounted() and absf(dir.x) > 0.1:
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
		$Body: WorldState.get_flag("outfit_body", "body_base"),
		$Dress: WorldState.get_flag("outfit_dress", "dress_white"),
		$Hair: WorldState.get_flag("outfit_hair", "hair_braids"),
		$Accessory: WorldState.get_flag("outfit_accessory", "none"),
	}
	# Same art set for every layer (canon when it has all worn parts, as the wardrobe does).
	var pattern := PaperDoll.art_dir_for(outfit.values())
	for sprite: Sprite2D in outfit:
		var item: String = outfit[sprite]
		var path := pattern % item
		sprite.texture = load(path) if item != "none" and ResourceLoader.exists(path) else null
		# Scale the doll to 48 px tall (NPC height) with its feet on the collision circle.
		var h := float(sprite.texture.get_height()) if sprite.texture else 48.0
		sprite.scale = Vector2.ONE * (48.0 / h)
		sprite.position = Vector2(0, -24) if is_mounted() else Vector2(0, -8)
