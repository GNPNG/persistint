extends Area2D
## Door — proximity map transition, or a locked door with a bark.
## Also used for mini-game entrances (a mini-game is just another scene).
## Every door draws a little kawaii doormat with a bobbing arrow, names where it goes
## when hovered or when the player is close, and can be clicked: the player walks over
## and goes through, like approaching an NPC.

const NEAR_DISTANCE := 72.0

@export var target_scene := ""  # res:// path
@export var target_spawn := "spawn_default"
@export var locked := false
@export var locked_bark := "It is sealed."
## Shown on hover/proximity, e.g. "Back to the Temple". Empty: named from target_scene.
@export var exit_label := ""
## Off for entrances that already have their own prop (the ritual table).
@export var show_marker := true

@onready var label: Label = $Label

var _name_label: Label
var _hovered := false
var _bob := 0.0
var _gone := false


func _ready() -> void:
	label.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void: _hovered = false)
	_name_label = label.duplicate() as Label
	_name_label.name = "NameLabel"
	_name_label.text = destination_name()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.hide()
	add_child(_name_label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 2


func destination_name() -> String:
	if exit_label != "":
		return exit_label
	var base := target_scene.get_file().get_basename().trim_prefix("ruins_").replace("_", " ")
	return "To the " + base.capitalize()


func _process(delta: float) -> void:
	_bob = fmod(_bob + delta * 3.0, TAU)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var near := player != null and player.global_position.distance_to(global_position) <= NEAR_DISTANCE
	_name_label.visible = (_hovered or near) and not label.visible
	if show_marker:
		queue_redraw()


func _draw() -> void:
	if not show_marker:
		return
	var mat := Color(1.0, 0.72, 0.84, 0.9) if not locked else Color(0.7, 0.68, 0.74, 0.9)
	var rim := Color(1, 1, 1, 0.95)
	# Doormat: a pill the size of the trigger, with a heart in the middle.
	draw_circle(Vector2(-14, 0), 10, mat)
	draw_circle(Vector2(14, 0), 10, mat)
	draw_rect(Rect2(-14, -10, 28, 20), mat)
	draw_arc(Vector2(-14, 0), 10, PI / 2, PI * 1.5, 12, rim, 1.5)
	draw_arc(Vector2(14, 0), 10, -PI / 2, PI / 2, 12, rim, 1.5)
	draw_line(Vector2(-14, -10), Vector2(14, -10), rim, 1.5)
	draw_line(Vector2(-14, 10), Vector2(14, 10), rim, 1.5)
	draw_circle(Vector2(-2.5, -1.5), 3.2, rim)
	draw_circle(Vector2(2.5, -1.5), 3.2, rim)
	draw_colored_polygon(PackedVector2Array([Vector2(-5.6, -0.4), Vector2(5.6, -0.4), Vector2(0, 5.5)]), rim)
	# Bobbing arrow above the mat pointing down at it.
	var y := -26.0 + sin(_bob) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(-7, y), Vector2(7, y), Vector2(0, y + 8)]), Color(1, 0.55, 0.75))
	draw_polyline(PackedVector2Array([Vector2(-7, y), Vector2(7, y), Vector2(0, y + 8), Vector2(-7, y)]), rim, 1.0)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.approach(self)
			get_viewport().set_input_as_handled()


## Called by the player on arrival after clicking the door.
func interact() -> void:
	if locked:
		label.text = locked_bark
		label.show()
		return
	_go()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if locked:
		label.text = locked_bark
		label.show()
		return
	_go()


func _go() -> void:
	if _gone:
		return
	_gone = true
	SceneRouter.goto_map(target_scene, target_spawn)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		label.hide()
