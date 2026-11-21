extends Node3D
## Visible weather: rain curtains (only seen where light catches them), ground
## splashes, drips off the booth roof, lightning flashes and mist density.

const G := -0.15

var environment: Environment
var lightning_light: DirectionalLight3D
var lightning_level := 0.0

var _rain_systems: Array[GPUParticles3D] = []
var _rain_mats: Array[ParticleProcessMaterial] = []
var _splash: GPUParticles3D
var _drips: GPUParticles3D
var _flash_queue: Array = []   # [delay, level] pulses still to play
var _rain_shader: Shader


func _ready() -> void:
	_rain_shader = load("res://shaders/rain_drop.gdshader")
	# Where the rain is: densest around the lamp and in front of the booth.
	_add_rain("RainLamp", Vector3(-9.0, G + 6.5, -14.0), Vector3(9.0, 3.5, 9.0), 3200)
	_add_rain("RainFront", Vector3(0.0, G + 5.0, -4.0), Vector3(6.0, 3.0, 2.7), 1400)
	_add_rain("RainLeft", Vector3(-5.0, G + 5.0, 1.0), Vector3(3.0, 3.0, 3.0), 700)
	_add_rain("RainWide", Vector3(0.0, G + 8.0, -22.0), Vector3(40.0, 4.0, 22.0), 4000, 0.3)
	_build_splashes()
	_build_drips()

	lightning_light = DirectionalLight3D.new()
	lightning_light.name = "LightningLight"
	lightning_light.light_color = Color(0.78, 0.84, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.shadow_enabled = true
	lightning_light.light_volumetric_fog_energy = 0.4
	lightning_light.directional_shadow_max_distance = 60.0
	lightning_light.visible = false
	add_child(lightning_light)

	Weather.lightning_struck.connect(_on_lightning)


func _rain_material(streak: float, brightness: float, splash := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _rain_shader
	m.set_shader_parameter("streak_length", streak)
	m.set_shader_parameter("brightness", brightness)
	m.set_shader_parameter("splash", splash)
	if splash:
		m.set_shader_parameter("streak_width", streak)
	return m


func _add_rain(n: String, center: Vector3, extents: Vector3, amount: int, brightness := 0.7) -> void:
	var p := GPUParticles3D.new()
	p.name = n
	p.position = center
	p.amount = amount
	p.lifetime = 1.4
	p.preprocess = 1.5
	p.fixed_fps = 0
	p.local_coords = false
	p.visibility_aabb = AABB(-extents - Vector3(4, 14, 4), extents * 2.0 + Vector3(8, 20, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 8.5
	pm.initial_velocity_max = 10.5
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _rain_material(0.42, brightness)
	p.draw_pass_1 = q
	add_child(p)
	_rain_systems.append(p)
	_rain_mats.append(pm)


func _build_splashes() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "Splashes"
	_splash.position = Vector3(-7.0, G + 0.02, -12.0)
	_splash.amount = 1600
	_splash.lifetime = 0.28
	_splash.local_coords = false
	_splash.visibility_aabb = AABB(Vector3(-14, -1, -10), Vector3(28, 3, 20))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12.0, 0.0, 8.0)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.3
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	_splash.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _rain_material(0.025, 0.9, true)
	_splash.draw_pass_1 = q
	add_child(_splash)


func _build_drips() -> void:
	# Water running off the front edge of the booth roof, right outside the glass.
	_drips = GPUParticles3D.new()
	_drips.name = "RoofDrips"
	_drips.position = Vector3(0, 2.66, -1.62)
	_drips.amount = 60
	_drips.lifetime = 1.0
	_drips.local_coords = false
	_drips.visibility_aabb = AABB(Vector3(-3, -4, -1), Vector3(6, 5, 2))
	_drips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.3, 0.0, 0.02)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 0.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, -9.8, 0)
	_drips.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _rain_material(0.16, 1.0)
	(q.material as ShaderMaterial).set_shader_parameter("fall_speed", 30.0)
	_drips.draw_pass_1 = q
	add_child(_drips)


func _process(delta: float) -> void:
	var r := Weather.rain
	var ws := Weather.gusty_wind()
	var wd := Weather.wind_vector()
	var vel := Vector3(wd.x * ws * 3.0, -9.5, wd.y * ws * 3.0)
	for i in _rain_systems.size():
		var p := _rain_systems[i]
		p.emitting = r > 0.02
		p.amount_ratio = clampf(r, 0.0, 1.0)
		_rain_mats[i].direction = vel.normalized()
	_splash.emitting = r > 0.05
	_splash.amount_ratio = clampf(r * 1.1, 0.0, 1.0)
	_drips.emitting = Weather.wetness > 0.2
	_drips.amount_ratio = clampf(0.25 + r, 0.0, 1.0)

	# Mist and haze.
	if environment:
		var f := Weather.fog
		environment.volumetric_fog_density = lerpf(0.002, 0.03, f * f) + r * 0.003
		environment.fog_density = lerpf(0.006, 0.04, f * f)

	_update_lightning(delta)


func _on_lightning(strength: float, distance: float) -> void:
	# A strike is several quick pulses.
	var s := strength * lerpf(1.0, 0.35, distance)
	# [delay since previous pulse, brightness]
	_flash_queue = [[0.0, 1.0 * s], [0.06, 0.15 * s], [0.05, 0.85 * s], [0.09, 0.05 * s], [0.12, 0.55 * s * randf()], [0.18, 0.0]]
	lightning_light.rotation_degrees = Vector3(randf_range(-60, -30), randf_range(140, 220), 0)
	lightning_light.visible = true


func _update_lightning(delta: float) -> void:
	if not _flash_queue.is_empty():
		_flash_queue[0][0] -= delta
		if _flash_queue[0][0] <= 0.0:
			lightning_level = _flash_queue[0][1]
			_flash_queue.pop_front()
	else:
		lightning_level = move_toward(lightning_level, 0.0, delta * 4.0)
	lightning_light.light_energy = lightning_level * 1.6
	if lightning_level <= 0.001 and _flash_queue.is_empty():
		lightning_light.visible = false
	RenderingServer.global_shader_parameter_set("lightning", lightning_level)
