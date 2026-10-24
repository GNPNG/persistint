shader_type canvas_item;
// Flat silhouette: every opaque texel becomes `tint`. Drawn under a sprite, offset by the edge
// width in eight directions, it is the engine-side paper border; drawn once, black and translucent,
// offset down-right, it is a hard drop shadow. One texture read per texel, nothing else.

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, a * tint.a);
}
