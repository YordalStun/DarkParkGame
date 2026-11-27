extends Node3D
## A second computer (the co-op hut's old PC): the same beige CRT as the booth's, running its own
## NightWin 95 desktop. It works on its own - its own windows, files and user - and shares only
## the web engine with the booth PC (Chromium runs once per game).
##
## It has the same members main.gd uses for the booth's PC (desk_props.gd): crt, crt_interact,
## desktop, crt_screen_mat, screen_pixel() and _on_desktop_state(), so the game can drive either one.

const CRTTerminal := preload("res://scripts/ui/crt_terminal.gd")
const DesktopOS := preload("res://scripts/desktop/os.gd")
const SCREEN_SIZE := Vector2(0.34, 0.255)
const SCREEN_CENTER := Vector3(0, 0.262, 0.217)
const CRT_CURVATURE := 0.08

var crt: Node3D
var crt_interact: Interactable
var crt_light: OmniLight3D
var terminal: SubViewport
var desktop: SubViewport
var crt_screen_mat: ShaderMaterial
var shared_web: Node   ## the booth PC's web engine (set before adding to the tree)
var _t := 0.0


func _ready() -> void:
	crt = self
	var beige := MK.mat(Color(0.8, 0.76, 0.62), "beige_plastic", 0.6, 0.4)   # older, more yellowed
	var dark := MK.mat(Color(0.12, 0.11, 0.1), "", 0.6)
	MK.cyl(self, 0.13, 0.15, 0.04, Vector3(0, 0.02, 0), beige, 12)
	MK.box(self, Vector3(0.46, 0.4, 0.08), Vector3(0, 0.25, 0.17), beige)
	MK.taper(self, Vector3(0.44, 0.32, 0.38), 0.3, 0.0, Vector3(0, 0.25, -0.03), beige, Vector3(-90, 0, 0), 0.26)
	MK.box(self, Vector3(0.38, 0.3, 0.02), Vector3(0, 0.26, 0.205), dark)
	terminal = CRTTerminal.new()
	terminal.name = "Terminal"
	add_child(terminal)
	desktop = DesktopOS.new()
	desktop.name = "Desktop"
	add_child(desktop)
	if shared_web and desktop.web != shared_web:
		desktop.web.queue_free()
		desktop.web = shared_web
	desktop.state_changed.connect(_on_desktop_state)
	crt_screen_mat = ShaderMaterial.new()
	crt_screen_mat.shader = load("res://shaders/crt_screen.gdshader")
	var screen := MK.quad(self, SCREEN_SIZE, SCREEN_CENTER, crt_screen_mat, Vector3.ZERO, "Screen")
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MK.box(self, Vector3(0.008, 0.008, 0.004), Vector3(0.12, 0.078, 0.213), MK.emissive(Color(0.3, 1.0, 0.3), 4.0))
	crt_light = MK.omni(self, Vector3(0, 0.2, 0.55), Color(0.35, 1.0, 0.5), 0.12, 1.6, false, "ScreenGlow")
	crt_light.light_specular = 0.3
	_on_desktop_state(false)
	# Keyboard in front of it.
	var kb := MK.box(self, Vector3(0.44, 0.03, 0.15), Vector3(0, 0.015, 0.42), beige)
	kb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crt_interact = Interactable.new()
	crt_interact.name = "CRTInteract"
	crt_interact.prompt = "Old PC"
	crt_interact.add_box(Vector3(0.46, 0.42, 0.45), Vector3(0, 0.25, 0.02))
	add_child(crt_interact)
	var marker := Node3D.new()
	marker.name = "ZoomMarker"
	marker.position = Vector3(0, 0.27, 0.62)
	add_child(marker)
	crt_interact.zoom_marker = marker
	crt_interact.zoom_fov = 38.0


func _process(delta: float) -> void:
	_t += delta
	crt_light.light_energy = 0.12 + 0.006 * sin(_t * 59.0) + 0.008 * sin(_t * 7.3)


func _on_desktop_state(on: bool) -> void:
	if on:
		crt_screen_mat.set_shader_parameter("screen", desktop.get_texture())
		crt_screen_mat.set_shader_parameter("texel", Vector2(1.0 / DesktopOS.W, 1.0 / DesktopOS.H))
		crt_screen_mat.set_shader_parameter("brightness", 2.4)
		crt_screen_mat.set_shader_parameter("bloom", 0.3)
		crt_screen_mat.set_shader_parameter("scan_depth", 0.14)
		crt_screen_mat.set_shader_parameter("gamma", 1.6)
		crt_light.light_color = Color(0.75, 0.88, 1.0)
	else:
		crt_screen_mat.set_shader_parameter("screen", terminal.get_texture())
		crt_screen_mat.set_shader_parameter("texel", Vector2(1.0 / CRTTerminal.W, 1.0 / CRTTerminal.H))
		crt_screen_mat.set_shader_parameter("brightness", 2.2)
		crt_screen_mat.set_shader_parameter("bloom", 1.0)
		crt_screen_mat.set_shader_parameter("scan_depth", 0.3)
		crt_screen_mat.set_shader_parameter("gamma", 1.0)
		crt_light.light_color = Color(0.35, 1.0, 0.5)


## Where the pointer lands on the desktop picture, in desktop pixels (same maths as desk_props.gd).
func screen_pixel(cam: Camera3D, pointer: Vector2) -> Vector2:
	var vp := cam.get_viewport()
	var sp := (pointer * 0.5 + Vector2(0.5, 0.5)) * Vector2(vp.size)
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	var inv := global_transform.affine_inverse()
	var lo := inv * o
	var ld := inv.basis * d
	if absf(ld.z) < 0.00001:
		return Vector2(-1e6, -1e6)
	var t := (SCREEN_CENTER.z - lo.z) / ld.z
	if t < 0.0:
		return Vector2(-1e6, -1e6)
	var h := lo + ld * t
	var uv := Vector2(h.x / SCREEN_SIZE.x + 0.5, 0.5 - (h.y - SCREEN_CENTER.y) / SCREEN_SIZE.y)
	var c := uv * 2.0 - Vector2.ONE
	c += c * Vector2(c.y * c.y, c.x * c.x) * CRT_CURVATURE
	uv = c * 0.5 + Vector2(0.5, 0.5)
	return uv * Vector2(DesktopOS.W, DesktopOS.H)
