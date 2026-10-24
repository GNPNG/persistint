class_name StageFigure
extends Control
## StageFigure — someone standing on a cruise show's stage: a host stand-in figure (a 4-frame
## idle sheet from tools/gen_stage_hosts.py: rest, breath, rest, blink) or the player's paper
## doll, with a nameplate over its head. The art is a generic canon kawaii figure; who it is comes
## only from the nameplate, read from data/cast.json (dev/STYLE.md 7.5: real people are named
## in the text, never drawn as themselves).
## place() puts the figure's feet at a point of the 640x360 screen, scaled to a height there.

const FPS := 3.0

var _art: Node
var _plate: PanelContainer


## A host figure: sheet path (res://assets/ui/stage/host_*.png) and a cast id for the nameplate.
static func host(sheet_path: String, cast_id: String) -> StageFigure:
	var f := StageFigure.new()
	f.name = "Host_" + cast_id
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _frames(load(sheet_path))
	sprite.play("idle")
	f._art = sprite
	f.add_child(sprite)
	f._add_plate(Cast.full(cast_id))
	return f


## The player's paper doll in her current outfit (no nameplate: she is "you").
static func player_doll(outfit: Dictionary) -> StageFigure:
	var f := StageFigure.new()
	f.name = "Player"
	var doll := PaperDoll.new()
	doll.set_outfit(outfit)
	f._art = doll
	f.add_child(doll)
	return f


## What the player is wearing (WorldState outfit_* flags, PaperDoll defaults).
static func current_outfit() -> Dictionary:
	var ws := (Engine.get_main_loop() as SceneTree).root.get_node("/root/WorldState")
	var outfit := {}
	for slot: String in PaperDoll.DEFAULT_OUTFIT:
		outfit[slot] = ws.get_flag("outfit_" + slot, PaperDoll.DEFAULT_OUTFIT[slot])
	return outfit


static func _frames(sheet: Texture2D) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.rename_animation(&"default", &"idle")
	sf.set_animation_speed(&"idle", FPS)
	var w := sheet.get_width() / 4.0
	for i in 4:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * w, 0, w, sheet.get_height())
		sf.add_frame(&"idle", at)
	return sf


func _add_plate(text: String) -> void:
	_plate = PanelContainer.new()
	_plate.name = "Nameplate"
	_plate.theme_type_variation = &"NameTag"  # the dialogue's speaker tag
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_child(label)
	add_child(_plate)


## Feet at (x, feet_y) on the screen, `height` px tall.
func place(x: float, feet_y: float, height: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _art is AnimatedSprite2D:
		var sprite := _art as AnimatedSprite2D
		SpriteFit.fit(sprite, height)
		size = Vector2(SpriteFit.frame_size(sprite).x * sprite.scale.x, height)
		sprite.position = Vector2(size.x / 2.0, height)
	else:
		var doll := _art as PaperDoll
		doll.display_height = height
		doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = doll.custom_minimum_size
		doll.size = size
	position = Vector2(x - size.x / 2.0, feet_y - size.y)
	if _plate:
		_plate.reset_size()  # over the head, clear of the dialogue box's own speaker tag
		_plate.position = Vector2((size.x - _plate.size.x) / 2.0, -_plate.size.y - 2.0)
