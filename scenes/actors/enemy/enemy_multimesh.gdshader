shader_type canvas_item;
render_mode unshaded;

varying float animation_wave;
varying float hit_amount;
varying float burn_amount;
varying float instance_seed;
varying vec3 ailment_state;
varying float health_fraction;

float circle_mask(vec2 point, vec2 center, float radius, float softness) {
	return 1.0 - smoothstep(radius - softness, radius + softness, length(point - center));
}

float ring_mask(float radius, float center_radius, float thickness) {
	return 1.0 - smoothstep(thickness, thickness + 1.2, abs(radius - center_radius));
}

float hash11(float value) {
	return fract(sin(value * 127.1) * 43758.5453123);
}

void vertex() {
	ailment_state = COLOR.rgb;
	health_fraction = COLOR.a;
	COLOR = vec4(1.0);
	instance_seed = instance_seed;
	float phase = instance_seed * 6.28318530718;
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
	float radius = length(point);
	float body_region = 1.0 - smoothstep(19.0, 31.0, radius);
	vec2 living_uv = UV + vec2(
		sin(animation_wave * 1.3 + point.y * 0.12),
		cos(animation_wave * 1.1 + point.x * 0.1)
	) * body_region * 0.0045;
	vec4 tex = texture(TEXTURE, living_uv);
	float pulse = 0.5 + 0.5 * sin(animation_wave * 2.0);
	float hot_mask = smoothstep(0.08, 0.62, tex.r - max(tex.g, tex.b) * 0.45);
	vec3 color = tex.rgb * 1.18 + vec3(0.14, 0.022, 0.032) * hot_mask * pulse;

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

	vec3 fx_color = vec3(0.0);
	float fx_alpha = 0.0;

	// Burning: hot shell, breathing aura, and rising embers.
	if (burn > 0.001) {
		float aura = (1.0 - smoothstep(25.0, 42.0, radius)) * burn;
		float flame_rim = ring_mask(radius, 25.0 + sin(atan(point.y, point.x) * 7.0 + TIME * 7.0) * 2.4, 2.2) * burn;
		fx_color += vec3(1.0, 0.10, 0.01) * aura * 0.42;
		fx_color += vec3(1.0, 0.46, 0.03) * flame_rim * 0.9;
		fx_alpha = max(fx_alpha, max(aura * 0.26, flame_rim * 0.62));

		for (int ember_index = 0; ember_index < 10; ember_index++) {
			float fi = float(ember_index);
			float seed = hash11(fi + instance_seed * 97.0);
			float drift = sin(TIME * (1.4 + seed) + fi * 2.2) * 4.0;
			float ember_x = mix(-22.0, 22.0, hash11(fi * 3.17 + instance_seed * 41.0)) + drift;
			float rise = mod(TIME * (12.0 + seed * 14.0) + fi * 8.3 + instance_seed * 31.0, 62.0);
			vec2 ember_pos = vec2(ember_x, 20.0 - rise);
			float spark = 1.0 - smoothstep(0.8, 2.5, length(point - ember_pos));
			fx_color += vec3(1.0, 0.38 + seed * 0.35, 0.02) * spark * burn;
			fx_alpha = max(fx_alpha, spark * burn);
		}
	}

	// Chill: cyan frost rim and crystalline spokes.
	if (chill > 0.001) {
		float angle = atan(point.y, point.x);
		float frost_rim = ring_mask(radius, 26.5, 2.0) * chill;
		float spoke_wave = pow(max(0.0, cos(angle * 8.0 + TIME * 0.7)), 18.0);
		float spoke_band = (1.0 - smoothstep(24.0, 38.0, radius)) * smoothstep(23.0, 29.0, radius);
		float crystals = spoke_wave * spoke_band * chill;
		fx_color += vec3(0.12, 0.72, 1.0) * frost_rim * 0.9;
		fx_color += vec3(0.72, 0.97, 1.0) * crystals;
		fx_alpha = max(fx_alpha, max(frost_rim * 0.55, crystals * 0.95));
	}

	// Shock: animated jagged purple arcs orbit the body.
	if (shock > 0.001) {
		float angle = atan(point.y, point.x);
		float wobble = sin(angle * 5.0 + TIME * 15.0 + instance_seed * 9.0) * 3.2;
		float arc1 = ring_mask(radius, 29.0 + wobble, 1.25);
		float arc2 = ring_mask(radius, 34.0 - wobble * 0.45, 0.9);
		float gaps1 = step(0.56, fract(angle * 1.28 + TIME * 2.3 + instance_seed));
		float gaps2 = step(0.72, fract(-angle * 1.73 + TIME * 3.1));
		float bolt = max(arc1 * gaps1, arc2 * gaps2) * shock;
		float shock_glow = (1.0 - smoothstep(25.0, 40.0, radius)) * shock * (0.45 + 0.35 * sin(TIME * 18.0 + animation_wave));
		fx_color += vec3(0.50, 0.17, 1.0) * shock_glow;
		fx_color += vec3(0.92, 0.74, 1.0) * bolt * 1.35;
		fx_alpha = max(fx_alpha, max(shock_glow * 0.32, bolt));
	}

	// Frozen: bright ice shell with hard crystalline rim.
	if (frozen > 0.001) {
		float angle = atan(point.y, point.x);
		float ice_shell = (1.0 - smoothstep(22.0, 30.0, radius)) * frozen;
		float ice_rim = ring_mask(radius, 27.0, 2.3) * frozen;
		float spike = pow(max(0.0, cos(angle * 10.0)), 22.0) * smoothstep(25.0, 31.0, radius) * (1.0 - smoothstep(31.0, 43.0, radius)) * frozen;
		color = mix(color, vec3(0.54, 0.89, 1.0), ice_shell * 0.72);
		fx_color += vec3(0.82, 0.98, 1.0) * (ice_rim + spike);
		fx_alpha = max(fx_alpha, max(ice_rim * 0.82, spike));
	}

	// GPU hit flash.
	color = mix(color, vec3(1.0, 0.94, 0.88), clamp(hit_amount * 1.35, 0.0, 1.0));

	// GPU health bar for damaged normal enemies. Replaces per-enemy Label nodes.
	if (health_fraction < 0.999) {
		float bar_y = 1.0 - smoothstep(1.2, 2.2, abs(point.y + 35.0));
		float bar_x = 1.0 - smoothstep(18.0, 20.0, abs(point.x));
		float bar_bg = bar_y * bar_x;
		float x01 = clamp((point.x + 18.0) / 36.0, 0.0, 1.0);
		float fill = 1.0 - step(health_fraction, x01);
		float bar_fill = bar_bg * fill;
		fx_color = mix(fx_color, vec3(0.03, 0.01, 0.02), bar_bg);
		fx_color = mix(fx_color, vec3(1.0, 0.08, 0.24), bar_fill);
		fx_alpha = max(fx_alpha, bar_bg * 0.95);
	}

	float final_alpha = max(tex.a, fx_alpha);
	vec3 final_color = tex.a > 0.001 ? color : vec3(0.0);
	final_color += fx_color;
	COLOR = vec4(final_color, final_alpha);
}
