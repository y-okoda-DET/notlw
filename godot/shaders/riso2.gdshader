// Second print. The first one inked every dark mid-tone with both plates, so a night frame came out as one
// dirty teal sheet with video-like mottle on it. This one prints like the club's zine:
//  - the frame is "scanned" first: exposure set from the frame's own average, so a night shot is printed
//    for its darks instead of being drowned in them;
//  - the blue plate carries the dark: mid-tones stay mostly paper, real shadows go solid;
//  - the orange plate carries only warm light (tungsten, skin, sunset) - never darkness;
//  - teal appears only where both overlap (shadow inside warm light), so it means something;
//  - grain is the size of a dot, not a cloud; ink density varies only very softly across the drum.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float enabled = 1.0;
uniform int mode = 0;
uniform float cell_px = 3.6;
uniform float edge_cell_px = 7.0;
uniform float print_fps = 12.0;
uniform float time_offset = 0.0;
uniform vec3 paper = vec3(0.945, 0.925, 0.875);
uniform vec3 ink_a = vec3(0.0, 0.47, 0.75);
uniform vec3 ink_b = vec3(1.0, 0.424, 0.184);
uniform float exposure = 1.0;
uniform float scan_target = 0.42;   // mean luminance the scan aims for
uniform float scan_strength = 0.0; // 0 = fixed exposure per scene (the printer's setting), 1 = follow the frame
uniform float look = 0.0;          // 試作94: 0 = the print as it was (夕方), 1 = the night print (coverage_night, dodge)
uniform float dodge = 0.45;        // night print: how far each part of the sheet is exposed for what is in it (0 = one exposure)
uniform float dodge_target = 0.30; // the mean it aims for, before the shoulder
uniform float dodge_max = 1.8;
uniform vec2 slip = vec2(0.0);     // 段階1 扉の場面: the second plate slips off register while Mio says nothing (px at 1080)

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float dots(vec2 px, float angle, float cell) {
	float a = radians(angle);
	vec2 r = vec2(px.x * cos(a) + px.y * sin(a), -px.x * sin(a) + px.y * cos(a)) / cell;
	return (cos(r.x * 6.2831853) + cos(r.y * 6.2831853)) * 0.25 + 0.5;
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float scan_gain() {
	float m = 0.0;
	for (int i = 0; i < 9; i++) {
		vec2 uv = vec2(0.17 + 0.33 * float(i % 3), 0.17 + 0.33 * float(i / 3));
		m += luma(textureLod(screen_tex, uv, 7.0).rgb);
	}
	if (scan_strength <= 0.0) return exposure;
	m = max(m / 9.0 * exposure, 0.004);
	return clamp(pow(scan_target / m, scan_strength), 0.7, 8.0) * exposure;
}

// the scanner's shoulder: lifted darks keep their highlights instead of burning a face to bare paper
vec3 scan(vec3 c) { return c / (1.0 + 0.55 * c); }

vec2 coverage(vec3 c) {
	float L = clamp(luma(c), 0.0, 1.0);
	float mx = max(max(c.r, c.g), c.b) + 1e-4;
	float warm = clamp((c.r - c.b) / mx, 0.0, 1.0);
	float cold = clamp((c.b - c.r) / mx, 0.0, 1.0);
	float d = 1.0 - L;
	// three steps: light = paper, mid-dark = blue alone, deepest shadow = blue + orange overprinted (the dark teal)
	float a = smoothstep(0.36, 0.86, d);                        // blue: the dark, mid-tones stay paper
	a += cold * 0.45 * (1.0 - a);                               // cold light prints as light blue dots
	a *= 1.0 - 0.55 * warm * smoothstep(0.08, 0.5, L);          // lit warm surfaces are not blue
	float b = clamp(warm * 1.15, 0.0, 1.0) * mix(0.55, 0.95, smoothstep(0.04, 0.4, L));  // orange: warm light only
	b *= 1.0 - 0.55 * smoothstep(0.35, 0.75, L);                // well-lit warm surfaces open up to paper between dots
	float deep = smoothstep(0.84, 0.975, d);                    // only the deepest shadow gets the second ink
	b = b + deep * 0.92 * (1.0 - b);
	return vec2(clamp(a, 0.0, 1.0), clamp(b, 0.0, 1.0));
}

// 試作94 the night print. The old coverage inked every dark with both plates, so a night room was one teal sheet
// with the form lost in it (the same failure as 試作4, back again once the whole house was dark). Here:
//  - paper is the light; the blue plate alone carries the form, on a long halftone ramp, solid only near black;
//  - the orange plate is warm AND lit (a lamp's pool, a lit face) - a dark surface is blue whatever its hue;
//  - both plates overlap only in the real black, so teal is the dark of the house and not its mid-tones;
//  - which plate a surface goes to is decided from a soft copy (cw), so a mottled wall is not split into two inks.
vec2 coverage_night(vec3 c, vec3 cw) {
	float L = clamp(luma(c), 0.0, 1.0), d = 1.0 - L;
	float Lw = clamp(luma(cw), 0.0, 1.0);
	float mx = max(max(c.r, c.g), c.b) + 1e-4, mw = max(max(cw.r, cw.g), cw.b) + 1e-4;
	float cold = clamp((c.b - c.r) / mx, 0.0, 1.0);
	float warm = clamp((cw.r - cw.b) / mw, 0.0, 1.0);
	float wk = smoothstep(0.12, 0.45, warm) * smoothstep(0.10, 0.30, Lw);
	float a = smoothstep(0.30, 0.90, d);
	a += cold * 0.35 * (1.0 - a);
	a *= 1.0 - wk * (1.0 - smoothstep(0.60, 0.92, d));          // in warm light the blue comes in only as its shadow
	float b = wk * 0.8 * smoothstep(0.30, 0.90, d) * (1.0 - 0.5 * smoothstep(0.60, 1.0, d));   // a well-lit warm surface opens to paper
	float deep = smoothstep(0.85, 0.96, d);
	b = b + deep * 0.9 * (1.0 - b);
	return vec2(clamp(a, 0.0, 1.0), clamp(b, 0.0, 1.0));
}
// the printer dodges: the gain of this part of the sheet, from a very soft copy of the frame (no halo at an edge)
float dodge_gain(vec2 uv, float g) {
	if (look < 0.5 || dodge <= 0.0) return g;
	vec2 o = vec2(0.045, 0.08);
	float m = luma(textureLod(screen_tex, uv, 6.0).rgb) * 2.0;
	m += luma(textureLod(screen_tex, uv + vec2(o.x, 0.0), 6.0).rgb) + luma(textureLod(screen_tex, uv - vec2(o.x, 0.0), 6.0).rgb);
	m += luma(textureLod(screen_tex, uv + vec2(0.0, o.y), 6.0).rgb) + luma(textureLod(screen_tex, uv - vec2(0.0, o.y), 6.0).rgb);
	m = max(m / 6.0 * g, 0.004);
	return g * clamp(pow(dodge_target / m, dodge), 1.0, dodge_max);   // it only lifts: what is lit keeps its paper
}
vec2 cover(vec2 uv, float g) {
	float gl = dodge_gain(uv, g);
	vec3 c = scan((textureLod(screen_tex, uv, 1.0).rgb * 0.5 + textureLod(screen_tex, uv, 0.0).rgb * 0.5) * gl);
	if (look < 0.5) return coverage(c);
	return coverage_night(c, scan(textureLod(screen_tex, uv, 5.0).rgb * gl));
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec3 src = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	if (enabled < 0.5) { COLOR = vec4(src * exposure, 1.0); }
	else {
		float g = scan_gain();
		float k = res.y / 1080.0;
		float frame = floor((TIME + time_offset) * print_fps);
		vec2 px = SCREEN_UV * res;
		float cell = max(cell_px * k, 3.0);
		if (mode == 1) {
			vec2 q = (SCREEN_UV - 0.5) * vec2(res.x / res.y, 1.0);
			cell = max(mix(cell_px, edge_cell_px, smoothstep(0.12, 0.62, length(q))) * k, 3.0);
		}
		vec2 cov = cover(SCREEN_UV, g);
		vec2 mis = vec2(-3.0, 2.0) * k + slip * k + (vec2(hash(vec2(frame, 1.7)), hash(vec2(frame, 9.1))) - 0.5) * 3.0 * k;
		vec2 uvb = SCREEN_UV - mis / res;
		float covb = cover(uvb, g).y;
		// grain the size of a dot, re-drawn every print
		float g1 = (hash(floor(px / max(cell * 0.5, 1.0)) + frame * 17.31) - 0.5) * 0.16;
		float g2 = (hash(floor((px + mis) / max(cell * 0.5, 1.0)) + frame * 23.77 + 5.0) - 0.5) * 0.16;
		float A = step(1.0 - dots(px, 15.0, cell) + g1, cov.x) * step(0.02, cov.x);
		float B = step(1.0 - dots(px + mis, 75.0, cell * 1.05) + g2, covb) * step(0.02, covb);
		// ink density: slow, soft, only noticeable in solids
		float da = 0.93 + 0.07 * vnoise(px / (420.0 * k) + vec2(3.0, 0.0));
		float db = 0.93 + 0.07 * vnoise(px / (420.0 * k) + vec2(11.0, 7.0));
		vec3 pap = paper * (0.975 + 0.025 * hash(floor(px / (2.0 * k))));
		vec3 o = pap * (1.0 - A * da * (1.0 - ink_a)) * (1.0 - B * db * (1.0 - ink_b));
		COLOR = vec4(o, 1.0);
	}
}
