shader_type canvas_item;

const float amplitude = 10.0;
const float period = 5.0;
const float vertical_shift = -10.0;
const float frequency = 10.0;


void vertex() {
	VERTEX.y += sin((TIME * period) + (UV.x * frequency)) * amplitude;
	VERTEX.y = VERTEX.y - vertical_shift;
}
