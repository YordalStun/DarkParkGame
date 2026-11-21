shader_type spatial;
// Old CRT monitor glass: curved picture, scanlines, phosphor bloom, a slow
// rolling refresh bar, flicker, and the curved glass reflecting the room.

uniform sampler2D screen : source_color, filter_linear;
uniform float brightness = 2.2;
uniform float curvature = 0.08;
uniform float scanline_count = 240.0;
uniform float power = 1.0;              // 0 = off, 1 = on (for power on/off effects)
uniform float bloom = 1.0;              // 1 = full phosphor blur, 0 = sharp
uniform float scan_depth = 0.3;         // scanline darkness
uniform float gamma = 1.0;              // >1 deepens mid-tones (contrast)
uniform vec2 texel = vec2(0.001953125, 0.00260417); // 1 / screen texture size
uniform vec3 glass_tint : source_color = vec3(0.025, 0.03, 0.028);

vec2 curve(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 o = uv.yx * uv.yx * curvature;
	uv += uv * o;
	return uv * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curve(UV);
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);

	// Phosphor bloom: small blur around each sample.
	vec2 px = texel;
	vec3 c = texture(screen, uv).rgb * 0.6;
	c += texture(screen, uv + vec2(px.x, 0.0)).rgb * 0.1;
	c += texture(screen, uv - vec2(px.x, 0.0)).rgb * 0.1;
	c += texture(screen, uv + vec2(0.0, px.y)).rgb * 0.1;
	c += texture(screen, uv - vec2(0.0, px.y)).rgb * 0.1;
	vec3 wide = texture(screen, uv + vec2(px.x * 2.0, 0.0)).rgb + texture(screen, uv - vec2(px.x * 2.0, 0.0)).rgb
		+ texture(screen, uv + vec2(0.0, px.y * 2.0)).rgb + texture(screen, uv - vec2(0.0, px.y * 2.0)).rgb;
	c += wide * 0.03;
	c = mix(texture(screen, uv).rgb, c, bloom);
	c = pow(c, vec3(gamma));

	float scan = (1.0 - scan_depth) + scan_depth * sin(uv.y * scanline_count * 3.14159 * 2.0);
	float roll = 1.0 + 0.06 * smoothstep(0.0, 0.08, fract(uv.y * 0.5 - TIME * 0.11)) * smoothstep(0.16, 0.08, fract(uv.y * 0.5 - TIME * 0.11));
	float flick = 1.0 + 0.015 * sin(TIME * 59.0) + 0.01 * sin(TIME * 7.3);
	float edge = smoothstep(0.0, 0.06, uv.x) * smoothstep(1.0, 0.94, uv.x) * smoothstep(0.0, 0.06, uv.y) * smoothstep(1.0, 0.94, uv.y);

	// The tube is never fully black: a faint green-grey phosphor glow.
	vec3 phosphor_floor = vec3(0.006, 0.014, 0.008);
	vec3 pic = (c * scan * roll * flick + phosphor_floor) * edge * inside * power;

	ALBEDO = glass_tint;
	EMISSION = pic * brightness;
	ROUGHNESS = 0.32;
	SPECULAR = 0.3;
}
