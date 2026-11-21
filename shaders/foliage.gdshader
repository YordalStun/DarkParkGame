shader_type spatial;
// Trees and bushes: wind sway (whole tree bends from the base, branches lag,
// leaves flutter). Displacement also runs in the shadow pass, so shadows sway too.

uniform sampler2D albedo_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float tex_scale = 1.0;     // texture repeats per metre (triplanar)
uniform float height = 6.0;        // tree height in metres (0..1 bend falloff)
uniform float stiffness = 1.0;     // 1 = leaves, ~0.4 = trunk
uniform float flutter = 1.0;       // leaf flutter amount
uniform float roughness_v = 0.85;

global uniform float wind_strength;
global uniform vec2 wind_dir;
global uniform float wetness;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin.xz, vec2(0.37, 0.71));
	float h = clamp(VERTEX.y / height, 0.0, 1.5);
	float bend = h * h * stiffness;
	float t = TIME;

	// Wind direction into local space (trees are only rotated about Y and uniformly scaled).
	vec3 wd = vec3(wind_dir.x, 0.0, wind_dir.y);
	mat3 basis = mat3(MODEL_MATRIX);
	float sc = length(basis[0]);
	vec3 local_wd = (transpose(basis) * wd) / (sc * sc);

	float w = wind_strength;
	// Main sway: steady lean + slow oscillation + faster secondary.
	float sway = w * 0.35 + sin(t * 0.9 + phase) * (0.25 + 0.5 * w) * w + sin(t * 2.3 + phase * 1.7) * 0.08 * w;
	VERTEX += local_wd * sway * bend * 0.9;
	// Cross-wind wobble.
	vec3 side = vec3(-local_wd.z, 0.0, local_wd.x);
	VERTEX += side * sin(t * 1.3 + phase * 2.1) * 0.12 * w * bend;
	// Bob: a branch moving sideways dips slightly.
	VERTEX.y -= abs(sway) * bend * 0.08;

	// Leaf flutter: high frequency, per-vertex phase.
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = sin(t * 7.0 + wp.x * 3.1 + wp.y * 4.7 + wp.z * 2.3) * sin(t * 4.3 + wp.y * 2.0);
	VERTEX += NORMAL * f * 0.04 * flutter * (0.2 + w) * h;

	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// world triplanar
	vec3 bl = pow(abs(wnorm), vec3(4.0));
	bl /= (bl.x + bl.y + bl.z);
	vec3 p = wpos * tex_scale;
	vec3 c = texture(albedo_tex, p.zy).rgb * bl.x + texture(albedo_tex, p.xz).rgb * bl.y + texture(albedo_tex, p.xy).rgb * bl.z;
	ALBEDO = c * tint * COLOR.rgb * mix(1.0, 0.7, wetness * 0.6);
	ROUGHNESS = mix(roughness_v, 0.45, wetness * 0.6);
	SPECULAR = 0.3;
}
