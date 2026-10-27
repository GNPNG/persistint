class_name StickerButton
extends TextureButton
## A floating sticker under the settings gear (top right) that a finger or a click can press: the
## wardrobe's clothes hanger or the journal's book (author 2026-10-24, bd ctw: "float like a little
## icon ... a little animated like clothes hanger"). The art is assets/ui/hud/<kind>.png and
## <kind>_pressed.png (tools/gen_hud_stickers.py); it sways a little so it reads as a toy, not a
## toolbar. Pointer and touch only: no focus, so a gamepad never lands on it (QA-13).

const SIZE := 32.0
const MARGIN := 8.0
const SWAY_DEGREES := 6.0
const SWAY_SECONDS := 2.4

## "hanger" (wardrobe) or "book" (journal).
@export var kind := "hanger"
## Which slot under the gear: 1 is the first one below it.
@export var slot := 1

var _t := 0.0


func _ready() -> void:
	texture_normal = load("res://assets/ui/hud/%s.png" % kind)
	texture_pressed = load("res://assets/ui/hud/%s_pressed.png" % kind)
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	pivot_offset = Vector2(SIZE / 2.0, 2.0)  # it hangs from its top, like a hanger on a rail
	tooltip_text = {"hanger": "Wardrobe (P)", "book": "Journal (J)"}.get(kind, "")
	_t = slot * 0.7  # neighbours don't sway in step
	_place()
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	position = Vector2(get_viewport_rect().size.x - SIZE - MARGIN, MARGIN + slot * (SIZE + MARGIN))


func _process(delta: float) -> void:
	_t += delta
	rotation_degrees = sin(_t * TAU / SWAY_SECONDS) * SWAY_DEGREES
