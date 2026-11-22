extends Node
## A slow, overcast sunrise between 05:00 and 07:00 on the night clock: the sky lightens through
## an orange band at the horizon to flat grey morning, the ambient and fog light follow, a low
## sun comes up, and the street lamp fades out near the end.

var world
var sun: DirectionalLight3D
var _last := -1.0


func setup(p_world) -> void:
	world = p_world
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.62, 0.38)
	sun.light_energy = 0.0
	sun.shadow_enabled = false   # never toggled: a shadow map appearing mid-game risks a driver reset
	sun.light_volumetric_fog_energy = 0.12
	# Shines from the sky's sunrise point (ahead-left of the booth), low at first.
	sun.rotation_degrees = Vector3(-4.0, 143.0, 0.0)
	world.add_child(sun)


func progress() -> float:
	var h := NightClock.hours_f()
	return smoothstep(5.0, 7.0, h) if h < 12.0 else 0.0


func _process(_delta: float) -> void:
	var d := progress()
	if is_equal_approx(d, _last):
		return
	_last = d
	apply(d)


func apply(d: float) -> void:
	var env: Environment = world.environment
	world.sky_material.set_shader_parameter("dawn", d)
	env.ambient_light_color = Color(0.03, 0.034, 0.045).lerp(Color(0.34, 0.37, 0.42), d)
	env.ambient_light_energy = lerpf(0.35, 1.0, d)
	env.fog_light_color = Color(0.016, 0.017, 0.022).lerp(Color(0.26, 0.28, 0.32), d)
	env.tonemap_exposure = lerpf(1.1, 1.05, d)
	# The volumetric mist (GPU/Forward+ only) otherwise stays near-black and hides the whole
	# sunrise: let it pick up the morning light and glow a little itself, warm first, then grey.
	env.volumetric_fog_ambient_inject = lerpf(0.0, 1.6, d)
	var glow := Color(0.55, 0.32, 0.18).lerp(Color(0.3, 0.32, 0.36), smoothstep(0.35, 0.9, d))
	env.volumetric_fog_emission = glow
	env.volumetric_fog_emission_energy = smoothstep(0.0, 0.6, d) * 0.06
	env.volumetric_fog_albedo = Color(0.55, 0.56, 0.6).lerp(Color(0.8, 0.8, 0.82), d)
	var up := smoothstep(0.1, 1.0, d)
	sun.light_energy = up * 0.9
	sun.light_color = Color(1.0, 0.6, 0.34).lerp(Color(0.86, 0.9, 1.0), smoothstep(0.3, 0.9, d))
	sun.rotation_degrees.x = lerpf(-4.0, -30.0, d)
	if d > 0.55:
		world.lot.lamp.level = 1.0 - smoothstep(0.55, 0.9, d)
