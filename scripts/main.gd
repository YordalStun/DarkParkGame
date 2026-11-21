extends Node
## Entry point. Renders the 3D world at a low internal resolution (PS1 style)
## and scales it up with nearest filtering through a dither/grain post shader.
## Routes mouse input to the desk camera.
##
## Dev keys: F1 clear, F2 rain + mist, F3 storm, F4 fog, F5 lightning,
##           F6 toggle heavy rain, F7 booth light flicker, F8 barrier gate,
##           F9 weather readout, F11 fullscreen.
##
## Screenshot mode (for automated checks), after `--` on the command line:
##   --screenshot=out.png --frames=120 --pointer=0.0,0.0 --weather=storm --rain=0.9
##   --lightning   --zoom

const World := preload("res://scripts/world/world.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TARGET_HEIGHT := 360.0   ## internal render height in pixels

var container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var hud: CanvasLayer
var post: ShaderMaterial

var _shot_path := ""
var _shot_frames := 0
var _frame := 0
var _args := {}


func _ready() -> void:
	_parse_args()

	post = ShaderMaterial.new()
	post.shader = load("res://shaders/post_ps1.gdshader")
	post.set_shader_parameter("fade", 0.0)

	container = SubViewportContainer.new()
	container.name = "View"
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.material = post
	container.process_mode = Node.PROCESS_MODE_PAUSABLE  # Main runs always (for input); the world pauses
	add_child(container)

	viewport = SubViewport.new()
	viewport.name = "World3D"
	viewport.audio_listener_enable_3d = true
	viewport.positional_shadow_atlas_size = 4096
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_debanding = false
	container.add_child(viewport)

	world = World.new()
	world.name = "World"
	viewport.add_child(world)

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	world.camera.hover_changed.connect(hud.set_prompt)
	world.camera.zoom_changed.connect(func(z): hud.set_zoomed(z))

	get_tree().root.size_changed.connect(_update_scale)
	_update_scale()
	_apply_args()

	# Fade in from black.
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_method(func(v): post.set_shader_parameter("fade", v), 0.0, 1.0, 3.5 if _shot_path == "" else 0.01)


func _update_scale() -> void:
	var h := float(get_tree().root.size.y)
	container.stretch_shrink = maxi(1, int(round(h / TARGET_HEIGHT)))


func _process(_delta: float) -> void:
	var win := get_tree().root
	var size := Vector2(win.size)
	if _args.has("pointer"):
		world.camera.set_pointer(_args.pointer)
	elif size.x > 0.0:
		var m := win.get_mouse_position()
		world.camera.set_pointer(Vector2(m.x / size.x * 2.0 - 1.0, m.y / size.y * 2.0 - 1.0).clamp(Vector2(-1, -1), Vector2(1, 1)))

	if _shot_path != "":
		_frame += 1
		if _args.has("lightning") and _frame == _shot_frames - 4:
			Weather.strike_lightning(1.0, 0.1)
		if _frame == _shot_frames:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_shot_path)
			print("Saved screenshot: ", _shot_path)
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if hud.paused:
			hud.set_paused(false)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if world.camera.hovered:
				world.ambience.play_ui("mouse_click", -8.0)
			world.camera.click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			world.camera.back()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if not world.camera.back():
					hud.set_paused(not hud.paused)
			KEY_Q:
				if hud.paused:
					get_tree().quit()
			KEY_F1:
				Weather.set_profile("clear", 8.0)
			KEY_F2:
				Weather.set_profile("rain_mist", 8.0)
			KEY_F3:
				Weather.set_profile("storm", 8.0)
			KEY_F4:
				Weather.set_profile("fog", 8.0)
			KEY_F5:
				Weather.strike_lightning(1.0)
			KEY_F6:
				Weather.set_heavy(not Weather.heavy, 6.0)
			KEY_F7:
				world.booth.force_flicker(1.0)
			KEY_F8:
				if world.lot.gate.is_open:
					world.lot.gate.close()
				else:
					world.lot.gate.open()
			KEY_F9:
				hud.toggle_debug()
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else true
	if _args.has("screenshot"):
		_shot_path = _args.screenshot
		_shot_frames = int(_args.get("frames", "90"))
	if _args.has("pointer"):
		var p: PackedStringArray = str(_args.pointer).split(",")
		_args.pointer = Vector2(float(p[0]), float(p[1]))


func _apply_args() -> void:
	if _args.has("weather"):
		Weather.set_profile(_args.weather, 0.0)
	if _args.has("rain"):
		var r := float(_args.rain)
		Weather.force(r, lerpf(0.25, 0.8, r), Weather.fog, 0.0)
		Weather.wetness = 1.0
	if _args.has("cam"):
		# Debug camera: --cam=x,y,z,yaw,pitch (degrees)
		var c: PackedStringArray = str(_args.cam).split(",")
		world.camera.state = world.camera.State.MOVING
		world.camera.position = Vector3(float(c[0]), float(c[1]), float(c[2]))
		world.camera.rotation_degrees = Vector3(float(c[4]), float(c[3]), 0)
	if _args.has("nofog"):
		world.environment.volumetric_fog_enabled = false
	if _args.has("zoom"):
		await get_tree().create_timer(0.1).timeout
		world.camera.zoom_to(world.props.crt_interact)
