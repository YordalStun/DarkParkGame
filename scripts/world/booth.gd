extends Node3D
## The security booth: walls, windows, desk, ceiling light, wall clock and decor.
##
## Layout (metres): interior X -1.8..1.8, Z -1.05 (front window wall)..1.6 (back),
## floor at Y 0, ceiling at 2.5. The player sits at about (0, 1.2, 0.3) facing -Z.

signal light_flickered
signal light_switched(on: bool)

const IN_X := 1.8
const FRONT_Z := -1.05
const BACK_Z := 1.6
const CEIL := 2.5
const SILL := 0.95
const HEAD := 2.2
const WALL := 0.1
const DESK_Y := 0.76
const DOOR_X := Vector2(0.45, 1.35)   ## the back door's opening (x range)
const DOOR_H := 2.08

## Back-of-booth dressing: "a" (lived-in) or "b" (sparse and eerie). Set before the world builds.
static var decor := "a"
var door: Node3D
var door_interact: Interactable
var light_switch: Interactable
var light_on := true
var exit_sign_mat: StandardMaterial3D

var light: OmniLight3D
var fill: OmniLight3D
var tube_mat: StandardMaterial3D
var light_base_energy := 1.25
var _flicker_timer := 0.0
var _blinks: Array = []   # [seconds left, brightness] steps of a flicker
var _hour_hand: Node3D
var _min_hand: Node3D
var _sec_hand: Node3D
var _glass_shader: Shader

## The sliding pane in the left wall, by the barrier lane. Open it to talk to drivers.
signal side_window_moved(open: bool)
var side_view: Interactable        ## click the left window to turn and face it (zoom with free look)
var side_pane: Node3D              ## the sliding sash (glass + frame)
var side_pane_interact: Interactable
var side_is_open := false
var side_open := 0.0               ## 0..1 how far open (the ambience reads this)
var raise_button: Interactable     ## barrier panel on the left sill
var lower_button: Interactable
var _side_tw: Tween
var lane_flood: SpotLight3D        ## floodlight outside the side window (story can switch it off)
const SIDE_SPAN := Vector2(0.06, 0.95)   ## z range of the sliding pane

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

	_flicker_timer = randf_range(90.0, 200.0)


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

	# Right wall: window at the front, solid behind.
	MK.box_from(self, Vector3(x, -0.15, fz - w), Vector3(x + w, SILL, 0.3), panel, "RightLower")
	MK.box_from(self, Vector3(x, HEAD, fz - w), Vector3(x + w, CEIL, bz + w), cream, "RightHeader")
	MK.box_from(self, Vector3(x, SILL, 0.18), Vector3(x + w, HEAD, 0.3), frame, "RightJamb")
	MK.box_from(self, Vector3(x, -0.15, 0.3), Vector3(x + w, HEAD, bz + w), panel, "RightSolid")
	MK.box_from(self, Vector3(x, -0.15, 0.18), Vector3(x + w, SILL, 0.3), panel)

	# Back wall, with the way out: a door behind the desk chair.
	MK.box_from(self, Vector3(-x - w, -0.15, bz), Vector3(DOOR_X.x, CEIL, bz + w), panel, "BackWall")
	MK.box_from(self, Vector3(DOOR_X.y, -0.15, bz), Vector3(x + w, CEIL, bz + w), panel, "BackWallR")
	MK.box_from(self, Vector3(DOOR_X.x, DOOR_H, bz), Vector3(DOOR_X.y, CEIL, bz + w), panel, "BackWallTop")
	# Frame.
	for fx in [DOOR_X.x - 0.04, DOOR_X.y]:
		MK.box_from(self, Vector3(fx, 0, bz - 0.02), Vector3(fx + 0.04, DOOR_H + 0.04, bz + w + 0.01), frame)
	MK.box_from(self, Vector3(DOOR_X.x - 0.04, DOOR_H, bz - 0.02), Vector3(DOOR_X.y + 0.04, DOOR_H + 0.05, bz + w + 0.01), frame)
	# The door (closed) with a wired-glass window. Hinged on the right; opens outward.
	door = Node3D.new()
	door.name = "Door"
	door.position = Vector3(DOOR_X.y, 0, bz + w * 0.5)
	add_child(door)
	var dw := DOOR_X.y - DOOR_X.x
	var door_m := MK.mat(Color(0.42, 0.36, 0.28), "metal", 0.6, 1.0)
	MK.box_from(door, Vector3(-dw, 0.0, -0.035), Vector3(0, 1.15, 0.035), door_m)
	MK.box_from(door, Vector3(-dw, 1.8, -0.035), Vector3(0, DOOR_H, 0.035), door_m)
	MK.box_from(door, Vector3(-dw, 1.15, -0.035), Vector3(-dw + 0.18, 1.8, 0.035), door_m)
	MK.box_from(door, Vector3(-0.18, 1.15, -0.035), Vector3(0, 1.8, 0.035), door_m)
	_glass(door, Vector3(-dw * 0.5, 1.475, 0.0), Vector2(dw - 0.36, 0.65), Vector3(0, 180, 0), 0.3)
	var chrome := MK.mat(Color(0.7, 0.68, 0.6), "", 0.3, 1.0, 0.9)
	MK.box(door, Vector3(0.14, 0.03, 0.06), Vector3(-dw + 0.14, 1.0, -0.07), chrome, Vector3.ZERO, "Handle")
	MK.box(door, Vector3(0.06, 0.09, 0.02), Vector3(-dw + 0.1, 1.0, -0.04), chrome)
	MK.box(door, Vector3(0.12, 0.2, 0.02), Vector3(-dw + 0.12, 1.75, -0.045), MK.mat(Color(0.8, 0.8, 0.75), "", 0.5))   # push bar plate
	door_interact = Interactable.new()
	door_interact.prompt = "Door"
	door_interact.add_box(Vector3(dw, DOOR_H, 0.2), Vector3(-dw * 0.5, DOOR_H * 0.5, -0.05))
	door_interact.enabled = false
	door.add_child(door_interact)

	# Skirting board.
	var skirt := MK.mat(Color(0.2, 0.16, 0.12), "", 0.6)
	MK.box_from(self, Vector3(-x, 0, bz - 0.02), Vector3(DOOR_X.x - 0.04, 0.1, bz), skirt)
	MK.box_from(self, Vector3(DOOR_X.y + 0.04, 0, bz - 0.02), Vector3(x, 0.1, bz), skirt)
	MK.box_from(self, Vector3(-x, 0, fz), Vector3(-x + 0.02, 0.1, bz), skirt)

	# Exterior concrete island the booth sits on.
	var island := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(5.0, 0.15, 4.6)
	island.mesh = pm
	island.position = Vector3(0, -0.085, 0.25)  # top at -1 cm: never level with the booth floor
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
	# Left side: a fixed pane at the front, and the sliding pane by the lane (face +X).
	_glass(self, Vector3(-IN_X - WALL * 0.5, yc, (FRONT_Z - 0.06) * 0.5), Vector2(-0.06 - FRONT_Z, h), Vector3(0, 90, 0), 0.6)
	_build_side_window(yc, h)
	_build_lane_flood()
	# Right front pane (face -X).
	_glass(self, Vector3(IN_X + WALL * 0.5, yc, (FRONT_Z + 0.18) * 0.5), Vector2(0.18 - FRONT_Z, h), Vector3(0, -90, 0), 0.4)


## The sliding sash, the view that faces it, and the barrier buttons on the sill.
func _build_side_window(yc: float, h: float) -> void:
	var frame := MK.mat(Color(0.23, 0.17, 0.12), "metal", 0.45, 1.0, 0.6)
	var w := SIDE_SPAN.y - SIDE_SPAN.x
	side_pane = Node3D.new()
	side_pane.name = "SidePane"
	# Sits a little inside the fixed glass so it can slide over it.
	side_pane.position = Vector3(-IN_X + 0.03, yc, (SIDE_SPAN.x + SIDE_SPAN.y) * 0.5)
	add_child(side_pane)
	_glass(side_pane, Vector3.ZERO, Vector2(w - 0.05, h - 0.05), Vector3(0, 90, 0), 0.6)
	MK.box(side_pane, Vector3(0.03, h, 0.035), Vector3(0, 0, -w * 0.5 + 0.0175), frame)
	MK.box(side_pane, Vector3(0.03, h, 0.035), Vector3(0, 0, w * 0.5 - 0.0175), frame)
	MK.box(side_pane, Vector3(0.03, 0.035, w), Vector3(0, -h * 0.5 + 0.0175, 0), frame)
	MK.box(side_pane, Vector3(0.03, 0.035, w), Vector3(0, h * 0.5 - 0.0175, 0), frame)
	MK.box(side_pane, Vector3(0.03, 0.12, 0.025), Vector3(0.025, 0, w * 0.5 - 0.06), MK.mat(Color(0.7, 0.68, 0.6), "", 0.3, 1.0, 0.9))  # finger pull

	# Turning to face the side window (from the desk).
	side_view = Interactable.new()
	side_view.name = "SideWindowView"
	side_view.prompt = "Side window"
	side_view.add_box(Vector3(0.12, h, 2.0), Vector3(-IN_X - 0.02, yc, -0.05))
	add_child(side_view)
	var marker := Node3D.new()
	marker.name = "SideViewMarker"
	marker.position = Vector3(-1.08, 1.24, 0.5)
	marker.rotation_degrees = Vector3(-6, 90, 0)   # facing -X, out of the window
	add_child(marker)
	side_view.zoom_marker = marker
	side_view.zoom_fov = 62.0
	side_view.zoom_look = Vector2(62.0, 34.0)

	side_pane_interact = Interactable.new()
	side_pane_interact.prompt = "Open window"
	side_pane_interact.requires_focus = side_view
	side_pane_interact.add_box(Vector3(0.06, h, w))
	side_pane.add_child(side_pane_interact)
	side_pane_interact.activated.connect(func(): set_side_window(not side_is_open))

	# Barrier control box on the wall under the side window: green RAISE, red LOWER.
	var panel := Node3D.new()
	panel.name = "BarrierPanel"
	panel.position = Vector3(-IN_X + 0.03, SILL - 0.16, 0.66)
	add_child(panel)
	var grey := MK.mat(Color(0.32, 0.33, 0.32), "metal", 0.5, 1.0, 0.4)
	MK.box(panel, Vector3(0.06, 0.1, 0.16), Vector3.ZERO, grey)
	MK.quad(panel, Vector2(0.13, 0.02), Vector3(0.031, 0.035, 0), MK.mat(Color(0.85, 0.82, 0.7), "", 0.6), Vector3(0, 90, 0))
	var green := MK.emissive(Color(0.1, 0.9, 0.2), 1.4, Color(0.05, 0.4, 0.1))
	var red := MK.emissive(Color(0.95, 0.12, 0.08), 1.4, Color(0.4, 0.05, 0.03))
	MK.cyl(panel, 0.016, 0.018, 0.016, Vector3(0.036, -0.01, 0.036), green, 10, Vector3(0, 0, 90))
	MK.cyl(panel, 0.016, 0.018, 0.016, Vector3(0.036, -0.01, -0.036), red, 10, Vector3(0, 0, 90))
	raise_button = _panel_button(panel, "Raise barrier", Vector3(0.036, -0.01, 0.036))
	lower_button = _panel_button(panel, "Lower barrier", Vector3(0.036, -0.01, -0.036))


## A bright floodlight on the outside wall over the side window: lights up the lane, the
## driver's window, and anything else that might be standing out there.
func _build_lane_flood() -> void:
	var fx := Node3D.new()
	fx.name = "LaneFlood"
	fx.position = Vector3(-IN_X - WALL - 0.02, CEIL - 0.05, 0.45)
	add_child(fx)
	var metal := MK.mat(Color(0.15, 0.15, 0.15), "metal", 0.5, 1.0, 0.5)
	MK.box(fx, Vector3(0.12, 0.05, 0.06), Vector3(-0.06, 0, 0), metal)                 # bracket
	MK.box(fx, Vector3(0.22, 0.16, 0.26), Vector3(-0.2, -0.04, 0), metal, Vector3(0, 0, -35))  # lamp housing
	MK.box(fx, Vector3(0.02, 0.13, 0.22), Vector3(-0.28, -0.11, 0), MK.emissive(Color(1.0, 0.97, 0.88), 6.0, Color(1, 1, 1)), Vector3(0, 0, -35))
	lane_flood = SpotLight3D.new()
	lane_flood.name = "LaneFloodLight"
	lane_flood.position = Vector3(-0.3, -0.12, 0)
	# Spot shines along -Z; aim it out (-X) and down at the lane.
	lane_flood.rotation_degrees = Vector3(-48, 90, 0)
	lane_flood.light_color = Color(1.0, 0.96, 0.86)
	lane_flood.light_energy = 5.0
	lane_flood.spot_range = 14.0
	lane_flood.spot_angle = 52.0
	lane_flood.spot_attenuation = 0.9
	lane_flood.light_volumetric_fog_energy = 1.0
	lane_flood.shadow_enabled = true
	lane_flood.shadow_bias = 0.05
	lane_flood.light_cull_mask = 1   # not the inside of cars (CarModel.CABIN_LAYER)
	fx.add_child(lane_flood)


func _panel_button(parent: Node3D, label: String, pos: Vector3) -> Interactable:
	var it := Interactable.new()
	it.prompt = label
	it.requires_focus = side_view
	it.add_box(Vector3(0.05, 0.045, 0.045), pos)
	parent.add_child(it)
	return it


func set_side_window(open: bool) -> void:
	if open == side_is_open:
		return
	side_is_open = open
	side_pane_interact.prompt = "Close window" if open else "Open window"
	if _side_tw:
		_side_tw.kill()
	_side_tw = create_tween().set_parallel(true)
	_side_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var z := (SIDE_SPAN.x + SIDE_SPAN.y) * 0.5 - (0.82 if open else 0.0)
	_side_tw.tween_property(side_pane, "position:z", z, 0.8)
	_side_tw.tween_property(self, "side_open", 1.0 if open else 0.0, 0.8)
	side_window_moved.emit(open)


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
	if not light_on:
		_blinks.clear()
		return
	if _flicker_timer <= 0.0 and _blinks.is_empty():
		_flicker_timer = randf_range(120.0, 300.0)
		force_flicker()
	# Play the queued blinks: each holds its brightness for a few frames, the way
	# a tired fluorescent tube cuts out and restrikes (not a per-frame strobe).
	if not _blinks.is_empty():
		_blinks[0][0] -= delta
		if _blinks[0][0] <= 0.0:
			_blinks.pop_front()
			_set_light(_blinks[0][1] if not _blinks.is_empty() else 1.0)


func _set_light(k: float) -> void:
	light.light_energy = light_base_energy * k
	fill.light_energy = 0.18 * k
	tube_mat.emission_energy_multiplier = 2.6 * k


## For the story: dim or kill the booth light. k 0..1.
func set_power(k: float) -> void:
	_set_light(k)


## A short tube flicker: 2-3 dips, each held for several frames.
func force_flicker() -> void:
	_blinks.clear()
	var n := randi_range(2, 3)
	for i in n:
		_blinks.append([randf_range(0.07, 0.14), randf_range(0.15, 0.4)])  # dip
		_blinks.append([randf_range(0.12, 0.35), 1.0])                       # back on
	_set_light(_blinks[0][1])
	light_flickered.emit()


# ------------------------------------------------------------------ decor
func _build_decor() -> void:
	var bz := BACK_Z
	# Calendar on the left wall, cork board on the back wall.
	MK.quad(self, Vector2(0.32, 0.44), Vector3(-IN_X + 0.012, 1.55, 1.3), MK.picture("calendar"), Vector3(0, 90, 0), "Calendar")
	var cork := MK.quad(self, Vector2(0.9, 0.68), Vector3(-0.75, 1.5, bz - 0.012), MK.picture("corkboard"), Vector3(0, 180, 0), "Corkboard")
	MK.box(cork, Vector3(0.94, 0.72, 0.02), Vector3(0, 0, -0.012), MK.mat(Color(0.3, 0.2, 0.12), "", 0.7))
	# Grey filing cabinet in the back-left corner.
	var cab := MK.mat(Color(0.5, 0.52, 0.5), "metal", 0.5, 1.0, 0.3)
	MK.box_from(self, Vector3(-1.78, 0, 0.95), Vector3(-1.3, 1.3, 1.58), cab, "FilingCabinet")
	for i in 3:
		MK.box(self, Vector3(0.02, 0.02, 0.12), Vector3(-1.295, 1.1 - i * 0.42, 1.27), MK.mat(Color(0.8, 0.8, 0.78), "", 0.3, 1.0, 0.9))
	# Over the door: a lit EXIT sign. Beside it: the light switch.
	exit_sign_mat = MK.picture("sign_exit", 0.5, 1.2)
	MK.box(self, Vector3(0.36, 0.14, 0.06), Vector3((DOOR_X.x + DOOR_X.y) * 0.5, DOOR_H + 0.2, bz - 0.03), MK.mat(Color(0.85, 0.85, 0.82), "", 0.5))
	MK.quad(self, Vector2(0.32, 0.12), Vector3((DOOR_X.x + DOOR_X.y) * 0.5, DOOR_H + 0.2, bz - 0.065), exit_sign_mat, Vector3(0, 180, 0))
	var glow := MK.omni(self, Vector3((DOOR_X.x + DOOR_X.y) * 0.5, DOOR_H + 0.1, bz - 0.25), Color(0.4, 1.0, 0.5), 0.15, 1.6, false, "ExitGlow")
	glow.light_volumetric_fog_energy = 0.0
	var plate := MK.box(self, Vector3(0.08, 0.12, 0.015), Vector3(DOOR_X.x - 0.16, 1.25, bz - 0.008), MK.mat(Color(0.9, 0.88, 0.8), "", 0.4))
	plate.name = "LightSwitch"
	_switch_rocker = MK.box(self, Vector3(0.025, 0.045, 0.02), Vector3(DOOR_X.x - 0.16, 1.25, bz - 0.02), MK.mat(Color(0.95, 0.94, 0.88), "", 0.4))
	_switch_rocker.rotation_degrees.x = -12.0
	light_switch = Interactable.new()
	light_switch.prompt = "Light switch"
	light_switch.add_box(Vector3(0.16, 0.2, 0.12), Vector3(DOOR_X.x - 0.16, 1.25, bz - 0.05))
	add_child(light_switch)
	light_switch.activated.connect(func(): set_light_on(not light_on))
	# Doormat.
	MK.box(self, Vector3(0.8, 0.012, 0.5), Vector3((DOOR_X.x + DOOR_X.y) * 0.5, 0.006, bz - 0.3), MK.mat(Color(0.2, 0.17, 0.12), "", 1.0))
	if decor == "b":
		_decor_eerie()
	else:
		_decor_lived_in()


## Design A: a booth people have actually worked in for years.
func _decor_lived_in() -> void:
	var bz := BACK_Z
	var steel := MK.mat(Color(0.36, 0.42, 0.48), "metal", 0.5, 1.0, 0.4)
	var dark := MK.mat(Color(0.08, 0.08, 0.08), "", 0.6)
	# Two staff lockers against the right wall.
	for i in 2:
		var z0 := 0.42 + i * 0.42
		MK.box_from(self, Vector3(1.38, 0, z0), Vector3(1.79, 1.85, z0 + 0.4), steel)
		for k in 4:
			MK.box(self, Vector3(0.005, 0.012, 0.22), Vector3(1.376, 1.6 - k * 0.04, z0 + 0.2), dark)   # vents
		MK.box(self, Vector3(0.02, 0.08, 0.03), Vector3(1.37, 1.0, z0 + 0.34), MK.mat(Color(0.7, 0.7, 0.68), "", 0.3, 1.0, 0.9))
	MK.quad(self, Vector2(0.14, 0.04), Vector3(1.372, 1.7, 0.62), MK.mat(Color(0.95, 0.95, 0.9), "", 0.6), Vector3(0, -90, 0))    # name tags
	MK.quad(self, Vector2(0.14, 0.04), Vector3(1.372, 1.7, 1.04), MK.mat(Color(0.95, 0.95, 0.9), "", 0.6), Vector3(0, -90, 0))
	# Coat hooks right of the door, with a rain coat and a hi-vis vest.
	var hook_x := DOOR_X.y + 0.25
	MK.box(self, Vector3(0.3, 0.05, 0.03), Vector3(hook_x, 1.75, bz - 0.02), MK.mat(Color(0.3, 0.2, 0.12), "", 0.7))
	MK.taper(self, Vector3(0.36, 0.9, 0.12), 0.16, 0.0, Vector3(hook_x - 0.06, 1.3, bz - 0.08), MK.mat(Color(0.35, 0.3, 0.12), "beige_plastic", 0.9, 0.5))
	MK.taper(self, Vector3(0.3, 0.55, 0.06), 0.18, 0.0, Vector3(hook_x + 0.08, 1.45, bz - 0.12), MK.emissive(Color(0.95, 0.85, 0.1), 0.15, Color(0.85, 0.8, 0.1)))
	# Kettle, mugs and a tea caddy on the filing cabinet.
	MK.cyl(self, 0.08, 0.09, 0.2, Vector3(-1.55, 1.4, 1.35), MK.mat(Color(0.85, 0.85, 0.82), "", 0.3), 12)
	MK.box(self, Vector3(0.03, 0.12, 0.08), Vector3(-1.46, 1.42, 1.35), MK.mat(Color(0.2, 0.2, 0.2), "", 0.5))
	MK.cyl(self, 0.04, 0.04, 0.09, Vector3(-1.62, 1.345, 1.12), MK.mat(Color(0.2, 0.4, 0.7), "", 0.4), 10)
	MK.cyl(self, 0.04, 0.04, 0.09, Vector3(-1.5, 1.345, 1.06), MK.mat(Color(0.9, 0.9, 0.86), "", 0.4), 10)
	MK.box(self, Vector3(0.1, 0.14, 0.1), Vector3(-1.66, 1.37, 1.5), MK.mat(Color(0.6, 0.12, 0.1), "metal", 0.4, 1.0, 0.4))
	# Signs and posters.
	MK.quad(self, Vector2(0.27, 0.36), Vector3(0.12, 1.55, bz - 0.012), MK.picture("poster_safety"), Vector3(0, 180, 0))
	MK.quad(self, Vector2(0.18, 0.24), Vector3(IN_X - 0.012, 1.95, 1.3), MK.picture("sign_nosmoking"), Vector3(0, -90, 0))
	# Fire extinguisher by the door.
	MK.cyl(self, 0.075, 0.075, 0.5, Vector3(DOOR_X.y + 0.25, 0.32, bz - 0.12), MK.mat(Color(0.75, 0.08, 0.05), "", 0.35, 1.0, 0.3), 12)
	MK.cyl(self, 0.03, 0.04, 0.08, Vector3(DOOR_X.y + 0.25, 0.61, bz - 0.12), dark, 8)
	# Fan heater on the floor by the desk.
	MK.box(self, Vector3(0.3, 0.26, 0.18), Vector3(-1.1, 0.13, 0.75), MK.mat(Color(0.78, 0.74, 0.62), "beige_plastic", 0.5, 0.4))
	MK.box(self, Vector3(0.22, 0.14, 0.01), Vector3(-1.1, 0.14, 0.845), MK.mat(Color(0.15, 0.08, 0.05), "", 0.6))
	# Waste bin.
	MK.cyl(self, 0.13, 0.11, 0.32, Vector3(1.0, 0.16, 0.2), MK.mat(Color(0.2, 0.25, 0.2), "metal", 0.6, 1.0, 0.3), 10)


## Design B: bare, cold, and someone else's things still here.
func _decor_eerie() -> void:
	var bz := BACK_Z
	# A plastic stacking chair against the right wall, nobody's.
	var orange := MK.mat(Color(0.75, 0.38, 0.12), "", 0.6)
	var legs := MK.mat(Color(0.35, 0.35, 0.35), "metal", 0.4, 1.0, 0.6)
	var c := Vector3(1.45, 0, 0.9)
	MK.box(self, Vector3(0.42, 0.04, 0.4), c + Vector3(0, 0.45, 0), orange)
	MK.box(self, Vector3(0.04, 0.4, 0.4), c + Vector3(0.2, 0.7, 0), orange, Vector3(0, 0, -6))
	for lx in [-0.18, 0.18]:
		for lz in [-0.17, 0.17]:
			MK.box(self, Vector3(0.025, 0.45, 0.025), c + Vector3(lx, 0.225, lz), legs)
	# Mop and bucket in the corner by the door.
	MK.cyl(self, 0.16, 0.13, 0.3, Vector3(1.6, 0.15, 1.38), MK.mat(Color(0.75, 0.72, 0.1), "", 0.5), 12)
	MK.cyl(self, 0.012, 0.012, 1.3, Vector3(1.6, 0.75, 1.42), MK.mat(Color(0.5, 0.4, 0.25), "", 0.7), 6, Vector3(10, 0, 0))
	# Roy's coat still on the hook, and his missing poster beside the door.
	MK.box(self, Vector3(0.06, 0.04, 0.06), Vector3(DOOR_X.y + 0.25, 1.78, bz - 0.03), MK.mat(Color(0.3, 0.3, 0.3), "metal", 0.4, 1.0, 0.6))
	MK.taper(self, Vector3(0.38, 1.0, 0.12), 0.16, 0.0, Vector3(DOOR_X.y + 0.25, 1.28, bz - 0.08), MK.mat(Color(0.12, 0.13, 0.16), "", 0.9))
	MK.quad(self, Vector2(0.3, 0.41), Vector3(0.12, 1.5, bz - 0.012), MK.picture("poster_missing"), Vector3(0, 180, -2))
	MK.quad(self, Vector2(0.18, 0.24), Vector3(IN_X - 0.012, 1.55, 1.15), MK.picture("sheet_rota"), Vector3(0, -90, 0))
	# A lost-property box with a torch and a flask in it.
	var card := MK.mat(Color(0.55, 0.42, 0.26), "", 0.9)
	MK.box(self, Vector3(0.45, 0.3, 0.35), Vector3(-1.0, 0.15, 1.35), card)
	MK.quad(self, Vector2(0.3, 0.08), Vector3(-1.0, 0.22, 1.172), MK.mat(Color(0.95, 0.95, 0.9), "", 0.6), Vector3(0, 180, 0))
	MK.cyl(self, 0.035, 0.035, 0.22, Vector3(-0.95, 0.38, 1.38), MK.mat(Color(0.3, 0.35, 0.3), "metal", 0.4, 1.0, 0.5), 8)
	# Muddy footprints from the door to the chair, a few at a time.
	var mud := MK.mat(Color(0.12, 0.1, 0.07), "", 1.0)
	for i in 5:
		var t := float(i) / 4.0
		var p := Vector3(lerpf(0.95, 1.3, t), 0.003, lerpf(1.3, 1.05, t)) + Vector3(0.08 if i % 2 == 0 else -0.08, 0, 0)
		MK.box(self, Vector3(0.09, 0.002, 0.22), p, mud)


var _switch_rocker: MeshInstance3D


## The booth's ceiling light, by the switch at the door.
func set_light_on(on: bool) -> void:
	light_on = on
	_switch_rocker.rotation_degrees.x = -12.0 if on else 12.0
	_set_light(1.0 if on else 0.0)
	light_switched.emit(on)


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
