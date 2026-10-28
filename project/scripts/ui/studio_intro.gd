extends Control
## G|P|G studio sting (assets/video/studio_intro.ogv, with its own sound), played when the game
## starts. It goes to the main menu when it ends; any click, touch or key skips it. If the video
## can't be loaded, the main menu opens at once.
## The web build does not always emit the player's finished signal at the end of the clip, so the
## intro also ends on its own max_seconds after it starts (the clip's length plus END_MARGIN), and
## if the player stops by itself. Input is read in _input, before the GUI: the full-screen Bg and
## Video controls would otherwise take a click or tap and only keys would get through (bd b4m).
## On the web build a "tap to start" gate (the boot splash with a prompt under it) comes first.
## Browsers, iOS Safari above all, keep the page's AudioContext suspended until a click, tap or
## key; Godot's web platform resumes it inside its own key, mouse and touch handlers
## (DisplayServerWeb::_key_callback/_mouse_button_callback/_touch_callback call
## OS_Web::resume_audio), so the first input on the gate unlocks the sound and only then does the
## sting play, with its sound, and the title theme after it. Without the gate the sting could
## play out and end with no input at all, and the page stayed silent (the logo's sound and the
## title theme never started on an iPad). Desktop builds have no such lock and skip the gate.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const VIDEO := "res://assets/video/studio_intro.ogv"
## The clip is 6.67 s (6.69 s of sound); used when the stream does not report a length.
const CLIP_SECONDS := 6.8
const END_MARGIN := 1.0
## Input in the first moments of the sting doesn't skip it: on touch screens one tap arrives as a
## touch and an emulated click, and the second must not skip the sting the first one started.
const SKIP_GRACE := 0.35

## Whether the gate shows: -1 on the web build only, 0 never, 1 always (tests set it).
static var gate_mode := -1

## Seconds after which the intro ends whatever the player reports; tests shorten it.
var max_seconds := CLIP_SECONDS + END_MARGIN
## True while the gate waits for the first input; the sting has not started.
var gated := false
var _done := false
var _elapsed := 0.0
var _pulse: Tween


func _ready() -> void:
	for c: Control in [self, $Bg, $Video, $Gate, $Gate/Bg, $Gate/Splash, $Gate/Prompt]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gated = gate_mode == 1 or (gate_mode == -1 and OS.has_feature("web"))
	$Gate.visible = gated
	if gated:
		var prompt: Label = $Gate/Prompt
		_pulse = create_tween().set_loops()
		_pulse.tween_property(prompt, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(prompt, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		return
	_start()


## Starts the sting (the gate's first input, or at once without a gate).
func _start() -> void:
	gated = false
	$Gate.visible = false
	if _pulse:
		_pulse.kill()
	_elapsed = 0.0
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
	if _done or gated:
		return
	_elapsed += delta
	var player: VideoStreamPlayer = $Video
	if _elapsed >= max_seconds or (_elapsed > 0.5 and not player.is_playing()):
		_finish()


func _input(event: InputEvent) -> void:
	if not (event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton)):
		return
	get_viewport().set_input_as_handled()
	if _done:
		return
	if gated:
		_start()
	elif _elapsed >= SKIP_GRACE:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU)
