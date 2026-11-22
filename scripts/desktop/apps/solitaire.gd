extends Control
## Solitaire (Klondike, draw one). Drag cards with the mouse; double-click a card to send it
## up to the foundations; click the deck to turn a card. Win and the cards bounce away.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")

const CW := 46          ## card size
const CH := 64
const GAP := 8
const FAN := 14         ## face-up overlap in a column
const FAN_DOWN := 5     ## face-down overlap
const TOP := 26         ## below the menu bar
const SUITS := ["S", "H", "D", "C"]   ## spades hearts diamonds clubs
const SUIT_CH := {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const FELT := Color(0.0, 0.5, 0.0)

var os: Node
var win: Control
var stock: Array = []
var waste: Array = []
var found: Array = [[], [], [], []]
var tab: Array = [[], [], [], [], [], [], []]
var drag: Array = []          ## cards being dragged
var drag_from := ""           ## "waste" | "tab:N" | "found:N"
var drag_pos := Vector2.ZERO
var drag_off := Vector2.ZERO
var won := false
var moves := 0
var _last_click := 0
var _bounce: Array = []       ## win animation: [card, pos, vel]
var _font: Font
var _bold: Font


func setup(p_os: Node, p_win: Control, _args: Dictionary) -> void:
	os = p_os
	win = p_win
	_font = W95.font("sans")
	_bold = W95.font("sansb")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var bar: Control = MBar.new()
	add_child(bar)
	bar.setup(os, [["Game", func(): return [
		{"text": "Deal", "key": "F2", "act": deal},
		{"sep": true},
		{"text": "Exit", "act": func(): win.request_close()},
	]], ["Help", func(): return [{"text": "How to Play", "act": func(): _help()}]]])
	bar.size = Vector2(600, 19)
	deal()


func _help() -> void:
	var D = load("res://scripts/desktop/dialogs.gd")
	D.msgbox(os, "Solitaire", "Build the four foundations (top right) up from Ace to King by suit.\nIn the columns, build down in alternating colours. Only a King can go in an empty column.\nClick the deck to turn a card. Double-click a card to send it home.", "info")


func deal() -> void:
	var deck := []
	for s in SUITS:
		for r in 13:
			deck.append({"s": s, "r": r, "up": false})
	deck.shuffle()
	stock = []
	waste = []
	found = [[], [], [], []]
	tab = [[], [], [], [], [], [], []]
	for c in 7:
		for k in c + 1:
			var card: Dictionary = deck.pop_back()
			card.up = k == c
			tab[c].append(card)
	stock = deck
	won = false
	moves = 0
	_bounce.clear()
	drag.clear()
	queue_redraw()


static func _red(c: Dictionary) -> bool:
	return c.s == "H" or c.s == "D"


# ------------------------------------------------------------------ layout
func _stock_rect() -> Rect2:
	return Rect2(GAP, TOP, CW, CH)


func _waste_rect() -> Rect2:
	return Rect2(GAP * 2 + CW, TOP, CW, CH)


func _found_rect(i: int) -> Rect2:
	return Rect2(GAP + (3 + i) * (CW + GAP), TOP, CW, CH)


func _col_x(c: int) -> float:
	return GAP + c * (CW + GAP)


func _tab_y(c: int, k: int) -> float:
	var y := TOP + CH + 14.0
	for i in k:
		y += FAN if tab[c][i].up else FAN_DOWN
	return y


func _tab_rect(c: int, k: int) -> Rect2:
	return Rect2(_col_x(c), _tab_y(c, k), CW, CH)


# ------------------------------------------------------------------ input
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var now := Time.get_ticks_msec()
			var dbl := now - _last_click < 400
			_last_click = now
			_press(ev.position, dbl)
		else:
			_release(ev.position)
		accept_event()
	elif ev is InputEventMouseMotion and not drag.is_empty():
		drag_pos = ev.position
		queue_redraw()
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_F2:
		deal()


func _press(p: Vector2, dbl: bool) -> void:
	if won:
		deal()
		return
	if _stock_rect().has_point(p):
		if stock.is_empty():
			while not waste.is_empty():
				var c: Dictionary = waste.pop_back()
				c.up = false
				stock.append(c)
		else:
			var c2: Dictionary = stock.pop_back()
			c2.up = true
			waste.append(c2)
		os.sound.emit("click2", -20.0)
		queue_redraw()
		return
	if _waste_rect().has_point(p) and not waste.is_empty():
		if dbl and _to_foundation(waste[-1]):
			waste.pop_back()
			_after_move()
			return
		_start_drag([waste[-1]], "waste", p, _waste_rect().position)
		return
	for i in 4:
		if _found_rect(i).has_point(p) and not found[i].is_empty():
			_start_drag([found[i][-1]], "found:%d" % i, p, _found_rect(i).position)
			return
	for c in 7:
		for k in range(tab[c].size() - 1, -1, -1):
			var r := _tab_rect(c, k)
			if k < tab[c].size() - 1:
				r.size.y = (FAN if tab[c][k].up else FAN_DOWN)
			if r.has_point(p):
				var card: Dictionary = tab[c][k]
				if not card.up:
					if k == tab[c].size() - 1:
						card.up = true   # turn over the top card
						queue_redraw()
					return
				if dbl and k == tab[c].size() - 1 and _to_foundation(card):
					tab[c].pop_back()
					_after_move()
					return
				_start_drag(tab[c].slice(k), "tab:%d" % c, p, r.position)
				return


func _start_drag(cards: Array, from: String, p: Vector2, card_pos: Vector2) -> void:
	drag = cards
	drag_from = from
	drag_pos = p
	drag_off = p - card_pos
	queue_redraw()


func _release(p: Vector2) -> void:
	if drag.is_empty():
		return
	var top: Dictionary = drag[0]
	var dropped := false
	var card_rect := Rect2(p - drag_off, Vector2(CW, CH))
	# Foundations (single card only).
	if drag.size() == 1:
		for i in 4:
			if _found_rect(i).grow(10).intersects(card_rect) and _fits_found(top, i):
				_take_from_source()
				found[i].append(top)
				dropped = true
				break
	if not dropped:
		var best := -1
		var best_d := 1e9
		for c in 7:
			var last: int = tab[c].size()
			var r := _tab_rect(c, maxi(last - 1, 0)) if last > 0 else Rect2(_col_x(c), TOP + CH + 14.0, CW, CH)
			if r.grow(12).intersects(card_rect) and _fits_tab(top, c) and drag_from != "tab:%d" % c:
				var d := r.get_center().distance_to(card_rect.get_center())
				if d < best_d:
					best_d = d
					best = c
		if best >= 0:
			_take_from_source()
			tab[best].append_array(drag)
			dropped = true
	drag = []
	if dropped:
		_after_move()
	else:
		queue_redraw()


func _take_from_source() -> void:
	if drag_from == "waste":
		waste.pop_back()
	elif drag_from.begins_with("found:"):
		found[int(drag_from.split(":")[1])].pop_back()
	elif drag_from.begins_with("tab:"):
		var c := int(drag_from.split(":")[1])
		tab[c].resize(tab[c].size() - drag.size())


func _fits_found(card: Dictionary, i: int) -> bool:
	if found[i].is_empty():
		return card.r == 0
	var t: Dictionary = found[i][-1]
	return t.s == card.s and card.r == t.r + 1


func _fits_tab(card: Dictionary, c: int) -> bool:
	if tab[c].is_empty():
		return card.r == 12
	var t: Dictionary = tab[c][-1]
	return t.up and _red(t) != _red(card) and card.r == t.r - 1


func _to_foundation(card: Dictionary) -> bool:
	for i in 4:
		if _fits_found(card, i):
			found[i].append(card)
			return true
	return false


func _after_move() -> void:
	moves += 1
	os.sound.emit("click2", -18.0)
	for c in 7:
		if not tab[c].is_empty() and not tab[c][-1].up:
			tab[c][-1].up = true
	var n := 0
	for f in found:
		n += f.size()
	if n == 52:
		won = true
		_start_bounce()
	queue_redraw()


# ------------------------------------------------------------------ win
func _start_bounce() -> void:
	_bounce.clear()
	for i in 4:
		for k in range(12, -1, -1):
			_bounce.append([found[i][k], _found_rect(i).position, Vector2(randf_range(-160, -40), randf_range(-60, 20)), 0.08 * (_bounce.size())])
	os.sound.emit("chime", -10.0)


func _process(delta: float) -> void:
	if not won or _bounce.is_empty():
		return
	var h := size.y
	for b in _bounce:
		if b[3] > 0.0:
			b[3] -= delta
			continue
		b[2].y += 500.0 * delta
		b[1] += b[2] * delta
		if b[1].y + CH > h:
			b[1].y = h - CH
			b[2].y *= -0.75
	queue_redraw()


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	draw_rect(Rect2(Vector2(0, 19), size - Vector2(0, 19)), FELT)
	if won and not _bounce.is_empty():
		for b in _bounce:
			if b[3] <= 0.0:
				_card(b[1], b[0])
		draw_string(_bold, Vector2(10, size.y - 10), "You win! Click to deal again.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		return
	# Stock and waste.
	if stock.is_empty():
		_slot(_stock_rect(), true)
	else:
		_back(_stock_rect().position)
	_slot(_waste_rect())
	if not waste.is_empty() and not (drag_from == "waste" and not drag.is_empty()):
		_card(_waste_rect().position, waste[-1])
	elif waste.size() > 1:
		_card(_waste_rect().position, waste[-2])
	for i in 4:
		_slot(_found_rect(i))
		var f: Array = found[i]
		var n := f.size()
		if drag_from == "found:%d" % i and not drag.is_empty():
			n -= 1
		if n > 0:
			_card(_found_rect(i).position, f[n - 1])
	for c in 7:
		_slot(Rect2(_col_x(c), TOP + CH + 14.0, CW, CH))
		var n2: int = tab[c].size()
		if drag_from == "tab:%d" % c and not drag.is_empty():
			n2 -= drag.size()
		for k in n2:
			var card: Dictionary = tab[c][k]
			if card.up:
				_card(_tab_rect(c, k).position, card)
			else:
				_back(_tab_rect(c, k).position)
	# Dragged cards on top.
	for i in drag.size():
		_card(drag_pos - drag_off + Vector2(0, i * FAN), drag[i])
	draw_string(_font, Vector2(size.x - 70, size.y - 6), "Moves: %d" % moves, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 1, 0.85))


func _slot(r: Rect2, ring := false) -> void:
	draw_rect(r, Color(0, 0.38, 0), false, 1.0)
	if ring:
		draw_arc(r.get_center(), 12, 0, TAU, 16, Color(0, 0.7, 0), 3.0)


func _back(p: Vector2) -> void:
	var r := Rect2(p, Vector2(CW, CH))
	draw_rect(r, Color.WHITE)
	draw_rect(r.grow(-3), Color(0.1, 0.2, 0.65))
	for y in range(int(p.y) + 5, int(p.y) + CH - 4, 4):
		draw_line(Vector2(p.x + 4, y), Vector2(p.x + CW - 4, y), Color(0.25, 0.4, 0.85), 1.0)
	draw_rect(r, Color.BLACK, false, 1.0)


func _card(p: Vector2, c: Dictionary) -> void:
	var r := Rect2(p, Vector2(CW, CH))
	draw_rect(r, Color.WHITE)
	draw_rect(r, Color.BLACK, false, 1.0)
	var col := Color(0.8, 0, 0) if _red(c) else Color.BLACK
	var rank: String = RANKS[c.r]
	var suit: String = SUIT_CH[c.s]
	draw_string(_bold, p + Vector2(3, 12), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	draw_string(_font, p + Vector2(3, 24), suit, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	draw_string(_font, p + Vector2(CW * 0.5 - 9, CH * 0.5 + 9), suit, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	if c.r >= 10:
		draw_rect(Rect2(p + Vector2(12, 8), Vector2(CW - 18, CH - 16)), Color(col.r, col.g, col.b, 0.12))
	draw_string(_bold, p + Vector2(CW - 4 - rank.length() * 7, CH - 4), rank, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
