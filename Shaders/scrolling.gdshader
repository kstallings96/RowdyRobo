shader_type canvas_item;

const float time_scale = 0.25;

void vertex() {
	UV.x += cos(TIME * time_scale);
	UV.y += sin(TIME * time_scale);
}
