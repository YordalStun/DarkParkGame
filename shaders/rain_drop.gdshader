shader_type spatial;
// Rain streaks. Each drop is a thin quad stretched along its fall direction and
// turned to face the camera. Drops are additive and only show where real light
// hits them (lamp cone, booth spill, lightning), like real rain at night.

render_mode blend_add, cull_disabled, depth_draw_never, specular_disabled, ambient_light_disabled;

uniform float streak_length = 0.45;
uniform float streak_width = 0.012;
uniform float brightness = 0.6;
uniform float fall_speed = 9.0;
uniform bool splash = false;   // ground splash mode: tiny round dots instead of streaks

global uniform float wind_strength;
global uniform vec2 wind_dir;

varying float v_fade;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - c);
	vec3 axis;
	if (splash) {
		axis = vec3(0.0, 1.0, 0.0) * streak_length;
	} else {
		vec3 vel = vec3(wind_dir.x * wind_strength * 3.0, -fall_speed, wind_dir.y * wind_strength * 3.0);
		axis = normalize(vel) * streak_length;
	}
	// Drops right at the lens are invisible anyway (faded out): collapse them so the
	// GPU doesn't rasterise huge transparent quads across the screen.
	float keep = step(0.6, length(INV_VIEW_MATRIX[3].xyz - c));
	vec3 side = normalize(cross(axis, to_cam)) * streak_width;
	vec3 fwd = normalize(cross(side, axis));
	// QuadMesh is 1x1: x in -0.5..0.5, y in -0.5..0.5
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * keep, 0.0), vec4(axis * keep, 0.0), vec4(fwd, 0.0), vec4(c, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	NORMAL = vec3(0.0, 0.0, 1.0);
	// fade drops very close to the camera (they'd be huge smears)
	float dist = length(INV_VIEW_MATRIX[3].xyz - c);
	v_fade = smoothstep(0.6, 2.0, dist) * COLOR.a;
}

void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float y = UV.y;
	float shape;
	if (splash) {
		shape = (1.0 - smoothstep(0.2, 1.0, length(UV - 0.5) * 2.0));
	} else {
		shape = (1.0 - x * x) * smoothstep(0.0, 0.35, y) * smoothstep(1.0, 0.7, y);
	}
	ALBEDO = vec3(0.85, 0.9, 1.0);
	ALPHA = shape * brightness * v_fade;
}

void light() {
	// Ignore N.L: a falling drop catches light from any direction.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.35;
}
