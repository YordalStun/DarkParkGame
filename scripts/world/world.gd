extends Node3D
## The whole location: booth interior, parking lot, lights, weather and sound.
## Everything is built in code from the scripts in this folder, so it is easy to
## tweak numbers; parts can be moved into hand-made .tscn scenes later.

const Booth := preload("res://scripts/world/booth.gd")
const DeskProps := preload("res://scripts/world/desk_props.gd")
const ParkingLot := preload("res://scripts/world/parking_lot.gd")
const WeatherFX := preload("res://scripts/world/weather_fx.gd")
const Ambience := preload("res://scripts/world/ambience.gd")
const DeskCamera := preload("res://scripts/player/desk_camera.gd")

var environment: Environment
var camera: Camera3D
var booth: Node3D
var props: Node3D
var lot: Node3D
var weather_fx: Node3D
var ambience: Node


func _ready() -> void:
	_build_environment()

	booth = Booth.new()
	booth.name = "Booth"
	add_child(booth)

	props = DeskProps.new()
	props.name = "DeskProps"
	add_child(props)

	lot = ParkingLot.new()
	lot.name = "ParkingLot"
	add_child(lot)

	weather_fx = WeatherFX.new()
	weather_fx.name = "WeatherFX"
	weather_fx.environment = environment
	add_child(weather_fx)

	camera = DeskCamera.new()
	camera.name = "DeskCamera"
	add_child(camera)

	ambience = Ambience.new()
	ambience.name = "Ambience"
	ambience.world = self
	add_child(ambience)


func _build_environment() -> void:
	var env := Environment.new()

	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/night_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.background_mode = Environment.BG_SKY
	env.sky = sky

	# Almost no ambient light: the lot must be dark except where lamps reach.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.03, 0.034, 0.045)
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0

	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.015
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.6)

	# Distance haze so the far lot fades into black-blue.
	env.fog_enabled = true
	env.fog_light_color = Color(0.016, 0.017, 0.022)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.15

	# Mist that lights glow through (the lamp's cone of light in the rain).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_albedo = Color(0.55, 0.56, 0.6)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.volumetric_fog_temporal_reprojection_amount = 0.85

	# Wet asphalt reflections.
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.5

	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6

	environment = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Very faint cold sky light so silhouettes read against the dark.
	var moon := DirectionalLight3D.new()
	moon.name = "SkyFill"
	moon.light_color = Color(0.45, 0.55, 0.8)
	moon.light_energy = 0.025
	moon.light_volumetric_fog_energy = 0.0
	moon.rotation_degrees = Vector3(-50, 30, 0)
	moon.shadow_enabled = false
	add_child(moon)
