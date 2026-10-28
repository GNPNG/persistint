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
## fit() gives such a label its own font (the one the theme or an override gives it, whatever it
## is: a FontFile, or a FontVariation over one) rasterized at the scale it is on screen, the
## viewport's oversampling times the zoom over it (4 at the game's zoom, 2.5 one level out), so a
## glyph's texel is one screen px. Only the rasterizing changes: the text is shaped at its own size
## as before, so every width, wrap and position stays as it was. A label shown at the viewport's
## own scale (a title-screen bubble, with no zoom) keeps its font.

## The oversampling is kept to quarter steps, so the zoom's 0.25 s tween and a resized window
## make a few fonts, once each (in the 1280x720 window 4 and 2.5, and 3.75 to 2.75 between).
const STEP := 0.25
## Set on each font made here: the instance id of the font it was made from. An id, not the font:
## the font keeps its copies (in its metadata, font_for), and a reference back would keep both
## alive for good. Nothing here is held in a static, so the copies go when their font goes.
const BASE := &"world_text_base"
## The visibility layer (bit) of what is drawn in the world for the screen alone: the ruins gloom
## laid over the camera's view under the words (ruins_decor.gd). The map card's miniature, a
## second camera over the same world (minimap.gd), leaves it out.
const SCREEN_ONLY_LAYER := 1 << 9


## Screen px per px of the item's own: the viewport's oversampling (the window's stretch) times
## the scale of the canvas transform (the camera's zoom) and of the nodes above the item.
static func screen_scale(item: CanvasItem) -> float:
	var vp := item.get_viewport()
	if vp == null:
		return 0.0
	var s := item.get_global_transform_with_canvas().get_scale()
	return vp.get_oversampling() * maxf(absf(s.x), absf(s.y))


## The font a font made here was made from (the label's own font), or the font itself.
static func base_of(font: Font) -> Font:
	if font == null or not font.has_meta(BASE):
		return font
	var base := instance_from_id(int(font.get_meta(BASE))) as Font
	return base if base != null else font


## Gives `l` the font its text is drawn sharp in where it is now, and returns true when that
## changed its font. Called each frame the label shows (door.gd, bark_bubble.gd, clickable.gd,
## knowledge_pickup.gd); while the scale holds it changes nothing. The text measures the same in
## either font, but a swap is a theme change, after which a Label works its minimum size out
## again: a label that sizes itself to its text lays itself out after a swap (BarkBubble.fit).
static func fit(l: Control) -> bool:
	var vp := l.get_viewport()
	if vp == null:
		return false
	var shown := screen_scale(l)
	if shown <= 0.0:
		return false
	var want := maxf(STEP, snappedf(shown, STEP))  # a small view (a headless run) never snaps to 0
	var font := l.get_theme_font("font")
	if font == null:
		return false
	var base := base_of(font)
	if absf(want - vp.get_oversampling()) < STEP / 2.0:
		if font == base:
			return false
		l.remove_theme_font_override("font")  # back to the font it had before
		if l.get_theme_font("font") != base:
			l.add_theme_font_override("font", base)
		return true
	var f := font_for(base, want)
	if f == null or f == font:
		return false
	l.add_theme_font_override("font", f)
	return true


## `base` rasterized at `oversampling`, made once and kept in `base`'s metadata, or null for a font
## that cannot be: one that is neither a FontFile nor a FontVariation over one, or is not
## rasterized by size (MSDF, a fixed-size bitmap font). A FontFile is copied with its data, its
## settings and its fallbacks; a FontVariation keeps its variation, spacing and fallbacks over a
## copy of its base font.
static func font_for(base: Font, oversampling: float) -> Font:
	if base == null:
		return null
	var key := StringName("world_text_%d" % roundi(oversampling * 100.0))
	if base.has_meta(key):
		return base.get_meta(key) as Font
	var made: Font = null
	if base is FontVariation:
		var v := base as FontVariation
		var under := font_for(v.base_font if v.base_font != null else ThemeDB.fallback_font, oversampling)
		if under == null:
			return null
		var copy := v.duplicate() as FontVariation
		for m: StringName in copy.get_meta_list():  # not the copies the original keeps
			copy.remove_meta(m)
		copy.base_font = under
		made = copy
	elif base is FontFile:
		var file := base as FontFile
		if file.multichannel_signed_distance_field or file.fixed_size > 0:
			return null
		var f := FontFile.new()
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
		made = f
	else:
		return null
	made.set_meta(BASE, base.get_instance_id())
	base.set_meta(key, made)
	return made
