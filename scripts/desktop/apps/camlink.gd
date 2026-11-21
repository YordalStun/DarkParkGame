extends Control
## CamLink CCTV: live feeds from the four real cameras in the 3D world, in a 2x2 grid.
## Click a picture to view that camera on its own; click again for the grid.
##
## When the player sits back from the desk with CamLink open, the window fills the
## screen (monitor mode) so the feeds stay readable on the CRT from the chair.

const W95 := preload("res://scripts/desktop/w95.gd")
const CCTV_SHADER := preload("res://shaders/cctv.gdshader")

var os: Node
var win: Control
var cctv: Node              ## world.cctv, or null when running without the game world
var _grid: GridContainer
var _tiles: Array = []      ## [{panel, picture, rec, time}]
var _solo := -1             ## camera shown alone, or -1 for the grid
var _status: Label
var _full_btn: Button
var _monitor_max := false   ## we maximised the window for monitor mode
var _blink := 0.0
var _noise: ImageTexture
var _noise_img: Image
var _noise_t := 0.0


func setup(p_os: Node, p_win: Control, _args: Dictionary) -> void:
	os = p_os
	win = p_win
	if os.world != null and os.world.get("cctv") != null:
		cctv = os.world.cctv
		cctv.acquire()

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_bottom = -30
	add_child(bg)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid.offset_bottom = -30
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	add_child(_grid)
	for i in 4:
		_grid.add_child(_make_tile(i))

	_full_btn = os.button("Full Screen")
	_full_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_full_btn.offset_left = -90
	_full_btn.offset_top = -27
	_full_btn.offset_right = -6
	_full_btn.offset_bottom = -4
	_full_btn.pressed.connect(func(): win.toggle_maximize())
	add_child(_full_btn)

	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 8
	_status.offset_top = -22
	add_child(_status)
	_status.text = "Link status: OK (4 of 4 cameras)  -  click a picture to enlarge" if cctv else "Link status: DOWN (4 of 4 cameras)"

	if os.has_signal("away_changed"):
		os.away_changed.connect(_on_away)
		if os.away:
			_on_away.call_deferred(true)


func _exit_tree() -> void:
	if cctv:
		cctv.release()
		cctv = null


func _make_tile(i: int) -> Control:
	var p := Panel.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", W95.field())
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev): _tile_input(ev, i))

	var tr := TextureRect.new()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 2
	tr.offset_top = 2
	tr.offset_right = -2
	tr.offset_bottom = -2
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = CCTV_SHADER
	m.set_shader_parameter("seed", float(i) * 17.0)
	if cctv:
		tr.texture = cctv.texture(i)
	else:
		tr.texture = _noise_tex()
		m.set_shader_parameter("signal_level", 0.0)
	tr.material = m
	p.add_child(tr)

	var font := W95.font("monob")
	var name_l := _overlay(p, cctv.cams[i].name if cctv else "CAM %d" % (i + 1), font)
	name_l.position = Vector2(7, 5)
	var time_l := _overlay(p, "", font)
	time_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	time_l.offset_left = 7
	time_l.offset_top = -19
	var rec := _overlay(p, "REC", font)
	rec.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rec.offset_left = -40
	rec.offset_top = 5
	rec.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	if not cctv:
		var ns := _overlay(p, "NO SIGNAL", font)
		ns.set_anchors_preset(Control.PRESET_CENTER)
		ns.offset_left = -34
		ns.offset_top = -8
	_tiles.append({"panel": p, "picture": tr, "rec": rec, "time": time_l})
	return p


func _overlay(parent: Control, text: String, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parent.add_child(l)
	return l


func _tile_input(ev: InputEvent, i: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_solo = -1 if _solo == i else i
		for j in _tiles.size():
			_tiles[j].panel.visible = _solo == -1 or _solo == j
		_grid.columns = 1 if _solo != -1 else 2
		os.play("click2", -16.0)


## Monitor mode: fill the screen while the player is away from the keyboard.
func _on_away(away: bool) -> void:
	if away and not win.maximized:
		win.toggle_maximize()
		_monitor_max = true
		os.focus_window(win)
	elif not away and _monitor_max:
		if win.maximized:
			win.toggle_maximize()
		_monitor_max = false


func _noise_tex() -> ImageTexture:
	if _noise == null:
		_noise_img = Image.create(64, 48, false, Image.FORMAT_L8)
		_noise = ImageTexture.create_from_image(_noise_img)
	return _noise


func _process(delta: float) -> void:
	_blink += delta
	var on := fmod(_blink, 1.0) < 0.6
	# Game clock for hours:minutes; the seconds tick in real time like a recorder's counter.
	var stamp := "13-10-89 %s:%02d" % [NightClock.time_text(), int(Time.get_ticks_msec() / 1000) % 60]
	for t in _tiles:
		t.rec.visible = on and cctv != null
		t.time.text = stamp
	_full_btn.text = "Restore" if win.maximized else "Full Screen"
	if cctv == null and _noise:
		_noise_t += delta
		if _noise_t > 0.1:
			_noise_t = 0.0
			var d := PackedByteArray()
			d.resize(64 * 48)
			for j in d.size():
				d[j] = randi() % 200
			_noise_img.set_data(64, 48, false, Image.FORMAT_L8, d)
			_noise.update(_noise_img)
