extends Node
## All ambient sound. Layers follow the Weather state. Outdoor sounds go through
## an "Outside" bus with a low-pass filter (heard through the booth's glass);
## indoor sounds are positional so they pan as the player looks around.

var world  ## the World node (untyped: we read its builder fields)

var _loops := {}            # name -> player
var _tick_timer := 0.0
var _tick_alt := false
var _creak_timer := 20.0
var _thunders: Array[AudioStream] = []
var _outside_lp: AudioEffectLowPassFilter



func _ready() -> void:
	setup_buses()
	_outside_lp = AudioServer.get_bus_effect(AudioServer.get_bus_index("Outside"), 0)
	_thunders = [_stream("thunder_1"), _stream("thunder_2"), _stream("thunder_3")]

	# Outdoor beds (non-positional, through the glass).
	_loop2d("rain_light", "Outside")
	_loop2d("rain_heavy", "Outside")
	_loop2d("wind", "Outside")
	_loop2d("traffic_distant", "Outside", -16.0)
	# Rain drumming on the booth roof.
	_loop2d("rain_roof", "Interior")

	# Positional loops.
	_loop3d("rain_window", Vector3(0.3, 1.6, -1.15), "Interior", 2.0)
	_loop3d("rain_gutter", Vector3(2.0, 1.2, -1.6), "Outside", 2.0)
	_loop3d("fluorescent_hum", Vector3(0, 2.4, 0.15), "Interior", 1.5)
	_loop3d("crt_hum", Vector3(0.72, 1.0, -0.62), "Interior", 0.8)
	var lamp = world.lot.lamp
	_loop3d("lamp_buzz", lamp.global_position + lamp.head_position, "Outside", 6.0)

	Weather.lightning_struck.connect(_on_lightning)
	world.booth.light_flickered.connect(_on_light_flicker)
	world.lot.lamp.sputtered.connect(func(): _one_shot_3d("light_flicker", lamp.global_position + lamp.head_position, -14.0, 0.6, "Outside", 8.0))


## Creates the mixer buses. Static so the world can call it before anything
## that plays sound (e.g. the radio) is built.
static func setup_buses() -> void:
	if AudioServer.get_bus_index("Outside") != -1:
		return
	for bus_name in ["Outside", "Interior", "UI"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	var out := AudioServer.get_bus_index("Outside")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 2600.0
	lp.resonance = 0.6
	AudioServer.add_bus_effect(out, lp)
	# Ear safety: the whole game sits a little lower, and a limiter on the master
	# output means no combination of sounds can ever clip or spike past -1.5 dBFS.
	Settings.set_fade(0.0)  # silent until fade_in() after loading (Settings owns the Master volume)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -1.5
	limiter.release = 0.15
	AudioServer.add_bus_effect(0, limiter)
	var inside := AudioServer.get_bus_index("Interior")
	var verb := AudioEffectReverb.new()
	verb.room_size = 0.12
	verb.damping = 0.7
	verb.wet = 0.06
	verb.dry = 1.0
	AudioServer.add_bus_effect(inside, verb)


## Bring the sound up from silence (called when the loading screen goes away).
func fade_in(seconds: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): Settings.set_fade(v), 0.0, 1.0, seconds)


func _stream(n: String) -> AudioStream:
	return load("res://assets/audio/%s.ogg" % n)


func _loop2d(n: String, bus: String, db := -80.0) -> AudioStreamPlayer:
	var s := _stream(n) as AudioStreamOggVorbis
	s.loop = true
	var p := AudioStreamPlayer.new()
	p.name = n
	p.stream = s
	p.bus = bus
	p.volume_db = db
	add_child(p)
	p.play(randf() * s.get_length())
	_loops[n] = p
	return p


func _loop3d(n: String, pos: Vector3, bus: String, unit := 1.0) -> AudioStreamPlayer3D:
	var s := _stream(n) as AudioStreamOggVorbis
	s.loop = true
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.stream = s
	p.bus = bus
	p.unit_size = unit
	p.max_db = 0.0  # never louder than its set volume, however close the camera is
	p.max_distance = 60.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.position = pos
	world.add_child(p)
	p.play(randf() * s.get_length())
	_loops[n] = p
	return p


func _one_shot_3d(n: String, pos: Vector3, db := 0.0, pitch := 1.0, bus := "Interior", unit := 1.5) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(n)
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = unit
	p.max_db = 0.0
	p.position = pos
	world.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func play_ui(n: String, db := -6.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _stream(n)
	p.bus = "UI"
	p.volume_db = db
	p.pitch_scale = randf_range(0.95, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _vol(n: String, linear: float, base_db: float) -> void:
	var p = _loops[n]
	p.volume_db = base_db + linear_to_db(maxf(linear, 0.0001))


func _process(delta: float) -> void:
	var r := Weather.rain
	var ws := Weather.gusty_wind()
	var heavy := smoothstep(0.45, 0.95, r)
	_vol("rain_light", smoothstep(0.02, 0.25, r) * (1.0 - heavy * 0.5), -4.0)
	_vol("rain_heavy", heavy, -3.0)
	_vol("rain_roof", clampf(r * 1.3, 0.0, 1.0), -7.0)
	_vol("rain_window", clampf(r * 1.2, 0.0, 1.0), -6.0)
	_vol("rain_gutter", Weather.wetness * clampf(0.25 + r, 0.0, 1.0), -8.0)
	_vol("wind", clampf(0.2 + ws * 0.9, 0.0, 1.3), -8.0)
	(_loops["wind"] as AudioStreamPlayer).pitch_scale = clampf(0.92 + ws * 0.15, 0.5, 1.5)

	var booth_k: float = world.booth.light.light_energy / world.booth.light_base_energy
	_vol("fluorescent_hum", booth_k, -10.0)
	_vol("crt_hum", 1.0, -14.0)
	var lamp_k: float = world.lot.lamp.spot.light_energy / world.lot.lamp.energy
	_vol("lamp_buzz", lamp_k, 2.0)

	# Heavier rain also muffles the outside a bit less (it is louder against the glass).
	_outside_lp.cutoff_hz = lerpf(2200.0, 3400.0, heavy)

	# Wall clock.
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += 1.0
		_tick_alt = not _tick_alt
		_one_shot_3d("clock_tick", Vector3(0.55, 2.35, -1.03), -10.0, 1.0 if _tick_alt else 0.9, "Interior", 1.0)

	# Trees creaking in strong wind.
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(25.0, 70.0)
		if ws > 0.3 and not world.lot.trees.is_empty():
			var t: Node3D = world.lot.trees[randi() % mini(9, world.lot.trees.size())]
			_one_shot_3d("tree_creak", t.global_position + Vector3(0, 4, 0), -2.0, randf_range(0.8, 1.1), "Outside", 10.0)


func _on_lightning(strength: float, distance: float) -> void:
	var delay := 0.25 + distance * 5.0
	var stream: AudioStream
	if distance < 0.35:
		stream = _thunders[1]
	else:
		stream = _thunders[0] if randf() < 0.6 else _thunders[2]
	await get_tree().create_timer(delay).timeout
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "Outside"
	p.volume_db = lerpf(-7.0, -15.0, distance) + linear_to_db(clampf(strength, 0.2, 1.0))
	p.pitch_scale = randf_range(0.85, 1.05)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _on_light_flicker() -> void:
	_one_shot_3d("light_flicker", Vector3(0, 2.4, 0.15), -11.0, randf_range(0.9, 1.1))
