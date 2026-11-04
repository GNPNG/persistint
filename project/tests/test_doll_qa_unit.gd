extends SceneTree
const Composer = preload("res://scripts/systems/doll_composer.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)

func _init() -> void:
	var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/doll/rig_chibi.json"))
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var a := clampf(80.5 - Vector2(x - 128.2, y - 127.8).length(), 0.0, 1.0)
			image.set_pixel(x, y, Color(0.4, 0.24, 0.16, a))
	check(Composer.pixel_report(image, "body", [], rig.qa).failures.is_empty(), "smooth brown fixture passes")
	var touched := image.duplicate() as Image
	touched.set_pixel(0, 20, Color(0.4, 0.24, 0.16, 0.01))
	check(Composer.pixel_report(touched, "body", [], rig.qa).failures.has("frame_border"), "fractional border alpha fails")
	var green := image.duplicate() as Image
	green.set_pixel(128, 128, Color(0, 1, 0, 0.2))
	check(Composer.pixel_report(green, "body", [], rig.qa).failures.has("green_residue"), "green residue fails")
	var skin := image.duplicate() as Image
	for y in range(110, 140):
		for x in range(110, 140):
			skin.set_pixel(x, y, Color8(252, 206, 183))
	check(Composer.pixel_report(skin, "dress", rig.skin.base, rig.qa).failures.has("skin_leak"), "skin leak in garment fails")
	var binary := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	binary.fill_rect(Rect2i(20, 20, 80, 80), Color(0.4, 0.24, 0.16))
	check(Composer.pixel_report(binary, "body", [], rig.qa).failures.has("boundary_alpha_levels"), "binary edge fails")
	var fringe := binary.duplicate() as Image
	fringe.fill_rect(Rect2i(20, 20, 80, 1), Color.WHITE)
	check(Composer.pixel_report(fringe, "body", [], rig.qa).failures.has("fringe"), "white outer ring fails")
	binary.set_pixel(2, 2, Color(0.4, 0.24, 0.16))
	check(Composer.stray_report(binary, rig.qa).size() == 1, "remote tiny component fails")
	var body := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	body.fill(Color.WHITE)
	var regions := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	regions.fill(Color8(1, 1, 1))
	var blank := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	check(Composer.region_report(blank, regions, body, {"covers": ["torso"]}, {"torso": 1}, rig.qa).failures.has("coverage:torso"), "coverage gap fails")
	check(Composer.region_report(body, regions, body, {"never": ["eye_band"]}, {"eye_band": 1}, rig.qa, body).failures.has("forbidden:eye_band"), "front mask never exempts eye band")
	check(Composer.region_report(body, regions, body, {"front_never": ["torso"]}, {"torso": 1}, rig.qa, body).failures.is_empty(), "explicit front mask permits front lock over torso")
	var back := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	back.fill(Color.RED)
	var top := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	top.fill(Color.BLUE)
	check(Composer.compose([back, top], Vector2i(8, 8)).get_pixel(4, 4) == Color.BLUE, "composition respects stack order")
	print("RESULT: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
