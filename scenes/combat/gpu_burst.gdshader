shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;

uniform sampler2D state_tex : filter_nearest;
uniform float state_width = 512.0;
uniform float state_rows = 2.0;

varying float v_active;
varying float v_type;
varying float v_life;
varying float v_seed;

vec4 read_state(int row) {
	vec2 uv = vec2((gpu_slot + 0.5) / state_width, (float(row) + 0.5) / state_rows);
	return textureLod(state_tex, uv, 0.0);
}

void vertex() {
	float gpu_slot = INSTANCE_CUSTOM.r;
	vec4 s0 = read_state(0);
	vec4 s1 = read_state(1);
	v_active = s1.w;
	v_type = s0.z;
	v_life = s1.y > 0.0 ? s1.x / s1.y : 0.0;
	v_seed = fract(gpu_slot * 0.569840296);
	if (v_active < 0.5) {
		VERTEX = vec2(-1000000.0);
		return;
	}
	float radius = max(s0.w, 8.0);
	VERTEX = s0.xy + VERTEX * (radius / 48.0);
}

void fragment() {
	if (v_active < 0.5) {
		discard;
	}
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float age = 1.0 - clamp(v_life, 0.0, 1.0);
	float ring_radius = mix(0.08, 0.92, age);
	float ring = 1.0 - smoothstep(0.04, 0.13, abs(r - ring_radius));
	float core = (1.0 - smoothstep(0.0, 0.72, r)) * (1.0 - age);
	float spokes = pow(max(0.0, cos(atan(p.y, p.x) * 10.0 + v_seed * 12.0)), 18.0) * (1.0 - smoothstep(0.25, 1.0, r));

	vec3 color = vec3(0.92, 0.94, 1.0);
	if (v_type < 1.5 && v_type > 0.5) {
		color = vec3(1.0, 0.18, 0.015);
	} else if (v_type < 2.5 && v_type > 1.5) {
		color = vec3(0.18, 0.76, 1.0);
	} else if (v_type < 3.5 && v_type > 2.5) {
		color = vec3(0.66, 0.24, 1.0);
	} else if (v_type < 4.5 && v_type > 3.5) {
		color = vec3(1.0, 0.16, 0.34);
	} else if (v_type > 4.5) {
		color = vec3(1.0, 0.42, 0.03);
	}
	float alpha = max(ring, max(core * 0.55, spokes * 0.7)) * clamp(v_life * 1.7, 0.0, 1.0);
	COLOR = vec4(color * (0.65 + ring * 1.35 + core), alpha);
}
