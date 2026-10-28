extends SceneTree
## Sticker peel (bd ulsb, StickerPeel): it ships off (the player's shadow has no peel and no
## material) and the review flag reads as a strength; the shader declares every uniform the script
## sets. The state machine runs idle -> peel -> walk -> settle -> idle on its timings at 60 fps
## (PEEL_TIME + RELAX_TIME, then SETTLE_TIME, each within a frame): flat on the first frame she
## moves, the trailing corner lifting to MAX_LIFT with a ripple that dies away, the low lift held
## while she walks, a press past flat when she stops, and a new peel from the lift it has when
## she walks on mid-settle. Forced on in the village, the player moves on the first physics frame
## the key is down, before the peel has even started (the walk never waits for it), and the peel
## runs and settles with her.
## Run: godot --headless --path project -s tests/test_sticker_peel.gd

const DT := 1.0 / 60.0
## Where she starts walking right in the village: land with nothing in the way for 150 px.
const WALK_FROM := Vector2(944, 890)
const UNIFORMS := ["frame_rect", "px_per_world", "flip", "corner", "lift_dir", "lift", "reach", "soft",
	"ripple", "ripple_waves", "ripple_phase"]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	StickerPeel.force = ""
	_check(not StickerPeel.ENABLED and StickerPeel.strength() == "", "off by default (ENABLED false, no review flag)")
	var flags := {"subtle": "subtle", " Very-Subtle ": "very_subtle", "1": StickerPeel.DEFAULT_STRENGTH,
		"on": StickerPeel.DEFAULT_STRENGTH, "0": "off", "off": "off", "loud": "", "": ""}
	for raw: String in flags:
		_check(StickerPeel.sanitize(raw) == flags[raw], "review flag '%s' reads as '%s'" % [raw, flags[raw]])
	StickerPeel.force = "very_subtle"
	_check(StickerPeel.strength() == "very_subtle", "force turns it on at a strength")
	StickerPeel.force = "off"
	_check(StickerPeel.strength() == "", "force off keeps it off")
	StickerPeel.force = ""

	_check(StickerPeel.corner_for(Vector2.RIGHT) == Vector2(-1, 1), "walking right lifts the bottom-left corner")
	_check(StickerPeel.corner_for(Vector2.LEFT) == Vector2(1, 1), "walking left lifts the bottom-right corner")
	_check(StickerPeel.corner_for(Vector2.UP) == Vector2(1, 1), "walking up lifts the bottom-right corner")
	_check(StickerPeel.corner_for(Vector2.DOWN) == Vector2(1, -1), "walking down lifts the top-right corner")
	_check(StickerPeel.corner_for(Vector2(1, -1)) == Vector2(-1, 1), "walking up and right lifts the bottom-left corner")

	var shader: Shader = load(StickerPeel.SHADER_PATH)
	_check(shader != null and shader.code.contains("shader_type canvas_item"), "the peel shader loads")
	if shader != null:
		for u: String in UNIFORMS:
			var re := RegEx.create_from_string("uniform\\s+\\w+\\s+%s\\b" % u)
			_check(re.search(shader.code) != null, "the shader declares uniform %s" % u)

	_timing()
	await _live()
	StickerPeel.force = ""
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)


## The state machine alone (no shadow), stepped at 60 fps.
func _timing() -> void:
	var p := StickerPeel.new()
	for i in 10:
		p.step(DT, false, Vector2.ZERO)
	_check(p.state == StickerPeel.State.IDLE and p.lift == 0.0, "standing: idle and flat")
	p.step(DT, true, Vector2.RIGHT)
	_check(p.state == StickerPeel.State.PEEL and p.time == 0.0 and p.lift == 0.0,
		"the first frame she moves starts the peel, still flat at t = 0")
	_check(p.corner == Vector2(-1, 1), "the trailing corner lifts")
	var frames := 0
	var top := 0.0
	var last := 0.0
	var rises := true
	var ripples: Array[float] = []
	while p.state == StickerPeel.State.PEEL and frames < 200:
		p.step(DT, true, Vector2.RIGHT)
		frames += 1
		if p.state == StickerPeel.State.PEEL and p.time <= StickerPeel.PEEL_TIME:
			rises = rises and p.lift >= last
		last = p.lift
		top = maxf(top, p.lift)
		if frames == 3 or frames == 9:
			ripples.append(p.ripple)
	var want := roundi((StickerPeel.PEEL_TIME + StickerPeel.RELAX_TIME) / DT)
	_check(absi(frames - want) <= 1, "peel and relax last %d frames (want %d, one either way)" % [frames, want])
	_check(rises, "the corner rises through the peel")
	_check(absf(top - StickerPeel.MAX_LIFT) < 0.02, "it peaks at MAX_LIFT (%.3f)" % top)
	_check(ripples.size() == 2 and ripples[0] > ripples[1] and ripples[1] > 0.0, "the ripple dies away (%s)" % [ripples])
	_check(p.state == StickerPeel.State.WALK and is_equal_approx(p.lift, StickerPeel.MAX_LIFT * StickerPeel.WALK_LIFT)
		and p.ripple == 0.0, "walking: the low lift held, no ripple")
	for i in 30:
		p.step(DT, true, Vector2.UP)
	_check(p.state == StickerPeel.State.WALK and p.corner == Vector2(-1, 1), "turning while walking keeps the corner")

	p.step(DT, false, Vector2.ZERO)
	_check(p.state == StickerPeel.State.SETTLE, "stopping starts the settle on that frame")
	frames = 0
	var lowest := 0.0
	while p.state == StickerPeel.State.SETTLE and frames < 200:
		p.step(DT, false, Vector2.ZERO)
		frames += 1
		lowest = minf(lowest, p.lift)
	want = roundi(StickerPeel.SETTLE_TIME / DT)
	_check(absi(frames - want) <= 1, "the settle lasts %d frames (want %d, one either way)" % [frames, want])
	_check(lowest < 0.0, "the settle presses past flat (%.3f)" % lowest)
	_check(p.state == StickerPeel.State.IDLE and p.lift == 0.0 and p.soft == 0.0 and p.ripple == 0.0, "then idle and flat")

	p.step(DT, true, Vector2.LEFT)
	_check(p.corner == Vector2(1, 1), "the next walk takes its own trailing corner")
	for i in 25:
		p.step(DT, true, Vector2.LEFT)
	p.step(DT, false, Vector2.ZERO)
	for i in 4:
		p.step(DT, false, Vector2.ZERO)
	var before := p.lift
	p.step(DT, true, Vector2.LEFT)
	_check(p.state == StickerPeel.State.PEEL and absf(p.lift - before) < 0.0001,
		"walking on mid-settle peels again from the lift it had")

	var v := StickerPeel.new(null, "very_subtle")
	for i in 13:
		v.step(DT, true, Vector2.RIGHT)
	_check(absf(v.lift - StickerPeel.MAX_LIFT * StickerPeel.STRENGTH_SCALE["very_subtle"]) < 0.02,
		"very subtle peaks at its share of MAX_LIFT (%.3f)" % v.lift)


## The player in the village: as shipped, then forced on.
func _live() -> void:
	StickerPeel.force = ""
	change_scene_to_file("res://scenes/maps/village.tscn")
	for i in 3:
		await process_frame
	var p: CharacterBody2D = current_scene.get_tree().get_first_node_in_group("player")
	var shadow: AnimatedSprite2D = p.get_node("PaperShadow")
	_check(p.get("_peel") == null and shadow.material == null, "as shipped the player's shadow has no peel and no material")

	StickerPeel.force = "subtle"
	change_scene_to_file("res://scenes/maps/village.tscn")
	for i in 3:
		await process_frame
	p = current_scene.get_tree().get_first_node_in_group("player")
	shadow = p.get_node("PaperShadow")
	var peel: StickerPeel = p.get("_peel")
	var mat := shadow.material as ShaderMaterial
	_check(peel != null and mat != null and mat.shader != null and mat.shader.resource_path == StickerPeel.SHADER_PATH,
		"forced on, the player's shadow carries the peel's material")
	if peel == null or mat == null:
		return
	var rect: Vector4 = mat.get_shader_parameter("frame_rect")
	_check(rect.z > 0.0 and rect.w > 0.0 and is_equal_approx(float(mat.get_shader_parameter("px_per_world")), 1.0 / shadow.scale.x),
		"the peel took the shadow's frame and scale (%s)" % [rect])
	_check(peel.state == StickerPeel.State.IDLE, "standing she is flat")

	# The open ground the peel shots walk (tools/shots/wso.json village-village-peel_*).
	p.global_position = WALK_FROM
	p.velocity = Vector2.ZERO
	for i in 3:
		await physics_frame
	var start := p.global_position
	# This runs inside the physics_frame signal, which the tree emits before it calls the nodes'
	# _physics_process, so the key is down for this very physics frame and she moves in it. The
	# process_frame signal comes next, before the nodes' _process, so the check below reads her
	# moved and the peel not yet stepped. One more physics_frame here would read a frame late,
	# after her _process has started the peel (on the first frame she moves, as it should).
	Input.action_press("move_right")
	await process_frame
	_check(p.velocity.x > 0.0 and p.global_position.x > start.x and peel.state == StickerPeel.State.IDLE,
		"she moves on the first physics frame the key is down, before the peel starts (velocity %s, %.2f px, %s)"
		% [p.velocity, p.global_position.x - start.x, StickerPeel.State.keys()[peel.state]])
	await process_frame
	_check(peel.state == StickerPeel.State.PEEL, "the peel starts as she walks")
	var ticks := 0
	while peel.state == StickerPeel.State.PEEL and ticks < 120:
		await physics_frame
		ticks += 1
	_check(peel.state == StickerPeel.State.WALK, "then she walks on with the corner held")
	_check(float(mat.get_shader_parameter("lift")) > 0.0, "the shader shows the held lift")
	Input.action_release("move_right")
	ticks = 0
	while peel.state != StickerPeel.State.IDLE and ticks < 120:
		await physics_frame
		ticks += 1
	_check(peel.state == StickerPeel.State.IDLE and float(mat.get_shader_parameter("lift")) == 0.0,
		"stopping, she settles back flat")
