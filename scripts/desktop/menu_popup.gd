extends Control
## A Windows 95 popup menu (Start menu, window menus, right-click menus) with
## cascading submenus. Items are dictionaries:
##   {"text": "Open", "act": Callable, "icon": Texture2D, "sub": [items...],
##    "sep": true, "dis": true, "check": true, "key": "Ctrl+O"}

const W95 := preload("res://scripts/desktop/w95.gd")

var os_ref: Node
var items: Array = []
var big := false              ## Start-menu style: 32px icons and a side banner
var banner := ""
var parent_menu: Control
var _child: Control
var _hover := -1
var _row_tops: Array = []
var _row_h := 20
var _pad_l := 20
var _banner_w := 0


func setup(os: Node, p_items: Array, p_big := false, p_banner := "") -> void:
	os_ref = os
	items = p_items
	big = p_big
	banner = p_banner
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row_h = 32 if big else 20
	_pad_l = 40 if big else 22
	_banner_w = 21 if banner != "" else 0
	var f := W95.font("sans")
	var w := 0.0
	var y := 2.0
	_row_tops.clear()
	for it in items:
		_row_tops.append(y)
		if it.get("sep", false):
			y += 9.0
			continue
		y += _row_h
		var tw := f.get_string_size(it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE).x
		if it.has("key"):
			tw += 24.0 + f.get_string_size(it["key"], HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE).x
		w = maxf(w, tw)
	size = Vector2(_banner_w + _pad_l + w + 28.0, y + 2.0)
	if big:
		size.x = maxf(size.x, 140.0)


func _row_at(py: float) -> int:
	for i in items.size():
		var top: float = _row_tops[i]
		var h := 9.0 if items[i].get("sep", false) else float(_row_h)
		if py >= top and py < top + h:
			return i
	return -1


func _draw() -> void:
	var f := W95.font("sans")
	draw_style_box(W95.menu_frame(), Rect2(Vector2.ZERO, size))
	if _banner_w > 0:
		var br := Rect2(2, 2, _banner_w, size.y - 4)
		draw_rect(br, W95.NAVY)
		draw_set_transform(Vector2(br.position.x + 16, br.end.y - 6), -PI / 2.0, Vector2.ONE)
		var fb := W95.font("sansb")
		draw_string(fb, Vector2(0, 0), "NightWin", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		var wd := fb.get_string_size("NightWin", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(f, Vector2(wd + 3, 0), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, W95.LIGHT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var x0 := 2.0 + _banner_w
	for i in items.size():
		var it: Dictionary = items[i]
		var top: float = _row_tops[i]
		if it.get("sep", false):
			var ly := top + 4.0
			draw_line(Vector2(x0 + 1, ly), Vector2(size.x - 3, ly), W95.SHADOW)
			draw_line(Vector2(x0 + 1, ly + 1), Vector2(size.x - 3, ly + 1), W95.WHITE)
			continue
		var hot: bool = i == _hover and not it.get("dis", false)
		if hot:
			draw_rect(Rect2(x0, top, size.x - x0 - 2, _row_h), W95.NAVY)
		var tcol := Color.WHITE if hot else W95.BLACK
		var ty := top + (_row_h + 9) / 2.0
		if it.get("check", false):
			draw_texture(W95.glyph("check", Color.WHITE if hot else W95.BLACK), Vector2(x0 + 6, top + (_row_h - 7) / 2.0))
		if it.has("icon") and it["icon"] != null:
			var ic: Texture2D = it["icon"]
			draw_texture(ic, Vector2(x0 + (4 if big else 2), top + (_row_h - ic.get_height()) / 2.0))
		var tx := x0 + _pad_l - (4 if big else 0)
		if it.get("dis", false):
			W95.draw_embossed(self, f, Vector2(tx, ty), it["text"], W95.FONT_SIZE)
		else:
			draw_string(f if not it.get("bold", false) else W95.font("sansb"), Vector2(tx, ty), it["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE, tcol)
		if it.has("key"):
			var kw := f.get_string_size(it["key"], HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE).x
			draw_string(f, Vector2(size.x - kw - 12, ty), it["key"], HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE, tcol)
		if it.has("sub"):
			draw_texture(W95.glyph("arrow_right", Color.WHITE if hot else W95.BLACK), Vector2(size.x - 12, top + (_row_h - 7) / 2.0))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var i := _row_at(ev.position.y)
		if i != _hover:
			_hover = i
			_close_child()
			if i >= 0 and items[i].has("sub") and not items[i].get("dis", false):
				_open_child(i)
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var i := _row_at(ev.position.y)
		if i < 0 or items[i].get("sep", false) or items[i].get("dis", false):
			return
		if items[i].has("sub"):
			if _child == null:
				_open_child(i)
			return
		var act: Callable = items[i].get("act", Callable())
		os_ref.close_menus()
		if act.is_valid():
			act.call()
		accept_event()


func _open_child(i: int) -> void:
	var m: Control = get_script().new()
	var sub_items: Array = items[i]["sub"]
	m.setup(os_ref, sub_items)
	m.parent_menu = self
	var pos := Vector2(position.x + size.x - 4, position.y + float(_row_tops[i]) - 2.0)
	if pos.x + m.size.x > os_ref.W:
		pos.x = position.x - m.size.x + 4
	pos.y = minf(pos.y, os_ref.H - 28 - m.size.y)
	m.position = pos
	os_ref.add_menu_node(m)
	_child = m


func _close_child() -> void:
	if _child != null and is_instance_valid(_child):
		_child.close_tree()
	_child = null


func close_tree() -> void:
	_close_child()
	queue_free()
