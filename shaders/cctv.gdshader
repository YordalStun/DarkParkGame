shader_type canvas_item;
// Late-80s CCTV look for a camera feed: black and white with a faint green cast,
// crushed blacks, grain, scanlines, a vignette and the odd jittery line.

uniform float seed = 0.0;
uniform float signal_level = 1.0;   // 0 = no signal (pure snow)

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float line = floor(uv.y * 240.0);
	float glitch = step(0.985, hash(vec2(floor(TIME * 4.0), seed)));
	uv.x += (hash(vec2(line, floor(TIME * 15.0) + seed)) - 0.5) * 0.012 * glitch;

	vec3 c = texture(TEXTURE, uv).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	l = clamp(pow(l, 0.65) * 1.25, 0.0, 1.0);
	float snow = hash(floor(uv * vec2(320.0, 240.0)) + fract(TIME * 13.7) * 91.0);
	l += (snow - 0.5) * 0.09;
	l = mix(snow * 0.7, l, signal_level);
	l *= 0.88 + 0.12 * sin(uv.y * 240.0 * 3.14159);
	vec2 d = UV - 0.5;
	l *= 1.0 - smoothstep(0.35, 0.75, length(d * vec2(1.1, 1.0)));
	COLOR = vec4(l * vec3(0.84, 1.0, 0.88), 1.0);
}
