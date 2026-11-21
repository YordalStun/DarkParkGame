extends Node3D
## Everything on the desk: CRT terminal, keyboard, mouse, phone, radio,
## logbook, coffee mug (with steam) and flashlight.

const CRTTerminal := preload("res://scripts/ui/crt_terminal.gd")
const RadioScript := preload("res://scripts/world/radio.gd")
const DESK_Y := 0.76

var crt: Node3D
var crt_interact: Interactable
var crt_light: OmniLight3D
var terminal: SubViewport
var crt_screen_mat: ShaderMaterial
var phone_interact: Interactable
var radio_interact: Interactable
var radio_player: Node3D  ## radio.gd: music on/off, playlist
var logbook_interact: Interactable
var _t := 0.0


func _ready() -> void:
	_build_crt()
	_build_keyboard_mouse()
	_build_phone()
	_build_radio()
	_build_logbook()
	_build_mug()
	_build_flashlight()


func _build_crt() -> void:
	crt = Node3D.new()
	crt.name = "CRT"
	crt.position = Vector3(0.72, DESK_Y, -0.76)
	crt.rotation_degrees = Vector3(0, -12, 0)  # angled slightly toward the player
	add_child(crt)

	var beige := MK.mat(Color(0.86, 0.81, 0.68), "beige_plastic", 0.55, 0.4)
	var dark := MK.mat(Color(0.12, 0.11, 0.1), "", 0.6)
	# Tilt/swivel base.
	MK.cyl(crt, 0.13, 0.15, 0.04, Vector3(0, 0.02, 0), beige, 12)
	# Body: deep tapered back.
	MK.box(crt, Vector3(0.46, 0.4, 0.08), Vector3(0, 0.25, 0.17), beige)                        # front bezel
	MK.taper(crt, Vector3(0.44, 0.32, 0.38), 0.3, 0.0, Vector3(0, 0.25, -0.03), beige, Vector3(-90, 0, 0), 0.26)  # tube housing
	# Vent slots on top.
	for i in 6:
		MK.box(crt, Vector3(0.22, 0.004, 0.01), Vector3(0, 0.452, 0.08 - i * 0.03), dark)
	# Screen recess and tube glass.
	MK.box(crt, Vector3(0.38, 0.3, 0.02), Vector3(0, 0.26, 0.205), dark)
	terminal = CRTTerminal.new()
	terminal.name = "Terminal"
	add_child(terminal)
	crt_screen_mat = ShaderMaterial.new()
	crt_screen_mat.shader = load("res://shaders/crt_screen.gdshader")
	crt_screen_mat.set_shader_parameter("screen", terminal.get_texture())
	var screen := MK.quad(crt, Vector2(0.34, 0.255), Vector3(0, 0.262, 0.217), crt_screen_mat, Vector3.ZERO, "Screen")
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Badge, power button and LED.
	MK.box(crt, Vector3(0.08, 0.012, 0.004), Vector3(-0.14, 0.078, 0.212), MK.mat(Color(0.45, 0.42, 0.36), "", 0.4))
	MK.box(crt, Vector3(0.03, 0.02, 0.01), Vector3(0.16, 0.078, 0.212), MK.mat(Color(0.7, 0.66, 0.55), "", 0.5))
	MK.box(crt, Vector3(0.008, 0.008, 0.004), Vector3(0.12, 0.078, 0.213), MK.emissive(Color(0.3, 1.0, 0.3), 4.0))

	# Green glow the screen throws on the keyboard and desk.
	crt_light = MK.omni(crt, Vector3(0, 0.2, 0.55), Color(0.35, 1.0, 0.5), 0.12, 1.6, false, "ScreenGlow")
	crt_light.light_specular = 0.3
	crt_light.light_volumetric_fog_energy = 0.0

	crt_interact = Interactable.new()
	crt_interact.name = "CRTInteract"
	crt_interact.prompt = "Terminal"
	crt_interact.add_box(Vector3(0.46, 0.42, 0.45), Vector3(0, 0.25, 0.02))
	crt.add_child(crt_interact)
	var marker := Node3D.new()
	marker.name = "ZoomMarker"
	marker.position = Vector3(0, 0.27, 0.62)
	crt.add_child(marker)
	crt_interact.zoom_marker = marker
	crt_interact.zoom_fov = 38.0


func _build_keyboard_mouse() -> void:
	var beige := MK.mat(Color(0.82, 0.78, 0.66), "beige_plastic", 0.6, 0.4)
	var kb := Node3D.new()
	kb.name = "Keyboard"
	kb.position = Vector3(0.62, DESK_Y, -0.48)
	kb.rotation_degrees = Vector3(0, -6, 0)
	add_child(kb)
	MK.taper(kb, Vector3(0.46, 0.035, 0.17), 0.46, 0.0, Vector3(0, 0.018, 0), beige, Vector3(0, 0, 0), 0.15)
	var keys := MK.quad(kb, Vector2(0.44, 0.15), Vector3(0, 0.0365, 0.0), MK.picture("keyboard", 0.6), Vector3(-90 + 4, 0, 0))
	keys.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Coiled cable to the monitor.
	MK.box(kb, Vector3(0.008, 0.008, 0.2), Vector3(0.05, 0.004, -0.18), MK.mat(Color(0.2, 0.19, 0.17), "", 0.6))

	# Mouse pad and mouse.
	MK.box(self, Vector3(0.22, 0.004, 0.19), Vector3(1.04, DESK_Y + 0.002, -0.46), MK.mat(Color(0.1, 0.14, 0.3), "", 0.9))
	var mouse := Node3D.new()
	mouse.position = Vector3(1.03, DESK_Y + 0.004, -0.45)
	mouse.rotation_degrees = Vector3(0, 12, 0)
	add_child(mouse)
	MK.taper(mouse, Vector3(0.06, 0.03, 0.1), 0.045, 0.0, Vector3(0, 0.015, 0), beige, Vector3.ZERO, 0.08)
	MK.box(mouse, Vector3(0.002, 0.002, 0.035), Vector3(0, 0.031, -0.025), MK.mat(Color(0.3, 0.3, 0.28), "", 0.6))
	MK.box(mouse, Vector3(0.006, 0.006, 0.25), Vector3(0, 0.004, -0.17), MK.mat(Color(0.2, 0.19, 0.17), "", 0.6))


func _build_phone() -> void:
	var phone := Node3D.new()
	phone.name = "Phone"
	phone.position = Vector3(-1.35, DESK_Y, -0.72)
	phone.rotation_degrees = Vector3(0, 18, 0)
	add_child(phone)
	var beige := MK.mat(Color(0.8, 0.74, 0.6), "beige_plastic", 0.45, 0.3)
	var dark := MK.mat(Color(0.15, 0.14, 0.12), "", 0.5)
	MK.taper(phone, Vector3(0.21, 0.07, 0.23), 0.21, 0.0, Vector3(0, 0.035, 0), beige, Vector3.ZERO, 0.15)
	# Keypad 4x3.
	for r in 4:
		for c in 3:
			MK.box(phone, Vector3(0.022, 0.008, 0.016), Vector3(-0.03 + c * 0.03, 0.07 + r * 0.004, 0.065 - r * 0.022), MK.mat(Color(0.92, 0.9, 0.84), "", 0.4))
	# Handset resting in the cradle.
	var hs := Node3D.new()
	hs.name = "Handset"
	hs.position = Vector3(0.0, 0.085, -0.055)
	phone.add_child(hs)
	MK.box(hs, Vector3(0.21, 0.03, 0.05), Vector3.ZERO, beige)
	MK.box(hs, Vector3(0.055, 0.045, 0.06), Vector3(-0.085, -0.008, 0), beige)
	MK.box(hs, Vector3(0.055, 0.045, 0.06), Vector3(0.085, -0.008, 0), beige)
	MK.box(phone, Vector3(0.006, 0.006, 0.22), Vector3(-0.115, 0.01, 0.1), dark)

	phone_interact = Interactable.new()
	phone_interact.prompt = "Telephone"
	phone_interact.add_box(Vector3(0.24, 0.12, 0.25), Vector3(0, 0.06, 0))
	phone.add_child(phone_interact)


func _build_radio() -> void:
	var radio := Node3D.new()
	radio.name = "Radio"
	radio.position = Vector3(-1.0, DESK_Y, -0.93)
	radio.rotation_degrees = Vector3(0, 10, 0)
	add_child(radio)
	var black := MK.mat(Color(0.08, 0.08, 0.08), "metal", 0.5, 0.3)
	MK.box(radio, Vector3(0.24, 0.13, 0.07), Vector3(0, 0.065, 0), black)
	MK.box(radio, Vector3(0.1, 0.09, 0.004), Vector3(-0.055, 0.065, 0.036), MK.mat(Color(0.25, 0.25, 0.24), "metal", 0.6, 0.05))
	var dial := MK.mat(Color(0.75, 0.6, 0.3), "", 0.4).duplicate() as StandardMaterial3D
	MK.box(radio, Vector3(0.08, 0.025, 0.004), Vector3(0.06, 0.09, 0.036), dial)  # tuning dial window
	MK.cyl(radio, 0.012, 0.012, 0.012, Vector3(0.06, 0.045, 0.04), MK.mat(Color(0.7, 0.7, 0.68), "", 0.3, 1.0, 0.8), 8, Vector3(90, 0, 0))
	MK.cyl(radio, 0.002, 0.003, 0.45, Vector3(0.1, 0.33, -0.02), MK.mat(Color(0.75, 0.75, 0.72), "", 0.2, 1.0, 1.0), 4, Vector3(0, 0, -14))
	radio_interact = Interactable.new()
	radio_interact.prompt = "Radio"
	radio_interact.add_box(Vector3(0.26, 0.15, 0.09), Vector3(0, 0.07, 0))
	radio.add_child(radio_interact)
	radio_player = RadioScript.new()
	radio_player.name = "RadioPlayer"
	radio_player.dial_mat = dial
	radio_player.interact = radio_interact
	radio.add_child(radio_player)


func _build_logbook() -> void:
	var lb := Node3D.new()
	lb.name = "Logbook"
	lb.position = Vector3(-0.62, DESK_Y, -0.58)
	lb.rotation_degrees = Vector3(0, 9, 0)
	add_child(lb)
	MK.box(lb, Vector3(0.24, 0.006, 0.33), Vector3(0, 0.003, 0), MK.mat(Color(0.45, 0.32, 0.2), "wood_desk", 0.7, 0.3))
	var paper := MK.quad(lb, Vector2(0.21, 0.28), Vector3(0, 0.0065, 0.015), MK.picture("paper_log", 0.9), Vector3(-90, 0, 0))
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MK.box(lb, Vector3(0.1, 0.014, 0.03), Vector3(0, 0.01, -0.15), MK.mat(Color(0.7, 0.7, 0.68), "", 0.25, 1.0, 1.0))
	# Pen.
	MK.cyl(self, 0.004, 0.004, 0.14, Vector3(-0.44, DESK_Y + 0.005, -0.55), MK.mat(Color(0.1, 0.15, 0.5), "", 0.3), 6, Vector3(90, 0, 70))
	logbook_interact = Interactable.new()
	logbook_interact.prompt = "Logbook"
	logbook_interact.add_box(Vector3(0.25, 0.03, 0.34), Vector3(0, 0.01, 0))
	lb.add_child(logbook_interact)


func _build_mug() -> void:
	var mug := Node3D.new()
	mug.name = "Mug"
	mug.position = Vector3(-0.18, DESK_Y, -0.52)
	add_child(mug)
	var cer := MK.mat(Color(0.75, 0.2, 0.15), "", 0.35)
	MK.cyl(mug, 0.04, 0.038, 0.095, Vector3(0, 0.0475, 0), cer, 10)
	MK.cyl(mug, 0.035, 0.035, 0.002, Vector3(0, 0.085, 0), MK.mat(Color(0.08, 0.04, 0.02), "", 0.05), 10)
	MK.box(mug, Vector3(0.012, 0.06, 0.03), Vector3(0.05, 0.05, 0), cer)
	MK.box(mug, Vector3(0.02, 0.012, 0.03), Vector3(0.042, 0.075, 0), cer)
	MK.box(mug, Vector3(0.02, 0.012, 0.03), Vector3(0.042, 0.025, 0), cer)

	var steam := GPUParticles3D.new()
	steam.name = "Steam"
	steam.position = Vector3(0, 0.1, 0)
	steam.amount = 10
	steam.lifetime = 3.0
	steam.preprocess = 3.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.02
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.06
	pm.gravity = Vector3(0, 0.01, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 2.0
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.05
	pm.scale_min = 0.05
	pm.scale_max = 0.08
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.25, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	steam.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/steam.gdshader")
	q.material = sm
	steam.draw_pass_1 = q
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	steam.visibility_aabb = AABB(Vector3(-0.3, -0.1, -0.3), Vector3(0.6, 0.8, 0.6))
	mug.add_child(steam)


func _build_flashlight() -> void:
	var fl := Node3D.new()
	fl.name = "Flashlight"
	fl.position = Vector3(0.18, DESK_Y + 0.022, -0.9)
	fl.rotation_degrees = Vector3(0, 70, 0)
	add_child(fl)
	var black := MK.mat(Color(0.06, 0.06, 0.06), "metal", 0.4, 0.3, 0.4)
	MK.cyl(fl, 0.018, 0.018, 0.2, Vector3.ZERO, black, 8, Vector3(0, 0, 90))
	MK.cyl(fl, 0.028, 0.02, 0.05, Vector3(0.12, 0.006, 0), black, 8, Vector3(0, 0, 90))
	MK.cyl(fl, 0.024, 0.024, 0.003, Vector3(0.146, 0.006, 0), MK.mat(Color(0.8, 0.8, 0.7), "", 0.05, 1.0, 0.5), 8, Vector3(0, 0, 90))


func _process(delta: float) -> void:
	_t += delta
	# Screen glow breathes very slightly with the CRT's flicker.
	crt_light.light_energy = 0.12 + 0.006 * sin(_t * 59.0) + 0.008 * sin(_t * 7.3)
