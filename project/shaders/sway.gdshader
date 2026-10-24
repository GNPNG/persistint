// Sways a sprite from its foot (the bottom edge stays put, the top leans): title-screen trees
// and palms (scenes/ui/main_menu_backdrop.tscn). Plain canvas_item vertex shader, fine on WebGL2.
shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 40.0) = 4.0; // px the top edge leans each way
uniform float speed : hint_range(0.0, 10.0) = 1.4;     // radians per second
uniform float phase = 0.0;

void vertex() {
	float lean = 1.0 - UV.y;
	VERTEX.x += sin(TIME * speed + phase) * amplitude * lean;
}
