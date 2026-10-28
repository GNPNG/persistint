class_name RigSheet
extends RefCounted
## RigSheet — SpriteFrames for the directional character sheets written by tools/gen_npc_rigs.py
## and tools/gen_player_rig.py: 8 columns x 3 rows of equal frames, rows down / left / up (the
## side view faces left; flip it for right), columns 0-3 idle and 4-7 walk. Animations are
## idle_<dir> and walk_<dir>. Built once per sheet and shared.

const DIRS: Array[String] = ["down", "left", "up"]
const IDLE_FPS := 3.0
const WALK_FPS := 8.0

static var _cache: Dictionary = {}  # path -> SpriteFrames
## Sheets cut into SpriteFrames (each once), counted for the walking perf check
## (tests/test_perf_walk.gd): none should be cut while the player walks.
static var sheets_built := 0


## Frame size of a rig sheet.
static func frame_size(sheet: Texture2D) -> Vector2:
	return Vector2(sheet.get_width() / 8.0, sheet.get_height() / 3.0)


## The rig sheet at `path` as SpriteFrames (idle_/walk_ + down/left/up).
static func frames(path: String) -> SpriteFrames:
	if _cache.has(path):
		return _cache[path]
	var sheet: Texture2D = load(path)
	var fr := frame_size(sheet)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row: int in 3:
		for state: String in ["idle", "walk"]:
			var anim := "%s_%s" % [state, DIRS[row]]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, IDLE_FPS if state == "idle" else WALK_FPS)
			for i in 4:
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(((0 if state == "idle" else 4) + i) * fr.x, row * fr.y, fr.x, fr.y)
				sf.add_frame(anim, at)
	_cache[path] = sf
	sheets_built += 1
	return sf


## A still picture as SpriteFrames with the same animation names (one frame each), for art that
## has no rig (the placeholder set): the code that drives a rig drives it unchanged.
static func still(path: String) -> SpriteFrames:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for dir: String in DIRS:
		for state: String in ["idle", "walk"]:
			sf.add_animation("%s_%s" % [state, dir])
			sf.add_frame("%s_%s" % [state, dir], tex)
	_cache[path] = sf
	sheets_built += 1
	return sf


## The animation for a character moving (or facing) along `d`: "<state>_<dir>" and whether to
## flip the left-facing side view.
static func facing(d: Vector2, state: String) -> Array:
	var side := absf(d.x) > absf(d.y) * 1.2
	var dir := "left" if side else ("up" if d.y < 0.0 else "down")
	return ["%s_%s" % [state, dir], side and d.x > 0.0]
