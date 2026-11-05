extends SceneTree
## The Florida people blink with their eye, not their ear (bd g0va). Each sheet from
## tools/gen_florida_cast.py has rows front, side (faces right), back and idle columns rest, breath,
## rest, blink. In the side row the blink frame may differ from the rest frame only at the front of
## the face, where the eye is: the ear, further back, stays drawn. Before the fix the blink painted
## skin over the ear and drew the closed-eye arc there, so the ear winked while the eye stayed open.
## Run: godot --headless --path project -s tests/test_florida_cast_blink.gd

const SHEETS := ["npc_daughter", "npc_stable_friend", "npc_father"]
## A blink change must start in the front half of the head's width at that height.
const FRONT_SHARE := 0.5

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	for sheet: String in SHEETS:
		# The source PNG, not the imported texture (a compressed texture has no pixels headless).
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/florida/%s.png" % sheet))
		var fw := img.get_width() / 4
		var fh := img.get_height() / 3
		var rest := img.get_region(Rect2i(fw * 2, fh, fw, fh))
		var blink := img.get_region(Rect2i(fw * 3, fh, fw, fh))
		var x0 := fw
		var x1 := -1
		var y0 := fh
		var y1 := -1
		for y in fh:
			for x in fw:
				var a := rest.get_pixel(x, y)
				var b := blink.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) > 0.05:
					x0 = mini(x0, x)
					x1 = maxi(x1, x)
					y0 = mini(y0, y)
					y1 = maxi(y1, y)
		_check(x1 >= 0, "%s: the side blink frame closes something" % sheet)
		if x1 < 0:
			continue
		# The head's extent at the changed rows' middle: back (left) to front (right) of the opaque figure.
		var row := (y0 + y1) / 2
		var back := -1
		var front := -1
		for x in fw:
			if rest.get_pixel(x, row).a > 0.5:
				if back < 0:
					back = x
				front = x
		var share := float(x0 - back) / float(maxi(front - back, 1))
		_check(share >= FRONT_SHARE,
			"%s: the side blink changes only the front of the face (x %d-%d of head %d-%d at y %d; starts at %.2f of its width, needs >= %.2f)"
			% [sheet, x0, x1, back, front, row, share, FRONT_SHARE])
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
