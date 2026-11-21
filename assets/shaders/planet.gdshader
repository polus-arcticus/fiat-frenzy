// The new-game screen's planet: a globe, or an azimuthal equidistant map over the north pole, painted with OpenStreetMap's
// tiles (an atlas of the world, and a patch of closer tiles where the view is), with the game's tile grid over it (TileKey:
// zoom 16, and its regions at zoom 10), the chosen tile and the one under the pointer. The pixel -> place formulas are
// PlanetProjection's; keep the two the same.
shader_type canvas_item;

uniform vec2 view_size = vec2(1300.0, 750.0);
uniform float k = 300.0;              // pixels per radian of latitude in the middle
uniform float flat_map = 0.0;         // 0: globe, 1: flat
uniform vec2 middle = vec2(0.87, 0.15); // GLOBE: the place in the middle (lat, lon, radians)
uniform vec2 pan = vec2(0.0);         // FLAT: the plane point in the middle

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform float atlas_px = 2048.0;
uniform sampler2D patch : filter_linear, repeat_disable;
uniform float patch_tiles = 0.0;      // tiles across the patch (0: no patch)
uniform vec3 patch_anchor;            // its north-west corner: lon (rad), Mercator psi (rad), tiles per radian
uniform vec3 grid_anchor;             // the same for the game tile in the middle of the view
uniform vec2 chosen = vec2(1e9);      // the chosen game tile, in tiles from grid_anchor's
uniform vec2 hovered = vec2(1e9);

const vec3 SPACE_TOP = vec3(0.071, 0.051, 0.122);
const vec3 SPACE_LOW = vec3(0.106, 0.071, 0.212);
const vec3 SEA = vec3(0.667, 0.827, 0.875);
const vec3 POLE = vec3(0.93, 0.95, 0.97);
const vec3 GRID = vec3(0.07, 0.05, 0.12);
const vec3 PINK = vec3(1.0, 0.31, 0.506);
const vec3 GOLD = vec3(1.0, 0.81, 0.227);

// The place at pixel `px` (lat, lon in radians); z is 1 on the planet, 0 off it.
vec3 place(vec2 px) {
	vec2 d = px - view_size * 0.5;
	if (flat_map > 0.5) {
		vec2 q = d / (k * PI) + pan;
		float r = length(q);
		return vec3(PI * 0.5 - r * PI, atan(q.x, q.y), r <= 1.0 ? 1.0 : 0.0);
	}
	float u = d.x / k;
	float v = -d.y / k;
	float r2 = u * u + v * v;
	if (r2 > 1.0) return vec3(0.0);
	float p = middle.x;
	float l = middle.y;
	vec3 toward = vec3(cos(p) * cos(l), sin(p), cos(p) * sin(l));
	vec3 east = vec3(-sin(l), 0.0, cos(l));
	vec3 north = vec3(-sin(p) * cos(l), cos(p), -sin(p) * sin(l));
	vec3 w = toward * sqrt(1.0 - r2) + east * u + north * v;
	return vec3(atan(w.y, length(w.xz)), atan(w.z, w.x), 1.0);
}

// Distance to the nearest grid line, in pixels, for coordinates `t` (in cells).
float line_px(vec2 t) {
	vec2 f = abs(fract(t + 0.5) - 0.5) / max(fwidth(t), vec2(1e-6));
	return min(f.x, f.y);
}

void fragment() {
	vec2 px = UV * view_size;
	vec3 at = place(px);
	if (at.z < 0.5) {
		vec3 sky = mix(SPACE_TOP, SPACE_LOW, UV.y);
		// a halo round the globe, a rim round the flat map
		vec2 d = px - view_size * 0.5;
		float edge = flat_map > 0.5 ? length(d / (k * PI) + pan) * k * PI - k * PI : length(d) - k;
		sky += vec3(0.35, 0.55, 1.0) * 0.35 * exp(-max(edge, 0.0) / 18.0);
		COLOR = vec4(sky, 1.0);
	} else {
		float lat = at.x;
		float lon = at.y;
		float psi = log(tan(lat) + 1.0 / cos(lat));  // Mercator's y (radians)
		vec3 c = abs(lat) > 1.4844 ? POLE : SEA;     // past 85.05 degrees the web map stops
		if (abs(lat) <= 1.4844) {
			vec2 uv = vec2((lon + PI) / (2.0 * PI), (PI - psi) / (2.0 * PI));
			float lod = log2(max(atlas_px / (2.0 * PI) / (k * max(cos(lat), 0.05)), 1.0));
			vec4 a = textureLod(atlas, uv, lod);
			c = mix(SEA, a.rgb, a.a);
			if (patch_tiles > 0.0) {
				vec2 t = vec2(lon - patch_anchor.x, patch_anchor.y - psi) * patch_anchor.z / patch_tiles;
				if (t.x >= 0.0 && t.y >= 0.0 && t.x < 1.0 && t.y < 1.0) {
					vec4 p = textureLod(patch, t, 0.0);
					c = mix(c, p.rgb, p.a);
				}
			}
			// the game's tiles, measured from the one in the middle (small numbers stay sharp)
			vec2 g = vec2(lon - grid_anchor.x, grid_anchor.y - psi) * grid_anchor.z;
			float cell = max(fwidth(g).x, fwidth(g).y);  // tiles per pixel
			float show = clamp((0.09 - cell) / 0.05, 0.0, 1.0);  // from about 11 px a tile
			vec2 tile = floor(g);
			if (tile == chosen) c = mix(c, PINK, 0.35);
			else if (tile == hovered) c = mix(c, vec3(1.0), 0.25 * show);
			c = mix(c, GRID, show * 0.45 * (1.0 - smoothstep(0.4, 1.2, line_px(g))));
			// the regions (64 x 64 tiles): faint further out
			vec2 rg = vec2(lon + PI, PI - psi) * grid_anchor.z / 64.0;
			float rcell = max(fwidth(rg).x, fwidth(rg).y);
			float rshow = clamp((0.2 - rcell) / 0.15, 0.0, 1.0);
			c = mix(c, GOLD * 0.6, rshow * 0.55 * (1.0 - smoothstep(0.6, 1.6, line_px(rg))));
			if (tile == chosen) {
				vec2 e = abs(fract(g) - 0.5) / max(fwidth(g), vec2(1e-6));  // pixels from the tile's middle
				vec2 half_px = 0.5 / max(fwidth(g), vec2(1e-6));
				float border = min(half_px.x - e.x, half_px.y - e.y);
				c = mix(c, PINK, 1.0 - smoothstep(1.5, 3.0, border));
			}
		}
		// the graticule, every 15 degrees, where the view is wide
		vec2 deg = vec2(lat, lon) * (12.0 / PI);
		float wide = clamp(1.0 - k / 3000.0, 0.0, 1.0);
		c = mix(c, vec3(1.0), wide * 0.25 * (1.0 - smoothstep(0.3, 1.1, line_px(deg))));
		if (flat_map < 0.5) {  // the globe is lit from over the viewer's shoulder
			vec2 d = (px - view_size * 0.5) / k;
			c *= mix(1.0, 0.72 + 0.28 * sqrt(max(1.0 - dot(d, d), 0.0)), clamp(1.0 - k / 6000.0, 0.0, 1.0));
		}
		COLOR = vec4(c, 1.0);
	}
}
