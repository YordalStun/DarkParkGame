shader_type spatial;
// Asphalt / concrete that gets wet: darker, glossier, with puddles that reflect
// the street lamp and show expanding raindrop ripples.

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tex_scale = 0.25;        // texture repeats per metre
uniform float puddle_amount = 0.5;     // 0 = none, 1 = lots
uniform float puddle_scale = 0.12;
uniform float dry_roughness = 0.9;

global uniform float rain_amount;
global uniform float wetness;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

// Ripple rings from raindrops on standing water. Returns a 2D normal offset.
vec2 ripples(vec2 p, float t, float density) {
	vec2 acc = vec2(0.0);
	for (int layer = 0; layer < 2; layer++) {
		vec2 q = p * (3.0 + float(layer) * 1.7) + float(layer) * 7.3;
		vec2 id = floor(q);
		vec2 f = fract(q);
		float rnd = hash(id + float(layer) * 13.1);
		if (rnd > density) continue;
		vec2 c = vec2(hash(id + 1.7), hash(id + 3.9)) * 0.6 + 0.2;
		float life = fract(t * (0.9 + rnd * 0.6) + rnd * 7.0);
		vec2 d = f - c;
		float dist = length(d);
		float radius = life * 0.45;
		float ring = sin(clamp((dist - radius) * 40.0, -3.1416, 3.1416)) * (1.0 - life) * smoothstep(0.08, 0.0, abs(dist - radius));
		acc += normalize(d + 0.0001) * ring;
	}
	return acc;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 base = texture(albedo_tex, p * tex_scale).rgb * tint;
	float wet = clamp(wetness, 0.0, 1.0);

	float pn = fbm(p * puddle_scale) + fbm(p * puddle_scale * 4.0) * 0.25;
	float puddle = smoothstep(0.72 - puddle_amount * 0.2, 0.76 - puddle_amount * 0.2, pn) * wet;
	float damp = smoothstep(0.45, 0.7, pn) * wet;

	ALBEDO = base * mix(1.0, 0.5, wet) * mix(1.0, 0.45, puddle);
	ROUGHNESS = mix(dry_roughness, mix(0.45, 0.25, damp), wet);
	ROUGHNESS = mix(ROUGHNESS, 0.02, puddle);
	SPECULAR = 0.5;

	// Ripples only on puddles and only while it rains.
	vec2 rip = ripples(p, TIME, 0.25 + rain_amount * 0.7) * puddle * clamp(rain_amount * 1.5, 0.0, 1.0);
	vec3 n_world = normalize(vec3(rip.x * 0.6, 1.0, rip.y * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
