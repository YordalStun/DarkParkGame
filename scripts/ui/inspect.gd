extends CanvasLayer
## Close-up overlays for the story: a staff ID card held up beside tonight's list, and
## a number plate. Emits `closed(choice)`: "ok" / "refuse" for an ID, "done" for a plate.

signal closed(choice: String)
signal opened

var is_open := false
var _root: Control
var _card: Control
var _list: Control
var _plate: Control
var _caption: Label
var _buttons: HBoxContainer
var _person := {}
var _staff_list: Array = []
var _reg := ""
var _sans: Font
var _bold: Font
var _mono: Font
var _vt: Font
var _date_text := ""


func _ready() -> void:
	layer = 9
	_sans = load("res://assets/fonts/LiberationSans-Regular.ttf")
	_bold = load("res://assets/fonts/LiberationSans-Bold.ttf")
	_mono = load("res://assets/fonts/LiberationMono-Regular.ttf")
	_vt = load("res://assets/fonts/VT323-Regular.ttf")

	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0, 0, 0, 0.55)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	_root.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			close("hold" if _reg == "" else "done"))

	_card = Control.new()
	_card.draw.connect(_draw_card)
	_root.add_child(_card)
	_list = Control.new()
	_list.draw.connect(_draw_list)
	_root.add_child(_list)
	_plate = Control.new()
	_plate.draw.connect(_draw_plate)
	_root.add_child(_plate)

	_caption = Label.new()
	var ls := LabelSettings.new()
	ls.font = _vt
	ls.font_size = 30
	ls.font_color = Color(0.9, 0.9, 0.85)
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 0.8)
	_caption.label_settings = ls
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.offset_left = -500
	_caption.offset_right = 500
	_caption.offset_top = 24
	_caption.offset_bottom = 96
	_root.add_child(_caption)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 30)
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_buttons.offset_left = -520
	_buttons.offset_right = 520
	_buttons.offset_top = -90
	_buttons.offset_bottom = -36
	_root.add_child(_buttons)
	get_viewport().size_changed.connect(_layout)


func _button(text: String, color: Color, choice: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(240, 50)
	b.add_theme_font_override("font", _vt)
	b.add_theme_font_size_override("font_size", 30)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color.darkened(0.55 if st == "normal" else 0.3)
		sb.border_color = color
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	b.pressed.connect(func(): close(choice))
	_buttons.add_child(b)


## Show a staff ID card next to tonight's list.
func show_id(person: Dictionary, staff_list: Array, date_text: String) -> void:
	_person = person
	_staff_list = staff_list
	_date_text = date_text
	_reg = ""
	_open("Check the card against tonight's list. Name on the list, card in date.")
	_card.visible = true
	_list.visible = true
	_plate.visible = false
	_button("HAND IT BACK - OK", Color(0.3, 0.8, 0.35), "ok")
	_button("HOLD ON TO IT", Color(0.75, 0.75, 0.7), "hold")
	_button("REFUSE ENTRY", Color(0.9, 0.25, 0.2), "refuse")


## Show the car's number plate (you lean to the glass and read it).
func show_plate(reg: String) -> void:
	_reg = reg
	_open("You lean to the glass and read the plate.")
	_card.visible = false
	_list.visible = false
	_plate.visible = true
	_button("DONE", Color(0.75, 0.75, 0.7), "done")


func _open(caption: String) -> void:
	for c in _buttons.get_children():
		c.queue_free()
	_caption.text = caption + ("\nEsc / right click: keep hold of it and decide later." if _reg == "" else "")
	_root.visible = true
	is_open = true
	opened.emit()
	_layout()


func close(choice := "back") -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	closed.emit(choice)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close("hold" if _reg == "" else "done")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		close("hold" if _reg == "" else "done")


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := clampf(vs.y / 720.0, 0.6, 2.0)
	var card_size := Vector2(520, 330) * s
	var list_size := Vector2(380, 470) * s
	var total := card_size.x + 40 * s + list_size.x
	var x0 := (vs.x - total) * 0.5
	_card.position = Vector2(x0, vs.y * 0.5 - card_size.y * 0.5 - 20 * s)
	_card.size = card_size
	_card.scale = Vector2.ONE
	_list.position = Vector2(x0 + card_size.x + 40 * s, vs.y * 0.5 - list_size.y * 0.5 - 10 * s)
	_list.size = list_size
	_plate.size = Vector2(720, 160) * s
	_plate.position = (vs - _plate.size) * 0.5
	_card.set_meta("s", s)
	_list.set_meta("s", s)
	_plate.set_meta("s", s)
	_card.queue_redraw()
	_list.queue_redraw()
	_plate.queue_redraw()


# ------------------------------------------------------------------ drawing
func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, from := 0.0, to := TAU) -> void:
	var pts := PackedVector2Array()
	var n := 28
	if to - from < TAU - 0.01:
		pts.append(c)
	for i in n + 1:
		var a := lerpf(from, to, float(i) / n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts, col)


func _draw_card() -> void:
	var ci := _card
	var s: float = ci.get_meta("s", 1.0)
	var p: Dictionary = _person
	var sz := ci.size
	var org: String = p.get("org", "ASHFORD GENERAL HOSPITAL")
	var band: Color = p.get("card_color", Color(0.1, 0.25, 0.6))
	# Card with rounded corners and a shadow.
	ci.draw_rect(Rect2(Vector2(8, 10) * s, sz), Color(0, 0, 0, 0.5))
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.95, 0.94, 0.9))
	ci.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, 62 * s)), band)
	ci.draw_string(_bold, Vector2(20, 30) * s, org, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * s), Color.WHITE)
	ci.draw_string(_sans, Vector2(20, 52) * s, "STAFF IDENTITY CARD  -  NOT TRANSFERABLE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s), Color(0.85, 0.9, 1.0))
	# Photo.
	var ph := Rect2(Vector2(20, 78) * s, Vector2(140, 172) * s)
	ci.draw_rect(ph, Color(0.62, 0.72, 0.8))
	var skin: Color = p.get("skin", Color(0.85, 0.66, 0.52))
	var hair: Color = p.get("hair", Color(0.2, 0.14, 0.08))
	var shirt: Color = p.get("shirt", Color(0.25, 0.3, 0.45))
	var cx := ph.position.x + ph.size.x * 0.5
	var long_hair: bool = p.get("hair_style", "short") == "long"
	if long_hair:
		_ellipse(ci, Vector2(cx, ph.position.y + 92 * s), Vector2(50, 62) * s, hair.darkened(0.15))
	_ellipse(ci, Vector2(cx, ph.end.y + 10 * s), Vector2(64, 50) * s, shirt, PI, TAU)
	ci.draw_rect(Rect2(Vector2(cx - 13 * s, ph.position.y + 112 * s), Vector2(26, 26) * s), skin.darkened(0.12))
	_ellipse(ci, Vector2(cx, ph.position.y + 82 * s), Vector2(36, 46) * s, skin)
	_ellipse(ci, Vector2(cx, ph.position.y + 52 * s), Vector2(39, 26) * s, hair, PI, TAU)
	if not long_hair:
		ci.draw_rect(Rect2(Vector2(cx - 39 * s, ph.position.y + 50 * s), Vector2(8, 22) * s), hair)
		ci.draw_rect(Rect2(Vector2(cx + 31 * s, ph.position.y + 50 * s), Vector2(8, 22) * s), hair)
	for ex in [-14.0, 14.0]:
		ci.draw_circle(Vector2(cx + ex * s, ph.position.y + 80 * s), 3.2 * s, Color(0.1, 0.08, 0.06))
		ci.draw_line(Vector2(cx + (ex - 7) * s, ph.position.y + 70 * s), Vector2(cx + (ex + 7) * s, ph.position.y + 70 * s), hair.darkened(0.2), 2.5 * s)
	if p.get("glasses", false):
		for ex in [-14.0, 14.0]:
			ci.draw_arc(Vector2(cx + ex * s, ph.position.y + 80 * s), 10 * s, 0, TAU, 16, Color(0.08, 0.08, 0.08), 2.0 * s)
		ci.draw_line(Vector2(cx - 4 * s, ph.position.y + 80 * s), Vector2(cx + 4 * s, ph.position.y + 80 * s), Color(0.08, 0.08, 0.08), 2.0 * s)
	if p.get("moustache", false):
		ci.draw_rect(Rect2(Vector2(cx - 12 * s, ph.position.y + 100 * s), Vector2(24, 5) * s), hair)
	ci.draw_line(Vector2(cx - 9 * s, ph.position.y + 108 * s), Vector2(cx + 9 * s, ph.position.y + 108 * s), skin.darkened(0.45), 2.0 * s)
	ci.draw_rect(ph, Color(0.2, 0.2, 0.2), false, 2.0 * s)

	# Details.
	var x := 182.0 * s
	var y := 96.0 * s
	var rows := [["NAME", p.get("name", "")], ["POSITION", p.get("role", "")], ["DEPARTMENT", p.get("dept", "")],
		["STAFF No.", p.get("staff_no", "")], ["EXPIRES", p.get("expires", "")]]
	for r in rows:
		ci.draw_string(_sans, Vector2(x, y), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color(0.4, 0.4, 0.42))
		ci.draw_string(_bold, Vector2(x, y + 22 * s), str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, sz.x - x - 14 * s, int(20 * s), Color(0.1, 0.1, 0.12))
		y += 44 * s
	# Signature.
	var sig := PackedVector2Array()
	var sx := 30.0 * s
	for i in 30:
		sig.append(Vector2(sx + i * 4.0 * s, (288 + sin(i * 1.3 + p.get("name", "").length()) * 7 + cos(i * 0.7) * 4) * s))
	ci.draw_polyline(sig, Color(0.1, 0.12, 0.35), 1.6 * s)
	ci.draw_string(_sans, Vector2(30, 316) * s, "Holder's signature", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * s), Color(0.4, 0.4, 0.42))
	# Water damage (some cards have been somewhere wet).
	if p.get("stained", false):
		var rng := RandomNumberGenerator.new()
		rng.seed = 29
		for i in 7:
			var c := Vector2(rng.randf_range(0, sz.x), rng.randf_range(0, sz.y))
			_ellipse(ci, c, Vector2(rng.randf_range(30, 90), rng.randf_range(20, 60)) * s, Color(0.45, 0.4, 0.25, 0.18))
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.3, 0.3, 0.3), false, 2.0 * s)


func _draw_list() -> void:
	var ci := _list
	var s: float = ci.get_meta("s", 1.0)
	var sz := ci.size
	# Clipboard.
	ci.draw_rect(Rect2(Vector2(-14, -14) * s, sz + Vector2(28, 28) * s), Color(0.42, 0.3, 0.18))
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.93, 0.92, 0.86))
	ci.draw_rect(Rect2(Vector2(sz.x * 0.5 - 50 * s, -22 * s), Vector2(100, 30) * s), Color(0.7, 0.7, 0.68))
	ci.draw_string(_bold, Vector2(18, 44) * s, "NIGHT STAFF - CAR PARK C", HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * s), Color(0.1, 0.1, 0.12))
	ci.draw_string(_sans, Vector2(18, 66) * s, _date_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(0.3, 0.3, 0.32))
	var y := 100.0 * s
	for e in _staff_list:
		ci.draw_string(_mono, Vector2(18 * s, y), "%-18s %s" % [e.name, e.staff_no], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s), Color(0.12, 0.12, 0.2))
		ci.draw_string(_sans, Vector2(18 * s, y + 18 * s), e.dept, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * s), Color(0.35, 0.35, 0.4))
		ci.draw_line(Vector2(14 * s, y + 27 * s), Vector2(sz.x - 14 * s, y + 27 * s), Color(0.6, 0.7, 0.85, 0.6), 1.0)
		y += 50 * s
	ci.draw_string(_sans, Vector2(18 * s, sz.y - 20 * s), "Cards must be in date. No list, no entry. - D.W.", HORIZONTAL_ALIGNMENT_LEFT, sz.x - 30 * s, int(12 * s), Color(0.6, 0.1, 0.1))


func _draw_plate() -> void:
	var ci := _plate
	var s: float = ci.get_meta("s", 1.0)
	var sz := ci.size
	ci.draw_rect(Rect2(Vector2(-10, -10) * s, sz + Vector2(20, 20) * s), Color(0.05, 0.05, 0.05))
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.96, 0.8, 0.12))
	var fs := int(110 * s)
	var w := _bold.get_string_size(_reg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(_bold, Vector2((sz.x - w) * 0.5, sz.y * 0.5 + fs * 0.36), _reg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.05, 0.05))
	# Dirt and rain.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_reg)
	for i in 40:
		ci.draw_circle(Vector2(rng.randf() * sz.x, rng.randf() * sz.y), rng.randf_range(1, 4) * s, Color(0.3, 0.25, 0.1, 0.25))
