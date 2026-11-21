shader_type spatial;
// Booth window: faint tint, reflections of the lit interior (via the reflection
// probe), and procedural raindrops that refract the dark lot behind them.
// Static beads appear and evaporate; bigger drops run down leaving trails.

render_mode blend_premul_alpha, cull_disabled, depth_draw_never;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 pane_size = vec2(1.0, 1.0);  // metres, keeps drop size constant across panes
uniform float seed = 0.0;
uniform vec3 tint : source_color = vec3(0.55, 0.62, 0.6);
uniform float tint_alpha = 0.06;
uniform float dirt = 0.04;
uniform float rain_side = 1.0;            // 1 = faces the weather, 0.3 = sheltered pane

global uniform float rain_amount;
global uniform float wetness;
global uniform float lightning;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
vec2 h22(vec2 p) {
	float n = h21(p);
	return vec2(n, h21(p + n));
}

// Static beads. Returns (offset.xy, mask)
vec3 beads(vec2 uv, float scale, float t, float density) {
	vec2 g = uv * scale;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	vec2 r = h22(id + seed);
	vec2 p = (r - 0.5) * 0.7;
	float life = fract(t * (0.05 + r.x * 0.08) + r.y);
	float present = step(r.x, density) * smoothstep(0.0, 0.05, life) * smoothstep(1.0, 0.6, life);
	float size = mix(0.12, 0.32, r.y);
	vec2 d = f - p;
	float m = smoothstep(size, size * 0.6, length(d)) * present;
	return vec3(d * m, m);
}

// Running drops in columns with trails. Returns (offset.xy, mask)
vec3 runners(vec2 uv, float t, float density) {
	vec2 a = vec2(6.0, 1.0);
	vec2 g = uv * a * 4.0;
	float col = floor(g.x);
	float rc = h21(vec2(col, seed * 3.1));
	if (rc > density) return vec3(0.0);
	g.y += t * (0.35 + rc * 0.5) + rc * 10.0;      // move down
	vec2 id = floor(g);
	vec2 f = fract(g) - vec2(0.5, 0.0);
	float n = h21(id + seed);
	// wiggle
	float x = (n - 0.5) * 0.6 + sin(g.y * 4.0 + sin(g.y * 2.1)) * 0.08;
	float y = 0.85 - fract(n * 7.0) * 0.1;
	vec2 d = (f - vec2(x, y)) / a * vec2(1.0, 4.0);
	float drop = smoothstep(0.06, 0.035, length(d * vec2(1.0, 0.8)));
	// trail of small beads above the drop
	float trail_on = smoothstep(y, y - 0.9, f.y) * step(f.y, y);
	vec2 td = vec2((f.x - x) / a.x, (fract(f.y * 8.0) - 0.5) / 8.0 / a.y * 4.0);
	float trail = smoothstep(0.025, 0.015, length(td)) * trail_on * step(0.3, fract(n * 13.0));
	float m = max(drop, trail * 0.8);
	return vec3(d * drop * 4.0 + td * trail, m);
}

void fragment() {
	vec2 uv = UV * pane_size;
	float r = clamp(rain_amount, 0.0, 1.0) * rain_side;
	float wet = clamp(wetness, 0.0, 1.0) * rain_side;
	float t = TIME;

	vec3 b1 = beads(uv, 22.0, t, 0.25 + 0.6 * wet);
	vec3 b2 = beads(uv + 0.37, 38.0, t * 1.3, 0.2 + 0.5 * wet);
	vec3 run = runners(uv * vec2(1.0, -1.0), t, r * 0.55);

	vec2 off = (b1.xy + b2.xy * 0.6) * 0.06 + run.xy * 0.05;
	float mask = clamp(b1.z + b2.z * 0.7 + run.z, 0.0, 1.0);

	// Refract what is behind the glass. Wet glass is a touch blurry overall.
	float blur = mix(0.0, 1.6, wet * 0.6) + mask * 1.5;
	vec3 behind = textureLod(screen_tex, SCREEN_UV + off, blur).rgb;
	vec3 sharp = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;

	// Drops gather light: brighten the refracted background a little.
	vec3 drop_col = behind * 1.35 + vec3(0.004, 0.005, 0.006) + lightning * 0.15;
	// Wet film (no drop) shows a slightly blurred view.
	vec3 film = mix(sharp, behind, wet * 0.5);

	float a = max(mask, wet * 0.5);
	vec3 base = mix(film, drop_col, mask);

	// Premultiplied: we replace (a) of the background with our own colour,
	// plus a faint tint/dirt layer. Specular reflections are added on top.
	ALBEDO = vec3(0.0);
	EMISSION = base * a + tint * (tint_alpha + dirt) * 0.05;
	ALPHA = clamp(a + tint_alpha + dirt, 0.0, 1.0);
	ROUGHNESS = mix(0.04, 0.12, mask);
	SPECULAR = 0.35;
	METALLIC = 0.0;
	NORMAL = normalize(NORMAL + vec3(off * 6.0, 0.0));
}

void light() {
	// No direct lighting: the glass only shows refraction and the interior
	// reflection probe (a point-light highlight would look like a moon).
}
