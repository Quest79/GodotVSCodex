shader_type canvas_item;

uniform sampler2D gradient_texture : source_color, filter_linear;
uniform float label_height = 50.0;

varying float title_y;

void vertex() {
	// VERTEX is local to the Label. Unlike UV, it is not a coordinate inside
	// Godot's packed font atlas, so every glyph shares one continuous gradient.
	float label_y = VERTEX.y / max(label_height, 1.0);
	// The centered glyphs occupy roughly the middle 58% of the Label. Remap
	// that range so the full color ramp is visible inside the letters.
	title_y = clamp((label_y - 0.21) / 0.58, 0.0, 1.0);
}

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	vec3 gradient_color = texture(gradient_texture, vec2(1.0 - title_y, 0.5)).rgb;
	COLOR = vec4(gradient_color, glyph.a * COLOR.a);
}
