class_name StickerPeel
extends RefCounted
## StickerPeel (bd ulsb): the paper character as a sticker being peeled up. When she starts to
## walk, her baked soft shadow (PaperBake shadow_soft) lifts from one corner, the trailing corner
## of the way she goes: under the lifted flap it moves further out and goes softer, with a faint
## ripple along the lifting edge that dies away (PEEL_TIME). It then relaxes to a low lift held
## while she walks (WALK_LIFT), and when she stops it presses down flat, a little past flat and
## back (SETTLE_TIME). Purely visual: the walk never waits for it, it only reads whether she
## moves. One ShaderMaterial on the shadow sprite (shaders/sticker_peel.gdshader), on the baked
## sheets as they are, made once when the player is built (so its shader compiles with the scene,
## not on her first step) and nothing allocated per frame; standing still the script returns at
## once and sets nothing, and the shader draws the plain shadow. Off, there is no material at all.
##
## Off until the author approves it (ENABLED). For review it is turned on per run: the web build
## with ?peel=subtle or ?peel=very_subtle (?peel=1 is DEFAULT_STRENGTH), the desktop binary with
## `-- --peel=subtle`; shots and tests set `force`. Wired to the player only (player.gd); it
## takes any AnimatedSprite2D shadow with a frame grid, so an NPC could use it the same way.
## The game has no reduced-motion setting yet; when it does, strength() should give "" under it.
## Names no autoload, so tests under `godot -s` can use it directly.

enum State { IDLE, PEEL, WALK, SETTLE }

const SHADER_PATH := "res://shaders/sticker_peel.gdshader"
## Off by default: on only for review (`force`, ?peel=, --peel=) until the author approves it.
const ENABLED := false
const DEFAULT_STRENGTH := "subtle"
## Each strength scales MAX_LIFT, SOFTNESS and RIPPLE_AMP.
const STRENGTH_SCALE := {"subtle": 1.0, "very_subtle": 0.55}
## Seconds: the corner lifts over PEEL_TIME (she is already walking), relaxes to WALK_LIFT over
## RELAX_TIME, and presses back down flat over SETTLE_TIME once she stops.
const PEEL_TIME := 0.2
const RELAX_TIME := 0.15
const SETTLE_TIME := 0.18
## World px the shadow moves at the very corner of the frame at the height of the peel (the
## frame is padded, so the figure's own corner moves about half of this).
const MAX_LIFT := 1.8
## The share of MAX_LIFT held while she walks (0: flat while walking).
const WALK_LIFT := 0.3
## How far past flat the settle presses the corner, as a share of MAX_LIFT.
const PRESS := 0.25
## How far the flap reaches in from the corner at the height of the peel, in frame widths along
## the diagonal (1: just past the middle of the frame).
const REACH := 1.0
## World px of extra blur at the corner at the height of the peel.
const SOFTNESS := 1.2
## The ripple along the lifting edge: world px at the corner when the peel starts, waves per frame
## width along the edge, waves per second running along it, and the seconds it takes to die to 1/e.
const RIPPLE_AMP := 0.6
const RIPPLE_WAVES := 3.0
const RIPPLE_HZ := 5.0
const RIPPLE_DECAY := 0.12
## The corner that lifts: the trailing corner of the way she starts to walk (TRAILING_CORNER), or
## always FIXED_CORNER. Corners are frame corners, x and y each -1 or 1 ((1, 1) the bottom right).
## An axis she hardly moves along (under AXIS_DEAD of the walk) takes DEFAULT_CORNER's side: the
## bottom right, the side the shadow falls to (PaperBake.SHADOW_OFFSET).
const TRAILING_CORNER := true
const FIXED_CORNER := Vector2(1, 1)
const DEFAULT_CORNER := Vector2(1, 1)
const AXIS_DEAD := 0.38
## The lifted shadow moves the way the light throws it (PaperBake.SHADOW_OFFSET) and this much
## out of the corner as well, so the lift shows at whichever corner it is.
const OUTWARD := 0.6

## A strength to run at, over ENABLED and the review flags: "" (no override), "off", or a key of
## STRENGTH_SCALE. Shots set it (shot_walk set_static); tests set it and put it back.
static var force := ""

var state := State.IDLE
## Seconds in the current state.
var time := 0.0
## What the shader shows now: the corner's lift (world px, negative while pressed), the flap's
## reach (frame widths), the ripple (world px) and its phase, the blur (world px), the corner.
var lift := 0.0
var reach := 0.0
var ripple := 0.0
var phase := 0.0
var soft := 0.0
var corner := DEFAULT_CORNER
## The strength's scale (STRENGTH_SCALE).
var amount := 1.0

var _from := 0.0  # lift when the current state began
var _reach_from := 0.0  # reach when the current state began
var _target: AnimatedSprite2D
var _mat: ShaderMaterial
var _flip := false


## The strength the peel runs at, "" when it is off: `force` when set, else the review flag
## (requested()), else DEFAULT_STRENGTH when ENABLED.
static func strength() -> String:
	var asked := force if force != "" else requested()
	if asked == "off":
		return ""
	if STRENGTH_SCALE.has(asked):
		return asked
	return DEFAULT_STRENGTH if ENABLED else ""


## The strength asked for on this run: ?peel= on the web build, --peel= after `--` on desktop
## (as DevScene reads ?scene=); "" when none.
static func requested() -> String:
	var raw := ""
	if OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('peel') || ''", true)
		raw = str(v) if v != null else ""
	else:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--peel="):
				raw = a.trim_prefix("--peel=")
	return sanitize(raw)


## A review flag's value as a strength: a key of STRENGTH_SCALE ("very-subtle" too), "off" for
## 0/off/false/no, DEFAULT_STRENGTH for 1/on/true/yes; "" for anything else.
static func sanitize(raw: String) -> String:
	var s := raw.strip_edges().to_lower().replace("-", "_")
	if s in ["1", "on", "true", "yes"]:
		return DEFAULT_STRENGTH
	if s in ["0", "off", "false", "no"]:
		return "off"
	return s if STRENGTH_SCALE.has(s) else ""


## The corner that lifts when she starts to walk along `dir` (see TRAILING_CORNER).
static func corner_for(dir: Vector2) -> Vector2:
	if not TRAILING_CORNER:
		return FIXED_CORNER
	var c := DEFAULT_CORNER
	var n := dir.length()
	if n <= 0.0:
		return c
	if absf(dir.x) > AXIS_DEAD * n:
		c.x = -signf(dir.x)
	if absf(dir.y) > AXIS_DEAD * n:
		c.y = -signf(dir.y)
	return c


## A peel at `strength_name` (a key of STRENGTH_SCALE) for `shadow`, which gets the peel's
## material; fit() takes its frame once it shows one. With no shadow it is the timing alone (tests).
func _init(shadow: AnimatedSprite2D = null, strength_name := DEFAULT_STRENGTH) -> void:
	amount = float(STRENGTH_SCALE.get(strength_name, 1.0))
	_target = shadow
	if shadow == null:
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_mat.set_shader_parameter(&"ripple_waves", RIPPLE_WAVES)
	shadow.material = _mat
	fit()
	_push()


## Takes the shadow's frame and scale again: call it after the shadow gets new frames or is fitted
## again (the player's outfit changing).
func fit() -> void:
	if _mat == null:
		return
	var fr := SpriteFit.frame_size(_target)
	if fr.x <= 0.0 or fr.y <= 0.0 or _target.scale.x == 0.0:
		return
	var lo := _target.offset - (fr / 2.0 if _target.centered else Vector2.ZERO)
	_mat.set_shader_parameter(&"frame_rect", Vector4(lo.x, lo.y, fr.x, fr.y))
	_mat.set_shader_parameter(&"px_per_world", 1.0 / absf(_target.scale.x))


## One frame: `moving` is whether she walks this frame, `dir` the way (her velocity). Standing
## still and flat it returns at once and sets nothing.
func step(delta: float, moving: bool, dir: Vector2) -> void:
	match state:
		State.IDLE:
			if not moving:
				return
			corner = corner_for(dir)
			_enter(State.PEEL)
		State.PEEL:
			time += delta
			if not moving:
				_enter(State.SETTLE)
			elif time >= PEEL_TIME + RELAX_TIME:
				_enter(State.WALK)
		State.WALK:
			if not moving:
				_enter(State.SETTLE)
			elif _target == null or _target.flip_h == _flip:
				return  # the held lift: nothing changes while she walks on
		State.SETTLE:
			time += delta
			if moving:
				_enter(State.PEEL)  # the same corner, from the lift it has now
			elif time >= SETTLE_TIME:
				_enter(State.IDLE)
	_shape()
	_push()


func _enter(s: State) -> void:
	_from = lift
	_reach_from = reach
	state = s
	time = 0.0


## The lift, reach, ripple and blur for the state and its time.
func _shape() -> void:
	var top := MAX_LIFT * amount
	ripple = 0.0
	match state:
		State.IDLE:
			lift = 0.0
			reach = 0.0  # the next peel grows from the corner again
		State.PEEL:
			if time < PEEL_TIME:
				var u := 1.0 - time / PEEL_TIME
				var e := 1.0 - u * u * u  # quick off the corner, slowing to the top
				lift = lerpf(_from, top, e)
				reach = lerpf(_reach_from, REACH, e)
			else:
				var k := smoothstep(0.0, 1.0, (time - PEEL_TIME) / RELAX_TIME)
				lift = lerpf(top, top * WALK_LIFT, k)
				reach = REACH
			ripple = RIPPLE_AMP * amount * exp(-time / RIPPLE_DECAY)
			phase = TAU * RIPPLE_HZ * time
		State.WALK:
			lift = top * WALK_LIFT
			reach = REACH
		State.SETTLE:
			var u := clampf(time / SETTLE_TIME, 0.0, 1.0)
			var press := top * PRESS * clampf(_reach_from / REACH, 0.0, 1.0)
			lift = _from * (1.0 - u) * (1.0 - u) - press * sin(PI * u)
	soft = SOFTNESS * amount * clampf(lift / top, 0.0, 1.0) if top > 0.0 else 0.0


## Hands the shape to the shader.
func _push() -> void:
	if _mat == null:
		return
	_flip = _target.flip_h
	_mat.set_shader_parameter(&"flip", -1.0 if _flip else 1.0)
	_mat.set_shader_parameter(&"corner", corner)
	_mat.set_shader_parameter(&"lift_dir", (PaperBake.SHADOW_OFFSET.normalized() + corner.normalized() * OUTWARD).normalized())
	_mat.set_shader_parameter(&"lift", lift)
	_mat.set_shader_parameter(&"reach", reach)
	_mat.set_shader_parameter(&"soft", soft)
	_mat.set_shader_parameter(&"ripple", ripple)
	_mat.set_shader_parameter(&"ripple_phase", phase)
