extends Control
## Main menu — New Game (fresh flags); Continue only when there is a save to continue.

const FIRST_MAP := "res://scenes/maps/village.tscn"


func _ready() -> void:
	%BeginButton.pressed.connect(_on_begin)
	%NewButton.pressed.connect(_on_new_game)
	%BeginButton.visible = WorldState.get_flag("_location") is Dictionary


func _on_begin() -> void:
	var loc: Variant = WorldState.get_flag("_location")
	if loc is Dictionary and ResourceLoader.exists(loc.get("scene", "")):
		SceneRouter.goto_map(loc["scene"], loc.get("spawn", "spawn_default"))
	else:
		SceneRouter.goto_map(FIRST_MAP, "spawn_default")


func _on_new_game() -> void:
	WorldState.reset()
	GameClock.restore()
	SceneRouter.goto_map(FIRST_MAP, "spawn_default")
