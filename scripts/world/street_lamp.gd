extends Node3D
## Cobra-head sodium street lamp. Throws an orange cone through the mist,
## buzzes, and now and then sputters like an ageing sodium tube.
## Origin = base of the pole on the ground. The arm points along local +X.

signal sputtered

const SODIUM := Color(1.0, 0.6, 0.26)

@export var pole_height := 6.2
@export var arm_length := 2.2
@export var energy := 20.0
@export var sputter_enabled := true

var spot: SpotLight3D
var bulb_mat: StandardMaterial3D
var halo_mat: ShaderMaterial
var level := 1.0          ## 0..1 overall brightness (story can turn it off)
var _sputter := 0.0
var _sputter_timer := 0.0
var _t := 0.0
var head_position: Vector3


func _ready() -> void:
	var metal := MK.mat(Color(0.35, 0.36, 0.36), "metal", 0.5, 1.0, 0.5)
	var dark := MK.mat(Color(0.15, 0.15, 0.15), "metal", 0.6, 1.0, 0.3)
	# Concrete footing and pole.
	MK.cyl(self, 0.28, 0.32, 0.45, Vector3(0, 0.2, 0), MK.mat(Color(0.6, 0.58, 0.55), "concrete", 0.9, 1.0), 8)
	MK.cyl(self, 0.07, 0.11, pole_height, Vector3(0, pole_height * 0.5, 0), metal, 8)
	# Curved arm: three segments rising then levelling out.
	var p0 := Vector3(0, pole_height - 0.35, 0)
	var p1 := Vector3(arm_length * 0.45, pole_height + 0.05, 0)
	var p2 := Vector3(arm_length, pole_height + 0.1, 0)
	_segment(p0, p1, 0.05, metal)
	_segment(p1, p2, 0.045, metal)
	# Cobra head.
	var head := Node3D.new()
	head.position = p2 + Vector3(0.3, -0.02, 0)
	head.rotation_degrees = Vector3(0, 0, -4)
	add_child(head)
	MK.taper(head, Vector3(0.75, 0.16, 0.36), 0.55, -0.05, Vector3(0, 0.05, 0), metal, Vector3.ZERO, 0.28)
	MK.box(head, Vector3(0.6, 0.03, 0.3), Vector3(0.02, -0.04, 0), dark)
	# Glowing refractor bowl.
	bulb_mat = MK.emissive(SODIUM, 9.0, Color(0.4, 0.3, 0.2))
	MK.box(head, Vector3(0.48, 0.07, 0.24), Vector3(0.02, -0.08, 0), bulb_mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head_position = head.position + Vector3(0.02, -0.12, 0)

	# Halo in the mist.
	halo_mat = ShaderMaterial.new()
	halo_mat.shader = load("res://shaders/glow_sprite.gdshader")
	halo_mat.set_shader_parameter("color", Color(1.0, 0.55, 0.22))
	halo_mat.set_shader_parameter("intensity", 0.5)
	var halo := MK.quad(self, Vector2(3.2, 3.2), head_position, halo_mat, Vector3.ZERO, "Halo")
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	spot = SpotLight3D.new()
	spot.name = "SodiumLight"
	spot.position = head_position + Vector3(0, 0.02, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = SODIUM
	spot.light_energy = energy
	spot.spot_range = 16.0
	spot.spot_angle = 64.0
	spot.spot_angle_attenuation = 0.6
	spot.spot_attenuation = 0.9
	spot.shadow_enabled = true
	spot.shadow_bias = 0.05
	spot.shadow_normal_bias = 1.0
	spot.shadow_blur = 1.5
	spot.light_volumetric_fog_energy = 1.0
	spot.light_size = 0.2
	add_child(spot)

	_sputter_timer = randf_range(30.0, 80.0)


func _segment(a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var mi := MK.cyl(self, r, r, a.distance_to(b), (a + b) * 0.5, m, 6)
	var dir := (b - a).normalized()
	var up := Vector3.FORWARD if absf(dir.y) > 0.9 else Vector3.UP
	# Cylinders run along local Y: aim -Z at the target, then tip Y onto that axis.
	mi.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5)


func _process(delta: float) -> void:
	_t += delta
	var k := 1.0
	if sputter_enabled:
		_sputter_timer -= delta
		if _sputter_timer <= 0.0 and _sputter <= 0.0:
			_sputter = randf_range(1.2, 3.0)
			_sputter_timer = randf_range(45.0, 120.0)
			sputtered.emit()
		if _sputter > 0.0:
			_sputter -= delta
			# Sodium lamps dim and surge rather than snap off.
			# Smooth, slow-ish surges (no single-frame drops, which read as glitches).
			k = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 5.0 + 1.7 * sin(_t * 2.3)))
	# Tiny constant shimmer.
	k *= 1.0 + 0.012 * sin(_t * 31.0) * sin(_t * 3.1)
	k *= level
	spot.light_energy = energy * k
	bulb_mat.emission_energy_multiplier = 9.0 * k
	halo_mat.set_shader_parameter("flicker", k)
