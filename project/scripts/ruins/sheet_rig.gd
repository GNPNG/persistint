extends RefCounted
## SheetRig — SpriteFrames for the ruins' rigged sheets (tools/gen_clone_children.py documents
## each sheet's frame size and rows), their size on screen, and the facing a walk takes.

## Each rig: frame size in texels, the frame's world height and its feet line (fraction of the
## frame height; SpriteFit puts it on the character's origin), and its animations
## (row, first column, frames, fps).
## A clone child: 192x272 frames (24x34 world px at 8 texels each); rows front/side/back; columns 0-1 idle, 2-5 walk.
const CLONE := {"size": Vector2i(192, 272), "world_h": 34.0, "feet": 1.0, "anims": {
	"idle_down": [0, 0, 2, 2.0], "walk_down": [0, 2, 4, 6.0],
	"idle_side": [1, 0, 2, 2.0], "walk_side": [1, 2, 4, 6.0],
	"idle_up": [2, 0, 2, 2.0], "walk_up": [2, 2, 4, 6.0]}}
## A polar bear cub: 192x176 frames (24x22 world px); rows front/side/back (idle 0-1, walk 2-5), smeared
## (idle 0-1, chomp 2-3) and nap (0-1).
const CUB := {"size": Vector2i(192, 176), "world_h": 22.0, "feet": 174.0 / 176.0, "anims": {
	"idle_down": [0, 0, 2, 2.0], "walk_down": [0, 2, 4, 8.0],
	"idle_side": [1, 0, 2, 2.0], "walk_side": [1, 2, 4, 8.0],
	"idle_up": [2, 0, 2, 2.0], "walk_up": [2, 2, 4, 8.0],
	"smeared": [3, 0, 2, 2.0], "chomp": [3, 2, 2, 8.0], "nap": [4, 0, 2, 1.2]}}


## Every animation in `rig` cut from `sheet`, all looping.
static func frames(sheet: Texture2D, rig: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var size: Vector2i = rig["size"]
	for anim: String in rig["anims"]:
		var a: Array = rig["anims"][anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, a[3])
		sf.set_animation_loop(anim, true)
		for i in int(a[2]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(Vector2((int(a[1]) + i) * size.x, int(a[0]) * size.y), size)
			sf.add_frame(anim, at)
	return sf


## Sizes `sprite` (playing a sheet cut by frames()) to the rig's world height, feet on its origin.
static func fit(sprite: AnimatedSprite2D, rig: Dictionary) -> void:
	SpriteFit.fit(sprite, float(rig["world_h"]), float(rig["feet"]))


## "down", "up" or "side" for a step along `delta` (side frames face right; flip for left).
static func facing(delta: Vector2) -> String:
	if absf(delta.x) >= absf(delta.y) * 0.8:
		return "side"
	return "down" if delta.y > 0 else "up"

