extends Control
## NightSnake: eat the coffee beans, don't hit the walls or your own tail.
## Arrow keys (or WASD) to steer, Space to pause, F2 for a new game. Keeps a high score.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")

const CELL := 12
const COLS := 26
const ROWS := 20
const TOP := 19 + 22

var os: Node
var win: Control
var body: Array = []        ## Vector2i, head first
var dir := Vector2i(1, 0)
var queued: Array = []      ## turns pressed since the last step
var food := Vector2i.ZERO
var score := 0
var best := 0
var state := "ready"        ## ready | play | paused | dead
var _acc := 0.0
var _font: Font


func setup(p_os: Node, p_win: Control, _args: Dictionary) -> void:
	os = p_os
	win = p_win
	_font = W95.font("vga")
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bar: Control = MBar.new()
	add_child(bar)
	bar.setup(os, [["Game", func(): return [
		{"text": "New Game", "key": "F2", "act": reset},
		{"text": "Pause", "key": "Space", "act": _toggle_pause},
		{"sep": true},
		{"text": "Exit", "act": func(): win.request_close()},
	]]])
	bar.size = Vector2(320, 19)
	reset()
	grab_focus.call_deferred()


func reset() -> void:
	body = [Vector2i(8, 10), Vector2i(7, 10), Vector2i(6, 10)]
	dir = Vector2i(1, 0)
	queued.clear()
	score = 0
	state = "ready"
	_place_food()
	queue_redraw()


func _place_food() -> void:
	while true:
		food = Vector2i(randi() % COLS, randi() % ROWS)
		if not body.has(food):
			return


func _toggle_pause() -> void:
	if state == "play":
		state = "paused"
	elif state == "paused":
		state = "play"
	queue_redraw()


func _speed() -> float:
	return maxf(0.055, 0.14 - score * 0.0025)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		grab_focus()
		if state in ["ready", "dead"]:
			if state == "dead":
				reset()
			state = "play"
		accept_event()
		return
	if not (ev is InputEventKey and ev.pressed):
		return
	accept_event()
	var want := Vector2i.ZERO
	match ev.keycode:
		KEY_UP, KEY_W: want = Vector2i(0, -1)
		KEY_DOWN, KEY_S: want = Vector2i(0, 1)
		KEY_LEFT, KEY_A: want = Vector2i(-1, 0)
		KEY_RIGHT, KEY_D: want = Vector2i(1, 0)
		KEY_SPACE:
			if state == "ready":
				state = "play"
			elif state == "dead":
				reset()
				state = "play"
			else:
				_toggle_pause()
			return
		KEY_F2:
			reset()
			return
	if want != Vector2i.ZERO:
		if state == "ready":
			state = "play"
		elif state == "dead":
			reset()
			state = "play"
		if queued.size() < 3:
			queued.append(want)


func _process(delta: float) -> void:
	if state != "play":
		return
	_acc += delta
	while _acc >= _speed() and state == "play":
		_acc -= _speed()
		_step()
	queue_redraw()


func _step() -> void:
	while not queued.is_empty():
		var q: Vector2i = queued.pop_front()
		if q != -dir and q != dir:
			dir = q
			break
	var head: Vector2i = body[0] + dir
	var hit_wall := head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS
	if hit_wall or body.slice(0, body.size() - 1).has(head):
		state = "dead"
		best = maxi(best, score)
		os.sound.emit("ding", -12.0)
		return
	body.push_front(head)
	if head == food:
		score += 1
		os.sound.emit("click2", -14.0)
		_place_food()
	else:
		body.pop_back()


func _draw() -> void:
	var o := Vector2(4, TOP)
	draw_rect(Rect2(Vector2(0, 19), size - Vector2(0, 19)), Color(0.75, 0.75, 0.75))
	draw_string(_font, Vector2(6, 19 + 16), "SCORE %03d   BEST %03d" % [score, maxi(best, score)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	draw_rect(Rect2(o - Vector2(2, 2), Vector2(COLS * CELL + 4, ROWS * CELL + 4)), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(o, Vector2(COLS * CELL, ROWS * CELL)), Color(0.02, 0.08, 0.03))
	# Coffee bean.
	var fp := o + Vector2(food) * CELL
	draw_circle(fp + Vector2(CELL, CELL) * 0.5, CELL * 0.38, Color(0.55, 0.3, 0.1))
	draw_line(fp + Vector2(CELL * 0.5, 2), fp + Vector2(CELL * 0.5, CELL - 2), Color(0.25, 0.12, 0.03), 1.5)
	for i in body.size():
		var p := o + Vector2(body[i]) * CELL
		var c := Color(0.3, 1.0, 0.4) if i == 0 else Color(0.1, 0.75, 0.25).lerp(Color(0.05, 0.4, 0.15), float(i) / maxf(body.size(), 1))
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), c)
	var msg := ""
	match state:
		"ready": msg = "Arrow keys to start"
		"paused": msg = "PAUSED"
		"dead": msg = "GAME OVER - Space to play again"
	if msg != "":
		var w := _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var c2 := o + Vector2(COLS * CELL, ROWS * CELL) * 0.5
		draw_rect(Rect2(c2 - Vector2(w * 0.5 + 8, 14), Vector2(w + 16, 24)), Color(0, 0, 0, 0.75))
		draw_string(_font, c2 + Vector2(-w * 0.5, 5), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1.0, 0.6))
