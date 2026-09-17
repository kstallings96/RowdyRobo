shader_type canvas_item;

const float amplitude = 10.0;
const float period = 5.0;

void vertex() {
	VERTEX.y += sin(TIME * period) * amplitude;
}