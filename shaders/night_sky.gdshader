shader_type sky;
// Overcast night: low clouds drifting with the wind, a faint sodium-orange
// city glow along the horizon, and lightning that lights the clouds from within.

uniform vec3 zenith : source_color = vec3(0.004, 0.005, 0.009);
uniform vec3 horizon : source_color = vec3(0.03, 0.026, 0.028);
uniform vec3 city_glow : source_color = vec3(0.13, 0.065, 0.028);
uniform vec3 cloud_col : source_color = vec3(0.03, 0.028, 0.032);
uniform float glow_strength = 1.0;
uniform float dawn = 0.0;   // 0 = night, 1 = full grey morning (05:00 -> 07:00)
uniform vec3 sunrise_col : source_color = vec3(0.95, 0.5, 0.24);
const vec2 SUN_DIR = vec2(-0.6, -0.8);   // where the sun comes up (ahead and to the left of the booth)

global uniform float lightning;
global uniform float wind_strength;
global uniform vec2 wind_dir;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, 0.0, 1.0);
	vec3 hor = mix(horizon, vec3(0.30, 0.33, 0.37), dawn);
	vec3 zen = mix(zenith, vec3(0.14, 0.17, 0.22), dawn);
	float band = smoothstep(0.05, 0.4, dawn) * (1.0 - smoothstep(0.55, 0.95, dawn));
	float az = pow(max(dot(normalize(d.xz + vec2(0.0001)), normalize(SUN_DIR)), 0.0), 2.0);
	vec3 col = mix(hor, zen, pow(up, 0.5));
	col += city_glow * glow_strength * (1.0 - smoothstep(0.0, 0.6, dawn)) * exp(-max(d.y, 0.0) * 9.0);
	col += sunrise_col * band * (0.25 + 0.75 * az) * 0.9 * exp(-max(d.y, 0.0) * 5.0);

	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.15);
		uv += wind_dir * TIME * (0.004 + 0.01 * wind_strength);
		float c = fbm(uv * 1.6);
		float c2 = fbm(uv * 3.7 + 4.0);
		float clouds = smoothstep(0.35, 0.8, c * 0.7 + c2 * 0.4);
		// Clouds are lit from below by the city glow.
		vec3 cc = mix(cloud_col, vec3(0.36, 0.38, 0.43), dawn) + city_glow * 0.5 * (1.0 - dawn) * exp(-d.y * 4.0);
		cc += sunrise_col * band * az * 0.55 * exp(-d.y * 3.0);
		col = mix(col, cc, clouds * 0.85);
		// Lightning: clouds flash, brighter where thick.
		col += vec3(0.55, 0.6, 0.75) * lightning * (0.25 + clouds * 1.4) * (0.5 + 0.5 * c2);
	} else {
		col = hor * 0.6;
	}
	COLOR = col;
}
