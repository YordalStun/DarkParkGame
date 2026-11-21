shader_type spatial;
// Faint wisps of steam rising from the coffee mug.

render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity = 0.08;

varying float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	seed = INSTANCE_CUSTOM.x;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 uv = UV;
	float n = noise(uv * 4.0 + vec2(0.0, -TIME * 0.6) + seed * 10.0);
	float d = length(uv - 0.5) * 2.0;
	float a = smoothstep(1.0, 0.2, d) * n * opacity * COLOR.a;
	ALBEDO = vec3(0.85);
	ALPHA = a;
}
