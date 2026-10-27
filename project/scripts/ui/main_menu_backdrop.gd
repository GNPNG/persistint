extends Node2D
class_name MainMenuBackdrop
## The animated title screen behind the main menu (bd persistint-game-3m3), the author's spec:
## the island and the wreck with waves crashing and the day sped up into a day-and-night cycle;
## palms swaying; birds flying, landing and flying again, sped up with the sun; charms falling
## slowly and peacefully in the foreground like anime cherry-blossom petals, blurred with depth
## (hearts, Atwood's skull, polar bear cubs, the Seal of the O book-club seal, a chibi uterus in
## estrus that winks); the O drawn very slowly over the title theme so it sits finished at about
## 80% of the track, then a blood trickle down until the track ends, a fade, and a reset. The O
## is the book trailer poster's (site/public/img/trailer-poster.jpg): a thick, uneven dark-red
## brush-stroke ring revealed along its stroke (shaders/reveal_ring.gdshader), then its drips
## growing down.
## The layers come from tools/gen_title_fx.py; data/title_layout.json says where they go, in the
## 640x360 world px of the menu. Everything is plain sprites and two tiny shaders (shaders/
## sway.gdshader, shaders/reveal_ring.gdshader), so it runs in the web export's GL
## Compatibility renderer.

const LAYOUT := "res://data/title_layout.json"
const DIR := "res://assets/ui/title/"
const SWAY_SHADER := "res://shaders/sway.gdshader"
const REVEAL_SHADER := "res://shaders/reveal_ring.gdshader"
const TEXTURES := {
	"sky_day": DIR + "sky_day.png", "sky_dusk": DIR + "sky_dusk.png", "sky_night": DIR + "sky_night.png",
	"clouds": DIR + "clouds.png", "waves": DIR + "waves.png", "foam": DIR + "foam.png",
	"island": DIR + "island.png", "sun": DIR + "sun.png", "moon": DIR + "moon.png",
	"bird": DIR + "bird.png", "o_ring": DIR + "o_ring.png", "o_drip": DIR + "o_drip.png",
	"tree_a": "res://assets/canon/deco_tree_a.png", "tree_b": "res://assets/canon/deco_tree_b.png",
	"tree_c": "res://assets/canon/deco_tree_c.png",
	"palm_a": "res://assets/florida/prop_palm_a.png", "palm_b": "res://assets/florida/prop_palm_b.png",
}
const CHARM_KINDS: Array[String] = ["heart", "sparkle", "skull", "cub", "seal", "uterus"]
## Depth layers, far to near: texture suffix, scale of the 4x charm art, alpha, fall speed (px/s),
## sway amplitude (px), rotation amplitude (rad), how many charms.
const CHARM_LAYERS := [
	{"suffix": "_far", "scale": 0.12, "alpha": 0.55, "fall": 5.0, "sway": 3.0, "rot": 0.12, "count": 7},
	{"suffix": "_mid", "scale": 0.18, "alpha": 0.8, "fall": 9.0, "sway": 5.0, "rot": 0.18, "count": 6},
	{"suffix": "", "scale": 0.27, "alpha": 1.0, "fall": 14.0, "sway": 8.0, "rot": 0.25, "count": 5},
]
const DAY_SECONDS := 36.0        # one sped-up day and night
const O_DONE := 0.8              # the O is complete at this fraction of the track (spec: 75-85%)
const FADE_SECONDS := 2.0        # the O and its drips fade out over the track's last seconds
const O_STEPS := 240             # the reveal moves in steps of 1/240 of the turn
const NIGHT_TINT := Color(0.6, 0.64, 0.9)
const DUSK_TINT := Color(1.0, 0.94, 0.9)
const BIRD_SPEED := 150.0        # world px per second (the birds are sped up like the sun)
const BIRD_COUNT := 3
const STAR_COUNT := 14
const TREE_SCALE := 0.25         # canon trees are 4x of 40x52 world px
const PALM_SCALE := 0.17         # Florida palms are 4x; 52x65 world px here
const WINK_SECONDS := 0.22

var layout: Dictionary = {}
var day_t := 0.0                 # 0 sunrise, 0.25 noon, 0.5 sunset, 0.75 midnight
var track_pos := 0.0             # seconds into the title theme (resynced to the player)
var follow_music := true         # off once set_time() drives it (tests, previews)
var charms: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var trees: Array[Sprite2D] = []
var _tex: Dictionary = {}
var _charm_tex: Dictionary = {}  # "<kind><suffix>" -> Texture2D
var _sky: Dictionary = {}        # "day" / "dusk" / "night" -> Sprite2D
var _stars: Array[Sprite2D] = []
var _sun: Sprite2D
var _moon: Sprite2D
var _world: Node2D
var _clouds: Array[Sprite2D] = []
var _o_ring: Sprite2D
var _o_drip: Sprite2D
var _o_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	_rng.seed = 7
	layout = _load_layout()
	for key: String in TEXTURES:
		_tex[key] = load(TEXTURES[key])
	_build_sky()
	_build_world()
	_build_o()
	_apply_sky(day_t)
	_apply_o()
	# The charms come a frame later: creating all forty-odd textures inside one frame stalls
	# some GL drivers (seen on Mesa's D3D12 layer under WSL), and nothing needs them yet.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for layer: Dictionary in CHARM_LAYERS:
		for kind: String in CHARM_KINDS + ["uterus_wink"]:
			_charm_tex[kind + String(layer["suffix"])] = load("%scharm_%s%s.png" % [DIR, kind, layer["suffix"]])
	_build_charms()


## data/title_layout.json, or {} (the scene still builds with the defaults below).
static func _load_layout() -> Dictionary:
	if not FileAccess.file_exists(LAYOUT):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return parsed if parsed is Dictionary else {}


# --- Timeline math (pure; tests/test_title_anim.gd checks it) ------------------------------

## Where the O, the drips and their fade are at `pos` seconds into a `length`-second track:
## "o" 0..1 (complete at O_DONE of the track), "trickle" 0..1 (from then to the end), "alpha"
## 1 until the last FADE_SECONDS, then down to 0 at the end.
static func timeline(pos: float, length: float) -> Dictionary:
	var len := maxf(length, 1.0)
	var o_end := len * O_DONE
	var p := clampf(pos, 0.0, len)
	return {
		"o": clampf(p / o_end, 0.0, 1.0),
		"trickle": clampf((p - o_end) / maxf(len - o_end, 0.001), 0.0, 1.0),
		"alpha": clampf((len - p) / FADE_SECONDS, 0.0, 1.0),
	}


## How much of each sky shows at day fraction `t` (the three sum to 1): day around noon, night
## around midnight, dusk (the golden hour of the title art) at sunrise and sunset.
static func sky_mix(t: float) -> Dictionary:
	var s := sin(t * TAU)
	var day := clampf(s * 1.6 - 0.2, 0.0, 1.0)
	var night := clampf(-s * 1.6 - 0.2, 0.0, 1.0)
	return {"day": day, "dusk": 1.0 - day - night, "night": night}


## The tint on the island, trees, sea and birds at day fraction `t`.
static func world_tint(t: float) -> Color:
	var m := sky_mix(t)
	return Color.WHITE.lerp(NIGHT_TINT, m["night"]).lerp(DUSK_TINT, m["dusk"] * 0.5)


## Where a body (the sun for the day half, the moon for the night half) is at `u` 0..1 along
## its arc from the left horizon over the top to the right horizon.
static func arc_point(u: float) -> Vector2:
	return Vector2(lerpf(-30.0, 670.0, u), 212.0 - 192.0 * sin(u * PI))


# --- Building ------------------------------------------------------------------------------

func _sprite(tex_key: String, pos: Vector2, scale_: float, centered := true, parent: Node = self) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex[tex_key]
	s.centered = centered
	s.position = pos
	s.scale = Vector2(scale_, scale_)
	parent.add_child(s)
	return s


func _build_sky() -> void:
	for key in ["day", "dusk", "night"]:
		var s := _sprite("sky_" + key, Vector2.ZERO, 1.0, false)
		s.name = "Sky" + key.capitalize()
		_sky[key] = s
	var stars := Node2D.new()
	stars.name = "Stars"
	add_child(stars)
	var sea_top := float(layout.get("sea_top", 196))
	for i in STAR_COUNT:
		var st := Sprite2D.new()
		st.texture = load(DIR + "charm_sparkle.png")
		st.position = Vector2(_rng.randf_range(10, 630), _rng.randf_range(8, sea_top * 0.8))
		st.scale = Vector2.ONE * _rng.randf_range(0.05, 0.1)
		stars.add_child(st)
		_stars.append(st)
	_sun = _sprite("sun", arc_point(0.0), 0.25)
	_sun.name = "Sun"
	_moon = _sprite("moon", arc_point(0.0), 0.25)
	_moon.name = "Moon"


func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	var cl: Dictionary = layout.get("clouds", {"scale": 0.5, "y": 0})
	for i in 2:
		var c := _sprite("clouds", Vector2(i * 640.0, float(cl.get("y", 0))), float(cl.get("scale", 0.5)), false, _world)
		c.name = "Clouds%d" % i
		_clouds.append(c)
	var wv: Dictionary = layout.get("waves", {"y": 196, "frame_w": 640, "frame_h": 164, "frames": 4, "scale": 0.5, "fps": 3})
	_add_sheet("Waves", "waves", wv, Vector2(0, float(wv.get("y", 196))))
	var fo: Dictionary = layout.get("foam", {"x": 24, "y": 224, "frame_w": 592, "frame_h": 136, "frames": 6, "scale": 0.5, "fps": 5})
	_add_sheet("Foam", "foam", fo, Vector2(float(fo.get("x", 24)), float(fo.get("y", 224))))
	var isl: Dictionary = layout.get("island", {"x": 36, "y": 170, "scale": 0.25})
	var island := _sprite("island", Vector2(float(isl.get("x", 36)), float(isl.get("y", 170))), float(isl.get("scale", 0.25)), false, _world)
	island.name = "Island"
	var shader: Shader = load(SWAY_SHADER)
	for t: Dictionary in layout.get("trees", []):
		trees.append(_add_swaying("tree_" + String(t.get("kind", "a")), Vector2(float(t["x"]), float(t["y"])), TREE_SCALE, shader, 3.0))
	for p: Dictionary in layout.get("palms", []):
		trees.append(_add_swaying("palm_" + String(p.get("kind", "a")), Vector2(float(p["x"]), float(p["y"])), PALM_SCALE, shader, 6.0))
	_build_birds()


## A sheet (one frame per row, frames stacked down) as a looping AnimatedSprite2D in the world.
func _add_sheet(node_name: String, tex_key: String, spec: Dictionary, pos: Vector2) -> AnimatedSprite2D:
	var sheet: Texture2D = _tex[tex_key]
	var fw := float(spec.get("frame_w", 640)) / float(spec.get("scale", 0.5))
	var fh := float(spec.get("frame_h", 164)) / float(spec.get("scale", 0.5))
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("loop")
	frames.set_animation_speed("loop", float(spec.get("fps", 4)))
	frames.set_animation_loop("loop", true)
	for i in int(spec.get("frames", 1)):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(0.0, i * fh, fw, fh)
		frames.add_frame("loop", at)
	var a := AnimatedSprite2D.new()
	a.name = node_name
	a.sprite_frames = frames
	a.centered = false
	a.position = pos
	a.scale = Vector2.ONE * float(spec.get("scale", 0.5))
	_world.add_child(a)
	a.play("loop")
	return a


## A tree or palm standing with its foot at `foot`, leaning in the breeze (shaders/sway.gdshader).
func _add_swaying(tex_key: String, foot: Vector2, scale_: float, shader: Shader, amplitude: float) -> Sprite2D:
	var tex: Texture2D = _tex[tex_key]
	var s := _sprite(tex_key, foot - Vector2(tex.get_width() * scale_ / 2.0, tex.get_height() * scale_), scale_, false, _world)
	s.name = tex_key.capitalize() + str(trees.size())
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("amplitude", amplitude / scale_)
	mat.set_shader_parameter("speed", _rng.randf_range(1.2, 1.8))
	mat.set_shader_parameter("phase", _rng.randf_range(0.0, TAU))
	s.material = mat
	return s


func _build_birds() -> void:
	var holder := Node2D.new()
	holder.name = "Birds"
	_world.add_child(holder)
	var sheet: Texture2D = _tex["bird"]
	var fw := sheet.get_width() / 3.0
	for i in BIRD_COUNT:
		var s := Sprite2D.new()
		s.name = "Bird%d" % i
		s.hframes = 3
		s.texture = sheet
		s.scale = Vector2(0.25, 0.25)
		s.offset = Vector2(0, -fw * 0.4)
		holder.add_child(s)
		var perch := i % maxi(_perches().size(), 1)
		var b := {"sprite": s, "perch": perch, "next": perch, "flying": false, "wait": _rng.randf_range(1.0, 4.0) + i,
			"from": _perch(perch), "to": _perch(perch), "ctrl": _perch(perch), "t": 0.0, "dur": 1.0, "flap": 0.0}
		s.position = _perch(perch)
		s.frame = 2
		birds.append(b)


func _perches() -> Array:
	return layout.get("perches", [[150, 236], [250, 238], [385, 220], [548, 188], [80, 266], [455, 296]])


func _perch(i: int) -> Vector2:
	var p: Array = _perches()[i % _perches().size()]
	return Vector2(float(p[0]), float(p[1]))


func _build_o() -> void:
	var o: Dictionary = layout.get("o", {"cx": 100, "cy": 118, "r": 54, "ring_w": 150, "ring_h": 230, "ring_cx": 75, "ring_cy": 78, "scale": 0.25})
	var scale_ := float(o.get("scale", 0.25))
	var centre := Vector2(float(o.get("ring_cx", 75)), float(o.get("ring_cy", 78)))
	var top_left := Vector2(float(o.get("cx", 100)), float(o.get("cy", 118))) - centre
	_o_ring = _sprite("o_ring", top_left, scale_, false)
	_o_ring.name = "ORing"
	_o_mat = ShaderMaterial.new()
	_o_mat.shader = load(REVEAL_SHADER)
	_o_mat.set_shader_parameter("center", centre / scale_)
	_o_mat.set_shader_parameter("progress", 0.0)
	_o_ring.material = _o_mat
	_o_drip = _sprite("o_drip", top_left, scale_, false)
	_o_drip.name = "ODrip"
	_o_drip.region_enabled = true
	_o_drip.region_rect = Rect2(0, 0, _o_drip.texture.get_width(), 0)


func _build_charms() -> void:
	var holder := Node2D.new()
	holder.name = "Charms"
	add_child(holder)
	var kind_i := 0
	for layer_i in CHARM_LAYERS.size():
		var layer: Dictionary = CHARM_LAYERS[layer_i]
		var group := Node2D.new()
		group.name = "Layer%d" % layer_i
		holder.add_child(group)
		for i in int(layer["count"]):
			var kind: String = CHARM_KINDS[kind_i % CHARM_KINDS.size()]
			kind_i += 1
			var s := Sprite2D.new()
			s.name = "%s%d" % [kind.capitalize(), i]
			s.texture = _charm_tex[kind + String(layer["suffix"])]
			s.scale = Vector2.ONE * float(layer["scale"])
			s.modulate.a = float(layer["alpha"])
			group.add_child(s)
			var c := {"sprite": s, "kind": kind, "layer": layer_i, "x": _rng.randf_range(0.0, 640.0),
				"y": _rng.randf_range(-40.0, 360.0), "fall": float(layer["fall"]) * _rng.randf_range(0.85, 1.15),
				"sway": float(layer["sway"]), "speed": _rng.randf_range(0.5, 1.1), "phase": _rng.randf_range(0.0, TAU),
				"rot": float(layer["rot"]), "wink": _rng.randf_range(2.0, 7.0), "winking": 0.0,
				"open": s.texture, "shut": _charm_tex["uterus_wink" + String(layer["suffix"])] if kind == "uterus" else null}
			charms.append(c)
			_place_charm(c)


# --- Every frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	day_t = fposmod(day_t + delta / DAY_SECONDS, 1.0)
	_apply_sky(day_t)
	_move_clouds(delta)
	_move_birds(delta)
	_move_charms(delta)
	_advance_track(delta)
	_apply_o()


func _apply_sky(t: float) -> void:
	var m := sky_mix(t)
	# Stacked day (bottom), dusk, night (top): their alphas give the weighted mix of the three.
	var day_dusk := float(m["day"]) + float(m["dusk"])
	_sky["day"].modulate.a = 1.0
	_sky["dusk"].modulate.a = float(m["dusk"]) / day_dusk if day_dusk > 0.0 else 0.0
	_sky["night"].modulate.a = float(m["night"])
	for st in _stars:
		st.modulate.a = float(m["night"]) * (0.6 + 0.4 * sin(_time * 3.0 + st.position.x))
	var daytime := t < 0.5
	_sun.visible = daytime
	_moon.visible = not daytime
	_sun.position = arc_point(t * 2.0) if daytime else Vector2(-100, -100)
	_moon.position = arc_point((t - 0.5) * 2.0) if not daytime else Vector2(-100, -100)
	_world.modulate = world_tint(t)


func _move_clouds(delta: float) -> void:
	for c in _clouds:
		c.position.x -= 4.0 * delta
		if c.position.x <= -640.0:
			c.position.x += 1280.0


func _move_birds(delta: float) -> void:
	for b in birds:
		var s: Sprite2D = b["sprite"]
		if b["flying"]:
			b["t"] = minf(b["t"] + delta / b["dur"], 1.0)
			var u: float = b["t"]
			var p: Vector2 = b["from"].lerp(b["ctrl"], u).lerp(b["ctrl"].lerp(b["to"], u), u)
			s.flip_h = b["to"].x < b["from"].x
			s.position = p
			b["flap"] += delta
			s.frame = int(b["flap"] / 0.12) % 2
			if u >= 1.0:
				b["flying"] = false
				b["wait"] = _rng.randf_range(1.5, 5.0)
				b["perch"] = b["next"]
				if b["perch"] < 0:                                 # went off screen: comes back later
					s.visible = false
				s.frame = 2
		else:
			b["wait"] -= delta
			if b["wait"] <= 0.0:
				_launch_bird(b)


func _launch_bird(b: Dictionary) -> void:
	var s: Sprite2D = b["sprite"]
	var n := _perches().size()
	var from: Vector2 = s.position if b["perch"] >= 0 else Vector2(-20.0 if _rng.randf() < 0.5 else 660.0, _rng.randf_range(40.0, 150.0))
	var next := -1 if _rng.randf() < 0.2 else _rng.randi_range(0, n - 1)
	if next == b["perch"] and n > 1:
		next = (next + 1) % n
	var to: Vector2 = _perch(next) if next >= 0 else Vector2(-24.0 if _rng.randf() < 0.5 else 664.0, _rng.randf_range(30.0, 140.0))
	b["from"] = from
	b["to"] = to
	b["next"] = next
	b["ctrl"] = (from + to) / 2.0 - Vector2(0, _rng.randf_range(60.0, 130.0))
	b["dur"] = maxf(from.distance_to(to) / BIRD_SPEED, 0.4)
	b["t"] = 0.0
	b["flying"] = true
	s.visible = true
	s.position = from


func _move_charms(delta: float) -> void:
	for c in charms:
		c["y"] += c["fall"] * delta
		if c["y"] > 400.0:
			c["y"] = -40.0
			c["x"] = _rng.randf_range(0.0, 640.0)
		if c["shut"] != null:
			if c["winking"] > 0.0:
				c["winking"] -= delta
				if c["winking"] <= 0.0:
					c["sprite"].texture = c["open"]
			else:
				c["wink"] -= delta
				if c["wink"] <= 0.0:
					c["wink"] = _rng.randf_range(3.0, 8.0)
					c["winking"] = WINK_SECONDS
					c["sprite"].texture = c["shut"]
		_place_charm(c)


func _place_charm(c: Dictionary) -> void:
	var s: Sprite2D = c["sprite"]
	var ph: float = _time * c["speed"] + c["phase"]
	s.position = Vector2(c["x"] + c["sway"] * sin(ph), c["y"])
	s.rotation = c["rot"] * sin(ph * 0.7 + 1.0)


## Follows the title theme: the player's position when it plays (that also catches the loop),
## a clock of its own otherwise (the web build before its first click, or no rendered track).
func _advance_track(delta: float) -> void:
	var length := track_length()
	var p := _player_position() if follow_music else -1.0
	if p >= 0.0 and absf(p - track_pos) > 0.75:
		track_pos = p
	else:
		track_pos += delta
	if track_pos >= length:
		track_pos = fmod(track_pos, length)


func track_length() -> float:
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("playing_stream"):
		var stream: AudioStream = music.playing_stream()
		if stream != null and stream.get_length() > 1.0:
			return stream.get_length()
	return float(layout.get("track_seconds_fallback", 172.0))


func _player_position() -> float:
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("active_player") and music.playing_stream() != null:
		var p: AudioStreamPlayer = music.active_player()
		if p != null and p.playing:
			return p.get_playback_position()
	return -1.0


## Reveals the O along its stroke and lets the drips down as far as the track position says.
func _apply_o() -> void:
	var tl := timeline(track_pos, track_length())
	_o_mat.set_shader_parameter("progress", floorf(float(tl["o"]) * O_STEPS) / O_STEPS)
	var tex: Texture2D = _o_drip.texture
	var shown := floorf(float(tl["trickle"]) * tex.get_height())
	_o_drip.region_rect = Rect2(0, 0, tex.get_width(), shown)
	_o_drip.visible = shown >= 1.0
	var a: float = tl["alpha"]
	_o_ring.modulate.a = a
	_o_drip.modulate.a = a


## The reveal of the O, 0..1 (what the shader was last told).
func o_progress() -> float:
	return float(_o_mat.get_shader_parameter("progress"))


## How far down the drips show, 0..1 of their texture.
func drip_progress() -> float:
	return _o_drip.region_rect.size.y / float(_o_drip.texture.get_height())


## For tests and previews: jump to `seconds` into the track and the day fraction `day`; from
## then on the backdrop keeps its own time instead of following the music.
func set_time(seconds: float, day := -1.0) -> void:
	follow_music = false
	track_pos = seconds
	if day >= 0.0:
		day_t = fposmod(day, 1.0)
		_apply_sky(day_t)
	_apply_o()
