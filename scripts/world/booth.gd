extends Node3D
## The security booth: walls, windows, desk, ceiling light, wall clock and decor.
##
## Layout (metres): interior X -1.8..1.8, Z -1.05 (front window wall)..1.6 (back),
## floor at Y 0, ceiling at 2.5. The player sits at about (0, 1.2, 0.3) facing -Z.

signal light_flickered

const IN_X := 1.8
const FRONT_Z := -1.05
const BACK_Z := 1.6
const CEIL := 2.5
const SILL := 0.95
const HEAD := 2.2
const WALL := 0.1
const DESK_Y := 0.76

var light: OmniLight3D
var fill: OmniLight3D
var tube_mat: StandardMaterial3D
var light_base_energy := 1.25
var _flicker_timer := 0.0
var _flickering := 0.0
var _hour_hand: Node3D
var _min_hand: Node3D
var _sec_hand: Node3D
var _glass_shader: Shader


func _ready() -> void:
	_glass_shader = load("res://shaders/window_glass.gdshader")
	_build_shell()
	_build_windows()
	_build_desk()
	_build_light()
	_build_decor()
	_build_clock()

	# Cancel the outdoor mist inside the booth.
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(IN_X * 2.0, CEIL, BACK_Z - FRONT_Z)
	fv.position = Vector3(0, CEIL * 0.5, (BACK_Z + FRONT_Z) * 0.5)
	var fm := FogMaterial.new()
	fm.density = -1.0
	fv.material = fm
	add_child(fv)

	# Interior reflections (seen faintly in the night-black windows and CRT glass).
	var probe := ReflectionProbe.new()
	probe.size = Vector3(IN_X * 2.0 + 0.2, CEIL, BACK_Z - FRONT_Z + 0.2)
	probe.position = Vector3(0, CEIL * 0.5, (BACK_Z + FRONT_Z) * 0.5)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.intensity = 0.45
	add_child(probe)

	_flicker_timer = randf_range(25.0, 60.0)


# ------------------------------------------------------------------ shell
func _build_shell() -> void:
	var panel := MK.mat(Color(1, 1, 1), "wall_panel", 0.7, 1.0)
	var cream := MK.mat(Color(0.78, 0.75, 0.66), "concrete", 0.9, 2.0)
	var frame := MK.mat(Color(0.23, 0.17, 0.12), "metal", 0.45, 1.0, 0.6)  # bronze anodised aluminium
	var floor_m := MK.mat(Color(1, 1, 1), "floor_lino", 0.55, 0.6)
	var ceil_m := MK.mat(Color(1, 1, 1), "ceiling_tile", 0.95, 0.6)
	var ext := MK.mat(Color(0.55, 0.53, 0.5), "concrete", 0.9, 1.5)

	var fz := FRONT_Z
	var bz := BACK_Z
	var x := IN_X
	var w := WALL

	# Floor and ceiling.
	MK.box_from(self, Vector3(-x - w, -0.05, fz - w), Vector3(x + w, 0.0, bz + w), floor_m, "Floor")
	MK.box_from(self, Vector3(-x - w, CEIL, fz - w), Vector3(x + w, CEIL + 0.08, bz + w), ceil_m, "Ceiling")
	# Roof with overhang (blocks the lamp from above, catches light spill).
	MK.box_from(self, Vector3(-x - 0.5, CEIL + 0.08, fz - 0.55), Vector3(x + 0.5, CEIL + 0.28, bz + 0.5), ext, "Roof")
	MK.box_from(self, Vector3(-x - 0.52, CEIL + 0.08, fz - 0.57), Vector3(x + 0.52, CEIL + 0.18, fz - 0.5), frame, "RoofFascia")

	# Front wall: lower panel, header, mullions.
	MK.box_from(self, Vector3(-x - w, -0.15, fz - w), Vector3(x + w, SILL, fz), panel, "FrontLower")
	MK.box_from(self, Vector3(-x - w, HEAD, fz - w), Vector3(x + w, CEIL, fz), cream, "FrontHeader")
	for mx in [-0.25, 1.3]:
		MK.box_from(self, Vector3(mx - 0.06, SILL, fz - w - 0.01), Vector3(mx + 0.06, HEAD, fz + 0.01), frame, "Mullion")
	# Sill board and frame trims.
	MK.box_from(self, Vector3(-x, SILL - 0.02, fz), Vector3(x, SILL + 0.02, fz + 0.13), MK.mat(Color(0.5, 0.42, 0.34), "wood_desk", 0.5, 0.9), "Sill")
	MK.box_from(self, Vector3(-x, HEAD - 0.03, fz - 0.06), Vector3(x, HEAD, fz + 0.01), frame, "HeadTrim")
	MK.box_from(self, Vector3(-x, SILL + 0.02, fz - 0.06), Vector3(x, SILL + 0.045, fz - 0.02), frame, "SillTrim")

	# Left wall (window toward the barrier and lane).
	MK.box_from(self, Vector3(-x - w, -0.15, fz - w), Vector3(-x, SILL, bz + w), panel, "LeftLower")
	MK.box_from(self, Vector3(-x - w, HEAD, fz - w), Vector3(-x, CEIL, bz + w), cream, "LeftHeader")
	MK.box_from(self, Vector3(-x - w, SILL, 0.95), Vector3(-x, HEAD, bz + w), panel, "LeftSolid")
	MK.box_from(self, Vector3(-x - w - 0.01, SILL, -0.06), Vector3(-x + 0.01, HEAD, 0.06), frame, "LeftMullion")
	MK.box_from(self, Vector3(-x, SILL - 0.02, fz), Vector3(-x + 0.13, SILL + 0.02, 0.95), MK.mat(Color(0.5, 0.42, 0.34), "wood_desk", 0.5, 0.9), "LeftSill")

	# Right wall: window at the front, door at the back.
	MK.box_from(self, Vector3(x, -0.15, fz - w), Vector3(x + w, SILL, 0.3), panel, "RightLower")
	MK.box_from(self, Vector3(x, HEAD, fz - w), Vector3(x + w, CEIL, bz + w), cream, "RightHeader")
	MK.box_from(self, Vector3(x, SILL, 0.18), Vector3(x + w, HEAD, 0.3), frame, "RightJamb")
	MK.box_from(self, Vector3(x, -0.15, 1.3), Vector3(x + w, HEAD, bz + w), panel, "RightSolid")
	# Door (closed) with a small wired-glass window.
	var door := Node3D.new()
	door.name = "Door"
	door.position = Vector3(x + 0.05, 0, 0.3)
	add_child(door)
	var door_m := MK.mat(Color(0.42, 0.36, 0.28), "metal", 0.6, 1.0)
	MK.box_from(door, Vector3(-0.04, 0.0, 0.0), Vector3(0.04, 1.2, 1.0), door_m)
	MK.box_from(door, Vector3(-0.04, 1.85, 0.0), Vector3(0.04, 2.2, 1.0), door_m)
	MK.box_from(door, Vector3(-0.04, 1.2, 0.0), Vector3(0.04, 1.85, 0.2), door_m)
	MK.box_from(door, Vector3(-0.04, 1.2, 0.8), Vector3(0.04, 1.85, 1.0), door_m)
	_glass(door, Vector3(0, 1.525, 0.5), Vector2(0.6, 0.65), Vector3(0, 90, 0), 0.25)
	MK.box(door, Vector3(0.06, 0.03, 0.14), Vector3(-0.08, 1.0, 0.88), MK.mat(Color(0.7, 0.68, 0.6), "", 0.3, 1.0, 0.9), Vector3.ZERO, "Handle")

	# Back wall.
	MK.box_from(self, Vector3(-x - w, -0.15, bz), Vector3(x + w, CEIL, bz + w), panel, "BackWall")

	# Skirting board.
	var skirt := MK.mat(Color(0.2, 0.16, 0.12), "", 0.6)
	MK.box_from(self, Vector3(-x, 0, bz - 0.02), Vector3(x, 0.1, bz), skirt)
	MK.box_from(self, Vector3(-x, 0, fz), Vector3(-x + 0.02, 0.1, bz), skirt)

	# Exterior concrete island the booth sits on.
	var island := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(5.0, 0.16, 4.6)
	island.mesh = pm
	island.position = Vector3(0, -0.08, 0.25)
	var im := ShaderMaterial.new()
	im.shader = load("res://shaders/wet_ground.gdshader")
	im.set_shader_parameter("albedo_tex", MK.tex("concrete"))
	im.set_shader_parameter("tex_scale", 0.6)
	im.set_shader_parameter("puddle_amount", 0.15)
	im.set_shader_parameter("tint", Color(0.8, 0.78, 0.74))
	island.material_override = im
	island.name = "Island"
	add_child(island)


func _glass(parent: Node3D, pos: Vector3, size: Vector2, rot: Vector3, rain_side := 1.0) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = _glass_shader
	m.set_shader_parameter("pane_size", size)
	m.set_shader_parameter("seed", randf() * 100.0)
	m.set_shader_parameter("rain_side", rain_side)
	var q := MK.quad(parent, size, pos, m, rot, "Glass")
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return q


func _build_windows() -> void:
	var z := FRONT_Z - WALL * 0.5
	var h := HEAD - SILL
	var yc := SILL + h * 0.5
	# Front panes between the mullions. (Quad faces +Z, i.e. toward the player.)
	for span in [[-IN_X, -0.31], [-0.19, 1.24], [1.36, IN_X]]:
		var w: float = span[1] - span[0]
		_glass(self, Vector3((span[0] + span[1]) * 0.5, yc, z), Vector2(w, h), Vector3.ZERO, 1.0)
	# Left side panes (face +X).
	for span in [[FRONT_Z, -0.06], [0.06, 0.95]]:
		var w2: float = span[1] - span[0]
		_glass(self, Vector3(-IN_X - WALL * 0.5, yc, (span[0] + span[1]) * 0.5), Vector2(w2, h), Vector3(0, 90, 0), 0.6)
	# Right front pane (face -X).
	_glass(self, Vector3(IN_X + WALL * 0.5, yc, (FRONT_Z + 0.18) * 0.5), Vector2(0.18 - FRONT_Z, h), Vector3(0, -90, 0), 0.4)


# ------------------------------------------------------------------- desk
func _build_desk() -> void:
	var top := MK.mat(Color(1, 1, 1), "wood_desk", 0.55, 0.9)
	var body := MK.mat(Color(0.62, 0.58, 0.5), "wood_desk", 0.7, 0.9)
	var edge := MK.mat(Color(0.18, 0.12, 0.08), "", 0.5)
	var handle := MK.mat(Color(0.75, 0.72, 0.62), "", 0.3, 1.0, 0.9)
	var fz := FRONT_Z
	var front := -0.35

	MK.box_from(self, Vector3(-IN_X, DESK_Y - 0.04, fz), Vector3(IN_X, DESK_Y, front), top, "DeskTop")
	MK.box_from(self, Vector3(-IN_X, DESK_Y - 0.05, front - 0.01), Vector3(IN_X, DESK_Y + 0.003, front + 0.012), edge, "DeskEdge")
	# Pedestals with drawers either side of the knee space.
	for ped in [[-IN_X, -0.95], [0.55, IN_X]]:
		MK.box_from(self, Vector3(ped[0], 0.0, fz), Vector3(ped[1], DESK_Y - 0.04, front - 0.02), body)
		var n := 3
		for i in n:
			var y0 := 0.06 + i * (DESK_Y - 0.12) / n
			var y1 := y0 + (DESK_Y - 0.12) / n - 0.025
			MK.box_from(self, Vector3(ped[0] + 0.03, y0, front - 0.02), Vector3(ped[1] - 0.03, y1, front - 0.005), body)
			var cx: float = (ped[0] + ped[1]) * 0.5
			MK.box(self, Vector3(0.12, 0.018, 0.02), Vector3(cx, y1 - 0.05, front + 0.005), handle)
	# Knee space back panel.
	MK.box_from(self, Vector3(-0.95, 0.1, fz), Vector3(0.55, DESK_Y - 0.04, fz + 0.02), body)


# ------------------------------------------------------------------ light
func _build_light() -> void:
	var fix := Node3D.new()
	fix.name = "CeilingLight"
	fix.position = Vector3(0, CEIL, 0.15)
	add_child(fix)
	var housing := MK.mat(Color(0.85, 0.84, 0.8), "metal", 0.6)
	MK.box(fix, Vector3(1.3, 0.06, 0.32), Vector3(0, -0.03, 0), housing)
	tube_mat = MK.emissive(Color(0.86, 0.97, 0.9), 2.6, Color(0.9, 0.95, 0.9))
	for tz in [-0.07, 0.07]:
		MK.cyl(fix, 0.016, 0.016, 1.2, Vector3(0, -0.085, tz), tube_mat, 6, Vector3(0, 0, 90))
	# Diffuser rails.
	MK.box(fix, Vector3(1.3, 0.04, 0.015), Vector3(0, -0.08, -0.16), housing)
	MK.box(fix, Vector3(1.3, 0.04, 0.015), Vector3(0, -0.08, 0.16), housing)

	light = MK.omni(self, Vector3(0, CEIL - 0.2, 0.15), Color(0.86, 0.96, 0.88), light_base_energy, 11.0, true, "BoothLight")
	light.omni_attenuation = 1.3
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.5
	light.light_volumetric_fog_energy = 1.2
	# Soft bounce so the room's shadows are not pure black.
	fill = MK.omni(self, Vector3(0, 1.0, 0.8), Color(0.75, 0.72, 0.62), 0.18, 4.0, false, "BounceFill")
	fill.light_specular = 0.0
	fill.light_volumetric_fog_energy = 0.0


func _process(delta: float) -> void:
	_update_clock()
	_flicker_timer -= delta
	if _flicker_timer <= 0.0 and _flickering <= 0.0:
		_flickering = randf_range(0.35, 0.9)
		_flicker_timer = randf_range(40.0, 140.0)
		light_flickered.emit()
	if _flickering > 0.0:
		_flickering -= delta
		var on := randf() > 0.45
		var k := 1.0 if on else randf_range(0.05, 0.35)
		if _flickering <= 0.0:
			k = 1.0
		_set_light(k)


func _set_light(k: float) -> void:
	light.light_energy = light_base_energy * k
	fill.light_energy = 0.18 * k
	tube_mat.emission_energy_multiplier = 2.6 * k


## For the story: dim or kill the booth light. k 0..1.
func set_power(k: float) -> void:
	_set_light(k)


func force_flicker(duration := 0.8) -> void:
	_flickering = duration
	light_flickered.emit()


# ------------------------------------------------------------------ decor
func _build_decor() -> void:
	# Calendar on the left wall's solid section, cork board on the back wall.
	MK.quad(self, Vector2(0.32, 0.44), Vector3(-IN_X + 0.012, 1.55, 1.3), MK.picture("calendar"), Vector3(0, 90, 0), "Calendar")
	var cork := MK.quad(self, Vector2(0.9, 0.68), Vector3(-0.6, 1.5, BACK_Z - 0.012), MK.picture("corkboard"), Vector3(0, 180, 0), "Corkboard")
	MK.box(cork, Vector3(0.94, 0.72, 0.02), Vector3(0, 0, -0.012), MK.mat(Color(0.3, 0.2, 0.12), "", 0.7))
	# Coat hook with a rain coat.
	var coat := MK.mat(Color(0.35, 0.3, 0.12), "beige_plastic", 0.9, 0.5)
	MK.taper(self, Vector3(0.45, 0.95, 0.14), 0.18, 0.0, Vector3(0.9, 1.25, BACK_Z - 0.09), coat)
	# Grey filing cabinet in the back corner.
	var cab := MK.mat(Color(0.5, 0.52, 0.5), "metal", 0.5, 1.0, 0.3)
	MK.box_from(self, Vector3(1.25, 0, 1.0), Vector3(1.78, 1.3, 1.58), cab, "FilingCabinet")
	for i in 3:
		MK.box(self, Vector3(0.12, 0.02, 0.02), Vector3(1.515, 1.1 - i * 0.42, 0.985), MK.mat(Color(0.8, 0.8, 0.78), "", 0.3, 1.0, 0.9))


func _build_clock() -> void:
	var clock := Node3D.new()
	clock.name = "WallClock"
	clock.position = Vector3(0.55, 2.35, FRONT_Z + 0.02)
	add_child(clock)
	MK.cyl(clock, 0.13, 0.13, 0.04, Vector3(0, 0, 0), MK.mat(Color(0.12, 0.12, 0.12), "", 0.4), 16, Vector3(90, 0, 0))
	MK.quad(clock, Vector2(0.24, 0.24), Vector3(0, 0, 0.021), MK.picture("clock_face", 0.35), Vector3.ZERO)
	var hand_m := MK.mat(Color(0.05, 0.05, 0.05), "", 0.5)
	_hour_hand = _hand(clock, 0.06, 0.012, hand_m, 0.024)
	_min_hand = _hand(clock, 0.095, 0.008, hand_m, 0.026)
	_sec_hand = _hand(clock, 0.1, 0.004, MK.mat(Color(0.6, 0.08, 0.05), "", 0.5), 0.028)


func _hand(parent: Node3D, length: float, width: float, m: Material, z: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, z)
	parent.add_child(pivot)
	MK.box(pivot, Vector3(width, length, 0.003), Vector3(0, length * 0.4, 0), m)
	return pivot


func _update_clock() -> void:
	var h := NightClock.hours_f()
	var sec := fmod(Time.get_ticks_msec() / 1000.0, 60.0)
	_hour_hand.rotation.z = -fmod(h, 12.0) / 12.0 * TAU
	_min_hand.rotation.z = -fmod(h * 60.0, 60.0) / 60.0 * TAU
	_sec_hand.rotation.z = -floor(sec) / 60.0 * TAU
