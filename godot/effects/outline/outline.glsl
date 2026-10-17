#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(set = 0, binding = 1) uniform sampler2D depth_tex;
layout(set = 0, binding = 2) uniform sampler2D mask_tex;

layout(push_constant, std430) uniform Params {
	vec2 size;
	float radius;
	float occlusion_tolerance;
	vec4 outline_color;
} params;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.size);
	if (px.x >= size.x || px.y >= size.y) {
		return;
	}
	// Only draw outside the silhouette.
	if (texelFetch(mask_tex, px, 0).a > 0.5) {
		return;
	}

	int r = int(params.radius);
	float best = 1e9;
	ivec2 nearest = px;
	for (int x = -r; x <= r; x++) {
		for (int y = -r; y <= r; y++) {
			float d2 = float(x * x + y * y);
			if (d2 > params.radius * params.radius || d2 >= best) {
				continue;
			}
			ivec2 sp = px + ivec2(x, y);
			if (sp.x < 0 || sp.y < 0 || sp.x >= size.x || sp.y >= size.y) {
				continue;
			}
			if (texelFetch(mask_tex, sp, 0).a > 0.5) {
				best = d2;
				nearest = sp;
			}
		}
	}
	if (best > 1e8) {
		return;
	}

	// Reverse-Z depth: larger is nearer, roughly proportional to 1 / distance. Skip the
	// pixel when the scene there is clearly nearer than the highlighted object.
	float depth_here = texelFetch(depth_tex, px, 0).r;
	float depth_object = texelFetch(depth_tex, nearest, 0).r;
	if (depth_here > depth_object * (1.0 + params.occlusion_tolerance)) {
		return;
	}

	float coverage = clamp(params.radius + 0.5 - sqrt(best), 0.0, 1.0) * params.outline_color.a;
	vec4 base = imageLoad(color_image, px);
	imageStore(color_image, px, vec4(mix(base.rgb, params.outline_color.rgb, coverage), base.a));
}
