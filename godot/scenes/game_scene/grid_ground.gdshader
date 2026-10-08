shader_type spatial;

// World-anchored grid for greyboxing. Lines are only drawn on upward-facing surfaces.

uniform vec4 base_color : source_color = vec4(0.12, 0.12, 0.13, 1.0);
uniform vec4 line_color : source_color = vec4(0.35, 0.35, 0.38, 1.0);
uniform vec4 major_line_color : source_color = vec4(0.65, 0.65, 0.7, 1.0);
uniform float cell_size = 1.0;
uniform float line_width = 0.02;
uniform float major_line_width = 0.05;
uniform int major_every = 10;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

// Anti-aliased coverage (0..1) of grid lines of `width` metres spaced `spacing` apart.
float grid_line(vec2 p, float spacing, float width) {
	vec2 d = abs(fract(p / spacing - 0.5) - 0.5) * spacing; // metres to nearest line
	vec2 aa = max(fwidth(p), vec2(0.0001));
	vec2 cov = 1.0 - smoothstep(vec2(width * 0.5) - aa, vec2(width * 0.5) + aa, d);
	return max(cov.x, cov.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	float top = step(0.5, world_normal.y);

	float minor = grid_line(p, cell_size, line_width) * top;
	float major = grid_line(p, cell_size * float(max(major_every, 1)), major_line_width) * top;

	vec3 col = mix(base_color.rgb, line_color.rgb, minor);
	col = mix(col, major_line_color.rgb, major);

	ALBEDO = col;
	ROUGHNESS = roughness;
}
