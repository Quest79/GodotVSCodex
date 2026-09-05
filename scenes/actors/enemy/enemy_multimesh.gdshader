shader_type canvas_item;
render_mode unshaded;

varying float animation_wave;
varying float hit_amount;
varying float burn_amount;
varying vec3 ailment_state;

float circle_mask(vec2 point, vec2 center, float radius, float softness) {
	return 1.0 - smoothstep(radius - softness, radius + softness, length(point - center));
}

void vertex() {
	ailment_state = COLOR.rgb;
	COLOR = vec4(1.0);
	float phase = INSTANCE_CUSTOM.r * 6.28318530718;
	float urgency = mix(0.25, 1.0, INSTANCE_CUSTOM.a);
	float animation = TIME * mix(2.3, 6.2, urgency) + phase;
	float breathing = sin(animation * 2.0) * 0.055;
	VERTEX.x *= 1.0 + breathing * 0.45;
	VERTEX.y *= 1.0 - breathing;
	VERTEX.x += max(0.0, sin(animation)) * mix(1.0, 4.2, urgency);
	float pop = 1.0 + INSTANCE_CUSTOM.b * 0.18;
	VERTEX *= pop;
	animation_wave = animation;
	hit_amount = INSTANCE_CUSTOM.b;
	burn_amount = INSTANCE_CUSTOM.g;
}

void fragment() {
	vec2 point = (UV - vec2(0.5)) * 96.0;
	float body_region = 1.0 - smoothstep(19.0, 31.0, length(point));
	vec2 living_uv = UV + vec2(
		sin(animation_wave * 1.3 + point.y * 0.12),
		cos(animation_wave * 1.1 + point.x * 0.1)
	) * body_region * 0.0045;
	vec4 tex = texture(TEXTURE, living_uv);
	float pulse = 0.5 + 0.5 * sin(animation_wave * 2.0);
	float hot_mask = smoothstep(0.08, 0.62, tex.r - max(tex.g, tex.b) * 0.45);
	vec3 color = tex.rgb * 1.18 + vec3(0.14, 0.022, 0.032) * hot_mask * pulse;

	// Rebuild the living core and twitching eyes per pixel on the GPU. These
	// details used to be recalculated in GDScript for every enemy redraw.
	float core_outer = circle_mask(point, vec2(10.0, -1.0), 9.4 + pulse * 1.2, 1.5);
	float core_inner = circle_mask(point, vec2(10.8, -1.0), 4.0 + pulse * 0.8, 1.0);
	color = mix(color, vec3(0.72, 0.07, 0.18), core_outer * 0.62);
	color = mix(color, vec3(1.0, 0.32 + pulse * 0.12, 0.4), core_inner * 0.9);
	for (int eye_index = 0; eye_index < 3; eye_index++) {
		vec2 eye_center = eye_index == 0 ? vec2(9.0, -8.0) : (eye_index == 1 ? vec2(15.0, 0.0) : vec2(9.0, 8.0));
		float eye_radius = eye_index == 1 ? 4.8 : 3.9;
		vec2 twitch = vec2(
			sin(animation_wave * 2.7 + float(eye_index) * 1.7),
			cos(animation_wave * 2.2 + float(eye_index) * 2.1)
		) * 0.85;
		float socket = circle_mask(point, eye_center, eye_radius, 0.8);
		float iris = circle_mask(point, eye_center + twitch, eye_radius * 0.57, 0.7);
		float pupil = circle_mask(point, eye_center + twitch * 1.35, eye_radius * 0.24, 0.45);
		color = mix(color, vec3(0.055, 0.006, 0.026), socket * 0.92);
		color = mix(color, vec3(1.0, 0.89, 0.65), iris);
		color = mix(color, vec3(1.0, 0.08, 0.18), pupil);
	}
	float chill = clamp(ailment_state.r, 0.0, 1.0);
	float shock = clamp(ailment_state.g, 0.0, 1.0);
	float frozen = clamp(ailment_state.b, 0.0, 1.0);
	float burn = clamp(burn_amount, 0.0, 1.0);
	color = mix(color, vec3(1.0, 0.22, 0.035), burn * 0.48);
	color = mix(color, vec3(0.2, 0.72, 1.0), chill * 0.42);
	float shock_pulse = 0.62 + 0.38 * sin(TIME * 14.0 + animation_wave);
	color += vec3(0.34, 0.12, 0.58) * shock * shock_pulse;
	color = mix(color, vec3(0.72, 0.94, 1.0), frozen * 0.72);
	color = mix(color, vec3(1.0, 0.94, 0.88), clamp(hit_amount * 1.35, 0.0, 1.0));
	// `tex` is already the sampled sprite color. Multiplying by fragment COLOR
	// here sampled/tinted the sprite a second time in the CanvasItem pipeline,
	// effectively squaring dark RGB values. That is why burn light appeared to
	// "fix" enemies only while afflicted.
	COLOR = vec4(color, tex.a);
}
