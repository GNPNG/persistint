extends Control
## G|P|G studio sting (assets/video/studio_intro.ogv, with its own sound), played when the game
## starts. It goes to the main menu when it ends; any click, touch or key skips it. If the video
## can't be loaded, the main menu opens at once.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VIDEO := "res://assets/video/studio_intro.ogv"

var _done := false


func _ready() -> void:
	var player: VideoStreamPlayer = $Video
	if not ResourceLoader.exists(VIDEO):
		_finish()
		return
	player.stream = load(VIDEO)
	player.finished.connect(_finish)
	player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU)
