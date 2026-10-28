// Sticker peel (bd ulsb): the player's baked soft shadow (PaperBake shadow_soft) lifts from one
// corner as she starts to walk, as a sticker does when it is peeled up: under the lifted flap the
// shadow moves further out and goes softer, with a faint ripple along the lifting edge, and when
// she stops it presses back down flat. The flap is a plane hinged on a fold line `reach` frame
// widths in from the corner, so how far the shadow moves grows linearly from the fold to the
// corner. scripts/util/sticker_peel.gd sets every uniform; with lift, ripple and soft at 0 this
// draws the shadow exactly as the plain sprite does (five reads of the same texel). Works on the
// baked sheets as they are: the frame is found from VERTEX (the sprite's local px), not from UV,
// which spans the whole sheet for an AtlasTexture frame.
shader_type canvas_item;

// One frame's rect in the sprite's local px: x, y, width, height.
uniform vec4 frame_rect = vec4(-0.5, -0.5, 1.0, 1.0);
// Local px per world px (1 / the sprite's scale).
uniform float px_per_world = 1.0;
// -1 while the sprite is flipped (flip_h): UV runs the other way across the frame.
uniform float flip = 1.0;
// The lifting corner of the frame, x and y each -1 or 1 (1, 1 is the bottom right).
uniform vec2 corner = vec2(-1.0, 1.0);
// The way the lifted shadow moves (a unit vector, world axes).
uniform vec2 lift_dir = vec2(0.86, 0.51);
// World px the shadow moves at the very corner; negative presses it in, under the sticker.
uniform float lift = 0.0;
// How far the flap reaches in from the corner, in frame widths along the diagonal.
uniform float reach = 1.0;
// World px of extra blur at the corner.
uniform float soft = 0.0;
// World px of ripple at the corner, and the ripple's waves per frame width along the edge.
uniform float ripple = 0.0;
uniform float ripple_waves = 3.0;
uniform float ripple_phase = 0.0;

varying vec2 v_local;
varying vec4 v_tint;

void vertex() {
	v_local = VERTEX;
	v_tint = COLOR;
}

// 1 inside the frame's rect, 0 outside: a moved read never takes the next cell of the sheet.
float inside(vec2 p) {
	vec2 lo = step(frame_rect.xy, p);
	vec2 hi = step(p, frame_rect.xy + frame_rect.zw);
	return lo.x * lo.y * hi.x * hi.y;
}

void fragment() {
	vec2 box = (v_local - frame_rect.xy) / frame_rect.zw;
	vec2 from_corner = box - (corner * 0.5 + 0.5);
	vec2 inward = -normalize(corner);
	float flap = clamp(1.0 - dot(from_corner, inward) / max(reach, 0.001), 0.0, 1.0);
	float along = dot(from_corner, vec2(-inward.y, inward.x));
	float wave = sin(along * ripple_waves * 6.2831853 + ripple_phase);
	vec2 d = lift_dir * (lift + ripple * wave) * flap * px_per_world;
	float r = max(soft, 0.0) * flap * px_per_world * 0.7071;
	vec2 to_uv = TEXTURE_PIXEL_SIZE * vec2(flip, 1.0);
	vec2 p = v_local - d;
	vec2 uv = UV - d * to_uv;
	vec4 sum = texture(TEXTURE, uv) * (inside(p) * 0.4);
	sum += texture(TEXTURE, uv + vec2(r, r) * to_uv) * (inside(p + vec2(r, r)) * 0.15);
	sum += texture(TEXTURE, uv + vec2(-r, r) * to_uv) * (inside(p + vec2(-r, r)) * 0.15);
	sum += texture(TEXTURE, uv + vec2(r, -r) * to_uv) * (inside(p + vec2(r, -r)) * 0.15);
	sum += texture(TEXTURE, uv + vec2(-r, -r) * to_uv) * (inside(p + vec2(-r, -r)) * 0.15);
	COLOR = v_tint * sum;
}
