shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;

uniform sampler2D state_tex : filter_nearest;
uniform float state_width = 256.0;
uniform float state_rows = 2.0;

varying float v_active;
varying float v_life;
varying float v_seed;

vec4 read_state(int row) {
	vec2 uv = vec2((gpu_slot + 0.5) / state_width, (float(row) + 0.5) / state_rows);
	return textureLod(state_tex, uv, 0.0);
}

void vertex() {
	float gpu_slot = INSTANCE_CUSTOM.r;
	vec4 ends = read_state(0);
	vec4 state = read_state(1);
	v_active = state.w;
	v_life = state.y > 0.0 ? state.x / state.y : 0.0;
	v_seed = fract(gpu_slot * 0.754877666);
	if (v_active < 0.5) {
		VERTEX = vec2(-1000000.0);
		return;
	}
	vec2 start_position = ends.xy;
	vec2 end_position = ends.zw;
	vec2 delta = end_position - start_position;
	float line_length = max(length(delta), 0.001);
	vec2 tangent = delta / line_length;
	vec2 normal = vec2(-tangent.y, tangent.x);
	vec2 midpoint = (start_position + end_position) * 0.5;
	float width = max(state.z, 2.0) * 4.0;
	VERTEX = midpoint + tangent * (VERTEX.x * line_length) + normal * (VERTEX.y * width);
}

void fragment() {
	if (v_active < 0.5) {
		discard;
	}
	float x = UV.x;
	float wave = sin(x * 41.0 + v_seed * 19.0) * 0.11 + sin(x * 83.0 + TIME * 28.0) * 0.045;
	float d = abs((UV.y - 0.5) - wave);
	float core = 1.0 - smoothstep(0.015, 0.07, d);
	float glow = 1.0 - smoothstep(0.04, 0.24, d);
	float flicker = 0.72 + 0.28 * sin(TIME * 45.0 + v_seed * 31.0);
	vec3 color = vec3(0.78, 0.42, 1.0) * glow + vec3(0.96, 0.92, 1.0) * core * 1.6;
	COLOR = vec4(color * flicker, max(core, glow * 0.42) * clamp(v_life * 2.2, 0.0, 1.0));
}
