extends Control
## Minesweeper. Left click reveals, right click flags, the face restarts.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")

const LEVELS := {"Beginner": Vector3i(9, 9, 10), "Intermediate": Vector3i(16, 16, 40), "Expert": Vector3i(30, 16, 99)}
const NUM_COLORS := [Color.BLACK, Color(0, 0, 1), Color(0, 0.5, 0), Color(1, 0, 0), Color(0, 0, 0.5), Color(0.5, 0, 0), Color(0, 0.5, 0.5), Color.BLACK, Color(0.5, 0.5, 0.5)]
const CELL := 16
const TOP := 19 + 6

var os: Node
var win: Control
var cols := 9
var rows := 9
var mines := 10
var mine: Array = []
var shown: Array = []
var flag: Array = []
var state := "ready"      # ready | play | won | lost
var seconds := 0
var _t := 0.0
var _boom := -1
var _down_face := false
var level := "Beginner"


func setup(p_os: Node, p_win: Control, _args: Dictionary) -> void:
	os = p_os
	win = p_win
	var bar: Control = MBar.new()
	add_child(bar)
	bar.setup(os, [["Game", func(): return [
		{"text": "New", "key": "F2", "act": reset},
		{"sep": true},
		{"text": "Beginner", "check": level == "Beginner", "act": func(): set_level("Beginner")},
		{"text": "Intermediate", "check": level == "Intermediate", "act": func(): set_level("Intermediate")},
		{"text": "Expert", "check": level == "Expert", "act": func(): set_level("Expert")},
		{"sep": true},
		{"text": "Exit", "act": func(): win.request_close()},
	]]])
	bar.size = Vector2(300, 19)
	set_level("Beginner")


func set_level(l: String) -> void:
	level = l
	var v: Vector3i = LEVELS[l]
	cols = v.x
	rows = v.y
	mines = v.z
	win.size = Vector2(cols * CELL + 6 + 8 + 6 + 2, rows * CELL + 6 + 48 + 8 + 19 + 20)
	reset()


func reset() -> void:
	mine = []
	shown = []
	flag = []
	for i in cols * rows:
		mine.append(false)
		shown.append(false)
		flag.append(false)
	state = "ready"
	seconds = 0
	_boom = -1
	queue_redraw()


func _place(avoid: int) -> void:
	var placed := 0
	while placed < mines:
		var i := randi() % (cols * rows)
		if not mine[i] and i != avoid:
			mine[i] = true
			placed += 1


func _count(x: int, y: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var nx := x + dx
			var ny := y + dy
			if (dx != 0 or dy != 0) and nx >= 0 and ny >= 0 and nx < cols and ny < rows and mine[ny * cols + nx]:
				n += 1
	return n


func _reveal(x: int, y: int) -> void:
	var stack := [Vector2i(x, y)]
	while stack.size() > 0:
		var p: Vector2i = stack.pop_back()
		var i := p.y * cols + p.x
		if shown[i] or flag[i]:
			continue
		shown[i] = true
		if _count(p.x, p.y) == 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := p.x + dx
					var ny := p.y + dy
					if nx >= 0 and ny >= 0 and nx < cols and ny < rows:
						stack.append(Vector2i(nx, ny))


func _board_origin() -> Vector2:
	return Vector2(8, TOP + 42)


func _face_rect() -> Rect2:
	var w := cols * CELL
	return Rect2(8 + (w - 26) / 2.0, TOP + 8, 26, 26)


func _process(d: float) -> void:
	if state == "play":
		_t += d
		if _t >= 1.0:
			_t -= 1.0
			seconds = mini(999, seconds + 1)
			queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed:
			if _face_rect().has_point(ev.position) and ev.button_index == MOUSE_BUTTON_LEFT:
				_down_face = true
				queue_redraw()
				return
			if state == "won" or state == "lost":
				return
			var o := _board_origin()
			var cx := int((ev.position.x - o.x) / CELL)
			var cy := int((ev.position.y - o.y) / CELL)
			if ev.position.x < o.x or ev.position.y < o.y or cx >= cols or cy >= rows:
				return
			var i := cy * cols + cx
			if ev.button_index == MOUSE_BUTTON_RIGHT:
				if not shown[i]:
					flag[i] = not flag[i]
			elif ev.button_index == MOUSE_BUTTON_LEFT and not flag[i] and not shown[i]:
				if state == "ready":
					_place(i)
					state = "play"
				if mine[i]:
					state = "lost"
					_boom = i
				else:
					_reveal(cx, cy)
					_check_win()
			os.play("click2", -18.0)
			queue_redraw()
		elif _down_face:
			_down_face = false
			if _face_rect().has_point(ev.position):
				reset()
			queue_redraw()


func _check_win() -> void:
	var left := 0
	for i in cols * rows:
		if not shown[i] and not mine[i]:
			left += 1
	if left == 0:
		state = "won"
		for i in cols * rows:
			if mine[i]:
				flag[i] = true


func _flags() -> int:
	var n := 0
	for f in flag:
		if f:
			n += 1
	return n


func _lcd(x: float, y: float, v: int) -> void:
	draw_rect(Rect2(x, y, 41, 25), Color.BLACK)
	draw_string(W95.font("vga"), Vector2(x + 3, y + 21), "%03d" % clampi(v, -99, 999), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.1, 0.1))


func _draw() -> void:
	var bw := cols * CELL
	var bh := rows * CELL
	draw_rect(Rect2(Vector2.ZERO, size), W95.FACE)
	# outer frame and header
	draw_style_box(W95.field(), Rect2(4, TOP + 4, bw + 8, 34))
	draw_style_box(W95.field(), Rect2(4, TOP + 40, bw + 8, bh + 8))
	_lcd(10, TOP + 8, rows * 0 + mines - _flags())
	_lcd(8 + bw - 41 + 4, TOP + 8, seconds)
	var fr := _face_rect()
	draw_style_box(W95.pressed() if _down_face else W95.raised(), fr)
	var fc := fr.get_center() + (Vector2(1, 1) if _down_face else Vector2.ZERO)
	draw_circle(fc, 9, Color.BLACK)
	draw_circle(fc, 8, Color(1, 1, 0))
	match state:
		"lost":
			draw_line(fc + Vector2(-5, -4), fc + Vector2(-2, -1), Color.BLACK)
			draw_line(fc + Vector2(-2, -4), fc + Vector2(-5, -1), Color.BLACK)
			draw_line(fc + Vector2(2, -4), fc + Vector2(5, -1), Color.BLACK)
			draw_line(fc + Vector2(5, -4), fc + Vector2(2, -1), Color.BLACK)
			draw_line(fc + Vector2(-4, 5), fc + Vector2(4, 5), Color.BLACK)
		"won":
			draw_rect(Rect2(fc.x - 6, fc.y - 4, 12, 3), Color.BLACK)
			draw_line(fc + Vector2(-4, 3), fc + Vector2(4, 3), Color.BLACK)
		_:
			draw_rect(Rect2(fc.x - 4, fc.y - 4, 2, 2), Color.BLACK)
			draw_rect(Rect2(fc.x + 2, fc.y - 4, 2, 2), Color.BLACK)
			draw_line(fc + Vector2(-4, 3), fc + Vector2(-2, 5), Color.BLACK)
			draw_line(fc + Vector2(-2, 5), fc + Vector2(2, 5), Color.BLACK)
			draw_line(fc + Vector2(2, 5), fc + Vector2(4, 3), Color.BLACK)
	var o := _board_origin()
	var f := W95.font("sansb")
	for y in rows:
		for x in cols:
			var i := y * cols + x
			var r := Rect2(o.x + x * CELL, o.y + y * CELL, CELL, CELL)
			var reveal_all: bool = state == "lost" and mine[i]
			if shown[i] or reveal_all and not flag[i]:
				draw_rect(r, Color(1, 0, 0) if i == _boom else W95.FACE)
				draw_rect(r, W95.SHADOW, false, 1.0)
				if mine[i]:
					draw_circle(r.get_center(), 4, Color.BLACK)
					draw_rect(Rect2(r.position.x + 5, r.position.y + 5, 2, 2), Color.WHITE)
				else:
					var n := _count(x, y)
					if n > 0:
						draw_string(f, r.position + Vector2(4, 13), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NUM_COLORS[n])
			else:
				_raised_cell(r)
				if flag[i]:
					draw_rect(Rect2(r.position.x + 7, r.position.y + 4, 2, 8), Color.BLACK)
					draw_rect(Rect2(r.position.x + 4, r.position.y + 11, 8, 2), Color.BLACK)
					draw_colored_polygon(PackedVector2Array([r.position + Vector2(8, 3), r.position + Vector2(8, 8), r.position + Vector2(3, 5.5)]), Color.RED)
					if state == "lost" and not mine[i]:
						draw_line(r.position + Vector2(2, 2), r.position + Vector2(14, 14), Color.RED, 2.0)


func _raised_cell(r: Rect2) -> void:
	draw_rect(r, W95.FACE)
	draw_line(r.position, r.position + Vector2(CELL - 1, 0), Color.WHITE, 2.0)
	draw_line(r.position, r.position + Vector2(0, CELL - 1), Color.WHITE, 2.0)
	draw_line(r.position + Vector2(0, CELL - 1), r.position + Vector2(CELL, CELL - 1), W95.SHADOW, 2.0)
	draw_line(r.position + Vector2(CELL - 1, 0), r.position + Vector2(CELL - 1, CELL), W95.SHADOW, 2.0)
