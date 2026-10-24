shader_type canvas_item;
// Tap-to-pixelate (gsd, 2xr): snaps the texture lookup to `block`-texel cells, so the art turns
// into pixels for a moment and comes back. block 0 = untouched. Only assigned while the effect
// runs (the script swaps the material in and out), so idle sprites pay nothing.

uniform float block = 0.0;

void fragment() {
	vec2 uv = UV;
	if (block > 0.5) {
		vec2 cell = TEXTURE_PIXEL_SIZE * block;
		uv = (floor(UV / cell) + 0.5) * cell;
	}
	COLOR = texture(TEXTURE, uv);
}
