extends Area2D
## Door — proximity map transition, or a locked door with a bark.
## Also used for mini-game entrances (a mini-game is just another scene).

@export var target_scene := ""  # res:// path
@export var target_spawn := "spawn_default"
@export var locked := false
@export var locked_bark := "It is sealed."

@onready var label: Label = $Label


func _ready() -> void:
	label.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if locked:
		label.text = locked_bark
		label.show()
		return
	SceneRouter.goto_map(target_scene, target_spawn)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		label.hide()
