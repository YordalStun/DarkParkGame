extends CanvasLayer
## The end-of-shift screen. The night fades to black (sound too) and this takes over the whole
## screen, with nothing of the game behind it: tonight's pay on the left, the bills on the right
## (tick which ones to pay), and what's left. No pass or fail: you carry on as long as you can
## cover the bills.
##
## show_night(ev) takes story/shift.gd evaluate()'s result plus "start" (coins brought forward).
## Emits next_night(coins_left) or start_again().

signal next_night(coins: int)
signal start_again

const DESIGN := Vector2(1280, 720)
const GOLD := Color(0.91, 0.75, 0.44)
const INK := Color(0.85, 0.84, 0.78)
const DIM := Color(0.54, 0.53, 0.49)
const GREEN := Color(0.5, 0.88, 0.54)
const RED := Color(1.0, 0.44, 0.38)
const BG := Color(0.043, 0.051, 0.047)
## Bills due each morning: [name, cost, ticked by default, note when you skip it]
## The three bills (single player keeps a meter for each; see SaveGame.BILL_COST).
const BILLS := [
	["Rent", 2, true, "landlord waits"],
	["Food", 1, true, "go hungry"],
	["Heat", 1, true, "cold flat"],
]
var _meters := {}       ## tonight's meters before the bills (empty = co-op: no meters)
var _status := {}       ## reports, risk
var _pips: Array = []   ## Label per bill showing the meter after tonight
var lost_reason := ""   ## "EVICTED" / "STARVING" / "TOO COLD" / "FIRED" / "CAUGHT" (game over), or ""
const BAR_MAX := 16.0
## Upgrades you can buy here: [id, name, cost, what it does]. Shown until owned.
const UPGRADES := [
	["vehicle_log", "Vehicle log", 4, "clipboard at the window"],
]

var _black: ColorRect
var _root: Control
var _stage: Control
var _font: Font
var _ticks: Array = []        ## CheckBox per bill
var _left_val: Label
var _after_val: Label
var _big: Label
var _bar_fill: ColorRect
var _next_btn: Button
var _warn: Label
var _start := 0
var _wages := 0
var _broke := false
var _up_ticks: Array = []    ## [id, cost, CheckBox]


func _tick(text: String, on: bool) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = on
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_override("font", _font)
	cb.add_theme_font_size_override("font_size", 28)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		cb.add_theme_color_override(st, INK)
	cb.add_theme_icon_override("checked", _box(true))
	cb.add_theme_icon_override("unchecked", _box(false))
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		cb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	return cb


## Upgrades ticked to buy tonight.
func bought_upgrades() -> Array:
	var out := []
	for u in _up_ticks:
		if u[2].button_pressed:
			out.append(u[0])
	return out


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://assets/fonts/VT323-Regular.ttf")
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.modulate.a = 0.0
	_black.visible = false
	add_child(_black)


## Fade the night out, then show the pay and bills.
func show_night(ev: Dictionary, night_title: String, date_text: String, note: String) -> void:
	_start = ev.start
	_meters = ev.get("meters", {})
	_status = {"reports": ev.get("reports", 0), "risk": ev.get("risk", 0)}
	_wages = ev.earned + ev.bonus
	_black.visible = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_black, "modulate:a", 1.0, 2.5)
	tw.tween_method(func(v): Settings.set_fade(v), Settings.fade, 0.0, 2.8)
	await tw.finished
	await get_tree().create_timer(0.6).timeout
	_build(ev, night_title, date_text, note)
	Settings.set_fade(0.7)   # quiet room tone for the screen's own clicks


func _label(text: String, size: int, color := INK, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if parent:
		parent.add_child(l)
	return l


func _row(parent: Control, left: String, right: String, rcol := INK, note := "", ncol := DIM) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 36)
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	_label(left, 28, INK, h)
	if note != "":
		_label(note, 28, ncol, h)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_label(right, 28, rcol, h)
	return h


func _rule(parent: Control) -> void:
	var r := ColorRect.new()
	r.color = Color(0.27, 0.27, 0.26)
	r.custom_minimum_size = Vector2(0, 1)
	parent.add_child(r)


func _build(ev: Dictionary, night_title: String, date_text: String, note: String) -> void:
	_root = ColorRect.new()
	(_root as ColorRect).color = BG
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_stage = Control.new()
	_stage.size = DESIGN
	_root.add_child(_stage)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 1.2)

	var t := _label("07:00", 84, GOLD, _stage)
	t.position = Vector2(90, 52)
	var s := _label("%s  -  %s" % [night_title, date_text], 30, DIM, _stage)
	s.position = Vector2(92, 140)

	# ---- tonight's pay
	var left := VBoxContainer.new()
	left.position = Vector2(90, 220)
	left.size = Vector2(480, 380)
	left.add_theme_constant_override("separation", 0)
	_stage.add_child(left)
	var cap := _label("TONIGHT'S PAY", 30, GOLD, left)
	cap.custom_minimum_size = Vector2(0, 38)
	_rule(left)
	var rows: Array = []
	for r in ev.rows:
		var d: int = r.delta
		var v: String = str(r.verdict)
		var tag := ""
		var tcol := DIM
		if d < 0:
			tag = "should've been turned away"
			tcol = RED
		elif d == 0 and v.contains("allowed in"):
			tag = "was on the list"
			tcol = Color(1.0, 0.69, 0.38)
		elif d == 0:
			tag = "turned away"
		rows.append(_row(left, r.name, "%+d" % d if d != 0 else "0", GREEN if d > 0 else (RED if d < 0 else DIM), tag, tcol))
	var missing: int = ev.admitted - ev.plates_ok
	var bnote := "(every plate logged)" if ev.bonus > 0 else ("(%d missing)" % missing if ev.admitted > 0 else "(nobody to log)")
	rows.append(_row(left, "Plate bonus", "%+d" % ev.bonus if ev.bonus else "0", GREEN if ev.bonus > 0 else DIM, bnote))
	_rule(left)
	rows.append(_row(left, "Wages", "%+d" % _wages, GREEN if _wages > 0 else (RED if _wages < 0 else DIM)))

	# ---- bills
	var right := VBoxContainer.new()
	right.position = Vector2(680, 220)
	right.size = Vector2(480, 380)
	right.add_theme_constant_override("separation", 0)
	_stage.add_child(right)
	var cap2 := _label("BILLS DUE", 30, GOLD, right)
	cap2.custom_minimum_size = Vector2(0, 38)
	_rule(right)
	for b in BILLS:
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(0, 36)
		right.add_child(h)
		var cb := CheckBox.new()
		cb.text = b[0]
		cb.button_pressed = b[2]
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_override("font", _font)
		cb.add_theme_font_size_override("font_size", 28)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			cb.add_theme_color_override(st, INK)
		cb.add_theme_icon_override("checked", _box(true))
		cb.add_theme_icon_override("unchecked", _box(false))
		cb.add_theme_icon_override("checked_disabled", _box(true))
		cb.add_theme_icon_override("unchecked_disabled", _box(false))
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			cb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		h.add_child(cb)
		var pip := _label("", 24, GOLD, h)
		_pips.append(pip)
		var nl := _label(" (%s)" % b[3], 24, DIM, h)
		nl.visible = not b[2]
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		_label("-%d" % b[1], 28, RED, h)
		cb.toggled.connect(func(on):
			nl.visible = not on
			_click()
			_recalc())
		_ticks.append(cb)
	for u in UPGRADES:
		if SaveGame.has_upgrade(u[0]):
			continue
		var h2 := HBoxContainer.new()
		h2.custom_minimum_size = Vector2(0, 34)
		right.add_child(h2)
		var cb2 := _tick("Buy: " + u[1], false)
		h2.add_child(cb2)
		_label(" (%s)" % u[3], 22, DIM, h2)
		var sp2 := Control.new()
		sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(sp2)
		_label("-%d" % u[2], 28, RED, h2)
		cb2.toggled.connect(func(_on):
			_click()
			_recalc())
		_up_ticks.append([u[0], u[2], cb2])
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	right.add_child(gap)
	_row(right, "Savings", str(_start))
	_after_val = (_row(right, "After pay and bills", "0").get_child(-1) as Label)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 16)
	right.add_child(gap2)
	var bar := ColorRect.new()
	bar.color = Color(0.13, 0.13, 0.13)
	bar.custom_minimum_size = Vector2(480, 22)
	right.add_child(bar)
	_bar_fill = ColorRect.new()
	_bar_fill.color = GOLD
	_bar_fill.size = Vector2(0, 22)
	bar.add_child(_bar_fill)
	_big = _label("", 56, INK, right)
	_big.custom_minimum_size = Vector2(0, 70)

	var foot := _label(note, 28, DIM, _stage)
	foot.position = Vector2(90, 650)
	foot.size = Vector2(760, 40)
	foot.clip_text = true
	_warn = _label("", 26, RED, _stage)
	_warn.position = Vector2(680, 612)

	# ---- buttons
	var quit := _button("QUIT", false)
	quit.position = Vector2(876, 636)
	quit.pressed.connect(func(): get_tree().quit())
	_next_btn = _button("NEXT NIGHT", true)
	_next_btn.position = Vector2(1004, 636)
	_next_btn.pressed.connect(_on_next)

	# Pay lines tick in one by one, then the totals.
	for r in rows:
		r.modulate.a = 0.0
	right.modulate.a = 0.0
	_recalc()
	await get_tree().create_timer(0.8).timeout
	for r in rows:
		create_tween().tween_property(r, "modulate:a", 1.0, 0.15)
		_click()
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(0.3).timeout
	create_tween().tween_property(right, "modulate:a", 1.0, 0.6)


func _button(text: String, solid: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 30)
	b.custom_minimum_size = Vector2(108 if not solid else 186, 50)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.set_border_width_all(2)
		if solid:
			sb.bg_color = GOLD if st != "hover" else GOLD.lightened(0.15)
			sb.border_color = sb.bg_color
			if st == "disabled":
				sb.bg_color = Color(0.25, 0.24, 0.22)
				sb.border_color = sb.bg_color
		else:
			sb.bg_color = Color(0, 0, 0, 0) if st != "hover" else Color(1, 1, 1, 0.06)
			sb.border_color = Color(0.4, 0.4, 0.4)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", BG if solid else INK)
	b.add_theme_color_override("font_hover_color", BG if solid else INK)
	b.add_theme_color_override("font_pressed_color", BG if solid else INK)
	b.add_theme_color_override("font_disabled_color", DIM)
	_stage.add_child(b)
	return b


func _box(on: bool) -> ImageTexture:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		for x in 22:
			var edge := x < 2 or y < 2 or x > 19 or y > 19
			if edge:
				img.set_pixel(x, y, INK)
			elif on and x >= 5 and y >= 5 and x <= 16 and y <= 16:
				img.set_pixel(x, y, GOLD)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := minf(vs.x / DESIGN.x, vs.y / DESIGN.y)
	_stage.scale = Vector2(k, k)
	_stage.position = (vs - DESIGN * k) * 0.5


func _click() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/click2.ogg")
	p.volume_db = -14.0
	p.bus = "UI"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## The bills left unticked (unpaid) tonight.
func skipped_bills() -> Array:
	var out := []
	for i in BILLS.size():
		if BILLS[i][2] and not _ticks[i].button_pressed:   # optional ones (the bus pass) don't count
			out.append(BILLS[i][0])
	return out


## What's left after pay and the ticked bills.
func coins_left() -> int:
	var v := _start + _wages
	for i in BILLS.size():
		if _ticks[i].button_pressed:
			v -= BILLS[i][1]
	for u in _up_ticks:
		if u[2].button_pressed:
			v -= u[1]
	return v


func _recalc() -> void:
	var v := coins_left()
	_after_val.text = str(v)
	_after_val.add_theme_color_override("font_color", RED if v < 0 else INK)
	_bar_fill.size.x = clampf(v / BAR_MAX, 0.0, 1.0) * 480.0
	# Survival meters (single player): what each bill's meter will be after tonight.
	var lost := ""
	lost_reason = ""
	if not _meters.is_empty():
		var paid := {"rent": _ticks[0].button_pressed, "food": _ticks[1].button_pressed, "heat": _ticks[2].button_pressed}
		var after: Dictionary = SaveGame.meters_after(_meters, paid)
		var keys := ["rent", "food", "heat"]
		for i in 3:
			var n: int = after[keys[i]]
			_pips[i].text = "  " + "|".repeat(n) + ".".repeat(SaveGame.METER_MAX - n)
			_pips[i].add_theme_color_override("font_color", RED if n <= 1 else GOLD)
		if after.rent == 0:
			lost = "EVICTED"
		elif after.food == 0:
			lost = "STARVING"
		elif after.heat == 0:
			lost = "TOO COLD"
		if int(_status.get("reports", 0)) >= SaveGame.REPORTS_FIRED:
			lost = "FIRED"
		elif int(_status.get("risk", 0)) >= 100:
			lost = "CAUGHT"
	# Broke: even paying nothing at all, you're in the red.
	lost_reason = lost
	_broke = _start + _wages < 0 or lost != ""
	if lost != "":
		_big.text = lost
		_big.add_theme_color_override("font_color", RED)
		var why := {"EVICTED": "Three nights without rent. The landlord's changed the locks.",
			"STARVING": "Three nights without food. You can't go on like this.",
			"TOO COLD": "Three nights without heat. You're too ill to work.",
			"FIRED": "Ten complaints. Dale's seen the footage. You're fired.",
			"CAUGHT": "The police were waiting when you got home."}
		_warn.text = why.get(lost, "")
		_next_btn.text = "START AGAIN"
		_next_btn.disabled = false
	elif _broke:
		_big.text = "YOU'RE BROKE"
		_big.add_theme_color_override("font_color", RED)
		_warn.text = "You can't afford another night."
		_next_btn.text = "START AGAIN"
		_next_btn.disabled = false
	elif v < 0:
		_big.text = "%d COINS SHORT" % -v
		_big.add_theme_color_override("font_color", RED)
		_warn.text = "Untick something you can live without."
		_next_btn.text = "NEXT NIGHT"
		_next_btn.disabled = true
	else:
		_big.text = "%d COIN%s LEFT" % [v, "" if v == 1 else "S"]
		_big.add_theme_color_override("font_color", INK)
		_warn.text = ""
		_next_btn.text = "NEXT NIGHT"
		_next_btn.disabled = false


## Co-op guest: the same report, but the host decides (bills, upgrades, NEXT NIGHT).
var view_only := false
func set_view_only(text: String) -> void:
	view_only = true
	await get_tree().process_frame
	for n in find_children("*", "BaseButton", true, false):
		if n.text != "QUIT":
			n.disabled = true
	if _next_btn:
		_next_btn.text = "WAITING..."
	if _warn:
		_warn.add_theme_color_override("font_color", DIM)
		_warn.text = text


## A pop-up over the screen (e.g. "CO-OP UNLOCKED"). Click OK to carry on.
func show_unlock(title: String, text: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.07)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	dim.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	box.add_child(v)
	var t := _label(title, 64, GOLD, v)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _label(text, 28, INK, v)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ok := Button.new()
	ok.text = "OK"
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_override("font", _font)
	ok.add_theme_font_size_override("font_size", 30)
	ok.custom_minimum_size = Vector2(160, 48)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.bg_color = GOLD
	ok.add_theme_stylebox_override("normal", bs)
	ok.add_theme_stylebox_override("hover", bs)
	ok.add_theme_stylebox_override("pressed", bs)
	ok.add_theme_color_override("font_color", BG)
	ok.add_theme_color_override("font_hover_color", BG)
	v.add_child(ok)
	box.scale = Vector2(0.8, 0.8)
	box.pivot_offset = box.get_combined_minimum_size() * 0.5
	dim.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.4)
	tw.tween_property(box, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/chime.ogg")
	p.bus = "UI"
	add_child(p)
	p.play()
	await ok.pressed
	_click()
	dim.queue_free()


func _on_next() -> void:
	_click()
	if _broke:
		start_again.emit()
	else:
		next_night.emit(coins_left())
