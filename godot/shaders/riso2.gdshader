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
uniform float look = 0.0;          // 試作94: 0 = the print as it was (夕方), 1 = the night print (coverage_night, dodge), 2 = the day print (証言の部屋, 2026-11-19)
uniform float flat_ink = 0.0;      // 証言 三: the flattened room - no screen, three flat inks (paper / blue / teal), like a cut-out background
uniform float dodge = 0.45;        // night print: how far each part of the sheet is exposed for what is in it (0 = one exposure)
uniform float dodge_target = 0.30; // the mean it aims for, before the shoulder
uniform float dodge_max = 1.8;
uniform vec2 slip = vec2(0.0);     // 段階1 扉の場面: the second plate slips off register while Mio says nothing (px at 1080)
uniform float face_grain = 1.0;    // 試作289：肌の上で粒を弱める仕組み。ユーザー「前の方がいい」（2026-11-25 20:43）で 1.0（弱めない）に戻した
uniform float cloth_blue = 0.0;    // 試作293（レビュー 2026-11-26 直し1「ろうそくの真琴が裸に見える」）: the night print gives pale things lit by a warm
                                   // light (a white sweater, white paint: warm 0.45..0.66) a light blue screen, so they part from skin (warm 0.70+)
uniform float show_skin = 0.0;     // check: tints what is read as skin    // 試作289（感想282 5-5）: the grain left on lit skin (1 = as everywhere else)

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
	// a well-lit warm surface opens to paper, but keeps a light tint of dots until it is really bright
	// (試作94: with none, a candle-lit counter burned out to bare paper - ユーザー「白く飛びすぎ」)
	float b = wk * (0.15 * (1.0 - smoothstep(0.78, 0.95, L)) + 0.60 * smoothstep(0.25, 0.88, d)) * (1.0 - 0.5 * smoothstep(0.60, 1.0, d));
	float deep = smoothstep(0.85, 0.96, d);
	b = b + deep * 0.9 * (1.0 - b);
	return vec2(clamp(a, 0.0, 1.0), clamp(b, 0.0, 1.0));
}
// 試作289 lit skin, from a soft copy: r > g > b, a little warm (not wood, not a flame or a sunset window), lit. The grain is weakened
// there, so a face in the radio's or a candle's light keeps its shape instead of being eaten by the speckle
float skin(vec2 uv) {
	vec3 c = textureLod(screen_tex, uv, 4.5).rgb;
	float mx = max(max(c.r, c.g), c.b) + 1e-4;
	float L = luma(c);
	float warm = (c.r - c.b) / mx;
	float order = step(c.b, c.g) * step(c.g, c.r);
	return order * smoothstep(0.04, 0.12, warm) * (1.0 - smoothstep(0.24, 0.34, warm)) * smoothstep(0.25, 0.5, L);
}
// 試作293 pale and lit by a warm light, and not skin: measured on 1時 (candle): sweater 0.57..0.60, white cabinet 0.64, skin 0.70..0.72, wood 0.95+
float cloth(vec2 uv) {
	// lod 1.5: a far, small figure keeps its edges (the cuff, the neckline); the dimmer side of the sweater still counts (L from 0.18)
	vec3 c = textureLod(screen_tex, uv, 1.5).rgb;
	float mx = max(max(c.r, c.g), c.b) + 1e-4;
	float L = luma(c);
	float warm = (c.r - c.b) / mx;
	float order = step(c.b, c.g) * step(c.g, c.r);
	return order * smoothstep(0.40, 0.50, warm) * (1.0 - smoothstep(0.64, 0.69, warm)) * smoothstep(0.18, 0.32, L);
}
// the printer dodges: the gain of this part of the sheet, from a very soft copy of the frame (no halo at an edge)
float dodge_gain(vec2 uv, float g) {
	if (look < 0.5 || look > 1.5 || dodge <= 0.0) return g;
	vec2 o = vec2(0.045, 0.08);
	float m = luma(textureLod(screen_tex, uv, 6.0).rgb) * 2.0;
	m += luma(textureLod(screen_tex, uv + vec2(o.x, 0.0), 6.0).rgb) + luma(textureLod(screen_tex, uv - vec2(o.x, 0.0), 6.0).rgb);
	m += luma(textureLod(screen_tex, uv + vec2(0.0, o.y), 6.0).rgb) + luma(textureLod(screen_tex, uv - vec2(0.0, o.y), 6.0).rgb);
	m = max(m / 6.0 * g, 0.004);
	return g * clamp(pow(dodge_target / m, dodge), 1.0, dodge_max);   // it only lifts: what is lit keeps its paper
}
vec2 cover(vec2 uv, float g) {
	float gl = dodge_gain(uv, g);
	vec3 raw = textureLod(screen_tex, uv, 1.0).rgb * 0.5 + textureLod(screen_tex, uv, 0.0).rgb * 0.5;
	vec3 c = scan(raw * gl);
	if (look > 1.5) {
		// the day print (blender/interview/iv/riso.py day=True, ユーザー OK 2026-11-15): only the shoji's white is paper;
		// a pale shadow (the leaves on the shoji) gets a light screen, the walls' mid-tones stay near white, the darks go solid
		vec2 cv = coverage(c);
		float d = 1.0 - clamp(luma(raw * gl), 0.0, 1.0);
		cv.x = 0.30 * smoothstep(0.06, 0.28, d) + 0.70 * smoothstep(0.38, 0.92, d);
		return cv;
	}
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
		float cl = (cloth_blue > 0.0 && look > 0.5 && look < 1.5) ? cloth(SCREEN_UV) * cloth_blue : 0.0;
		cov.x = max(cov.x, cl * 0.26);   // a light blue screen on it
		vec2 mis = vec2(-3.0, 2.0) * k + slip * k + (vec2(hash(vec2(frame, 1.7)), hash(vec2(frame, 9.1))) - 0.5) * 3.0 * k;
		vec2 uvb = SCREEN_UV - mis / res;
		float covb = cover(uvb, g).y * (1.0 - 0.25 * cl);   // and less of the warm plate: a pale thing, not skin
		// grain the size of a dot, re-drawn every print
		float sk = skin(SCREEN_UV);
		float gk = mix(1.0, face_grain, sk);
		float gate = 0.02;   // and on skin, no lone dots where there is almost no ink
		float g1 = (hash(floor(px / max(cell * 0.5, 1.0)) + frame * 17.31) - 0.5) * 0.16 * gk;
		float g2 = (hash(floor((px + mis) / max(cell * 0.5, 1.0)) + frame * 23.77 + 5.0) - 0.5) * 0.16 * gk;
		float A = step(1.0 - dots(px, 15.0, cell) + g1, cov.x) * step(gate, cov.x);
		float B = step(1.0 - dots(px + mis, 75.0, cell * 1.05) + g2, covb) * step(gate, covb);
		if (flat_ink > 0.5) {   // flat: solid where dark, an even light tint where there is any ink, paper elsewhere
			float ta = step(1.0 - dots(px, 15.0, cell), 0.42), tb = step(1.0 - dots(px + mis, 75.0, cell * 1.05), 0.30);
			A = cov.x > 0.55 ? 1.0 : (cov.x > 0.03 ? ta : 0.0);
			B = covb > 0.6 ? 1.0 : (covb > 0.25 ? tb : 0.0);
		}
		// ink density: slow, soft, only noticeable in solids
		float da = 0.93 + 0.07 * vnoise(px / (420.0 * k) + vec2(3.0, 0.0));
		float db = 0.93 + 0.07 * vnoise(px / (420.0 * k) + vec2(11.0, 7.0));
		vec3 pap = paper * (0.975 + 0.025 * hash(floor(px / (2.0 * k))));
		vec3 o = pap * (1.0 - A * da * (1.0 - ink_a)) * (1.0 - B * db * (1.0 - ink_b));
		COLOR = vec4(o, 1.0);
		if (show_skin > 0.5) COLOR = vec4(mix(o, vec3(1.0, 0.0, 1.0), sk * 0.7), 1.0);
	}
}
