// The whole frame re-printed in two Riso inks on off-white paper.
// Blue takes the dark and the cold, Orange takes what the warm (tungsten) lights touch; where they overprint
// they make the deep teal. Halftone screens at 15° and 75°, a grain that changes 12 times a second,
// the orange plate slightly out of register and wandering a pixel or two between "prints".
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float enabled = 1.0;
uniform int mode = 0;                 // 0: one screen size everywhere, 1: fine at the centre, coarse at the edges
uniform float cell_px = 3.6;          // halftone cell at 1080 lines (mode 0) / at the centre (mode 1)
uniform float edge_cell_px = 7.0;     // mode 1: cell at the frame edges
uniform float print_fps = 12.0;
uniform float time_offset = 0.0;
uniform vec3 paper = vec3(0.933, 0.910, 0.855);
uniform vec3 ink_a = vec3(0.0, 0.47, 0.75);     // Riso Blue
uniform vec3 ink_b = vec3(1.0, 0.424, 0.184);   // Riso Fluorescent Orange
uniform float exposure = 1.0;

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

vec2 coverage(vec3 c) {
	float L = dot(c, vec3(0.299, 0.587, 0.114));
	float warm = clamp(c.r - c.b, 0.0, 1.0), cold = clamp(c.b - c.r, 0.0, 1.0);
	float dark = 1.0 - pow(clamp(L * 1.25, 0.0, 1.0), 0.8);
	float a = clamp(dark * 1.05 + cold * 2.2 - warm * 0.8, 0.0, 1.0);
	float b = clamp(dark * 0.82 + warm * 1.9 - cold * 0.6, 0.0, 1.0);
	return vec2(a, b);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec3 src = textureLod(screen_tex, SCREEN_UV, 0.0).rgb * exposure;
	if (enabled < 0.5) { COLOR = vec4(src, 1.0); }
	else {
		float k = res.y / 1080.0;                                   // keep the screen size tied to the print, not the monitor
		float frame = floor((TIME + time_offset) * print_fps);
		vec2 px = SCREEN_UV * res;
		float cell = max(cell_px * k, 3.0);
		if (mode == 1) {
			vec2 q = (SCREEN_UV - 0.5) * vec2(res.x / res.y, 1.0);
			float d = smoothstep(0.12, 0.62, length(q));
			cell = max(mix(cell_px, edge_cell_px, d) * k, 3.0);
		}
		// soften the source a little so the screen does not alias against hard pixel edges
		vec3 c = textureLod(screen_tex, SCREEN_UV, 1.0).rgb * exposure * 0.5 + src * 0.5;
		vec2 cov = coverage(c);
		// the orange plate is out of register, and wanders between prints
		vec2 mis = vec2(-3.0, 2.0) * k + (vec2(hash(vec2(frame, 1.7)), hash(vec2(frame, 9.1))) - 0.5) * 3.0 * k;
		vec3 cb = textureLod(screen_tex, SCREEN_UV - mis / res, 1.0).rgb * exposure * 0.5 + textureLod(screen_tex, SCREEN_UV - mis / res, 0.0).rgb * exposure * 0.5;
		float covb = coverage(cb).y;
		float g1 = (hash(floor(px / max(1.6 * k, 1.0)) + frame * 17.31) - 0.5) * 0.2 + (vnoise(px / (40.0 * k) + frame * 3.1) - 0.5) * 0.05;
		float g2 = (hash(floor(px / max(1.6 * k, 1.0)) + frame * 23.77 + 5.0) - 0.5) * 0.2 + (vnoise(px / (40.0 * k) + frame * 5.3 + 11.0) - 0.5) * 0.05;
		float A = step(1.0 - dots(px, 15.0, cell) + g1, cov.x) * step(0.03, cov.x);
		float B = step(1.0 - dots(px + mis, 75.0, cell * 1.05) + g2, covb) * step(0.03, covb);
		float drum = 0.9 + 0.1 * vnoise(px / (90.0 * k));         // uneven ink on the drum
		vec3 pap = paper * (0.96 + 0.04 * hash(floor(px / (3.0 * k)) + 0.5));
		vec3 o = pap * (1.0 - A * drum * (1.0 - ink_a)) * (1.0 - B * drum * (1.0 - ink_b));
		COLOR = vec4(o, 1.0);
	}
}
