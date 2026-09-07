shader_type canvas_item;
render_mode unshaded;

uniform sampler2D gpu_state_tex : filter_nearest;
uniform bool gpu_state_enabled = false;
uniform float gpu_state_width = 1024.0;
uniform float gpu_state_rows = 3.0;

varying float instance_active;

vec4 read_gpu_state(int row, float slot) {
	vec2 uv = vec2((slot + 0.5) / gpu_state_width, (float(row) + 0.5) / gpu_state_rows);
	return textureLod(gpu_state_tex, uv, 0.0);
}

void vertex() {
	float gpu_slot = INSTANCE_CUSTOM.r;
	instance_active = 1.0;
	if (gpu_state_enabled) {
		vec4 s0 = read_gpu_state(0, gpu_slot);
		vec4 s1 = read_gpu_state(1, gpu_slot);
		vec4 s2 = read_gpu_state(2, gpu_slot);
		instance_active = s1.x;
		if (instance_active < 0.5) {
			VERTEX = vec2(-1000000.0);
		} else {
			float scale_value = max(s2.w, 0.2);
			VERTEX = s0.xy + vec2(0.0, 18.0 * scale_value) + VERTEX * scale_value;
		}
	}
}


void fragment() {
	if (instance_active < 0.5) {
		discard;
	}
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	float distance_from_center = dot(centered, centered);
	float soft_ellipse = 1.0 - smoothstep(0.48, 1.0, distance_from_center);
	COLOR = vec4(0.015, 0.025, 0.035, soft_ellipse * 0.20);
}
