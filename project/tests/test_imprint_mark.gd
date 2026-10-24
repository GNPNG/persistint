extends SceneTree
## Headless check of the GNPNG Ping Pong imprint mark: the sheet matches the frame layout in
## tools/gen_imprint_mark.py, the SpriteFrames rally loops, the main menu carries the mark and
## the boot splash and the app icon are set.
## Run: godot --headless --path project -s tests/test_imprint_mark.gd

const ImprintMark := preload("res://scripts/ui/imprint_mark.gd")

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		print("ok   ", what)
	else:
		_failures += 1
		print("FAIL ", what)


func _run() -> void:
	await process_frame
	var sheet: Texture2D = ImprintMark.SHEET
	var rows := ceili(float(ImprintMark.FRAME_COUNT) / ImprintMark.COLUMNS)
	_check(sheet.get_size() == Vector2(ImprintMark.FRAME_SIZE.x * ImprintMark.COLUMNS,
		ImprintMark.FRAME_SIZE.y * rows), "sheet size matches the documented frame layout")

	var frames: SpriteFrames = ImprintMark.build_frames()
	_check(frames.has_animation(&"idle"), "SpriteFrames has the idle rally")
	_check(frames.get_frame_count(&"idle") == ImprintMark.FRAME_COUNT, "idle has every frame")
	_check(frames.get_animation_loop(&"idle"), "idle loops")
	var last: AtlasTexture = frames.get_frame_texture(&"idle", ImprintMark.FRAME_COUNT - 1)
	_check(Rect2(Vector2.ZERO, sheet.get_size()).encloses(last.region), "last frame lies inside the sheet")

	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	var mark := menu.get_node_or_null("Imprint/Mark")
	_check(mark != null and mark.get_script() == ImprintMark, "main menu carries the imprint mark")
	menu.free()

	var splash: String = ProjectSettings.get_setting("application/boot_splash/image", "")
	_check(splash == "res://assets/ui/brand/boot_splash.png" and ResourceLoader.exists(splash),
		"boot splash shows the wordmark (tools/gen_brand_art.py)")
	var icon: String = ProjectSettings.get_setting("application/config/icon", "")
	_check(icon == "res://assets/ui/icon/app_icon.png" and ResourceLoader.exists(icon), "the app ships an icon")

	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures else 0)
