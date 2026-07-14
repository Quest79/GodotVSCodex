shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float distance_from_center = dot(centered, centered);
	float soft_ellipse = 1.0 - smoothstep(0.48, 1.0, distance_from_center);
	COLOR = vec4(0.015, 0.025, 0.035, soft_ellipse * 0.20);
}
