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
##   --desktop[=browser,paint]   lean in, boot the desktop and open those programs
##   --url=http://...            address for the browser (with --desktop=browser)

const World := preload("res://scripts/world/world.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const LoadingScreen := preload("res://scripts/ui/loading_screen.gd")
const Inspect := preload("res://scripts/ui/inspect.gd")
const Shift := preload("res://scripts/story/shift.gd")
const TARGET_HEIGHT := 360.0   ## internal render height in pixels

var container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var hud: CanvasLayer
var inspect: CanvasLayer
var story: Node
var post: ShaderMaterial

var _shot_path := ""
var _shot_frames := 0
var _frame := 0
var _args := {}
var _loaded := false
var _loading: CanvasLayer
var _hires := false          ## render at higher resolution while using the desktop so its text is legible
var _desk_drag := false
var _desk_last := Vector2.ZERO


func _ready() -> void:
	_parse_args()

	# Title screen (save slots) first, unless going straight on to the next night or testing.
	if not SaveGame.skip_title and _shot_path == "" and not _args.has("notitle"):
		var title = load("res://scripts/ui/title_screen.gd").new()
		add_child(title)
		await title.chosen
	SaveGame.skip_title = false

	# Show the loading screen before anything heavy happens.
	_loading = LoadingScreen.new()
	add_child(_loading)
	await get_tree().process_frame
	await get_tree().process_frame

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

	get_tree().root.size_changed.connect(_update_scale)
	_update_scale()

	# Back-of-booth dressing: lived-in on night one, emptier and stranger from night two.
	SaveGame.ensure_slot()
	load("res://scripts/world/booth.gd").decor = "a" if SaveGame.night() <= 1 else "b"
	if _args.has("booth"):   # testing: --booth=a | b
		load("res://scripts/world/booth.gd").decor = str(_args.booth)
	world = World.new()
	world.name = "World"
	world.progress.connect(_loading.set_progress)
	viewport.add_child(world)
	await world.build()

	hud = Hud.new()
	hud.name = "HUD"
	add_child(hud)
	inspect = Inspect.new()
	inspect.name = "Inspect"
	add_child(inspect)
	inspect.opened.connect(func():
		world.camera.blocked = true
		hud._hint.visible = false
		hud.set_look_back(false))
	inspect.closed.connect(func(_c):
		world.camera.blocked = false
		hud._hint.visible = true
		hud.set_look_back(world.camera.focus == world.booth.side_view))
	hud.overlay_changed.connect(func(o): world.camera.blocked = o)
	story = Shift.new()
	story.name = "Story"
	add_child(story)
	world.story = story
	story.setup(world, hud, inspect)
	world.camera.hover_changed.connect(hud.set_prompt)
	world.camera.focus_changed.connect(func(f): hud.set_zoomed(f != null))
	world.camera.walk_blockers = world.booth.walk_blockers
	world.camera.footstep.connect(func(): world.ambience.play_at("footstep", world.camera.global_position - Vector3(0, 1.5, 0), -10.0 + randf_range(-2, 1), "Interior", 1.0))
	var desk = world.props.desktop
	desk.world = world
	desk.state_changed.connect(func(on): hud.set_hint("Esc to sit back" if on else "Right click to sit back", on))
	desk.sound.connect(func(n, db): world.ambience.play_ui(n, db))
	world.camera.focus_changed.connect(func(f): desk.set_away(f != world.props.crt_interact))
	world.camera.focus_changed.connect(func(f):
		hud.set_look_left(f == null)
		hud.set_look_back(f == world.booth.side_view))
	world.camera.zoom_changed.connect(func(z): if z: hud.set_look_left(false))
	hud.look_back_btn.pressed.connect(func():
		if world.camera.state == world.camera.State.ZOOMED:
			hud.set_look_back(false)
			world.camera.unzoom())
	hud.look_left_btn.pressed.connect(func():
		if world.camera.state == world.camera.State.SEATED:
			world.camera.zoom_to(world.booth.side_view))
	hud.set_look_left(true)

	_apply_args()
	_apply_graphics()
	Settings.graphics_changed.connect(_apply_graphics)
	hud.test_action.connect(_on_test)
	await _warm_up()

	# Loading screen away, then the scene and its sound fade in from black.
	var quick := _shot_path != ""
	await _loading.finish(0.01 if quick else 0.6)
	_loaded = true
	world.ambience.fade_in(0.01 if quick else 4.0)
	if _args.has("test"):   # testing: --test=id,id (testing-menu buttons, one a second)
		for id in str(_args.test).split(","):
			await get_tree().create_timer(1.0).timeout
			print("TEST ", id)
			_on_test(id)
	if _args.has("leave_booth"):
		story.debug_leave()
	elif _args.has("shiftend"):
		story.debug_shift_end()
	elif _args.has("report"):
		story.debug_report()
	elif not quick or _args.has("story"):
		story.start()
	if _args.has("pause"):
		hud.set_paused(true)
	if _args.has("cctv"):
		_cctv_grid()
	var tw := create_tween()
	tw.tween_interval(0.0 if quick else 0.3)
	tw.tween_method(func(v): post.set_shader_parameter("fade", v), 0.0, 1.0, 0.01 if quick else 3.5)


## Render the scene (hidden behind the loading screen) until frame times settle,
## so shader compilation happens here instead of stuttering after the fade-in.
func _warm_up() -> void:
	var max_frames := 6 if _shot_path != "" else 600
	var calm := 0
	var start := Time.get_ticks_msec()
	for i in max_frames:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		calm = calm + 1 if dt < 0.05 else 0
		var elapsed := (Time.get_ticks_msec() - start) / 1000.0
		_loading.set_progress(0.62 + 0.36 * minf(elapsed / 4.0, 1.0), "")
		if i > 20 and calm >= 15:
			break
		if elapsed > 15.0:
			break


func _update_scale() -> void:
	var h := float(get_tree().root.size.y)
	var target: float = Settings.PIXEL_HEIGHTS[Settings.graphics.pixels]
	if target <= 0.0:
		target = h   # full resolution
	# At the desktop the picture needs more pixels than the PS1 look allows, or its text is mush.
	container.stretch_shrink = maxi(1, int(round(h / (maxf(640.0, target) if _hires else target))))


# ------------------------------------------------------------------ graphics options
## Applies the GRAPHICS tab (all of it on start-up, or just the option that changed).
func _apply_graphics(key := "") -> void:
	var g: Dictionary = Settings.graphics
	if key in ["", "pixels"]:
		_update_scale()
	if key in ["", "fullscreen"] and _shot_path == "":
		var w := get_window()
		if g.fullscreen:
			w.mode = Window.MODE_FULLSCREEN
		elif w.mode == Window.MODE_FULLSCREEN:
			w.mode = Window.MODE_MAXIMIZED
	if key in ["", "vsync"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g.vsync else DisplayServer.VSYNC_DISABLED)
	if key in ["", "fps_cap"]:
		Engine.max_fps = Settings.FPS_CAPS[g.fps_cap]
	var env: Environment = world.environment
	if key in ["", "mist"] and not _args.has("nofog"):
		env.volumetric_fog_enabled = g.mist
	if key in ["", "reflections"]:
		env.ssr_enabled = g.reflections
	if key in ["", "ao"]:
		env.ssao_enabled = g.ao
	if key in ["", "glow"]:
		env.glow_enabled = g.glow
	if key in ["", "retro_colour"]:
		post.set_shader_parameter("color_levels", 32.0 if g.retro_colour else 256.0)
		post.set_shader_parameter("dither_strength", 1.0 if g.retro_colour else 0.0)
	if key in ["", "grain"]:
		post.set_shader_parameter("grain", 0.035 if g.grain else 0.0)
	if key in ["", "show_fps"]:
		hud.show_fps(g.show_fps)
	# Shadows only change at start-up: switching shadow maps mid-game can upset some drivers.
	if key == "" and not g.shadows:
		for l in world.find_children("*", "Light3D", true, false):
			(l as Light3D).shadow_enabled = false


# ------------------------------------------------------------------ testing menu
func _on_test(id: String) -> void:
	var resume := true
	match id:
		"time_1": NightClock.set_time(1, 0)
		"time_455": NightClock.set_time(4, 55)
		"time_658": NightClock.set_time(6, 58)
		"next_car": story.skip_wait()
		"car_now":
			if story.current == null:
				story.debug_visitor(randi() % (story.arrivals.size() - 1))
			else:
				hud.notify("There's already a car at the window.", 3.0)
		"leaver": story.debug_send_leaver()
		"clockout":
			NightClock.set_time(6, 59)
			story.debug_shift_end_now()
		"leave": story.debug_leave()
		"report": story.debug_report()
		"w_clear": Weather.set_profile("clear", 4.0)
		"w_rain": Weather.set_profile("rain_mist", 4.0)
		"w_storm": Weather.set_profile("storm", 4.0)
		"w_fog": Weather.set_profile("fog", 4.0)
		"w_flash": Weather.strike_lightning(1.0)
		"booth_a", "booth_b":
			story._save_progress(story.money, 1 if id == "booth_a" else 2)
			story._restart()
		"flicker": world.booth.force_flicker()
		"gate":
			if world.lot.gate.is_open:
				world.lot.gate.close()
			else:
				world.lot.gate.open()
		"coins":
			story.money += 5
			hud.set_money(story.money)
			resume = false
		"reset":
			story._save_progress(story.START_MONEY, 1)
			story._restart()
		"readout":
			hud.toggle_debug()
	if resume and hud.paused:
		hud.set_paused(false)



func _process(_delta: float) -> void:
	if not _loaded:
		return
	var win := get_tree().root
	var size := Vector2(win.size)
	if world.camera.state == world.camera.State.WALK:
		world.camera.set_pointer(Vector2.ZERO)   # standing: you use what's in the middle of the view
	elif _args.has("pointer"):
		world.camera.set_pointer(_args.pointer)
	elif size.x > 0.0:
		var m := win.get_mouse_position()
		world.camera.set_pointer(Vector2(m.x / size.x * 2.0 - 1.0, m.y / size.y * 2.0 - 1.0).clamp(Vector2(-1, -1), Vector2(1, 1)))

	_update_desktop_mode(size)

	if _shot_path != "":
		_frame += 1
		if _args.has("lightning") and _frame == _shot_frames - 4:
			Weather.strike_lightning(1.0, 0.1)
		if _frame == _shot_frames:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_shot_path)
			print("Saved screenshot: ", _shot_path)
			get_tree().quit()


## Higher render resolution and a hidden system cursor while the player is using the desktop.
func _update_desktop_mode(win_size: Vector2) -> void:
	var desk = world.props.desktop
	var want: bool = _at_crt() and desk.is_on()
	if want != _hires:
		_hires = want
		_update_scale()
	var over := false
	if want and not hud.paused:
		var px := _screen_px(win_size)
		over = _on_screen(px) or _desk_drag
	# Keep the cursor inside the window while using the desktop; released on alt-tab.
	var focused := DisplayServer.window_is_focused()
	var confine: bool = want and not hud.paused and focused
	var mode := Input.MOUSE_MODE_VISIBLE
	var walking: bool = world.camera.state == world.camera.State.WALK
	if walking and not hud.paused and focused and _shot_path == "":
		mode = Input.MOUSE_MODE_CAPTURED
	elif confine:
		mode = Input.MOUSE_MODE_CONFINED_HIDDEN if over else Input.MOUSE_MODE_CONFINED
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
	desk.set_pointer_visible(over)


## Leaned in to the CRT (not some other close-up view like the side window).
func _at_crt() -> bool:
	return world.camera.state == world.camera.State.ZOOMED and world.camera.focus == world.props.crt_interact


func _pointer_ndc(pos: Vector2, win_size: Vector2) -> Vector2:
	return Vector2(pos.x / win_size.x * 2.0 - 1.0, pos.y / win_size.y * 2.0 - 1.0)


func _screen_px(win_size: Vector2, pos := Vector2(-1, -1)) -> Vector2:
	var m := pos if pos.x >= 0.0 else get_tree().root.get_mouse_position()
	return world.props.screen_pixel(world.camera, _pointer_ndc(m, win_size))


func _on_screen(px: Vector2) -> bool:
	return px.x >= 0.0 and px.y >= 0.0 and px.x < 640.0 and px.y < 480.0


## Sends mouse and keyboard to the desktop while the player is leaned in to the screen.
## Returns true if the event was used.
func _desktop_input(event: InputEvent) -> bool:
	var desk = world.props.desktop
	if not _at_crt():
		_desk_drag = false
		return false
	var win_size := Vector2(get_tree().root.size)
	if event is InputEventMouse:
		var px := _screen_px(win_size, event.position)
		var on := _on_screen(px)
		if not desk.is_on():
			# The green terminal: click the glass to start the computer.
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and on:
				desk.power_on()
				return true
			return false
		var left_down: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if event is InputEventMouseButton:
			if event.pressed and not on:
				return event.button_index != MOUSE_BUTTON_RIGHT   # right click off the glass = sit back
			if not event.pressed and not on and not _desk_drag:
				return false
			if left_down:
				_desk_drag = true
			elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_desk_drag = false
		elif not on and not _desk_drag:
			return false
		px = px.clamp(Vector2.ZERO, Vector2(639, 479))
		var e: InputEventMouse = event.duplicate()
		e.position = px
		e.global_position = px
		if e is InputEventMouseMotion:
			e.relative = px - _desk_last
		_desk_last = px
		desk.push_input(e, true)
		return true
	if event is InputEventKey and desk.is_on():
		if event.pressed and event.keycode == KEY_ESCAPE:
			return desk.escape()   # closes a menu/dialog, otherwise falls through to "sit back"
		if event.keycode >= KEY_F1 and event.keycode <= KEY_F12:
			return false
		desk.push_input(event, true)
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _loaded:
		return
	if not hud.paused and _desktop_input(event):
		return
	if event is InputEventMouseMotion and world.camera.state == world.camera.State.WALK and not hud.paused:
		world.camera.look(event.relative)
		return
	if event is InputEventMouseButton and event.pressed:
		if hud.paused:
			hud.set_paused(false)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if (hud.waiting_click or not world.camera.hovered) and hud.skip_line():
				return
			if world.camera.hovered:
				world.ambience.play_ui("mouse_click", -8.0)
			world.camera.click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			world.camera.back()
	elif event is InputEventKey and event.pressed and not event.echo:
		if hud.waiting_click and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			hud.skip_line()
			return
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
				world.booth.force_flicker()
			KEY_F8:
				if world.lot.gate.is_open:
					world.lot.gate.close()
				else:
					world.lot.gate.open()
			KEY_F9:
				hud.toggle_debug()
			KEY_F10, KEY_P:
				hud.set_paused(not hud.paused)
			KEY_F11:
				Settings.set_graphics("fullscreen", not Settings.graphics.fullscreen)
			KEY_N:
				story.open_notes()
			KEY_E:
				# Standing: E uses what you're looking at (the door needs it to leave).
				if world.camera.state == world.camera.State.WALK and world.camera.hovered and not world.camera.blocked:
					var it = world.camera.hovered
					it.key_used.emit()
					if it == world.booth.light_switch:
						it.activate()
			KEY_F12:
				# Testing menu.
				hud.set_paused(true)
				hud.show_tab("TESTING")


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


## Testing (--cctv): shows the four camera feeds, with the CCTV look, in a 2x2 grid over everything.
func _cctv_grid() -> void:
	world.cctv.acquire()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var shader := load("res://shaders/cctv.gdshader")
	for i in 4:
		world.cctv.cams[i].viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var tr := TextureRect.new()
		tr.texture = world.cctv.texture(i)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.size = Vector2(478, 358)
		tr.position = Vector2(160 + (i % 2) * 480, 1 + (i / 2) * 360)
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("seed", float(i))
		tr.material = m
		layer.add_child(tr)


func _apply_args() -> void:
	if _args.has("time"):   # e.g. --time=6.25 (hours) for checking the sunrise
		var th := float(_args.time)
		NightClock.set_time(int(th), int((th - int(th)) * 60.0))
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
	# Health line in the log every 15 s (or --perflog=N). The log is user://logs/godot.log;
	# on Windows: %APPDATA%\Godot\app_userdata\Dark Park\logs\godot.log
	_perf_log()
	if _args.has("paused"):
		hud.set_paused(true)
		if _args.has("tab"):
			hud.show_tab(str(_args.tab))
	if _args.has("nofog"):
		world.environment.volumetric_fog_enabled = false
	if _args.has("audiotest") or _args.has("novisuals"):
		_strip_visuals()  # audio-only run: make software rendering fast
	if _args.has("audiotest"):
		_audio_stress_test()
	if _args.has("answer"):   # testing: pick up the phone as soon as it rings
		var t := Timer.new()
		t.wait_time = 0.5
		t.autostart = true
		t.timeout.connect(story._on_phone)
		add_child(t)
	if _args.has("leave"):   # testing: send one evening car home now
		get_tree().create_timer(0.5).timeout.connect(func(): story._leavers[int(_args.leave)].go())
	if _args.has("notes"):   # testing: --notes="..." [--opennotes]
		story.notes = str(_args.notes).replace("|", "\n")
		if _args.has("opennotes"):
			get_tree().create_timer(1.0).timeout.connect(story.open_notes)
	if _args.has("tiptest"):
		hud.tip("test", "You can write things down. Press N (or click the notepad on the desk) and type.")
	if _args.has("car"):
		story.debug_visitor(int(_args.car))
		if _args.has("idcard"):
			get_tree().create_timer(1.5).timeout.connect(func(): story._on_card(story.current, story.arrivals[int(_args.car)], story.results[-1]))
		if _args.has("vlog"):
			get_tree().create_timer(1.5).timeout.connect(func(): story._open_log())
		if _args.has("plate"):
			get_tree().create_timer(1.5).timeout.connect(func(): inspect.show_plate(story.arrivals[int(_args.car)].reg))
		if _args.has("drivein"):
			get_tree().create_timer(1.0).timeout.connect(func(): story._on_raise())
	if _args.has("side") or _args.has("sideopen"):
		await get_tree().create_timer(0.1).timeout
		world.camera.zoom_to(world.booth.side_view)
		if _args.has("sideopen"):
			world.booth.set_side_window(true)
	if _args.has("zoom") or (_args.has("desktop") and not _args.has("seated")):
		await get_tree().create_timer(0.1).timeout
		world.camera.zoom_to(world.props.crt_interact)
	if _args.has("desktop"):
		_open_desktop_for_test()


## --desktop: boot the desktop straight away and open the listed programs (for screenshots).
func _open_desktop_for_test() -> void:
	var desk = world.props.desktop
	desk.net_connected = _args.has("online")
	desk.power_on(true)
	await get_tree().create_timer(0.3).timeout
	if _args.has("menu"):
		desk.toggle_start()
	if _args.has("volpopup"):
		desk._volume_popup()
	for id in str(_args.desktop).split(",", false):
		if id == "1" or id == "true":
			continue
		var a := {}
		if _args.has("url"):
			a["url"] = _args.url
		desk.open_app(id, a)
	# --dumpcams=dir : save each CCTV camera's raw picture as PNG
	if _args.has("dumpcams"):
		await get_tree().create_timer(2.0).timeout
		for i in world.cctv.cams.size():
			world.cctv.texture(i).get_image().save_png("%s/cam_%d.png" % [_args.dumpcams, i + 1])
		print("Saved CCTV frames to ", _args.dumpcams)
	# --sitback : sit back from the desk again after opening the programs (tests monitor mode)
	if _args.has("sitback"):
		await get_tree().create_timer(1.5).timeout
		world.camera.unzoom()
	# --simclick=x,y;x,y : inject real left clicks at window pixels (tests the screen mapping)
	if _args.has("simclick"):
		await get_tree().create_timer(1.5).timeout
		for pt in str(_args.simclick).split(";", false):
			var xy := pt.split(",")
			var pos := Vector2(float(xy[0]), float(xy[1]))
			var mv := InputEventMouseMotion.new()
			mv.position = pos
			mv.global_position = pos
			Input.parse_input_event(mv)
			await get_tree().create_timer(0.3).timeout
			for pressed in [true, false]:
				var b := InputEventMouseButton.new()
				b.button_index = MOUSE_BUTTON_LEFT
				b.pressed = pressed
				b.position = pos
				b.global_position = pos
				Input.parse_input_event(b)
				await get_tree().create_timer(0.15).timeout
			await get_tree().create_timer(0.4).timeout


## --audiotest: worst case for loudness checks. Full storm, heavy rain, and every
## loud one-shot firing repeatedly (overhead lightning, light flickers, lamp sputter, clicks).
func _audio_stress_test() -> void:
	Weather.set_profile("storm", 0.0)
	Weather.force(1.0, 1.0, 0.6, 0.0)
	Weather.wetness = 1.0
	var t := 0
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		t += 1
		if t % 7 == 2:
			Weather.strike_lightning(1.0, 0.0)  # directly overhead: loudest thunder
		if t % 9 == 4:
			world.booth.force_flicker()
		if t % 11 == 6:
			world.lot.lamp._sputter = 2.0
			world.lot.lamp.sputtered.emit()
		if t % 3 == 0:
			world.ambience.play_ui("mouse_click", -8.0)


func _strip_visuals() -> void:
	var env: Environment = world.environment
	env.volumetric_fog_enabled = false
	env.ssr_enabled = false
	env.ssao_enabled = false
	env.glow_enabled = false
	for l in world.find_children("*", "Light3D", true, false):
		(l as Light3D).shadow_enabled = false
	for p in world.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).visible = false


## --perflog[=seconds]: print memory and object counts every few seconds (leak hunting).
func _perf_log() -> void:
	var every := float(_args.perflog) if _args.has("perflog") and str(_args.perflog).is_valid_float() else 15.0
	var t := 0.0
	while is_inside_tree():
		await get_tree().create_timer(every).timeout
		t += every
		if _args.has("strikes"):
			Weather.strike_lightning(1.0, 0.1)
		print("PERF t=%4ds desk=%s zoom=%s rain=%.2f vram=%6.1fMB tex=%6.1fMB buf=%6.1fMB objs=%d nodes=%d res=%d static=%6.1fMB fps=%d" % [
			int(t), world.props.desktop.is_on(), world.camera.state == world.camera.State.ZOOMED, Weather.rain,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Engine.get_frames_per_second()])
