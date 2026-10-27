class_name GearButton
extends TextureButton
## A floating sticker gear at the top right that opens the settings screen with a tap or a click.
## The art is assets/ui/hud/gear.png and gear_pressed.png (tools/gen_hud_stickers.py); sized for
## a finger. Pointer and touch only: no focus, so a gamepad never lands on it (QA-13).

const SIZE := 32.0
const MARGIN := 8.0


func _ready() -> void:
	texture_normal = load("res://assets/ui/hud/gear.png")
	texture_pressed = load("res://assets/ui/hud/gear_pressed.png")
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	tooltip_text = "Settings"
	_place()
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	position = Vector2(get_viewport_rect().size.x - SIZE - MARGIN, MARGIN)
