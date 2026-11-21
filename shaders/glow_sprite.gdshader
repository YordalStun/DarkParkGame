shader_type spatial;
// Soft camera-facing halo for lamps (the misty glow around a bulb in the rain).

render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.6, 0.25);
uniform float intensity = 1.0;
uniform float softness = 2.2;
uniform float flicker = 1.0;   // driven by script

global uniform float rain_amount;

void vertex() {
	// full billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float g = pow(clamp(1.0 - d, 0.0, 1.0), softness);
	float core = pow(clamp(1.0 - d * 2.5, 0.0, 1.0), 3.0);
	// Rain and mist make the halo bigger and stronger.
	float mist = 0.6 + 0.6 * rain_amount;
	ALBEDO = color * (g * mist + core * 2.0) * intensity * flicker;
}
