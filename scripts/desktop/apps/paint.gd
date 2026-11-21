extends Control
## Paint: pencil, brush, eraser, fill, spray, line, rectangle, ellipse, colour picker.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

const CW := 380
const CH := 226
const TOOLS := ["pencil", "brush", "eraser", "fill", "spray", "line", "rect", "ellipse", "pick"]
const PALETTE := [
	Color8(0, 0, 0), Color8(128, 128, 128), Color8(128, 0, 0), Color8(128, 128, 0), Color8(0, 128, 0), Color8(0, 128, 128), Color8(0, 0, 128), Color8(128, 0, 128), Color8(128, 128, 64), Color8(0, 64, 64), Color8(0, 128, 255), Color8(0, 64, 128), Color8(64, 0, 255), Color8(128, 64, 0),
	Color8(255, 255, 255), Color8(192, 192, 192), Color8(255, 0, 0), Color8(255, 255, 0), Color8(0, 255, 0), Color8(0, 255, 255), Color8(0, 0, 255), Color8(255, 0, 255), Color8(255, 255, 128), Color8(0, 255, 128), Color8(128, 255, 255), Color8(128, 128, 255), Color8(255, 0, 128), Color8(255, 128, 64),
]

var os: Node
var win: Control
var img: Image
var base: Image          # image before the current shape drag
var tex: ImageTexture
var view: Control
var tool := "pencil"
var fg := Color.BLACK
var bg := Color.WHITE
var _drag := false
var _start := Vector2i.ZERO
var _last := Vector2i.ZERO
var _btn := MOUSE_BUTTON_LEFT
var _tool_btns := {}
var _swatch: Control
var path_name := "untitled"


func setup(p_os: Node, p_win: Control, args: Dictionary) -> void:
	os = p_os
	win = p_win
	img = Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	tex = ImageTexture.create_from_image(img)
	var bar: Control = MBar.new()
	add_child(bar)
	bar.setup(os, [["File", func(): return [{"text": "New", "act": _new}, {"sep": true}, {"text": "Exit", "act": func(): win.request_close()}]],
		["Help", func(): return [{"text": "About Paint", "act": func(): Dialogs.msgbox(os, "About Paint", "NightWin 95 Paint", "info")}]]])
	bar.size = Vector2(460, 19)
	# Tool box (2 columns)
	for i in TOOLS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.icon = W95.icon("pt_" + TOOLS[i], false) if false else load("res://assets/desktop/icons/pt_%s.png" % TOOLS[i])
		b.position = Vector2(4 + (i % 2) * 25, 26 + (i / 2) * 25)
		b.size = Vector2(25, 25)
		b.set_pressed_no_signal(i == 0)
		var t: String = TOOLS[i]
		b.pressed.connect(func(): _set_tool(t))
		add_child(b)
		_tool_btns[t] = b
	_swatch = Control.new()
	_swatch.position = Vector2(8, 26 + 5 * 25 + 6)
	_swatch.size = Vector2(40, 36)
	_swatch.draw.connect(_draw_swatch)
	add_child(_swatch)
	# Canvas
	var holder := Panel.new()
	holder.add_theme_stylebox_override("panel", W95.field())
	holder.position = Vector2(56, 22)
	holder.size = Vector2(CW + 4, CH + 4)
	add_child(holder)
	view = Control.new()
	view.position = Vector2(2, 2)
	view.size = Vector2(CW, CH)
	view.mouse_default_cursor_shape = Control.CURSOR_CROSS
	view.draw.connect(func(): view.draw_texture(tex, Vector2.ZERO))
	view.gui_input.connect(_canvas_input)
	holder.add_child(view)
	# Palette
	for i in PALETTE.size():
		var sw := Control.new()
		var col: Color = PALETTE[i]
		sw.position = Vector2(56 + (i % 14) * 17, 22 + CH + 10 + (i / 14) * 17)
		sw.size = Vector2(17, 17)
		sw.draw.connect(func():
			sw.draw_style_box(W95.field(), Rect2(Vector2.ZERO, sw.size))
			sw.draw_rect(Rect2(2, 2, 13, 13), col))
		sw.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_RIGHT:
					bg = col
				else:
					fg = col
				_swatch.queue_redraw())
		add_child(sw)
	var args_path: String = args.get("path", "")
	if args_path != "":
		var up := args_path.to_upper()
		var src := ""
		if up.ends_with("LOT_C.BMP"):
			src = "lot_photo2"
		elif up.ends_with("IMG_0013.BMP"):
			src = "lot_photo"
		if src != "":
			var im: Image = (load("res://assets/desktop/web/%s.png" % src) as Texture2D).get_image()
			im.convert(Image.FORMAT_RGBA8)
			img.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(0, 0))
			_refresh()
		path_name = os.vfs.base_name(args_path)
	win.set_title("%s - Paint" % path_name)


func _draw_swatch() -> void:
	_swatch.draw_style_box(W95.field(), Rect2(10, 10, 26, 24))
	_swatch.draw_rect(Rect2(12, 12, 14, 14), bg)
	_swatch.draw_style_box(W95.field(), Rect2(0, 0, 26, 24))
	_swatch.draw_rect(Rect2(2, 2, 22, 20), fg)


func _set_tool(t: String) -> void:
	tool = t
	for k in _tool_btns:
		_tool_btns[k].set_pressed_no_signal(k == t)


func _new() -> void:
	img.fill(Color.WHITE)
	path_name = "untitled"
	win.set_title("untitled - Paint")
	_refresh()


func _refresh() -> void:
	tex.update(img)
	view.queue_redraw()


# --------------------------------------------------------------- raster ops
func _plot(im: Image, x: int, y: int, c: Color, s: int) -> void:
	var h := s / 2
	for dy in range(-h, s - h):
		for dx in range(-h, s - h):
			var px := x + dx
			var py := y + dy
			if px >= 0 and py >= 0 and px < CW and py < CH:
				im.set_pixel(px, py, c)


func _line(im: Image, a: Vector2i, b: Vector2i, c: Color, s: int) -> void:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var x := a.x
	var y := a.y
	while true:
		_plot(im, x, y, c, s)
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy


func _rect(im: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var p := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var q := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	_line(im, p, Vector2i(q.x, p.y), c, 1)
	_line(im, Vector2i(q.x, p.y), q, c, 1)
	_line(im, q, Vector2i(p.x, q.y), c, 1)
	_line(im, Vector2i(p.x, q.y), p, c, 1)


func _ellipse(im: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	var cx := (a.x + b.x) / 2.0
	var cy := (a.y + b.y) / 2.0
	var rx := absf(b.x - a.x) / 2.0
	var ry := absf(b.y - a.y) / 2.0
	var steps := maxi(16, int((rx + ry) * 3.0))
	var prev := Vector2i(int(cx + rx), int(cy))
	for i in range(1, steps + 1):
		var t := TAU * i / steps
		var p := Vector2i(int(round(cx + cos(t) * rx)), int(round(cy + sin(t) * ry)))
		_line(im, prev, p, c, 1)
		prev = p


func _flood(im: Image, p: Vector2i, c: Color) -> void:
	var target := im.get_pixelv(p)
	if target.is_equal_approx(c):
		return
	var stack := [p]
	while stack.size() > 0:
		var q: Vector2i = stack.pop_back()
		if q.x < 0 or q.y < 0 or q.x >= CW or q.y >= CH:
			continue
		if not im.get_pixelv(q).is_equal_approx(target):
			continue
		# scanline
		var x0 := q.x
		while x0 > 0 and im.get_pixel(x0 - 1, q.y).is_equal_approx(target):
			x0 -= 1
		var x1 := q.x
		while x1 < CW - 1 and im.get_pixel(x1 + 1, q.y).is_equal_approx(target):
			x1 += 1
		for x in range(x0, x1 + 1):
			im.set_pixel(x, q.y, c)
			if q.y > 0 and im.get_pixel(x, q.y - 1).is_equal_approx(target):
				stack.append(Vector2i(x, q.y - 1))
			if q.y < CH - 1 and im.get_pixel(x, q.y + 1).is_equal_approx(target):
				stack.append(Vector2i(x, q.y + 1))


func _canvas_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_RIGHT):
		var p := Vector2i(ev.position)
		if ev.pressed:
			_btn = ev.button_index
			var col := fg if _btn == MOUSE_BUTTON_LEFT else bg
			_drag = true
			_start = p
			_last = p
			match tool:
				"fill":
					_flood(img, p, col)
					_drag = false
				"pick":
					if p.x >= 0 and p.y >= 0 and p.x < CW and p.y < CH:
						var pc := img.get_pixelv(p)
						if _btn == MOUSE_BUTTON_LEFT:
							fg = pc
						else:
							bg = pc
						_swatch.queue_redraw()
					_drag = false
				"line", "rect", "ellipse":
					base = img.duplicate()
				_:
					_stroke(p, p, col)
			_refresh()
		else:
			if _drag and (tool == "line" or tool == "rect" or tool == "ellipse"):
				_shape(img, _start, p, fg if _btn == MOUSE_BUTTON_LEFT else bg)
				base = null
			_drag = false
			_refresh()
	elif ev is InputEventMouseMotion and _drag:
		var p := Vector2i(ev.position)
		var col := fg if _btn == MOUSE_BUTTON_LEFT else bg
		if tool == "line" or tool == "rect" or tool == "ellipse":
			img.copy_from(base)
			_shape(img, _start, p, col)
		else:
			_stroke(_last, p, col)
		_last = p
		_refresh()


func _shape(im: Image, a: Vector2i, b: Vector2i, c: Color) -> void:
	match tool:
		"line": _line(im, a, b, c, 1)
		"rect": _rect(im, a, b, c)
		"ellipse": _ellipse(im, a, b, c)


func _stroke(a: Vector2i, b: Vector2i, c: Color) -> void:
	match tool:
		"pencil": _line(img, a, b, c, 1)
		"brush": _line(img, a, b, c, 4)
		"eraser": _line(img, a, b, bg, 9)
		"spray":
			for i in 14:
				var o := Vector2i(randi_range(-8, 8), randi_range(-8, 8))
				if o.length() <= 8.0:
					_plot(img, b.x + o.x, b.y + o.y, c, 1)
