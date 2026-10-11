shader_type canvas_item;

// Sizes are in screen pixels, so the dot stays crisp regardless of the rect size.
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.9);
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform float radius : hint_range(0.5, 16.0) = 1.5;
uniform float outline_width : hint_range(0.0, 8.0) = 1.0;

void fragment() {
	// Distance from the rect center in pixels.
	vec2 px = (UV - 0.5) / fwidth(UV);
	float d = length(px);

	float dot_a = 1.0 - smoothstep(radius - 0.5, radius + 0.5, d);
	float outer_a = 1.0 - smoothstep(radius + outline_width - 0.5, radius + outline_width + 0.5, d);

	vec4 outline = vec4(outline_color.rgb, outline_color.a * outer_a);
	COLOR = mix(outline, vec4(color.rgb, color.a), dot_a);
	COLOR.a = max(outline.a * (1.0 - dot_a), color.a * dot_a);
}
