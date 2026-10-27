extends Control
## G|P|G studio sting (assets/video/studio_intro.ogv, with its own sound), played when the game
## starts. It goes to the main menu when it ends; any click, touch or key skips it. If the video
## can't be loaded, the main menu opens at once.
## The web build does not always emit the player's finished signal at the end of the clip, so the
## intro also ends on its own max_seconds after it starts (the clip's length plus END_MARGIN), and
## if the player stops by itself. Input is read in _input, before the GUI: the full-screen Bg and
## Video controls would otherwise take a click or tap and only keys would get through (bd b4m).

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VIDEO := "res://assets/video/studio_intro.ogv"
## The clip is 7.0 s (7.02 s of sound); used when the stream does not report a length.
const CLIP_SECONDS := 7.1
const END_MARGIN := 1.0

## Seconds after which the intro ends whatever the player reports; tests shorten it.
var max_seconds := CLIP_SECONDS + END_MARGIN
var _done := false
var _elapsed := 0.0


func _ready() -> void:
	for c: Control in [self, $Bg, $Video]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var player: VideoStreamPlayer = $Video
	if not ResourceLoader.exists(VIDEO):
		_finish()
		return
	player.stream = load(VIDEO)
	player.finished.connect(_finish)
	player.play()
	var length := player.get_stream_length()
	if length > 0.0:
		max_seconds = length + END_MARGIN


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	var player: VideoStreamPlayer = $Video
	if _elapsed >= max_seconds or (_elapsed > 0.5 and not player.is_playing()):
		_finish()


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU)
