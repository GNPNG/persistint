extends Control
## Main menu — Begin (continue save) / New Game (fresh flags).

const FIRST_MAP := "res://scenes/maps/village.tscn"


func _ready() -> void:
	$Center/VBox/BeginButton.pressed.connect(_on_begin)
	$Center/VBox/NewButton.pressed.connect(_on_new_game)


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
