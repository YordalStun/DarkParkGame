shader_type canvas_item;
// Full-screen PS1 look, applied to the low-resolution 3D view as it is upscaled:
// 15-bit colour with ordered dithering, film grain, vignette and a faint lens warmth.

uniform float color_levels = 32.0;   // per channel (32 = PS1 15-bit colour)
uniform float dither_strength = 1.0;
uniform float grain = 0.035;
uniform float vignette = 0.45;
uniform float fade = 1.0;            // 0 = black, 1 = visible (scene fades)
uniform float flash = 0.0;           // extra exposure (lightning through the window)

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	// 4x4 Bayer matrix
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);   // low-res pixel coordinate
	vec3 c = texture(TEXTURE, UV).rgb;
	c *= 1.0 + flash;

	// grain (animated, per low-res pixel)
	float n = hash(px + fract(TIME * 7.13) * 91.7) - 0.5;
	c += n * grain * (0.4 + 0.6 * (1.0 - dot(c, vec3(0.33))));

	// vignette
	vec2 d = UV - 0.5;
	d.x *= 1.3;
	c *= 1.0 - vignette * smoothstep(0.25, 0.8, length(d));

	// ordered dither + colour quantisation
	float lv = color_levels - 1.0;
	c = floor(c * lv + 0.5 + bayer4(px) * dither_strength) / lv;

	COLOR = vec4(clamp(c, 0.0, 1.0) * fade, 1.0);
}
