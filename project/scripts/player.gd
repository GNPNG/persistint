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
		sprite.position = Vector2(0, -8)
