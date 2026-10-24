extends Control
## The GNPNG Ping Pong mark (the publisher's colophon for its games; the promo site's G|P|G pong
## badge), the paddles and ball rallying. Plays the sheet written by tools/gen_imprint_mark.py through SpriteFrames; the
## layout constants below match that generator's docstring. Fits the mark inside this control's
## size, centred. Clicking it opens gnpng.org, as the mark on the promo site does.

const SHEET := preload("res://assets/ui/brand/gnpng_pingpong_sheet.png")
const FRAME_SIZE := Vector2i(384, 152)
const COLUMNS := 6
const FRAME_COUNT := 36
const FPS := 12.0
const URL := "https://gnpng.org"

var _sprite: AnimatedSprite2D


func _ready() -> void:
	tooltip_text = "GNPNG Ping Pong, an imprint of GNPNG"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = build_frames()
	_sprite.centered = true
	add_child(_sprite)
	_sprite.play(&"idle")
	resized.connect(_fit)
	_fit()


static func build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.rename_animation(&"default", &"idle")
	frames.set_animation_speed(&"idle", FPS)
	frames.set_animation_loop(&"idle", true)
	for i in FRAME_COUNT:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(Vector2((i % COLUMNS) * FRAME_SIZE.x, (i / COLUMNS) * FRAME_SIZE.y), FRAME_SIZE)
		frames.add_frame(&"idle", atlas)
	return frames


func _fit() -> void:
	var s := minf(size.x / FRAME_SIZE.x, size.y / FRAME_SIZE.y)
	_sprite.scale = Vector2(s, s)
	_sprite.position = size / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		OS.shell_open(URL)
		accept_event()
