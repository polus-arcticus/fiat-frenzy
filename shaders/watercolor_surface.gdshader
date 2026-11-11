// Watercolour surface for vertex-coloured low-poly meshes (the Blender pipeline writes COLOR_0).
// Banded toon light, world-space pigment granulation, darkened silhouette edges, and a small
// colour jitter per instance so repeated props don't look stamped.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D pigment_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float granulation : hint_range(0.0, 1.0) = 0.3;
uniform float noise_scale = 0.6;
uniform float edge_darken : hint_range(0.0, 1.0) = 0.35;
uniform float band_softness : hint_range(0.001, 0.3) = 0.06;
uniform float band_wobble : hint_range(0.0, 0.5) = 0.18;
uniform float instance_jitter : hint_range(0.0, 0.2) = 0.06;
uniform float emission_strength = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float triplanar(vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(pigment_noise, p.zy * scale).r * w.x
		+ texture(pigment_noise, p.xz * scale).r * w.y
		+ texture(pigment_noise, p.xy * scale).r * w.z;
}

void fragment() {
	vec3 base = COLOR.rgb * tint.rgb;
	float n = triplanar(world_pos, world_normal, noise_scale);
	float fine = triplanar(world_pos, world_normal, noise_scale * 4.1);
	// pigment pools in the paper's tooth: darker, slightly denser colour
	float pool = (n - 0.5) * granulation + (fine - 0.5) * granulation * 0.6;
	base *= 1.0 - pool * 0.7;
	float h = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	base *= 1.0 + h * instance_jitter * vec3(1.0, -0.6, 0.8);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	base *= 1.0 - fres * edge_darken;
	ALBEDO = clamp(base, 0.0, 1.0);
	ROUGHNESS = 1.0;
	EMISSION = base * emission_strength;
}

void light() {
	float wob = (texture(pigment_noise, world_pos.xz * 0.21 + world_pos.y * 0.13).r - 0.5) * band_wobble;
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION + wob;
	float band = smoothstep(0.04, 0.04 + band_softness, lit) * 0.6
		+ smoothstep(0.5, 0.5 + band_softness, lit) * 0.4;
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
