extends Control
## A window's menu bar ("File  Edit  View ..."). Each menu is a title plus a
## Callable that returns the item list when the menu opens, so check marks and
## enabled states are always current.

const W95 := preload("res://scripts/desktop/w95.gd")

var os_ref: Node
var menus: Array = []        # [[title, Callable], ...]
var _rects: Array = []
var _hover := -1
var _open := -1


func setup(os: Node, p_menus: Array) -> void:
	os_ref = os
	menus = p_menus
	custom_minimum_size = Vector2(0, 19)
	var f := W95.font("sans")
	var x := 2.0
	for m in menus:
		var w := f.get_string_size(m[0], HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE).x + 12.0
		_rects.append(Rect2(x, 1, w, 17))
		x += w


func _draw() -> void:
	var f := W95.font("sans")
	for i in menus.size():
		var r: Rect2 = _rects[i]
		if i == _open:
			draw_style_box(W95.thin_sunken(), r)
		elif i == _hover and _open < 0:
			draw_style_box(W95.thin_raised(), r)
		var off := 1.0 if i == _open else 0.0
		draw_string(f, Vector2(r.position.x + 6 + off, r.position.y + 13 + off), menus[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE, W95.BLACK)
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), W95.SHADOW)
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), W95.WHITE)


func _idx_at(p: Vector2) -> int:
	for i in _rects.size():
		if (_rects[i] as Rect2).has_point(p):
			return i
	return -1


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var i := _idx_at(ev.position)
		if i != _hover:
			_hover = i
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var i := _idx_at(ev.position)
		if i >= 0:
			open_menu(i)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()


func open_menu(i: int) -> void:
	os_ref.close_menus()
	_open = i
	var r: Rect2 = _rects[i]
	var gp := get_global_rect().position + Vector2(r.position.x, r.end.y + 1)
	os_ref.open_menu(menus[i][1].call(), gp, {"on_close": _closed, "motion": _motion})
	queue_redraw()


func _closed() -> void:
	_open = -1
	queue_redraw()


## While a menu from this bar is open, moving over another title switches to it.
func _motion(global_pos: Vector2) -> void:
	var local := global_pos - get_global_rect().position
	var i := _idx_at(local)
	if i >= 0 and i != _open and local.y >= 0 and local.y < size.y:
		open_menu(i)
