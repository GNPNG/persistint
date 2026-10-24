extends SceneTree
## Animated title screen (bd 3m3): the main menu carries the backdrop and the letters; every layer texture and the
## sway shader load; the timeline math follows the author's spec (the O complete at 75-85% of the
## track, the trickle to the end, a fade in the last seconds, a reset at the loop); the sky mix
## sums to one with day at noon and night at midnight; the O, trickle and charms are built and
## move; the layout file names the island, foam, trees, palms, perches and the O. The wordmark is
## ten letter sprites that jiggle on the beat; a tap pops hearts and speaks a tier's line, the
## counter decays, sulk tiers ignore taps for a moment, and the chime-ins step in once past
## their thresholds; the letters' hit areas stay clear of the menu's buttons.
## Run: godot --headless --path project -s tests/test_title_anim.gd

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const Backdrop := preload("res://scripts/ui/main_menu_backdrop.gd")
const Letters := preload("res://scripts/ui/title_letters.gd")

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# --- Layout and textures ---
	var layout: Dictionary = Backdrop._load_layout()
	for key in ["island", "foam", "waves", "trees", "palms", "perches", "o", "track_seconds_fallback"]:
		_check(layout.has(key), "title_layout.json has %s" % key)
	_check((layout.get("trees", []) as Array).size() == 6 and (layout.get("palms", []) as Array).size() == 2, "six trees and two palms")
	for key: String in Backdrop.TEXTURES:
		var path: String = Backdrop.TEXTURES[key]
		_check(ResourceLoader.exists(path) and load(path) is Texture2D, "%s loads (%s)" % [key, path])
	for kind: String in Backdrop.CHARM_KINDS:
		for suffix in ["", "_mid", "_far"]:
			var path := "%scharm_%s%s.png" % [Backdrop.DIR, kind, suffix]
			_check(load(path) is Texture2D, "charm %s loads" % path)
	_check(load(Backdrop.DIR + "charm_uterus_wink.png") is Texture2D, "the wink frame loads")
	_check(load(Backdrop.SWAY_SHADER) is Shader, "sway shader loads")
	_check(load(Backdrop.REVEAL_SHADER) is Shader, "ring reveal shader loads")

	# --- Timeline math ---
	var len := 172.0
	_check(is_zero_approx(Backdrop.timeline(0.0, len)["o"]), "the O starts undrawn")
	var done_at := -1.0
	var t := 0.0
	while t <= len and done_at < 0.0:
		if Backdrop.timeline(t, len)["o"] >= 1.0:
			done_at = t
		t += 0.5
	_check(done_at >= 0.75 * len and done_at <= 0.85 * len, "the O is complete at 75-85%% of the track (at %.0f%%)" % (100.0 * done_at / len))
	_check(Backdrop.timeline(done_at - 10.0, len)["o"] < 1.0, "the O is still being drawn before that")
	_check(is_zero_approx(Backdrop.timeline(len * Backdrop.O_DONE, len)["trickle"]) and Backdrop.timeline(done_at, len)["trickle"] < 0.02, "the trickle starts when the O is done")
	_check(is_equal_approx(Backdrop.timeline(len, len)["trickle"], 1.0), "the trickle reaches its end with the track")
	var mid := (done_at + len) / 2.0
	_check(absf(Backdrop.timeline(mid, len)["trickle"] - 0.5) < 0.05, "the trickle is halfway halfway through its run")
	_check(is_equal_approx(Backdrop.timeline(len - 3.0, len)["alpha"], 1.0), "no fade before the last seconds")
	_check(is_equal_approx(Backdrop.timeline(len - 1.0, len)["alpha"], 0.5), "fading in the last seconds")
	_check(is_zero_approx(Backdrop.timeline(len, len)["alpha"]), "faded out at the end")
	for u in [0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9]:
		var m: Dictionary = Backdrop.sky_mix(u)
		_check(is_equal_approx(m["day"] + m["dusk"] + m["night"], 1.0) and m["dusk"] >= 0.0, "sky mix sums to one at %s" % u)
	_check(is_equal_approx(Backdrop.sky_mix(0.25)["day"], 1.0), "noon is day")
	_check(is_equal_approx(Backdrop.sky_mix(0.75)["night"], 1.0), "midnight is night")
	_check(Backdrop.sky_mix(0.0)["dusk"] > 0.5 and Backdrop.sky_mix(0.5)["dusk"] > 0.5, "sunrise and sunset are the golden hour")
	_check(Backdrop.arc_point(0.5).y < Backdrop.arc_point(0.0).y, "the sun rises to the top of its arc")

	# --- The menu carries the backdrop; its parts are built and move ---
	change_scene_to_file(MAIN_MENU)
	await process_frame
	await process_frame
	var bd: Node = current_scene.get_node_or_null("Backdrop")
	_check(bd != null and bd is Backdrop, "the main menu has the Backdrop")
	_check(current_scene.get_node_or_null("Art") == null, "the still title art is gone")
	_check(current_scene.get_node_or_null("Wordmark") is Letters and current_scene.get_node_or_null("Center/Panel/VBox/NewButton") != null, "the menu is still there, the wordmark is the letters")
	_check(current_scene.get_node_or_null("Imprint/Mark") != null, "the G|P|G mark is still there")
	var idx_bd := current_scene.get_node("Backdrop").get_index()
	_check(idx_bd < current_scene.get_node("Wordmark").get_index() and idx_bd > current_scene.get_node("Bg").get_index(), "the backdrop sits behind the menu, over the colour")
	if bd != null:
		_check(bd.charms.size() == 18 and bd.birds.size() == 3 and bd.trees.size() == 8, "18 charms, 3 birds, 8 trees and palms")
		var kinds := {}
		for c in bd.charms:
			kinds[c["kind"]] = true
		_check(kinds.size() == 6, "every charm kind falls (%s)" % str(kinds.keys()))
		var length: float = bd.track_length()
		_check(length > 60.0, "the track length comes from the title theme or the fallback (%.0f s)" % length)
		bd.set_time(0.0)
		_check(is_zero_approx(bd.o_progress()) and is_zero_approx(bd.drip_progress()) and not bd.get_node("ODrip").visible, "nothing drawn at the start")
		bd.set_time(length * 0.5)
		_check(absf(bd.o_progress() - 0.625) < 0.01, "half the track, 5/8 of the O (%.3f)" % bd.o_progress())
		bd.set_time(length * Backdrop.O_DONE)
		_check(is_equal_approx(bd.o_progress(), 1.0), "the O is complete")
		bd.set_time(length * 0.9)
		_check(absf(bd.drip_progress() - 0.5) < 0.02 and bd.get_node("ODrip").visible, "the drips are halfway down (%.2f)" % bd.drip_progress())
		_check(bd.get_node("ODrip").region_rect.size.x == bd.get_node("ODrip").texture.get_width(), "the drips show full width")
		bd.set_time(length - 0.5)
		_check(bd.get_node("ORing").modulate.a < 0.5 and bd.get_node("ODrip").modulate.a < 0.5, "the O and its drips fade at the end")
		bd.track_pos = length - 0.5
		bd._advance_track(1.0)
		bd._apply_o()
		_check(bd.track_pos < 1.0 and bd.o_progress() < 1.0, "the loop resets the drawing")
		var mat: ShaderMaterial = bd.get_node("ORing").material
		_check(mat != null and mat.shader == load(Backdrop.REVEAL_SHADER), "the ring is revealed by the shader")
		var centre: Vector2 = mat.get_shader_parameter("center")
		_check(centre.x > 0.0 and centre.x < bd.get_node("ORing").texture.get_width(), "the reveal turns round the ring's centre")
		bd.set_time(0.0, 0.75)
		_check(bd.get_node("Moon").visible and not bd.get_node("Sun").visible and bd.get_node("World").modulate.b > bd.get_node("World").modulate.r, "midnight: the moon is up and the world is blue")
		bd.set_time(0.0, 0.25)
		_check(bd.get_node("Sun").visible and bd.get_node("Sun").position.y < 60.0, "noon: the sun is high")
		var y0: Array[float] = []
		for c in bd.charms:
			y0.append(c["y"])
		var bird0: Vector2 = bd.birds[0]["sprite"].position
		for i in 120:
			bd._process(0.1)
		var fell := 0
		for i in bd.charms.size():
			if bd.charms[i]["y"] != y0[i]:
				fell += 1
		_check(fell == bd.charms.size(), "every charm fell in 12 seconds")
		var flew := false
		for b in bd.birds:
			if b["sprite"].position != bird0 or b["flying"]:
				flew = true
		_check(flew, "a bird took off within 12 seconds")
		for c in bd.charms:
			_check(c["y"] <= 400.0 and c["x"] >= 0.0 and c["x"] <= 640.0, "charm stays in its lane")
		var day_before: float = bd.day_t
		bd._process(1.0)
		_check(bd.day_t > day_before and bd.day_t < 1.0, "the day advances")

	# --- The letters ---
	var wm: Node = current_scene.get_node_or_null("Wordmark")
	if wm is Letters:
		_check(wm.letters.size() == 10, "ten letters (%d)" % wm.letters.size())
		var word := ""
		for h in wm.letters:
			word += h.name.substr(h.name.length() - 1)
		_check(word == "PERSISTINT", "the letters spell PERSISTINT (%s)" % word)
		var tiers: Array = wm.tiers()
		_check(tiers.size() >= 6 and wm.chime_ins().size() == 2, "tiers and two chime-ins in data")
		_check(wm.speaker("letters") == "silverman" and wm.speaker("reason") == "warren" and wm.speaker("last_word") == "richter", "the three speakers")
		_check(Letters.tier_for(0, tiers).is_empty(), "no tier below the first tap")
		_check((Letters.tier_for(1, tiers)["lines"] as Array).has("hee hee hee") and (Letters.tier_for(3, tiers)["lines"] as Array).has("ooh, stop it"), "taps 1-3 giggle")
		_check(Letters.tier_for(4, tiers)["lines"][0] == "come on, enough", "tap 4 is enough")
		_check(float(Letters.tier_for(5, tiers).get("sulk_seconds", 0)) > 0.0 and String(Letters.tier_for(5, tiers)["lines"][0]).ends_with("bad touch"), "tap 5 is bad touch and a sulk")
		_check(String(Letters.tier_for(7, tiers)["lines"][0]).begins_with("are you going to sit here"), "taps 6-7 ask about playing the game")
		_check(String(Letters.tier_for(9, tiers)["lines"][0]).begins_with("see that button?"), "taps 8-9 point at the button")
		_check(String(Letters.tier_for(11, tiers)["lines"][0]).begins_with("thanks."), "taps 10-11 say thanks")
		_check(String(Letters.tier_for(20, tiers)["lines"][0]).begins_with("Stop. Okay. Enough."), "tap 12 and past is the last tier")
		# hit areas: every letter clear of every button; a point on a letter finds it
		var buttons: Array[Control] = []
		for n in ["BeginButton", "NewButton", "SupportButton"]:
			buttons.append(current_scene.get_node("Center/Panel/VBox/" + n))
		await process_frame
		var clear := true
		for h in wm.letters:
			var sp: Sprite2D = h.get_node("Sprite")
			var r: Rect2 = (wm.global_transform * h.transform * sp.transform) * sp.get_rect()
			for b in buttons:
				if b.visible and r.intersects(b.get_global_rect()):
					clear = false
		_check(clear, "no letter overlaps a menu button")
		var first: Node2D = wm.letters[0]
		_check(wm.letter_at(first.position) == 0 and wm.letter_at(Vector2(5, 300)) == -1, "letter_at finds the P and nothing in the sea")
		var ph: float = wm.beat_phase()
		_check(ph >= 0.0 and ph < 1.0, "beat phase is a fraction")
		# taps: giggles with hearts, then the tiers, a sulk that ignores taps, the chime-ins
		wm.tap(0)
		_check(wm.spoken.size() == 1 and wm.spoken[0]["speaker"] == "silverman" and (Letters.tier_for(1, tiers)["lines"] as Array).has(wm.spoken[0]["text"]), "the first tap giggles as silverman")
		_check(wm.hearts_flying() >= 3, "hearts pop out (%d)" % wm.hearts_flying())
		_check(first.get_node("BarkBubble").visible and first.get_node("BarkBubble").text == wm.spoken[0]["text"], "the bubble shows the line")
		var bb: Control = first.get_node("BarkBubble")
		var bb_top: float = (first.global_position + bb.position).y
		_check(bb_top > first.global_position.y and bb_top + bb.size.y < 360.0 and bb_top >= 0.0, "the letter's bubble hangs below it, on screen")
		_check(wm.get_index() > current_scene.get_node("Center").get_index(), "the letters and their bubbles draw over the menu panel")
		wm.tap(1)
		wm.tap(2)
		_check(wm.spoken.size() == 3 and wm.spoken[1]["text"] != wm.spoken[0]["text"], "giggles rotate")
		wm.tap(3)
		_check(wm.spoken[3]["text"] == "come on, enough" and int(wm.count) == 4, "the fourth tap in a row is enough")
		wm.tap(4)
		_check(String(wm.spoken[4]["text"]).ends_with("bad touch") and wm.sulk_left > 0.0, "the fifth is bad touch, the letters sulk")
		wm.tap(5)
		_check(wm.spoken.size() == 5 and int(wm.count) == 5, "a tap during the sulk is ignored")
		wm._process(wm.sulk_left + 0.01)
		_check(wm.sulk_left == 0.0, "the sulk passes")
		for i in 4:
			wm.tap(i % 10)
		var chimes: Array = wm.spoken.filter(func(d: Dictionary) -> bool: return d["speaker"] == "warren")
		_check(chimes.size() == 1 and String(chimes[0]["text"]).begins_with("Look, did you hear what she said?"), "past nine taps the voice of reason chimes in once (count %.1f)" % wm.count)
		_check(wm._aside.get_node("BarkBubble").visible, "the chime-in has its own bubble")
		for i in 5:
			wm.tap(i)
			if wm.sulk_left > 0.0:
				wm._process(wm.sulk_left + 0.01)
		var last: Array = wm.spoken.filter(func(d: Dictionary) -> bool: return d["speaker"] == "richter")
		_check(last.size() == 1 and String(last[0]["text"]).begins_with("Okay, look, you gotta just click"), "past fourteen the last word steps in once (count %.1f)" % wm.count)
		_check(wm.spoken.filter(func(d: Dictionary) -> bool: return d["speaker"] == "warren").size() == 1, "the voice of reason does not repeat while the count stays high")
		# decay: back to the giggles, the chime-ins re-armed
		wm._process(60.0)
		_check(wm.count == 0.0, "the counter decays to nothing")
		wm.tap(0)
		_check((Letters.tier_for(1, tiers)["lines"] as Array).has(wm.spoken[-1]["text"]), "after the decay a tap giggles again")
		wm.count = 8.0
		wm.tap(1)
		_check(wm.spoken.filter(func(d: Dictionary) -> bool: return d["speaker"] == "warren").size() == 2, "the voice of reason chimes in again once the count has come down and gone back up")
		# the beat moves the letters
		var s0: Vector2 = first.get_node("Sprite").scale
		var moved := false
		for i in 30:
			wm._process(0.033)
			if first.get_node("Sprite").scale != s0:
				moved = true
		_check(moved, "the letters jiggle with the beat")

	print("RESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails else 0)
