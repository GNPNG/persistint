class_name WorldText
extends RefCounted
## WorldText — text in the world drawn at the resolution it is shown at (bd wso.4). Door names,
## bark bubbles, a Florida thing's floating label and a recovered piece's card outside a ruins
## room are Labels sized in world px (5 px) under the camera's zoom (2, or 1.25 one level out).
## Godot rasterizes a font at its size times the viewport's oversampling, which is the window's
## stretch (2 in the 1280x720 window) and leaves the camera out, so those words were drawn at half
## the screen's resolution and doubled with nearest filtering: the thin light strokes of the ruins
## door names came out lilac-grey, and the seed bag's "Now planting" pale grey.
##
## fit() gives such a label its font rasterized at the scale it is on screen, the viewport's
## oversampling times the zoom over it (4 at the game's zoom, 2.5 one level out), so a glyph's
## texel is one screen px. Only the rasterizing changes: the text is shaped at its own size as
## before, so every width, wrap and position stays as it was. A label shown at the viewport's own
## scale (a title-screen bubble, with no zoom) keeps the theme's font.

## The oversampling is kept to quarter steps, so the zoom's 0.25 s tween and a resized window
## make a few fonts, once each (in the 1280x720 window 4 and 2.5, and 3.75 to 2.75 between).
const STEP := 0.25
## Set on each font made here: the font it was made from.
const BASE := &"world_text_base"

static var _made := {}  # "<base font id>/<oversampling>" -> FontFile


## Screen px per px of the item's own: the viewport's oversampling (the window's stretch) times
## the scale of the canvas transform (the camera's zoom) and of the nodes above the item.
static func screen_scale(item: CanvasItem) -> float:
	var vp := item.get_viewport()
	if vp == null:
		return 0.0
	var s := item.get_global_transform_with_canvas().get_scale()
	return vp.get_oversampling() * maxf(absf(s.x), absf(s.y))


## Gives `l` the font its text is drawn sharp in where it is now. Called each frame the label
## shows (door.gd, bark_bubble.gd, clickable.gd, knowledge_pickup.gd); while the scale holds it
## changes nothing.
static func fit(l: Control) -> void:
	var vp := l.get_viewport()
	if vp == null:
		return
	var want := snappedf(screen_scale(l), STEP)
	var font := l.get_theme_font("font")
	if font == null:
		return
	var base: Font = font.get_meta(BASE, font)
	if want <= 0.0 or absf(want - vp.get_oversampling()) < STEP / 2.0:
		if font != base:  # back to the font it had before
			l.remove_theme_font_override("font")
			if l.get_theme_font("font") != base:
				l.add_theme_font_override("font", base)
		return
	var f := font_for(base, want)
	if f != null and f != font:
		l.add_theme_font_override("font", f)


## `base` rasterized at `oversampling` (made once, then kept), or null for a font that cannot be:
## one that is not a FontFile, or is not rasterized by size (MSDF, a fixed-size bitmap font).
static func font_for(base: Font, oversampling: float) -> FontFile:
	var file := base as FontFile
	if file == null or file.multichannel_signed_distance_field or file.fixed_size > 0:
		return null
	var key := "%d/%s" % [file.get_instance_id(), oversampling]
	var f: FontFile = _made.get(key)
	if f == null:
		f = FontFile.new()
		f.data = file.data  # Godot's default font is embedded: this copies its bytes once
		f.antialiasing = file.antialiasing
		f.hinting = file.hinting
		f.subpixel_positioning = file.subpixel_positioning
		f.keep_rounding_remainders = file.keep_rounding_remainders
		f.generate_mipmaps = file.generate_mipmaps
		f.disable_embedded_bitmaps = file.disable_embedded_bitmaps
		f.force_autohinter = file.force_autohinter
		f.allow_system_fallback = file.allow_system_fallback
		f.fallbacks = file.fallbacks
		f.oversampling = oversampling
		f.set_meta(BASE, file)
		_made[key] = f
	return f
