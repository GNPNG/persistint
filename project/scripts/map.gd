extends Node2D
## Map — common behavior for every map area: place the player at the requested
## spawn marker, build the HUD (clock + calendar), P toggles the wardrobe.

const WARDROBE_SCENE := "res://scenes/ui/wardrobe.tscn"

## Pixel size of the map; the camera stops at its edge. Zero leaves the camera free.
@export var map_size := Vector2.ZERO

var _hud_label: Label
var _wardrobe: CanvasLayer
var _journal: CanvasLayer
const JOURNAL_SCRIPT := preload("res://scripts/ui/journal.gd")


func _ready() -> void:
	# Ponies stay in Florida: arriving anywhere else, the rider has already hopped down.
	if not scene_file_path.contains("/florida/") and WorldState.get_flag("fl_riding", "") != "":
		WorldState.set_flag("fl_riding", "")
	_spawn_player()
	_limit_camera()
	_build_hud()
	GameClock.phase_changed.connect(func(_p: String) -> void: _update_hud())
	GameClock.day_changed.connect(func(_d: int) -> void: _update_hud())


func _spawn_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var marker := find_child(SceneRouter.next_spawn, true, false)
	if marker == null:
		marker = find_child("spawn_default", true, false)
	if player and marker:
		player.global_position = (marker as Node2D).global_position


func _limit_camera() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cam: Camera2D = player.get_node_or_null("Camera2D") if player else null
	if cam and map_size != Vector2.ZERO:
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(map_size.x)
		cam.limit_bottom = int(map_size.y)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	_hud_label = Label.new()
	_hud_label.position = Vector2(8, 4)
	_hud_label.add_theme_font_size_override("font_size", 10)
	_hud_label.add_theme_color_override("font_color", Color(0.35, 0.22, 0.35))
	_hud_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_hud_label.add_theme_constant_override("outline_size", 3)
	layer.add_child(_hud_label)
	_update_hud()


func _update_hud() -> void:
	if _hud_label:
		_hud_label.text = GameClock.status_text()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		toggle_wardrobe()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_J:
		toggle_journal()


func toggle_journal() -> void:
	if _journal and is_instance_valid(_journal):
		_journal.queue_free()
		_journal = null
		return
	_journal = JOURNAL_SCRIPT.new()
	add_child(_journal)


func toggle_wardrobe() -> void:
	if _wardrobe and is_instance_valid(_wardrobe):
		_wardrobe.queue_free()
		_wardrobe = null
		return
	_wardrobe = load(WARDROBE_SCENE).instantiate()
	add_child(_wardrobe)
