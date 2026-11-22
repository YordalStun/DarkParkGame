extends Node3D
## The car park outside the booth: wet asphalt, worn bay lines, parked cars,
## the sodium street lamp, barrier gate, fence, swaying trees and the distant
## town beyond. Ground level is Y = -0.15 (the booth sits on a raised island).
##
## The lot stretches out in front of the booth (toward -Z).

const StreetLamp := preload("res://scripts/world/street_lamp.gd")
const BarrierGate := preload("res://scripts/world/barrier_gate.gd")
const Store := preload("res://scripts/world/store.gd")

const G := -0.15  # ground height

var lamp: Node3D
var gate: Node3D
var trees: Array[Node3D] = []
var cars: Array[Node3D] = []
var payphone: Node3D
var store: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1013
	_build_ground()
	_build_lines()
	_build_lamp()
	_build_cars()
	_build_gate_and_signs()
	_build_store()
	_build_fence()
	_build_trees()
	_build_distance()


func _wet(texture: String, tex_scale: float, puddles: float, tint := Color(1, 1, 1)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/wet_ground.gdshader")
	m.set_shader_parameter("albedo_tex", MK.tex(texture))
	m.set_shader_parameter("tex_scale", tex_scale)
	m.set_shader_parameter("puddle_amount", puddles)
	m.set_shader_parameter("tint", tint)
	return m


func _plane(size: Vector2, pos: Vector3, m: Material, name := "") -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = pos
	mi.material_override = m
	if name != "":
		mi.name = name
	add_child(mi)
	return mi


func _build_ground() -> void:
	_plane(Vector2(90, 46), Vector3(0, G, -21), _wet("asphalt", 0.22, 0.7, Color(1.35, 1.3, 1.25)), "Asphalt")
	# Grass verges and the strip beyond the fence.
	var grass := _wet("grass", 0.5, 0.0, Color(0.7, 0.75, 0.65))
	grass.set_shader_parameter("dry_roughness", 0.95)
	_plane(Vector2(90, 40), Vector3(0, G - 0.02, -64), grass, "FarGrass")
	_plane(Vector2(30, 46), Vector3(-60, G - 0.02, -21), grass, "LeftGrass")
	_plane(Vector2(30, 46), Vector3(60, G - 0.02, -21), grass, "RightGrass")
	_plane(Vector2(120, 30), Vector3(0, G - 0.02, 17), grass, "BehindGrass")
	# Kerbs along the far edge and around the lamp island.
	var kerb := MK.mat(Color(0.7, 0.68, 0.64), "concrete", 0.85, 1.0)
	MK.box_from(self, Vector3(-45, G, -44.2), Vector3(45, G + 0.14, -43.9), kerb)
	MK.box_from(self, Vector3(-12.6, G, -18.2), Vector3(-9.8, G + 0.14, -13.0), kerb, "LampIsland")
	var island_top := _plane(Vector2(2.6, 5.0), Vector3(-11.2, G + 0.155, -15.6), _wet("grass", 0.5, 0.0, Color(0.6, 0.65, 0.55)))
	island_top.name = "LampIslandGrass"


func _line(a: Vector3, b: Vector3, width := 0.11) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = MK.tex("paint_worn")
	m.albedo_color = Color(0.85, 0.82, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.35
	var length := a.distance_to(b)
	m.uv1_scale = Vector3(length / 2.0, 1, 1)
	var pm := PlaneMesh.new()
	pm.size = Vector2(length, width)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = (a + b) * 0.5 + Vector3(0, G + 0.006, 0)
	mi.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	add_child(mi)


func _build_lines() -> void:
	# Three rows of bays: one facing the booth, two back-to-back further out.
	var x0 := -16.7
	var bay := 2.7
	for i in 13:
		var x := x0 + i * bay
		_line(Vector3(x, 0, -9.2), Vector3(x, 0, -14.2))
		_line(Vector3(x, 0, -19.5), Vector3(x, 0, -24.5))
		_line(Vector3(x, 0, -24.5), Vector3(x, 0, -29.5))
	_line(Vector3(x0, 0, -14.2), Vector3(x0 + 12 * bay, 0, -14.2))
	_line(Vector3(x0, 0, -24.5), Vector3(x0 + 12 * bay, 0, -24.5))
	# Entrance lane markings to the left of the booth.
	for i in 6:
		_line(Vector3(-4.4, 0, 3.0 - i * 2.2), Vector3(-4.4, 0, 2.0 - i * 2.2), 0.12)
	_line(Vector3(-2.8, 0, -2.35), Vector3(-6.4, 0, -2.35), 0.3)  # stop line under the barrier


func _build_lamp() -> void:
	lamp = StreetLamp.new()
	lamp.name = "StreetLamp"
	lamp.position = Vector3(-11.5, G + 0.14, -14.0)
	add_child(lamp)


func _build_cars() -> void:
	# Four vehicles, as the terminal says. Bay centres: x0 + (i + 0.5) * 2.7
	var specs := [
		# colour, kind, position, yaw (degrees; 0 = nose toward the booth)
		[Color(0.32, 0.05, 0.05), "sedan", Vector3(-7.25, G, -11.8), 2.0],    # maroon, under the lamp
		[Color(0.62, 0.57, 0.45), "sedan", Vector3(3.55, G, -11.9), -1.5],   # beige, in the booth's spill
		[Color(0.07, 0.1, 0.22), "sedan", Vector3(-9.95, G, -21.9), 181.0],  # navy, edge of the lamp light
		[Color(0.12, 0.16, 0.12), "van", Vector3(8.95, G, -27.0), 0.5],     # dark green van, far and dark
	]
	for s in specs:
		var c := CarBuilder.make(s[0], s[1])
		c.position = s[2]
		c.rotation_degrees.y = s[3]
		c.name = "Car_%d" % cars.size()
		add_child(c)
		cars.append(c)


func _build_gate_and_signs() -> void:
	gate = BarrierGate.new()
	gate.name = "BarrierGate"
	gate.position = Vector3(-2.65, G, -2.6)
	add_child(gate)

	# "LOT C" sign on a post beside the lane, angled toward the booth.
	var sign := Node3D.new()
	sign.name = "LotSign"
	sign.position = Vector3(-7.0, G, -2.8)
	sign.rotation_degrees.y = 25
	add_child(sign)
	var post := MK.mat(Color(0.45, 0.46, 0.46), "metal", 0.5, 1.0, 0.5)
	MK.cyl(sign, 0.04, 0.04, 2.1, Vector3(0, 1.05, 0), post, 6)
	MK.box(sign, Vector3(1.04, 0.54, 0.03), Vector3(0, 2.0, -0.02), post)
	MK.quad(sign, Vector2(1.0, 0.5), Vector3(0, 2.0, 0.0), MK.picture("lot_sign", 0.6))

	# Payphone by the booth (a story hook for later nights).
	payphone = Node3D.new()
	payphone.name = "Payphone"
	payphone.position = Vector3(3.9, G, -2.4)
	payphone.rotation_degrees.y = -20
	add_child(payphone)
	var steel := MK.mat(Color(0.55, 0.56, 0.56), "metal", 0.4, 1.0, 0.6)
	var blue := MK.mat(Color(0.1, 0.2, 0.45), "metal", 0.5, 1.0, 0.3)
	MK.box(payphone, Vector3(0.12, 1.2, 0.12), Vector3(0, 0.6, -0.15), steel)
	MK.box(payphone, Vector3(0.7, 0.9, 0.4), Vector3(0, 1.55, 0), steel)
	MK.box(payphone, Vector3(0.74, 0.12, 0.44), Vector3(0, 2.05, 0), blue)
	MK.box(payphone, Vector3(0.36, 0.5, 0.12), Vector3(0, 1.5, 0.2), MK.mat(Color(0.2, 0.2, 0.2), "metal", 0.4, 1.0, 0.5))
	MK.box(payphone, Vector3(0.08, 0.24, 0.07), Vector3(-0.25, 1.5, 0.24), MK.mat(Color(0.05, 0.05, 0.05), "", 0.5))

	# A litter bin by the booth.
	MK.cyl(self, 0.25, 0.22, 0.85, Vector3(2.75, G + 0.425, -1.9), MK.mat(Color(0.18, 0.22, 0.16), "metal", 0.6, 1.0, 0.3), 10)


## The 24h store on the east edge, its front facing back across the lot.
func _build_store() -> void:
	store = Store.new()
	store.name = "Store"
	store.position = Vector3(19.5, G, -10.0)
	add_child(store)


func _build_fence() -> void:
	var post := MK.mat(Color(0.45, 0.46, 0.46), "metal", 0.5, 1.0, 0.5)
	var link := StandardMaterial3D.new()
	link.albedo_texture = MK.tex("chainlink")
	link.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	link.alpha_scissor_threshold = 0.5
	link.cull_mode = BaseMaterial3D.CULL_DISABLED
	link.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	link.albedo_color = Color(0.6, 0.6, 0.6)
	link.metallic = 0.6
	link.roughness = 0.45
	var z := -44.6
	var height := 2.2
	var x := -42.0
	while x < 42.0:
		MK.cyl(self, 0.035, 0.035, height, Vector3(x, G + height * 0.5, z), post, 6)
		x += 3.0
	var m := link.duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(84.0 / 0.6, height / 0.6, 1)
	var q := MK.quad(self, Vector2(84, height), Vector3(0, G + height * 0.5, z), m, Vector3.ZERO, "ChainLink")
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	MK.cyl(self, 0.025, 0.025, 84, Vector3(0, G + height, z), post, 5, Vector3(0, 0, 90))


func _add_tree(kind: String, pos: Vector3, height: float, variant := -1) -> Node3D:
	if variant < 0:
		variant = _rng.randi_range(0, 3)
	var t := TreeBuilder.make(kind, variant, height)
	t.position = Vector3(pos.x, G + pos.y, pos.z)
	t.rotation.y = _rng.randf_range(0, TAU)
	var s := _rng.randf_range(0.9, 1.1)
	t.scale = Vector3(s, s, s)
	add_child(t)
	trees.append(t)
	return t


func _build_trees() -> void:
	# Close to the lamp, so its branches sway through the light and cast moving shadows.
	_add_tree("oak", Vector3(-10.9, 0.14, -16.9), 6.4, 1)
	_add_tree("bush", Vector3(-12.0, 0.14, -13.8), 1.0, 0)
	_add_tree("oak", Vector3(-16.5, 0, -12.0), 8.0, 3)
	# Left verge, seen through the side window and beyond the entrance lane.
	_add_tree("oak", Vector3(-15.5, 0, -1.0), 8.5, 2)
	_add_tree("pine", Vector3(-17.0, 0, -6.5), 10.0, 0)
	_add_tree("oak", Vector3(-12.0, 0, 6.0), 7.0, 3)
	_add_tree("pine", Vector3(-19.5, 0, 2.5), 11.0, 1)
	# Right verge.
	_add_tree("oak", Vector3(31.5, 0, -2.0), 8.0, 0)
	_add_tree("pine", Vector3(32.5, 0, -20.0), 9.5, 2)
	_add_tree("bush", Vector3(12.0, 0, -1.0), 1.4, 1)
	# Tree line beyond the fence.
	var x := -40.0
	while x < 40.0:
		var kind := "pine" if _rng.randf() < 0.45 else "oak"
		_add_tree(kind, Vector3(x + _rng.randf_range(-1.0, 1.0), 0, -48.0 - _rng.randf_range(0.0, 6.0)), _rng.randf_range(7.0, 12.0))
		x += _rng.randf_range(3.5, 6.0)
	for i in 12:
		_add_tree("bush", Vector3(_rng.randf_range(-40, 40), 0, -46.0 - _rng.randf_range(0, 2)), _rng.randf_range(1.0, 1.8))


func _build_distance() -> void:
	# Town silhouette: dark blocks with a scatter of lit office windows.
	var brick := MK.mat(Color(0.25, 0.24, 0.24), "brick", 0.9, 3.0)
	var win := StandardMaterial3D.new()
	win.albedo_color = Color(0, 0, 0)
	win.emission_enabled = true
	win.emission_texture = MK.tex("office_windows")
	win.emission_energy_multiplier = 0.9
	win.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var x := -90.0
	while x < 90.0:
		var w := _rng.randf_range(10.0, 22.0)
		var h := _rng.randf_range(8.0, 34.0)
		var z := _rng.randf_range(-115.0, -95.0)
		MK.box(self, Vector3(w, h, 10), Vector3(x + w * 0.5, G + h * 0.5, z), brick)
		if _rng.randf() < 0.75:
			var wm := win.duplicate() as StandardMaterial3D
			wm.uv1_scale = Vector3(w / 8.0, h / 8.0, 1)
			wm.uv1_offset = Vector3(_rng.randf(), _rng.randf(), 0)
			var q := MK.quad(self, Vector2(w - 1.0, h - 2.0), Vector3(x + w * 0.5, G + h * 0.5 + 0.5, z + 5.02), wm)
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		x += w + _rng.randf_range(1.0, 9.0)

	# A road behind the trees with a row of far-off street lights (glow only).
	var glow := load("res://shaders/glow_sprite.gdshader")
	for i in 9:
		var px := -64.0 + i * 16.0 + _rng.randf_range(-2, 2)
		var hm := ShaderMaterial.new()
		hm.shader = glow
		hm.set_shader_parameter("color", Color(1.0, 0.55, 0.2))
		hm.set_shader_parameter("intensity", 0.35)
		var q2 := MK.quad(self, Vector2(2.2, 2.2), Vector3(px, G + 7.0, -72.0), hm)
		q2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		MK.cyl(self, 0.08, 0.1, 7.0, Vector3(px, G + 3.5, -72.0), MK.mat(Color(0.1, 0.1, 0.1), "", 0.8), 5)
