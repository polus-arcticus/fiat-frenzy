// Full-screen watercolour pass on a camera-attached quad: ink outlines from depth + normal
// edges, slight wet-edge colour bleed, paper grain, a warm wash, and a vignette.
// Normal-based edges need Forward+ (hint_normal_roughness_texture); depth edges work everywhere.
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, skip_vertex_transform;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform sampler2D paper_noise : hint_default_white, filter_linear_mipmap, repeat_enable; // soft blotches
uniform sampler2D grain_tex : hint_default_white, filter_linear, repeat_enable;          // paper tooth

uniform vec4 ink_color : source_color = vec4(0.16, 0.14, 0.2, 1.0);
uniform vec4 paper_color : source_color = vec4(0.97, 0.94, 0.87, 1.0);
uniform float line_width = 1.2;
uniform float depth_sensitivity = 9.0;
uniform float normal_sensitivity = 1.4;
uniform float line_fade_distance = 60.0;
uniform float bleed = 0.0025;
uniform float paper_strength : hint_range(0.0, 1.0) = 0.16;
uniform float wash : hint_range(0.0, 1.0) = 0.05;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 view_normal(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = line_width / VIEWPORT_SIZE;
	vec2 grain_uv = uv * VIEWPORT_SIZE / 256.0;
	float grain = texture(grain_tex, grain_uv).r;
	float fibre = texture(grain_tex, grain_uv * vec2(0.12, 1.0)).r;
	float blotch = texture(paper_noise, uv * 6.0).r;

	// wet-edge bleed: wobble the lookup and soften with a tiny cross blur
	vec2 wob = (vec2(texture(paper_noise, uv * 2.3).r, texture(paper_noise, uv * 2.3 + 0.37).r) - 0.5) * bleed;
	vec2 suv = uv + wob;
	vec3 col = texture(screen_tex, suv).rgb * 0.5
		+ (texture(screen_tex, suv + vec2(px.x, 0.0)).rgb + texture(screen_tex, suv - vec2(px.x, 0.0)).rgb
		+ texture(screen_tex, suv + vec2(0.0, px.y)).rgb + texture(screen_tex, suv - vec2(0.0, px.y)).rgb) * 0.125;

	// How bright this pixel is. The paper effects below add light, so they must fade out in the dark,
	// or a night scene (pixels near 0.02) gets lifted to a milky grey, like looking through smoke.
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	float lit = smoothstep(0.02, 0.25, lum);
	float lit_ink = smoothstep(0.0, 0.2, lum);

	// ink lines: compare the centre against 4 neighbours
	float dc = linear_depth(uv, INV_PROJECTION_MATRIX);
	vec3 nc = view_normal(uv);
	float de = 0.0;
	float ne = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		float d = linear_depth(uv + offs[i], INV_PROJECTION_MATRIX);
		de += abs(d - dc) / max(dc, 0.1);
		ne += 1.0 - dot(nc, view_normal(uv + offs[i]));
	}
	float edge = clamp(de * depth_sensitivity, 0.0, 1.0);
	edge = max(edge, clamp(ne * normal_sensitivity - 0.15, 0.0, 1.0));
	edge *= smoothstep(line_fade_distance, line_fade_distance * 0.3, dc); // fade with distance
	edge *= smoothstep(0.3, 0.55, blotch + grain * 0.3);                  // broken, sketchy line
	edge *= mix(0.25, 1.0, lit_ink);                                      // few pale scribbles in the dark
	col = mix(col, ink_color.rgb * col * 1.5 + ink_color.rgb * 0.3 * lit_ink, edge * 0.85);

	// paper: lift the darks, tint toward the paper, grain + fibres
	col = mix(col, paper_color.rgb, wash * (0.6 + blotch * 0.8) * lit);
	col *= mix(1.0, (0.86 + grain * 0.22) * (0.96 + fibre * 0.06), paper_strength * mix(0.5, 1.0, lit));
	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * vignette * 1.6;
	ALBEDO = col;
}
