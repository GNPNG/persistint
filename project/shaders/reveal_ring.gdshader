// Reveals a painted ring along its stroke: everything past `progress` of the turn from the top,
// clockwise round `center` (in texture pixels), is hidden; the edge of the reveal is feathered.
// The title screen's O (scenes/ui/main_menu_backdrop.tscn) is drawn this way over the track.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(300.0, 312.0);
uniform float feather : hint_range(0.0, 0.2) = 0.012;

void fragment() {
	vec4 c = COLOR;                                 // the texture times the sprite's modulate (its fade)
	vec2 d = UV / TEXTURE_PIXEL_SIZE - center;
	float a = atan(d.x, -d.y);                      // 0 at the top, growing clockwise
	float turn = (a < 0.0 ? a + TAU : a) / TAU;
	float shown = 1.0 - smoothstep(progress, progress + feather, turn);
	COLOR = vec4(c.rgb, c.a * shown);
}
