extends Control
## CamLink CCTV. PLACEHOLDER: every camera reports NO SIGNAL. The real feeds will
## come from actual cameras in the 3D world later; replace the noise TextureRects
## in _make_tile() with a SubViewport texture from each camera when that exists.

const W95 := preload("res://scripts/desktop/w95.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

const NAMES := ["CAM 1  ROW A", "CAM 2  ROW B", "CAM 3  ROW C", "CAM 4  BOOTH"]

var os: Node
var _imgs: Array = []
var _texs: Array = []
var _t := 0.0


func setup(p_os: Node, _win: Control, _args: Dictionary) -> void:
	os = p_os
	var grid := GridContainer.new()
	grid.columns = 2
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.offset_bottom = -30
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	add_child(grid)
	for i in 4:
		grid.add_child(_make_tile(i))
	var b: Button = os.button("Reconnect")
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = -84
	b.offset_top = -27
	b.offset_right = -6
	b.offset_bottom = -4
	b.pressed.connect(func(): Dialogs.msgbox(os, "CamLink", "LINK TIMEOUT.\nNo response from camera driver CAMDRV.SYS.\nCheck the camera cable.", "error"))
	add_child(b)
	var st := Label.new()
	st.text = "Link status: DOWN (4 of 4 cameras)"
	st.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	st.offset_left = 8
	st.offset_top = -22
	add_child(st)


func _make_tile(i: int) -> Control:
	var p := Panel.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", W95.field())
	var img := Image.create(64, 48, false, Image.FORMAT_L8)
	var tex := ImageTexture.create_from_image(img)
	_imgs.append(img)
	_texs.append(tex)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 2
	tr.offset_top = 2
	tr.offset_right = -2
	tr.offset_bottom = -2
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.add_child(tr)
	var l := Label.new()
	l.text = NAMES[i]
	l.position = Vector2(6, 5)
	l.add_theme_color_override("font_color", Color(0.8, 1, 0.8))
	p.add_child(l)
	var ns := Label.new()
	ns.text = "NO SIGNAL"
	ns.set_anchors_preset(Control.PRESET_CENTER)
	ns.add_theme_font_override("font", W95.font("monob"))
	ns.add_theme_font_size_override("font_size", 14)
	ns.add_theme_color_override("font_color", Color.WHITE)
	ns.offset_left = -40
	ns.offset_top = -8
	p.add_child(ns)
	return p


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.12:
		return
	_t = 0.0
	for i in _imgs.size():
		var d := PackedByteArray()
		d.resize(64 * 48)
		for j in d.size():
			d[j] = randi() % 90
		_imgs[i].set_data(64, 48, false, Image.FORMAT_L8, d)
		_texs[i].update(_imgs[i])
