// The sky, painted: a gradient in soft bands (like a watercolour wash), toon clouds with a lit and a shaded side, a sun with a
// warm halo, a glow along the horizon at dawn and dusk, and stars at night. DayNight sets the colours from the time of day.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.28, 0.55, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.9, 0.98);
uniform vec3 ground_color : source_color = vec3(0.3, 0.32, 0.4);
uniform vec3 glow_color : source_color = vec3(1.0, 0.7, 0.45);
uniform float glow = 0.0;                // 0..1: dawn and dusk
uniform vec3 cloud_lit : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.68, 0.74, 0.86);
uniform float cloud_cover = 0.5;         // 0 clear .. 1 overcast
uniform float drift = 0.0;               // how far the clouds have moved
uniform float night = 0.0;               // 0 day .. 1 night: stars, and the sun goes away
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float bands = 7.0;               // the gradient is painted in this many washes


float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// gradient noise: unlike value noise it has no creases along its lattice lines, so thresholded into clouds it stays soft
vec2 grad(vec2 i) {
	float a = hash(i) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n = mix(mix(dot(grad(i), f), dot(grad(i + vec2(1, 0)), f - vec2(1, 0)), u.x),
			mix(dot(grad(i + vec2(0, 1)), f - vec2(0, 1)), dot(grad(i + vec2(1, 1)), f - vec2(1, 1)), u.x), u.y);
	return 0.5 + 0.7 * n;
}

// (each octave turned a little and the whole thing bent by a slow warp, so the grid the noise sits on never shows)
float fbm(vec2 p) {
	p += 0.45 * vec2(noise(p * 0.9 + vec2(3.1, 1.7)), noise(p * 0.9 + vec2(9.2, 5.3))) - 0.22;
	mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p = turn * p * 2.03 + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}

// a gradient value, painted in soft steps
float wash(float x) {
	float s = x * bands;
	return (floor(s) + smoothstep(0.35, 0.65, fract(s))) / bands;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 sun_dir = normalize(LIGHT0_DIRECTION);
	// the wash from the horizon up
	float up = wash(clamp(pow(max(h, 0.0), 0.55), 0.0, 1.0));
	vec3 col = mix(horizon_color, top_color, up);
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}
	// the glow along the horizon, strongest toward the sun
	float toward = max(dot(vec2(dir.x, dir.z), normalize(vec2(sun_dir.x, sun_dir.z) + vec2(0.0001))), 0.0);
	float band = (1.0 - smoothstep(0.0, 0.5, abs(h))) * glow;
	col = mix(col, glow_color, band * (0.35 + 0.65 * pow(toward, 2.0)));
	// stars
	if (night > 0.02 && h > 0.02) {
		vec2 g = dir.xz / (h + 0.6) * 150.0;
		vec2 cell = floor(g);
		float r = hash(cell);
		vec2 centre = cell + 0.3 + 0.4 * vec2(hash(cell + 3.1), hash(cell + 7.7));
		float star = step(0.985, r) * smoothstep(0.28, 0.0, length(g - centre));
		col += vec3(0.95, 0.95, 1.0) * star * night * smoothstep(0.02, 0.3, h);
	}
	// the sun: a disc and a warm halo
	float s = dot(dir, sun_dir);
	float sun_up = 1.0 - night;
	col += sun_color * smoothstep(0.9988, 0.9995, s) * sun_up * 1.6;
	col += sun_color * pow(max(s, 0.0), 24.0) * 0.22 * sun_up;
	col += glow_color * pow(max(s, 0.0), 6.0) * 0.12 * glow;
	// clouds: on a plane overhead, thresholded into two tones, lit from the sun's side
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.3) * 2.1 + vec2(drift, drift * 0.3);
		float d = fbm(uv);
		float edge = 1.0 - cloud_cover;
		float mass = smoothstep(edge, edge + 0.07, d);
		float toward_sun = fbm(uv + normalize(vec2(sun_dir.x, sun_dir.z) + vec2(0.0001)) * 0.12);
		float lit = smoothstep(-0.02, 0.05, d - toward_sun + 0.01);
		vec3 cloud = mix(cloud_shade, cloud_lit, lit);
		cloud = mix(cloud, glow_color * 1.05, glow * 0.45 * lit);
		float fade = smoothstep(0.0, 0.18, h);  // clouds thin out toward the horizon
		col = mix(col, cloud, mass * fade * 0.96);
	}
	COLOR = col;
}
