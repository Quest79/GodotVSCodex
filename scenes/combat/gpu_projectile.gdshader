shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;

uniform sampler2D state_tex : filter_nearest;
uniform float state_width = 2048.0;
uniform float state_rows = 2.0;

varying float v_active;
varying float v_skill;
varying float v_life;
varying float v_seed;

vec4 read_state(int row) {
	vec2 uv = vec2((INSTANCE_CUSTOM.r + 0.5) / state_width, (float(row) + 0.5) / state_rows);
	return textureLod(state_tex, uv, 0.0);
}

void vertex() {
	vec4 s0 = read_state(0);
	vec4 s1 = read_state(1);
	v_active = s1.x;
	v_skill = s1.z;
	v_life = s1.w;
	v_seed = fract(INSTANCE_CUSTOM.r * 0.61803398875);
	if (v_active < 0.5) {
		VERTEX = vec2(-1000000.0);
		return;
	}
	vec2 direction = normalize(s0.zw + vec2(0.00001, 0.0));
	mat2 rotation_matrix = mat2(direction.x, -direction.y, direction.y, direction.x);
	vec2 local = rotation_matrix * (VERTEX * max(s1.y, 0.2));
	VERTEX = s0.xy + local;
}

void fragment() {
	if (v_active < 0.5) {
		discard;
	}
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float core = 1.0 - smoothstep(0.12, 0.48, r);
	float glow = 1.0 - smoothstep(0.28, 0.98, r);
	float tail = smoothstep(-0.95, 0.25, p.x) * (1.0 - smoothstep(0.18, 0.7, abs(p.y)));
	float pulse = 0.72 + 0.28 * sin(TIME * 18.0 + v_seed * 18.0);

	vec3 color = vec3(0.85, 0.92, 1.0);
	if (v_skill < 1.5 && v_skill > 0.5) {
		color = mix(vec3(1.0, 0.09, 0.01), vec3(1.0, 0.76, 0.12), core);
	} else if (v_skill < 2.5 && v_skill > 1.5) {
		color = mix(vec3(0.05, 0.5, 1.0), vec3(0.78, 0.98, 1.0), core);
	} else if (v_skill > 2.5) {
		color = mix(vec3(0.42, 0.08, 1.0), vec3(0.96, 0.82, 1.0), core);
	}
	float alpha = max(core, glow * 0.48 + tail * 0.34) * clamp(v_life * 1.8 + 0.25, 0.0, 1.0);
	COLOR = vec4(color * (0.72 + core * 0.9) * pulse, alpha);
}
