extends Node
## Global weather state. Visuals (rain, fog, trees, puddles, sky) and audio read
## from here, so the story can change the weather with one call, e.g.
##     Weather.set_profile("storm")
##     Weather.force(0.0, 0.1, 1.0, 30.0)   # rain, wind, fog, over 30 seconds
##
## Values are all 0..1. They are also pushed to global shader uniforms
## (rain_amount, wind_strength, wind_dir, wetness, lightning).

signal lightning_struck(strength: float, distance: float)  ## distance 0 = overhead, 1 = far away
signal profile_changed(profile: String)

## Profile definitions.
##   rain/wind/fog: [light value, heavy value]; heavy spells only if heavy_chance > 0.
const PROFILES := {
	"clear":     {"rain": [0.0, 0.0],   "wind": [0.12, 0.2],  "fog": [0.15, 0.15], "heavy_chance": 0.0,  "lightning": false},
	"rain_mist": {"rain": [0.3, 0.95],  "wind": [0.25, 0.7],  "fog": [0.55, 0.7],  "heavy_chance": 0.4,  "lightning": true},
	"storm":     {"rain": [0.85, 1.0],  "wind": [0.7, 1.0],   "fog": [0.45, 0.6],  "heavy_chance": 0.8,  "lightning": true},
	"fog":       {"rain": [0.0, 0.0],   "wind": [0.04, 0.08], "fog": [1.0, 1.0],   "heavy_chance": 0.0,  "lightning": false},
	"drizzle":   {"rain": [0.15, 0.3],  "wind": [0.15, 0.3],  "fog": [0.7, 0.8],   "heavy_chance": 0.2,  "lightning": false},
}

var profile := "rain_mist"

# Current (smoothed) values.
var rain := 0.3
var wind := 0.25
var fog := 0.55
var wetness := 1.0
var wind_angle := 0.25  ## radians, direction the wind blows towards (on the XZ plane)
var heavy := false      ## currently in a heavy spell

# Targets and transition speed.
var _rain_target := 0.3
var _wind_target := 0.25
var _fog_target := 0.55
var _transition := 15.0
var _spell_timer := 0.0
var _lightning_timer := 30.0
var _forced := false
var _gust := 0.0
var _t := 0.0


func _ready() -> void:
	set_profile(profile, 0.0)


## Switch to one of PROFILES. transition = seconds to blend there.
func set_profile(p: String, transition := 20.0) -> void:
	if not PROFILES.has(p):
		push_warning("Unknown weather profile: %s" % p)
		return
	profile = p
	_forced = false
	heavy = false
	_transition = transition
	_apply_spell()
	_spell_timer = randf_range(40.0, 90.0)
	if transition <= 0.0:
		rain = _rain_target
		wind = _wind_target
		fog = _fog_target
	profile_changed.emit(p)


## Story override: hold exact values until set_profile() is called again.
func force(rain_v: float, wind_v: float, fog_v: float, transition := 10.0) -> void:
	_forced = true
	_rain_target = rain_v
	_wind_target = wind_v
	_fog_target = fog_v
	_transition = transition
	if transition <= 0.0:
		rain = rain_v
		wind = wind_v
		fog = fog_v


## Start or stop a heavy spell right now (only meaningful for rainy profiles).
func set_heavy(on: bool, transition := 12.0) -> void:
	heavy = on
	print("EVENT weather heavy=%s profile=%s" % [on, profile])
	_transition = transition
	_apply_spell()
	_spell_timer = randf_range(30.0, 80.0) if on else randf_range(60.0, 150.0)


## Trigger lightning now (for scripted scares). distance 0..1.
func strike_lightning(strength := 1.0, distance := -1.0) -> void:
	if distance < 0.0:
		distance = randf_range(0.15, 1.0)
	lightning_struck.emit(strength, distance)


func _apply_spell() -> void:
	var d: Dictionary = PROFILES[profile]
	var i := 1 if heavy else 0
	_rain_target = d.rain[i] * randf_range(0.9, 1.05)
	_wind_target = d.wind[i] * randf_range(0.85, 1.1)
	_fog_target = d.fog[i]


func _process(delta: float) -> void:
	_t += delta
	var d: Dictionary = PROFILES[profile]

	if not _forced:
		# Alternate between light and heavy spells.
		_spell_timer -= delta
		if _spell_timer <= 0.0:
			if heavy:
				set_heavy(false, randf_range(15.0, 30.0))
			elif randf() < d.heavy_chance:
				set_heavy(true, randf_range(8.0, 18.0))
			else:
				_transition = 20.0
				_apply_spell()  # small drift within the light range
				_spell_timer = randf_range(45.0, 120.0)

		# Lightning during heavy rain.
		if d.lightning and rain > 0.7:
			_lightning_timer -= delta
			if _lightning_timer <= 0.0:
				strike_lightning(randf_range(0.5, 1.0))
				_lightning_timer = randf_range(18.0, 55.0) / (0.5 + rain)

	# Exponential ease toward the targets, reaching ~95% in one transition time.
	# (The weight is always between 0 and 1: a weight above 1 overshoots and
	# grows every frame, which once sent rain/fog/wind to infinity a minute in.)
	var k := 1.0 if _transition <= 0.0 else 1.0 - exp(-3.0 * delta / _transition)
	rain = clampf(lerpf(rain, _rain_target, k), 0.0, 1.0)
	fog = clampf(lerpf(fog, _fog_target, k), 0.0, 1.0)
	wind = clampf(lerpf(wind, _wind_target, k), 0.0, 1.5)
	wetness = clampf(maxf(wetness - delta * 0.002, rain * 2.0), 0.0, 1.0)

	# Gusts: slow noise on top of the base wind.
	_gust = 0.5 + 0.5 * sin(_t * 0.31) * sin(_t * 0.173 + 1.3)
	wind_angle = 0.25 + 0.3 * sin(_t * 0.021)

	RenderingServer.global_shader_parameter_set("rain_amount", rain)
	RenderingServer.global_shader_parameter_set("wind_strength", gusty_wind())
	RenderingServer.global_shader_parameter_set("wind_dir", wind_vector())
	RenderingServer.global_shader_parameter_set("wetness", wetness)


## Wind including gusts, 0..~1.3
func gusty_wind() -> float:
	return wind * (0.65 + 0.6 * _gust)


func wind_vector() -> Vector2:
	return Vector2(cos(wind_angle), sin(wind_angle))


func describe() -> String:
	if rain > 0.75:
		return "HEAVY RAIN"
	if rain > 0.4:
		return "RAIN"
	if rain > 0.08:
		return "LIGHT RAIN"
	if fog > 0.8:
		return "FOG"
	return "CLEAR"
