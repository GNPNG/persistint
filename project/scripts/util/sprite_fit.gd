class_name SpriteFit
extends RefCounted
## SpriteFit — the one place that sizes art for display. Art is stored at its source resolution
## (canon cuts at the sheet's pixels, generated sheets at 4x or 8x) and scaled here to the height
## it is shown at, so the GPU downsamples it smoothly (mipmaps, Linear Mipmap filter) and nothing
## ever renders at its native pixel size by accident.
##
## Characters and props stand with their origin on their feet: fit() puts the frame's feet line
## on the node's origin, so y-sorted maps order everything by where it stands.


## Scales a Sprite2D or AnimatedSprite2D uniformly so one frame is `world_h` world px tall and
## puts its feet on the node's origin: `feet` is how far down the frame the feet line sits
## (1.0 = the bottom edge, 50/52 for a rig with two px of ground under the feet), centred across.
static func fit(node: Node2D, world_h: float, feet := 1.0) -> void:
	var fr := frame_size(node)
	if fr.y <= 0.0:
		return
	var k := world_h / fr.y
	node.scale = Vector2(k, k)
	node.set("centered", true)
	node.set("offset", Vector2(0.0, -fr.y * (feet - 0.5)))


## fit() for a sheet that states its own resolution: a SpriteFrames with display_scale metadata
## (texture px to world px, written by the generator, e.g. 0.25 for art drawn at 4x).
static func fit_sheet(node: AnimatedSprite2D, feet := 1.0) -> void:
	var k := float(node.sprite_frames.get_meta(&"display_scale", 1.0))
	fit(node, frame_size(node).y * k, feet)


## Scale that shows `tex` (or one frame `frame_h` px tall) `world_h` px tall.
static func scale_for(tex: Texture2D, world_h: float, frame_h := 0.0) -> float:
	var h := frame_h if frame_h > 0.0 else float(tex.get_height())
	return world_h / h if h > 0.0 else 1.0


## Size of `tex` shown `display_h` px tall (aspect kept): for TextureRects and other Controls.
static func size_for(tex: Texture2D, display_h: float) -> Vector2:
	if tex == null or tex.get_height() == 0:
		return Vector2.ZERO
	return Vector2(tex.get_width() * display_h / tex.get_height(), display_h)


## Size in texture px of one frame of a Sprite2D (region, hframes/vframes) or AnimatedSprite2D
## (its current animation's current frame).
static func frame_size(node: Node2D) -> Vector2:
	if node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames == null or not a.sprite_frames.has_animation(a.animation):
			return Vector2.ZERO
		if a.sprite_frames.get_frame_count(a.animation) == 0:
			return Vector2.ZERO
		var t := a.sprite_frames.get_frame_texture(a.animation, mini(a.frame, a.sprite_frames.get_frame_count(a.animation) - 1))
		return t.get_size() if t else Vector2.ZERO
	if node is Sprite2D:
		var s := node as Sprite2D
		if s.texture == null:
			return Vector2.ZERO
		var size := s.region_rect.size if s.region_enabled else s.texture.get_size()
		return Vector2(size.x / s.hframes, size.y / s.vframes)
	return Vector2.ZERO
