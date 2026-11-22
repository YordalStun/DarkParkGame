extends Node3D
## A car leaving the lot at the end of someone's shift: it sits parked nose-out in its bay,
## then (go()) lights up, pulls out, turns into the exit lane, the exit barrier lifts by
## itself, and it drives off up the access road. Nobody needs checking on the way out.

signal left

const G := -0.15
const EXIT_X := -5.9
const MAX_SPEED := 6.5

var world
var style := "saloon"
var paint := Color(0.4, 0.4, 0.42)
var reg := ""
var state := "parked"    ## parked | leaving | gone

var _model: CarModel
var _curve: Curve3D
var _dist := 0.0
var _speed := 0.0
var _engine: AudioStreamPlayer3D
var _heads: Array[SpotLight3D] = []
var _gate_open := false


## Park it nose-out (facing the booth) in a bay.
func park_at(bay: Vector3) -> void:
	position = bay
	rotation.y = 0.0


func _ready() -> void:
	_model = CarModel.new()
	_model.paint = paint
	_model.style = style
	_model.build()
	add_child(_model)
	for p in [[_model.front_plate_z + 0.002, 0.0], [_model.rear_plate_z - 0.002, 180.0]]:
		var l := Label3D.new()
		l.text = reg
		l.font = load("res://assets/fonts/LiberationSans-Bold.ttf")
		l.font_size = 56
		l.pixel_size = 0.0014
		l.modulate = Color(0.02, 0.02, 0.02)
		l.shaded = true
		l.double_sided = false
		l.position = Vector3(0, _model.plate_y, p[0])
		l.rotation_degrees.y = p[1]
		add_child(l)
	for hp in _model.head_points:
		var sp := SpotLight3D.new()
		sp.position = hp
		sp.rotation_degrees = Vector3(-7, 180, 0)
		sp.light_color = Color(1.0, 0.92, 0.75)
		sp.light_energy = 3.0
		sp.spot_range = 22.0
		sp.spot_angle = 26.0
		sp.light_volumetric_fog_energy = 0.6
		sp.visible = false
		add_child(sp)
		_heads.append(sp)
	set_process(false)


## Off home.
func go() -> void:
	if state != "parked":
		return
	state = "leaving"
	var p := global_position
	var side := signf(p.x - EXIT_X)
	var pts := [
		p,
		Vector3(p.x, G, -8.2),
		Vector3(p.x - side * 1.6, G, -6.6),
		Vector3(EXIT_X + side * 1.6, G, -6.3),
		Vector3(EXIT_X, G, -4.6),
		Vector3(EXIT_X, G, -2.8),
		Vector3(EXIT_X, G, 12.0),
		Vector3(EXIT_X, G, 44.0),
	]
	_curve = Curve3D.new()
	_curve.bake_interval = 0.1
	for i in pts.size():
		var tan := Vector3.ZERO
		if i > 0 and i < pts.size() - 1:
			tan = (pts[i + 1] - pts[i - 1]) * 0.2
		if i >= 4:
			tan = Vector3(0, 0, 1) * (1.6 if i < pts.size() - 1 else 0.0)
		_curve.add_point(pts[i], -tan, tan)
	_dist = 0.0
	# Engine starts, lights on, a moment before moving off.
	_engine = AudioStreamPlayer3D.new()
	var s := load("res://assets/audio/engine_idle.ogg") as AudioStreamOggVorbis
	s.loop = true
	_engine.stream = s
	_engine.bus = "Outside"
	_engine.unit_size = 2.0
	_engine.max_db = 0.0
	_engine.position = Vector3(0, 0.6, 1.4)
	add_child(_engine)
	_engine.volume_db = -60.0
	_engine.play()
	create_tween().tween_property(_engine, "volume_db", -15.0 + Settings.mix_db("cars"), 0.8)
	if world:
		world.ambience.play_at("car_door", global_position + global_basis * Vector3(-1.0, 1.0, 0), -10.0 + Settings.mix_db("cars"), "Outside", 6.0)
	await get_tree().create_timer(1.8).timeout
	for h in _heads:
		h.visible = true
	_model.head_mat.emission_energy_multiplier = 3.0
	_model.tail_mat.emission_energy_multiplier = 1.2
	set_process(true)


func _process(delta: float) -> void:
	var length := _curve.get_baked_length()
	var p := global_position
	# The exit barrier: wait at it until it is up, then it drops once we're through.
	var stop_at := length
	var gate_d := _curve.get_closest_offset(Vector3(EXIT_X, G, -4.0))
	var gate = world.lot.exit_gate if world else null
	if gate and not _gate_open and _dist > gate_d - 6.0:
		gate.open(1.6)
		_gate_open = true
		get_tree().create_timer(1.6).timeout.connect(func(): _gate_up = true)
	if gate and not _gate_up:
		stop_at = gate_d
	if gate and _gate_up and p.z > 3.0 and gate.is_open:
		gate.close(2.0)
	var remaining := maxf(stop_at - _dist, 0.0)
	var vmax := MAX_SPEED if _dist > gate_d else 2.8
	var want := minf(vmax, sqrt(2.0 * 2.8 * remaining))
	_speed = move_toward(_speed, want, (2.4 if _speed < want else 6.0) * delta)
	_dist = minf(_dist + _speed * delta, length)
	var a := _curve.sample_baked(clampf(_dist - 0.6, 0.0, length))
	var b := _curve.sample_baked(clampf(_dist + 0.6, 0.0, length))
	var fwd := b - a
	fwd.y = 0.0
	if fwd.length() > 0.001:
		global_transform = Transform3D(Basis.looking_at(-fwd.normalized(), Vector3.UP), _curve.sample_baked(_dist))
	_engine.pitch_scale = 0.9 + _speed * 0.11
	_engine.volume_db = -15.0 + _speed * 0.6 + Settings.mix_db("cars")
	var braking := _speed < 1.2
	_model.tail_mat.emission_energy_multiplier = 3.5 if braking else 1.2
	if _dist >= length - 0.05:
		state = "gone"
		left.emit()
		queue_free()


var _gate_up := false
