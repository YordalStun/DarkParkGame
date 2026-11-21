extends Control
## A Windows 95 style window: bevelled frame, navy title bar with
## minimise / maximise / close buttons, dragging and edge resizing.
## Apps put their content in `client`.

const W95 := preload("res://scripts/desktop/w95.gd")

signal closed(win)

const BORDER := 4
const TITLE_H := 18
const BTN_W := 16
const BTN_H := 14

const L := 1
const R := 2
const T := 4
const B := 8

var os_ref: Node            ## the DesktopOS
var title := ""
var icon: Texture2D
var client: Control
var app: Control            ## the app node inside client (may be null for dialogs)
var active := false
var maximized := false
var minimized := false
var can_min := true
var can_max := true
var can_resize := true
var dialog := false
var min_win_size := Vector2(150, 80)

var _restore_rect := Rect2()
var _drag := false
var _drag_off := Vector2.ZERO
var _resize_edges := 0
var _resize_start := Rect2()
var _resize_mouse := Vector2.ZERO
var _btn_down := ""
var _btn_hover := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func setup(os: Node, p_title: String, icon_name: String, size_px: Vector2, opts := {}) -> void:
	os_ref = os
	title = p_title
	icon = W95.icon(icon_name, true)
	can_min = opts.get("min", true)
	can_max = opts.get("max", true)
	can_resize = opts.get("resize", true)
	dialog = opts.get("dialog", false)
	min_win_size = opts.get("min_size", Vector2(150, 80))
	size = size_px
	client = Control.new()
	client.name = "Client"
	client.clip_contents = true
	add_child(client)
	_layout_client()


func _layout_client() -> void:
	client.position = Vector2(BORDER, BORDER + TITLE_H + 1)
	client.size = size - Vector2(BORDER * 2, BORDER * 2 + TITLE_H + 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and client != null:
		_layout_client()
		queue_redraw()


func set_title(t: String) -> void:
	title = t
	queue_redraw()
	if os_ref:
		os_ref.refresh_taskbar()


func set_active(a: bool) -> void:
	active = a
	queue_redraw()


# --------------------------------------------------------------- drawing
func _btn_rect(name: String) -> Rect2:
	var y := BORDER + 2
	var right := size.x - BORDER - 2
	match name:
		"close":
			return Rect2(right - BTN_W, y, BTN_W, BTN_H)
		"max":
			return Rect2(right - BTN_W * 2 - 2, y, BTN_W, BTN_H)
		"min":
			return Rect2(right - BTN_W * 3 - 2, y, BTN_W, BTN_H)
	return Rect2()


func _buttons() -> Array:
	var a := ["close"]
	if can_max or can_min:
		a.append("max")
		a.append("min")
	return a


func _draw() -> void:
	draw_style_box(W95.window_frame(), Rect2(Vector2.ZERO, size))
	var bar := Rect2(BORDER, BORDER, size.x - BORDER * 2, TITLE_H)
	draw_rect(bar, W95.NAVY if active else W95.SHADOW)
	var f := W95.font("sansb")
	var tx := bar.position.x + 2
	if icon != null:
		draw_texture(icon, Vector2(tx, bar.position.y + 1))
		tx += 19
	var tcol := Color.WHITE if active else W95.FACE
	var avail := _btn_rect("min").position.x - tx - 4 if can_max or can_min else _btn_rect("close").position.x - tx - 4
	draw_string(f, Vector2(tx, bar.position.y + 13), title, HORIZONTAL_ALIGNMENT_LEFT, avail, W95.FONT_SIZE, tcol, TextServer.JUSTIFICATION_NONE, TextServer.DIRECTION_AUTO, TextServer.ORIENTATION_HORIZONTAL)
	for b in _buttons():
		var r := _btn_rect(b)
		var down: bool = _btn_down == b and _btn_hover == b
		var disabled: bool = (b == "max" and not can_max) or (b == "min" and not can_min)
		draw_style_box(W95.pressed() if down else W95.raised(), r)
		var g: Texture2D
		match b:
			"close": g = W95.glyph("close")
			"max": g = W95.glyph("restore" if maximized else "maximize")
			"min": g = W95.glyph("minimize")
		var gp := r.position + ((r.size - g.get_size()) / 2.0).floor()
		if b == "min":
			gp.y += 3
		if down:
			gp += Vector2(1, 1)
		draw_texture(g, gp, W95.SHADOW if disabled else Color.WHITE)


# ----------------------------------------------------------------- input
func edge_at(p: Vector2) -> int:
	if not can_resize or maximized:
		return 0
	var e := 0
	var m := float(BORDER)
	var c := 14.0
	if p.x < m or (p.x < c and (p.y < m or p.y > size.y - m)):
		e |= L
	if p.x > size.x - m or (p.x > size.x - c and (p.y < m or p.y > size.y - m)):
		e |= R
	if p.y < m or (p.y < c and (p.x < m or p.x > size.x - m)):
		e |= T
	if p.y > size.y - m or (p.y > size.y - c and (p.x < m or p.x > size.x - m)):
		e |= B
	return e


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var m := ev as InputEventMouseMotion
		if _drag:
			position = (m.global_position - _drag_off).clamp(Vector2(-size.x + 60, 0), Vector2(os_ref.W - 40, os_ref.H - 28 - TITLE_H - 8))
		elif _resize_edges != 0:
			_do_resize(m.global_position)
		else:
			var h := ""
			for b in _buttons():
				if _btn_rect(b).has_point(m.position):
					h = b
			if h != _btn_hover:
				_btn_hover = h
				queue_redraw()
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			os_ref.focus_window(self)
			for b in _buttons():
				if _btn_rect(b).has_point(mb.position):
					if (b == "max" and not can_max) or (b == "min" and not can_min):
						return
					_btn_down = b
					_btn_hover = b
					queue_redraw()
					return
			var e := edge_at(mb.position)
			if e != 0:
				_resize_edges = e
				_resize_start = Rect2(position, size)
				_resize_mouse = mb.global_position
				return
			if mb.position.y < BORDER + TITLE_H + 2:
				if mb.double_click and can_max:
					toggle_maximize()
					return
				if not maximized:
					_drag = true
					_drag_off = mb.global_position - position
		else:
			_drag = false
			_resize_edges = 0
			if _btn_down != "":
				var b := _btn_down
				var inside := _btn_rect(b).has_point(mb.position)
				_btn_down = ""
				queue_redraw()
				if inside:
					match b:
						"close": request_close()
						"max": toggle_maximize()
						"min": os_ref.minimize_window(self)


func _do_resize(mouse: Vector2) -> void:
	var d := mouse - _resize_mouse
	var r := _resize_start
	var minw := min_win_size.x
	var minh := min_win_size.y
	if _resize_edges & R:
		r.size.x = maxf(minw, r.size.x + d.x)
	if _resize_edges & B:
		r.size.y = maxf(minh, r.size.y + d.y)
	if _resize_edges & L:
		var nw := maxf(minw, _resize_start.size.x - d.x)
		r.position.x = _resize_start.position.x + (_resize_start.size.x - nw)
		r.size.x = nw
	if _resize_edges & T:
		var nh := maxf(minh, _resize_start.size.y - d.y)
		r.position.y = _resize_start.position.y + (_resize_start.size.y - nh)
		r.size.y = nh
	position = r.position
	size = r.size


func toggle_maximize() -> void:
	if not can_max:
		return
	if maximized:
		maximized = false
		position = _restore_rect.position
		size = _restore_rect.size
	else:
		_restore_rect = Rect2(position, size)
		maximized = true
		position = Vector2.ZERO
		size = Vector2(os_ref.W, os_ref.H - 28)
	queue_redraw()


func request_close() -> void:
	if app != null and app.has_method("on_close") and not app.on_close():
		return
	if dialog:
		os_ref.close_dialog(self)
	else:
		os_ref.close_window(self)
