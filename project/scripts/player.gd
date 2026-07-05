extends CharacterBody2D
## Player — click-to-walk via NavigationAgent2D, click-on-things to approach & interact.
## Paper-doll: layered sprites (Body/Hair/Dress/Accessory) driven by WorldState outfit flags.

const SPEED := 130.0
const INTERACT_DISTANCE := 34.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D

var _interact_target: Node2D = null


func _ready() -> void:
	add_to_group("player")
	WorldState.flag_changed.connect(_on_flag_changed)
	refresh_outfit()


func _unhandled_input(event: InputEvent) -> void:
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
	velocity = dir * SPEED
	move_and_slide()


func _on_flag_changed(key: String, _value: Variant) -> void:
	if key.begins_with("outfit_"):
		refresh_outfit()


func refresh_outfit() -> void:
	_set_layer($Body, WorldState.get_flag("outfit_body", "body_base"))
	_set_layer($Dress, WorldState.get_flag("outfit_dress", "dress_teal"))
	_set_layer($Hair, WorldState.get_flag("outfit_hair", "hair_rose"))
	_set_layer($Accessory, WorldState.get_flag("outfit_accessory", "none"))


func _set_layer(sprite: Sprite2D, item: String) -> void:
	if item == "none" or item.is_empty():
		sprite.texture = null
		return
	var path := "res://assets/placeholder/%s.png" % item
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
