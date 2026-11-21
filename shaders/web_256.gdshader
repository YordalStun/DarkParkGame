shader_type canvas_item;
// Shows modern web pages the way a 1995 PC with a 256-colour display would:
// colours snapped to the 216-colour "web-safe" palette with an ordered dither.
// Videos get the same treatment, which gives them that grainy CD-ROM look.

uniform bool enabled = true;
uniform float levels = 6.0;          // per channel: 6 x 6 x 6 = 216 colours
uniform float dither_amount = 0.85;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[x + y * 4] / 16.0 - 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (enabled) {
		float lv = levels - 1.0;
		vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
		c.rgb = floor(c.rgb * lv + 0.5 + bayer4(px) * dither_amount) / lv;
	}
	COLOR = vec4(clamp(c.rgb, 0.0, 1.0), 1.0);
}
