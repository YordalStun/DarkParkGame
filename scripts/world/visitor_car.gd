extends Node3D
## A staff member arriving for the night shift. Drives up the entrance lane, stops with
## the driver's window beside the booth's side window, holds out a work ID, then either
## drives in and parks (barrier raised) or reverses back out (refused).
##
## Car nose = local +Z. Right-hand drive (UK), so the driver sits on local -X, which faces
## the booth when the car heads up the lane (-Z).

signal arrived          ## stopped at the window
signal parked           ## engine off in its bay
signal gone             ## reversed away and removed
signal card_taken
signal card_returned

const G := -0.15
const LANE_X := -3.4
const STOP_Z := 0.33
const SPAWN_Z := 42.0
const MAX_SPEED := 6.0
const ACCEL := 2.5
const DECEL := 2.8

var person: Dictionary     ## see shift.gd STAFF entries
var world                  ## the World node
var state := "approach"    ## approach | waiting | entering | parked | leaving | gone
var card_interact: Interactable
var plate_interact: Interactable
var card_out := false      ## the driver is holding the ID out of the window
var card_with_guard := false

var _curve: Curve3D
var _dist := 0.0
var _target := 0.0
var _speed := 0.0
var _dir := 1.0
var _stop_dist := 0.0
var _model: CarModel
var _thighs: MeshInstance3D
var _driver: Node3D
var _arm: MeshInstance3D
var _hand: Node3D
var _card: Node3D
var _hand_t := 0.0
var _heads: Array[SpotLight3D] = []
var _head_mat: StandardMaterial3D
var _tail_mat: StandardMaterial3D
var _dome: OmniLight3D
var _engine: AudioStreamPlayer3D
var _engine_on := true
var _walker: Node3D

const SHOULDER := Vector3(-0.55, 1.02, -0.27)
const HAND_REST := Vector3(-0.42, 0.98, 0.2)
const HAND_OUT := Vector3(-1.4, 1.22, -0.12)


func setup(p_world, p_person: Dictionary, bay: Vector3) -> void:
	world = p_world
	person = p_person
	_build_path(bay)


func _ready() -> void:
	_model = CarModel.new()
	_model.paint = person.get("paint", Color(0.4, 0.4, 0.42))
	_model.style = person.get("style", "saloon")
	_model.driver_window_open = true
	_model.build()
	add_child(_model)
	_build_lights()
	_build_plates()
	_build_driver()
	_build_interacts()
	_engine = AudioStreamPlayer3D.new()
	var s := load("res://assets/audio/engine_idle.ogg") as AudioStreamOggVorbis
	s.loop = true
	_engine.stream = s
	_engine.bus = "Outside"
	_engine.unit_size = 4.0
	_engine.max_db = 0.0
	_engine.volume_db = -4.0
	_engine.position = Vector3(0, 0.6, 1.6)
	add_child(_engine)
	_engine.play(randf() * s.get_length())
	_place()
	state = "approach"
	_target = _stop_dist


# ------------------------------------------------------------------ path
func _build_path(bay: Vector3) -> void:
	var pts := [
		Vector3(LANE_X, G, SPAWN_Z),
		Vector3(LANE_X, G, 12.0),
		Vector3(LANE_X, G, STOP_Z),
		Vector3(LANE_X, G, -4.0),
		Vector3(lerpf(LANE_X, bay.x, 0.5), G, -6.4),
		Vector3(bay.x, G, -8.6),
		Vector3(bay.x, G, bay.z),
	]
	_curve = Curve3D.new()
	_curve.bake_interval = 0.1
	for i in pts.size():
		var p: Vector3 = pts[i]
		var tan := Vector3.ZERO
		if i > 0 and i < pts.size() - 1:
			tan = (pts[i + 1] - pts[i - 1]) * 0.18
		# The straight run past the window and barrier stays straight.
		if i <= 3:
			tan = Vector3(0, 0, -1) * (2.0 if i > 0 else 0.0)
		_curve.add_point(p, -tan, tan)
	_stop_dist = _curve.get_closest_offset(Vector3(LANE_X, G, STOP_Z))


func _place() -> void:
	var len := _curve.get_baked_length()
	var p := _curve.sample_baked(clampf(_dist, 0.0, len))
	var a := _curve.sample_baked(clampf(_dist - 0.6, 0.0, len))
	var b := _curve.sample_baked(clampf(_dist + 0.6, 0.0, len))
	var fwd := (b - a)
	fwd.y = 0.0
	if fwd.length() > 0.001:
		global_transform = Transform3D(Basis.looking_at(-fwd.normalized(), Vector3.UP), p)
	else:
		global_position = p


func _process(delta: float) -> void:
	_drive(delta)
	_update_arm(delta)
	_update_lights()
	if _walker:
		_walk(delta)


func _drive(delta: float) -> void:
	if state in ["waiting", "parked", "gone"]:
		_speed = 0.0
		return
	var remaining := absf(_target - _dist)
	var vmax := MAX_SPEED if state != "leaving" else 3.0
	if state == "entering" and _dist > _curve.get_closest_offset(Vector3(LANE_X, G, -4.0)):
		vmax = 2.6   # creeping into the bay
	var want := minf(vmax, sqrt(2.0 * DECEL * remaining))
	if _speed < want:
		_speed = minf(want, _speed + ACCEL * delta)
	else:
		_speed = want
	_dist = move_toward(_dist, _target, _speed * delta)
	_place()
	_engine.pitch_scale = 0.9 + _speed * 0.11
	if absf(_target - _dist) < 0.01:
		_reached()


func _reached() -> void:
	match state:
		"approach":
			state = "waiting"
			arrived.emit()
		"entering":
			state = "parked"
			_park()
		"leaving":
			state = "gone"
			gone.emit()
			queue_free()


## Barrier is up: drive in to the bay.
func drive_in() -> void:
	if state != "waiting":
		return
	retract_card()
	state = "entering"
	_target = _curve.get_baked_length()


## Turned away: reverse back down the lane.
func reverse_out() -> void:
	if state != "waiting":
		return
	retract_card()
	state = "leaving"
	_target = 0.0


func is_past_barrier() -> bool:
	return global_position.z < -5.5 and state in ["entering", "parked"]


func _park() -> void:
	await get_tree().create_timer(0.8).timeout
	var tw := create_tween()
	tw.tween_property(_engine, "volume_db", -60.0, 0.6)
	tw.tween_callback(_engine.stop)
	_engine_on = false
	await get_tree().create_timer(1.6).timeout
	if world:
		world.ambience.play_at("car_door", global_position + global_basis * Vector3(-0.9, 1.0, 0), -2.0, "Outside", 6.0)
	_start_walk()
	parked.emit()


# ------------------------------------------------------------------ the ID card
## Hold the ID card out of the window toward the booth.
func offer_card() -> void:
	card_out = true
	card_with_guard = false
	_card.visible = true
	card_interact.enabled = true


func retract_card() -> void:
	card_out = false
	card_interact.enabled = false


## The guard took the card (it disappears from the driver's hand).
func take_card() -> void:
	card_with_guard = true
	_card.visible = false
	card_interact.enabled = false
	card_taken.emit()


func return_card() -> void:
	card_with_guard = false
	_card.visible = true
	card_out = false
	card_returned.emit()


func _update_arm(delta: float) -> void:
	if not is_instance_valid(_driver) or _walker != null or state == "parked":
		return
	var want := 1.0 if card_out or card_with_guard else 0.0
	_hand_t = move_toward(_hand_t, want, delta * 1.4)
	var k := _hand_t * _hand_t * (3.0 - 2.0 * _hand_t)
	_hand.position = HAND_REST.lerp(HAND_OUT, k) + Vector3(0, sin(Time.get_ticks_msec() * 0.003) * 0.004 * k, 0)
	if _driver.visible:
		var from := SHOULDER
		var to := _hand.position
		var mid := (from + to) * 0.5
		var d := to - from
		_arm.position = mid
		_arm.scale = Vector3(1, 1, d.length())
		if d.length() > 0.01:
			_arm.basis = Basis.looking_at(d.normalized(), Vector3.UP).scaled(Vector3(1, 1, d.length()))
	if not card_out and not card_with_guard and _hand_t < 0.05 and state != "waiting":
		_card.visible = false


# ------------------------------------------------------------------ building
func _build_lights() -> void:
	_head_mat = _model.head_mat
	_tail_mat = _model.tail_mat
	for hp in _model.head_points:
		var sp := SpotLight3D.new()
		sp.position = hp
		sp.rotation_degrees = Vector3(-7, 180, 0)   # spot shines along -Z; turn it to face the nose (+Z)
		sp.light_color = Color(1.0, 0.92, 0.75)
		sp.light_energy = 3.0
		sp.spot_range = 22.0
		sp.spot_angle = 26.0
		sp.spot_attenuation = 0.8
		sp.light_volumetric_fog_energy = 0.6
		sp.shadow_enabled = false
		add_child(sp)
		_heads.append(sp)
	_dome = OmniLight3D.new()
	_dome.position = Vector3(-0.1, 1.3, -0.1)
	_dome.light_color = Color(1.0, 0.8, 0.55)
	_dome.light_energy = 0.0
	_dome.light_cull_mask = 1 << (CarModel.CABIN_LAYER - 1)
	_dome.omni_range = 1.4
	_dome.light_specular = 0.0
	_dome.light_volumetric_fog_energy = 0.0
	add_child(_dome)


func _update_lights() -> void:
	var on := _engine_on
	for h in _heads:
		h.visible = on
	_head_mat.emission_energy_multiplier = 3.0 if on else 0.0
	var braking := on and (state == "waiting" or (_speed < 1.5 and state in ["approach", "entering"]))
	_tail_mat.emission_energy_multiplier = (3.5 if braking else 1.2) if on else 0.0
	var dome_want := 0.12 if state == "waiting" else 0.0   # just enough for a faint outline
	_dome.light_energy = move_toward(_dome.light_energy, dome_want, get_process_delta_time() * 0.8)


func _build_plates() -> void:
	var reg: String = person.get("reg", "")
	for p in [[_model.front_plate_z + 0.002, 0.0], [_model.rear_plate_z - 0.002, 180.0]]:
		var l := Label3D.new()
		l.text = reg
		l.font = load("res://assets/fonts/LiberationSans-Bold.ttf")
		l.font_size = 56
		l.pixel_size = 0.0014
		l.modulate = Color(0.02, 0.02, 0.02)
		l.outline_size = 0
		l.shaded = true
		l.double_sided = false
		l.position = Vector3(0, _model.plate_y, p[0])
		l.rotation_degrees.y = p[1]
		add_child(l)


func _build_driver() -> void:
	_driver = Node3D.new()
	_driver.name = "Driver"
	add_child(_driver)
	# Muted, dark tones: inside the car they should read as a faint shape, not a lit doll.
	var skin := MK.mat(person.get("skin", Color(0.85, 0.66, 0.52)).darkened(0.35), "", 0.8)
	var hair := MK.mat(person.get("hair", Color(0.2, 0.14, 0.08)).darkened(0.2), "", 0.95)
	var coat := MK.mat(person.get("shirt", Color(0.25, 0.3, 0.45)).darkened(0.7), "", 0.95)
	var c: Vector3 = _model.seat
	# Seated torso: tapered from shoulders to waist, leaning back a touch.
	var torso := MK.taper(_driver, Vector3(0.36, 0.5, 0.22), 0.44, 0.0, c + Vector3(0, 0.82, -0.05), coat)
	torso.rotation_degrees.x = -8.0
	_thighs = MK.box(_driver, Vector3(0.36, 0.14, 0.42), c + Vector3(0, 0.6, 0.15), coat)
	MK.cyl(_driver, 0.045, 0.05, 0.09, c + Vector3(0, 1.1, -0.06), skin, 8)                         # neck
	var head := MK.sphere(_driver, 0.1, c + Vector3(0, 1.22, -0.05), skin, 10, 8)
	head.scale = Vector3(0.88, 1.12, 0.98)
	MK.box(_driver, Vector3(0.03, 0.04, 0.03), c + Vector3(0, 1.21, 0.05), skin)                   # nose
	var style: String = person.get("hair_style", "short")
	if style == "long":
		var back := MK.sphere(_driver, 0.112, c + Vector3(0, 1.24, -0.08), hair, 10, 8)
		back.scale = Vector3(0.95, 1.15, 0.95)
		MK.box(_driver, Vector3(0.2, 0.22, 0.1), c + Vector3(0, 1.11, -0.11), hair)
	else:
		var cap := MK.sphere(_driver, 0.104, c + Vector3(0, 1.26, -0.06), hair, 10, 8)
		cap.scale = Vector3(0.92, 0.8, 1.0)
	if person.get("glasses", false):
		MK.box(_driver, Vector3(0.17, 0.035, 0.012), c + Vector3(0, 1.235, 0.045), MK.mat(Color(0.06, 0.06, 0.06), "", 0.2, 1.0, 0.5))
	if person.get("moustache", false):
		MK.box(_driver, Vector3(0.07, 0.015, 0.02), c + Vector3(0, 1.18, 0.055), hair)
	# Far arm on the wheel.
	MK.box(_driver, Vector3(0.07, 0.07, 0.36), c + Vector3(0.16, 0.93, 0.2), coat, Vector3(-30, 0, 0))
	_arm = MK.box(_driver, Vector3(0.075, 0.075, 1.0), SHOULDER, coat)
	_hand = Node3D.new()
	_hand.position = HAND_REST
	_driver.add_child(_hand)
	MK.box(_hand, Vector3(0.03, 0.07, 0.06), Vector3.ZERO, skin)
	MK.box(_hand, Vector3(0.03, 0.035, 0.04), Vector3(0, 0.05, 0.03), skin)   # thumb
	_card = Node3D.new()
	_card.position = Vector3(-0.04, 0.035, 0.03)
	_card.rotation_degrees = Vector3(0, 0, 0)
	_hand.add_child(_card)
	MK.box(_card, Vector3(0.003, 0.054, 0.086), Vector3.ZERO, MK.mat(Color(0.92, 0.92, 0.9), "", 0.4))
	MK.box(_card, Vector3(0.004, 0.012, 0.086), Vector3(0, 0.02, 0), MK.mat(person.get("card_color", Color(0.1, 0.25, 0.6)), "", 0.4))
	MK.box(_card, Vector3(0.004, 0.022, 0.018), Vector3(0, -0.006, -0.028), MK.mat(Color(0.5, 0.55, 0.6), "", 0.6))  # photo
	_card.visible = false
	# Everything but the hand (and the card in it) stays in the dark cabin.
	for part in _driver.get_children():
		if part != _hand and part != _arm:
			CarModel.to_cabin_layer(part)


func _build_interacts() -> void:
	var side: Interactable = world.booth.side_view if world else null
	card_interact = Interactable.new()
	card_interact.prompt = "Take ID card"
	card_interact.requires_focus = side
	card_interact.add_box(Vector3(0.22, 0.2, 0.26))
	card_interact.enabled = false
	_hand.add_child(card_interact)
	plate_interact = Interactable.new()
	plate_interact.prompt = "Check number plate"
	plate_interact.requires_focus = side
	plate_interact.add_box(Vector3(1.8, 0.7, 4.4), Vector3(0, 0.5, 0))
	add_child(plate_interact)


# ------------------------------------------------------------------ getting out
func _start_walk() -> void:
	plate_interact.enabled = false
	# The driver gets out on the right side and walks off west along the aisle, toward the hospital.
	_walker = Node3D.new()
	get_parent().add_child(_walker)
	var out := global_transform * Vector3(-1.3, 0.0, _model.seat.z)
	_walker.global_position = Vector3(out.x, G, out.z)
	_driver.get_parent().remove_child(_driver)
	_walker.add_child(_driver)
	_driver.transform = Transform3D(Basis(), Vector3(-_model.seat.x, 0.3, -_model.seat.z))   # seat -> standing
	_arm.visible = false
	_hand.visible = false
	_thighs.visible = false
	for c in _driver.get_children():
		if c is VisualInstance3D:
			c.layers = 1
	var legs := MK.mat(Color(0.12, 0.12, 0.14), "", 0.8)
	for sx in [-0.09, 0.09]:
		MK.box(_driver, Vector3(0.12, 0.62, 0.13), _model.seat + Vector3(sx, 0.0, 0.0), legs)
	_walk_path = [Vector3(out.x, G, -7.4), Vector3(-24.0, G, -7.4)]


var _walk_path: Array = []


func _walk(delta: float) -> void:
	if _walk_path.is_empty():
		_walker.queue_free()
		_walker = null
		return
	var p := _walker.global_position
	var to: Vector3 = _walk_path[0] - p
	to.y = 0.0
	if to.length() < 0.2:
		_walk_path.pop_front()
		return
	var dir := to.normalized()
	_walker.global_position += dir * 1.3 * delta
	_walker.basis = Basis.looking_at(-dir, Vector3.UP)
	_driver.position.y = 0.3 + absf(sin(Time.get_ticks_msec() * 0.009)) * 0.03
