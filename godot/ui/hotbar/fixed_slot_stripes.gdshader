shader_type canvas_item;

// Diagonal hazard-style stripes marking a hotbar slot as fixed (not for items).
uniform vec4 stripe_color : source_color = vec4(1.0, 1.0, 1.0, 0.12);
uniform float stripe_count = 8.0;
uniform float stripe_width : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float band = fract((UV.x + UV.y) * stripe_count);
	COLOR = stripe_color * step(band, stripe_width);
}
