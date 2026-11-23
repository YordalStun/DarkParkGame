extends CanvasLayer
## Close-up overlays for the story: a staff ID card held up beside tonight's list, and
## a number plate, and the vehicle log clipboard (type the reg, pick the name, log it).
## Emits `closed(choice)`: "ok" / "hold" / "refuse" for an ID, "done" / "log" for a plate,
## "done" for the vehicle log.

signal closed(choice: String)
signal opened

var is_open := false
var mode := ""            ## "id" | "plate" | "log" | "notes"
var _next_mode := ""
var _id_car := ""         ## night two: the plate of the car the driver is in, shown above the card
var _notes_box: Label     ## your notepad, stuck beside the ID card
var _notes: Control       ## the notepad screen
var _notes_edit: TextEdit
var _notes_cb: Callable
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
var _log: Control            ## the vehicle log clipboard (built on first use)
var _log_names: VBoxContainer
var _log_reg: LineEdit
var _log_name: Label
var _log_status: Label
var _log_list: Label
var smudge := false          ## rain-soaked paperwork: water stains over the ID card and the list (night two on)
var _page: Control           ## the logbook page (previous operator's notes and doodles)
var _log_pick := ""
var _log_cb: Callable        ## func(reg, name)
var _log_entries: Callable   ## func() -> Array of {time, reg, name}


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
			close("hold" if mode == "id" else "done"))

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
func show_id(person: Dictionary, staff_list: Array, date_text: String, car_reg := "", notes := "") -> void:
	_person = person
	_staff_list = staff_list
	_date_text = date_text
	_reg = ""
	_id_car = car_reg
	_next_mode = "id"
	_open("Check the card against tonight's list. Name on the list, card in date." +
		("\nThe car's plate (top) must match the reg on the list." if car_reg != "" else ""))
	mode = "id"
	_card.visible = true
	_list.visible = true
	_plate.visible = car_reg != ""
	_show_notes_box(notes)
	_set_smudges(_card, smudge, hash(str(person.get("name", ""))), 340, 216, 0.55)
	_set_smudges(_list, smudge, 7, 250, 310, 0.5)
	_layout()
	_button("HAND IT BACK - OK", Color(0.3, 0.8, 0.35), "ok")
	_button("HOLD ON TO IT", Color(0.75, 0.75, 0.7), "hold")
	_button("REFUSE ENTRY", Color(0.9, 0.25, 0.2), "refuse")


## Show the car's number plate (you lean to the glass and read it).
func show_plate(reg: String) -> void:
	_reg = reg
	_id_car = ""
	_next_mode = "plate"
	_open("You lean to the glass and read the plate.")
	mode = "plate"
	_card.visible = false
	_list.visible = false
	_plate.visible = true
	if _log_ready:
		_button("LOG THIS CAR", Color(0.91, 0.75, 0.44), "log")
	_button("DONE", Color(0.75, 0.75, 0.7), "done")


var _log_ready := false   ## the story has hooked up the vehicle log


## The vehicle log clipboard. `reg` is the plate of the car at the window ("" if none),
## shown as a close-up at the top so you can copy it straight across.
func show_log(reg: String, staff_list: Array, date_text: String, on_log: Callable, get_entries: Callable) -> void:
	_reg = reg
	_staff_list = staff_list
	_date_text = date_text
	_log_cb = on_log
	_log_entries = get_entries
	_id_car = ""
	_next_mode = "log"
	_open("Type the plate, click the driver's name, then LOG ENTRY.")
	mode = "log"
	_card.visible = false
	_list.visible = false
	_plate.visible = reg != ""
	if _log == null:
		_build_log()
	_log.visible = true
	_log_pick = ""
	_fill_log()
	_button("DONE", Color(0.75, 0.75, 0.7), "done")
	_layout()
	_log_reg.text = ""
	_log_reg.grab_focus.call_deferred()


func _build_log() -> void:
	_log = Control.new()
	_log.size = Vector2(900, 440)
	_root.add_child(_log)
	var paper := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.93, 0.92, 0.86)
	sb.border_color = Color(0.42, 0.3, 0.18)
	sb.set_border_width_all(12)
	paper.add_theme_stylebox_override("panel", sb)
	paper.size = Vector2(900, 440)
	_log.add_child(paper)
	var ink := Color(0.12, 0.12, 0.2)
	var t := _paper_label("VEHICLE LOG  -  LOT C, BOOTH 2", _bold, 22, ink)
	t.position = Vector2(30, 22)
	var d := _paper_label("", _sans, 15, Color(0.35, 0.35, 0.38))
	d.position = Vector2(32, 52)
	d.name = "Date"
	var lt := _paper_label("TONIGHT'S LIST  (click a name)", _bold, 15, Color(0.4, 0.3, 0.2))
	lt.position = Vector2(30, 86)
	_log_names = VBoxContainer.new()
	_log_names.position = Vector2(26, 110)
	_log_names.size = Vector2(400, 300)
	_log_names.add_theme_constant_override("separation", 2)
	_log.add_child(_log_names)
	var rl := _paper_label("REG", _bold, 15, Color(0.4, 0.3, 0.2))
	rl.position = Vector2(470, 86)
	_log_reg = LineEdit.new()
	_log_reg.position = Vector2(466, 108)
	_log_reg.size = Vector2(300, 52)
	_log_reg.max_length = 9
	_log_reg.placeholder_text = "E123 ABC"
	_log_reg.add_theme_font_override("font", _mono)
	_log_reg.add_theme_font_size_override("font_size", 32)
	_log_reg.add_theme_color_override("font_color", ink)
	_log_reg.add_theme_color_override("font_placeholder_color", Color(0.6, 0.6, 0.6))
	_log_reg.add_theme_color_override("caret_color", ink)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(1, 1, 0.97)
	fsb.border_color = Color(0.5, 0.5, 0.55)
	fsb.border_width_bottom = 2
	fsb.content_margin_left = 10
	_log_reg.add_theme_stylebox_override("normal", fsb)
	_log_reg.add_theme_stylebox_override("focus", fsb)
	_log_reg.text_changed.connect(func(tx):
		var c := _log_reg.caret_column
		_log_reg.text = tx.to_upper()
		_log_reg.caret_column = c)
	_log_reg.text_submitted.connect(func(_t): _do_log())
	_log.add_child(_log_reg)
	var nl := _paper_label("NAME", _bold, 15, Color(0.4, 0.3, 0.2))
	nl.position = Vector2(470, 172)
	_log_name = _paper_label("-  click one on the left  -", _mono, 18, Color(0.45, 0.45, 0.5))
	_log_name.position = Vector2(470, 194)
	var b := Button.new()
	b.text = "LOG ENTRY"
	b.focus_mode = Control.FOCUS_NONE
	b.position = Vector2(466, 232)
	b.size = Vector2(200, 44)
	b.add_theme_font_override("font", _vt)
	b.add_theme_font_size_override("font_size", 28)
	for st in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.18, 0.3, 0.2) if st != "hover" else Color(0.24, 0.42, 0.28)
		bs.set_corner_radius_all(3)
		b.add_theme_stylebox_override(st, bs)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	b.pressed.connect(_do_log)
	_log.add_child(b)
	_log_status = _paper_label("", _sans, 16, Color(0.15, 0.45, 0.2))
	_log_status.position = Vector2(680, 244)
	var ll := _paper_label("LOGGED TONIGHT", _bold, 15, Color(0.4, 0.3, 0.2))
	ll.position = Vector2(470, 292)
	_log_list = _paper_label("", _mono, 15, ink)
	_log_list.position = Vector2(470, 314)
	_log_list.size = Vector2(410, 110)
	_log_list.clip_text = true


func _paper_label(text: String, f: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	_log.add_child(l)
	return l


func _fill_log() -> void:
	(_log.get_node("Date") as Label).text = _date_text
	for c in _log_names.get_children():
		c.queue_free()
	for e in _staff_list:
		var b := Button.new()
		b.text = "  %-18s %s" % [e.name, e.staff_no]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = e.name == _log_pick
		b.add_theme_font_override("font", _mono)
		b.add_theme_font_size_override("font_size", 17)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var bs := StyleBoxFlat.new()
			bs.bg_color = Color(0, 0, 0, 0) if st == "normal" else (Color(0.98, 0.85, 0.3, 0.8) if st.contains("pressed") else Color(0, 0, 0, 0.06))
			b.add_theme_stylebox_override(st, bs)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color(0.12, 0.12, 0.2))
		var who: String = e.name
		b.pressed.connect(func():
			_log_pick = who
			_log_name.text = who
			_log_name.add_theme_color_override("font_color", Color(0.12, 0.12, 0.2))
			_fill_log())
		_log_names.add_child(b)
	var lines := []
	var all: Array = _log_entries.call() if _log_entries.is_valid() else []
	for i in range(maxi(0, all.size() - 5), all.size()):
		lines.append("%s  %-9s %s" % [all[i].time, all[i].reg, all[i].name])
	_log_list.text = "\n".join(lines) if not lines.is_empty() else "(nothing yet)"


func _do_log() -> void:
	var reg := _log_reg.text.strip_edges()
	if reg.length() < 3:
		_log_status.text = "Type the plate first."
		_log_status.add_theme_color_override("font_color", Color(0.7, 0.2, 0.15))
		return
	if _log_pick == "":
		_log_status.text = "Click the driver's name."
		_log_status.add_theme_color_override("font_color", Color(0.7, 0.2, 0.15))
		return
	_log_cb.call(reg, _log_pick)
	_log_status.text = "Logged %s." % reg
	_log_status.add_theme_color_override("font_color", Color(0.15, 0.45, 0.2))
	_log_reg.text = ""
	_log_pick = ""
	_log_name.text = "-  click one on the left  -"
	_log_name.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	_fill_log()


## Your notepad: a lined pad you type on. on_change(text) is called as you type.
func show_notes(text: String, on_change: Callable) -> void:
	_id_car = ""
	_reg = "-"
	_next_mode = "notes"
	_open("Your notepad. Type anything. Esc, N or DONE to put it down.")
	mode = "notes"
	_card.visible = false
	_list.visible = false
	_plate.visible = false
	if _notes == null:
		_build_notes()
	_notes_cb = on_change
	_notes_edit.text = text
	_notes.visible = true
	_button("DONE", Color(0.75, 0.75, 0.7), "done")
	_layout()
	_notes_edit.grab_focus.call_deferred()
	_notes_edit.set_caret_line.call_deferred(_notes_edit.get_line_count() - 1)


func _build_notes() -> void:
	_notes = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.93, 0.55)
	sb.border_color = Color(0.75, 0.2, 0.15)
	sb.border_width_top = 26
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.6)
	_notes.add_theme_stylebox_override("panel", sb)
	_notes.size = Vector2(560, 480)
	_root.add_child(_notes)
	_notes_edit = TextEdit.new()
	_notes_edit.position = Vector2(30, 46)
	_notes_edit.size = Vector2(500, 410)
	_notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_notes_edit.placeholder_text = "e.g.  Janet Lowe OFF tonight.  Kevin Platt ON - van B908 RWD"
	_notes_edit.add_theme_font_override("font", load("res://assets/fonts/LiberationSerif-Italic.ttf"))
	_notes_edit.add_theme_font_size_override("font_size", 26)
	_notes_edit.add_theme_color_override("font_color", Color(0.1, 0.12, 0.35))
	_notes_edit.add_theme_color_override("font_placeholder_color", Color(0.45, 0.42, 0.3, 0.7))
	_notes_edit.add_theme_color_override("caret_color", Color(0.1, 0.12, 0.35))
	_notes_edit.add_theme_constant_override("line_spacing", 10)
	var clear := StyleBoxEmpty.new()
	_notes_edit.add_theme_stylebox_override("normal", clear)
	_notes_edit.add_theme_stylebox_override("focus", clear)
	_notes_edit.text_changed.connect(func():
		if _notes_cb.is_valid():
			_notes_cb.call(_notes_edit.text))
	_notes.add_child(_notes_edit)
	# Ruled lines.
	_notes.draw.connect(func():
		for i in 10:
			var y := 46.0 + 8.0 + (i + 1) * 40.5
			if y > _notes.size.y - 12:
				break
			_notes.draw_line(Vector2(20, y), Vector2(540, y), Color(0.55, 0.6, 0.8, 0.5), 1.0)
		_notes.draw_line(Vector2(24, 26), Vector2(24, 470), Color(0.85, 0.3, 0.25, 0.6), 1.0))


## Your notes as a sticky note under the ID card (only if you've written anything).
func _show_notes_box(text: String) -> void:
	if _notes_box == null:
		_notes_box = Label.new()
		_notes_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_notes_box.add_theme_font_override("font", load("res://assets/fonts/LiberationSerif-Italic.ttf"))
		_notes_box.add_theme_color_override("font_color", Color(0.1, 0.12, 0.35))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.98, 0.93, 0.55)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.shadow_size = 8
		sb.shadow_color = Color(0, 0, 0, 0.5)
		_notes_box.add_theme_stylebox_override("normal", sb)
		_notes_box.max_lines_visible = 3
		_root.add_child(_notes_box)
	_notes_box.text = "MY NOTES:\n" + text.strip_edges()
	_notes_box.visible = text.strip_edges() != ""


func _open(caption: String) -> void:
	if _page:
		_page.visible = false
	if _notes:
		_notes.visible = false
	if _notes_box:
		_notes_box.visible = false
	if _log:
		_log.visible = false
	if _log_status:
		_log_status.text = ""
	for c in _buttons.get_children():
		c.queue_free()
	_caption.text = caption + ("\nEsc / right click: keep hold of it and decide later." if _next_mode == "id" else "")
	_root.visible = true
	is_open = true
	opened.emit()
	_layout()


func close(choice := "back") -> void:
	if not is_open:
		return
	is_open = false
	mode = ""
	_root.visible = false
	closed.emit(choice)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close("hold" if mode == "id" else "done")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		close("hold" if mode == "id" else "done")


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := clampf(vs.y / 720.0, 0.6, 2.0)
	var card_size := Vector2(520, 330) * s
	var list_size := Vector2(380, 470) * s
	var total := card_size.x + 40 * s + list_size.x
	var x0 := (vs.x - total) * 0.5
	var drop := 46.0 * s if _id_car != "" else 0.0   # room for the car's plate above
	_card.position = Vector2(x0, vs.y * 0.5 - card_size.y * 0.5 - 30 * s + drop)
	_card.size = card_size
	_card.scale = Vector2.ONE
	_list.position = Vector2(x0 + card_size.x + 40 * s, vs.y * 0.5 - list_size.y * 0.5 - 10 * s + drop * 0.5)
	_list.size = list_size
	_plate.size = Vector2(720, 160) * s
	_plate.position = (vs - _plate.size) * 0.5
	if _id_car != "":
		_plate.size = Vector2(300, 66) * s
		_plate.position = Vector2(x0 + (card_size.x - _plate.size.x) * 0.5, _card.position.y - _plate.size.y - 16 * s)
	if _notes_box and _notes_box.visible:
		_notes_box.add_theme_font_size_override("font_size", int(17 * s))
		_notes_box.position = Vector2(x0, _card.position.y + card_size.y + 14 * s)
		_notes_box.custom_minimum_size = Vector2(card_size.x, 0)
		_notes_box.size = Vector2(card_size.x, 0)
		_notes_box.reset_size.call_deferred()
	if _notes and _notes.visible:
		var ns := s * 0.95
		_notes.scale = Vector2(ns, ns)
		_notes.position = (vs - _notes.size * ns) * 0.5 + Vector2(0, 10 * s)
	if _page and _page.visible:
		var ps := s * 0.95
		_page.scale = Vector2(ps, ps)
		_page.position = (vs - _page.size * ps) * 0.5
	if _log and _log.visible:
		# Clipboard under a smaller plate close-up.
		var ls := s * 0.95
		_log.scale = Vector2(ls, ls)
		var top := 112.0 * s if _plate.visible else 0.0
		_log.position = Vector2((vs.x - 900 * ls) * 0.5, (vs.y - 440 * ls + top) * 0.5 + 10 * s)
		_plate.size = Vector2(430, 96) * s
		_plate.position = Vector2((vs.x - _plate.size.x) * 0.5, _log.position.y - _plate.size.y - 16 * s)
	_card.set_meta("s", s)
	_list.set_meta("s", s)
	_plate.set_meta("s", s)
	_card.queue_redraw()
	_list.queue_redraw()
	_plate.queue_redraw()


# ------------------------------------------------------------------ water stains
## Rain-soaked paper: water damage drawn as a texture over `parent` (the ID card or the list):
## irregular tide-marked stains, faded ink patches, ink that has run in streaks, beads of water
## and damp edges. The same seed always gives the same damage.
func _set_smudges(parent: Control, on: bool, seed_v: int, w: int, h: int, coverage: float) -> void:
	var old := parent.get_node_or_null("Smudge")
	if old:
		old.queue_free()
	if not on:
		return
	var tr := TextureRect.new()
	tr.name = "Smudge"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.texture = _stain_texture(w, h, seed_v, coverage)
	parent.add_child(tr)


func _stain_texture(w: int, h: int, seed_v: int, coverage: float) -> ImageTexture:
	var big := FastNoiseLite.new()
	big.seed = seed_v
	big.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	big.frequency = 0.011
	big.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = seed_v + 11
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.frequency = 0.09
	var wash := FastNoiseLite.new()
	wash.seed = seed_v + 29
	wash.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wash.frequency = 0.02
	wash.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := PackedFloat32Array()      # how stained each pixel is (0..1), kept for the streaks
	body.resize(w * h)
	var thr := 0.34 - coverage * 0.5
	for y in h:
		for x in w:
			var v := big.get_noise_2d(x, y) + 0.12 * fine.get_noise_2d(x, y)
			var inside := smoothstep(thr - 0.05, thr + 0.12, v)
			body[y * w + x] = inside
			# The tide line: a thin darker band right at the edge of each stain, broken up by fine noise.
			var tide := exp(-pow((v - thr) / 0.03, 2.0)) * (0.55 + 0.45 * fine.get_noise_2d(x * 1.7, y * 1.7))
			# Faded ink: patches where the print has washed out (paler than the paper).
			var fade := smoothstep(0.18, 0.5, wash.get_noise_2d(x, y)) * inside
			# Damp, slightly dark edges of the paper.
			var edge_d := float(mini(mini(x, y), mini(w - 1 - x, h - 1 - y)))
			var damp := exp(-edge_d / 9.0) * smoothstep(-0.2, 0.2, v) * 0.5
			var a_stain := inside * (0.1 + 0.08 * fine.get_noise_2d(x * 0.6, y * 0.6))
			var a_tide := clampf(tide, 0.0, 1.0) * 0.38
			var a_fade := fade * 0.42
			var a_damp := damp * 0.3
			# Composite: damp edge and stain (grey-brown), then the tide line (darker), then the fade (pale).
			var col := Color(0.36, 0.35, 0.33)
			var a := clampf(a_stain + a_damp, 0.0, 0.6)
			col = col.lerp(Color(0.27, 0.22, 0.16), clampf(a_tide / maxf(a + a_tide, 0.001), 0.0, 1.0))
			a = clampf(a + a_tide * (1.0 - a), 0.0, 0.7)
			col = col.lerp(Color(0.96, 0.95, 0.9), clampf(a_fade / maxf(a + a_fade, 0.001), 0.0, 1.0))
			a = clampf(a + a_fade * (1.0 - a), 0.0, 0.75)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	# Ink that has run: faint blue-grey streaks trickling down from inside the stains.
	for i in int(7 + coverage * 14):
		var sx := rng.randi_range(4, w - 5)
		var sy := rng.randi_range(4, h - 30)
		if body[sy * w + sx] < 0.6:
			continue
		var len := rng.randi_range(14, mini(70, h - sy - 2))
		var wd := rng.randi_range(1, 2)
		var drift := rng.randf_range(-0.12, 0.12)
		for t in len:
			var px := int(sx + t * drift)
			var py := sy + t
			var fa := 0.2 * (1.0 - float(t) / len)
			for dx in wd:
				if px + dx >= 0 and px + dx < w and py < h:
					var c := img.get_pixel(px + dx, py)
					img.set_pixel(px + dx, py, Color(0.18, 0.2, 0.36, clampf(c.a + fa, 0.0, 0.8)).lerp(c, 0.25))
	# Beads of water: a pale centre with a bright highlight and a dark ring, scattered over the stains.
	for i in int(14 + coverage * 40):
		var cx := rng.randi_range(8, w - 9)
		var cy := rng.randi_range(8, h - 9)
		if body[cy * w + cx] < 0.25 and rng.randf() > 0.2:
			continue
		var r := rng.randf_range(2.0, 5.5)
		for dy in range(-int(r) - 2, int(r) + 3):
			for dx in range(-int(r) - 2, int(r) + 3):
				var px := cx + dx
				var py := cy + dy
				if px < 0 or py < 0 or px >= w or py >= h:
					continue
				var d := Vector2(dx, dy).length()
				var c := img.get_pixel(px, py)
				if d <= r:
					var lit := clampf(1.0 - (Vector2(dx, dy) - Vector2(-r * 0.35, -r * 0.35)).length() / (r * 0.9), 0.0, 1.0)
					c = c.lerp(Color(0.97, 0.97, 0.95), 0.14 + 0.5 * lit * lit)
					c.a = maxf(c.a, 0.3 + 0.35 * lit)
				elif d <= r + 1.4:
					c = c.lerp(Color(0.22, 0.2, 0.18), 0.55)
					c.a = maxf(c.a, 0.45)
				else:
					continue
				img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ logbook page
## A page from the logbook: the previous operator's notes and little drawings, read only.
func show_page(title: String, body: String, doodles := true) -> void:
	_id_car = ""
	_reg = "-"
	_next_mode = "page"
	_open("Right click, Esc or DONE to put it down.")
	mode = "page"
	_card.visible = false
	_list.visible = false
	_plate.visible = false
	if _page == null:
		_build_page()
	(_page.get_node("Title") as Label).text = title
	(_page.get_node("Body") as RichTextLabel).text = body
	_page.set_meta("doodles", doodles)
	_page.visible = true
	_page.queue_redraw()
	_button("DONE", Color(0.75, 0.75, 0.7), "done")
	_layout()


func _build_page() -> void:
	_page = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.9, 0.87, 0.76)
	sb.border_color = Color(0.4, 0.28, 0.16)
	sb.set_border_width_all(10)
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.6)
	_page.add_theme_stylebox_override("panel", sb)
	_page.size = Vector2(760, 520)
	_root.add_child(_page)
	var t := Label.new()
	t.name = "Title"
	t.add_theme_font_override("font", _bold)
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1))
	t.position = Vector2(34, 20)
	_page.add_child(t)
	var b := RichTextLabel.new()
	b.name = "Body"
	b.bbcode_enabled = true
	b.scroll_active = false
	b.position = Vector2(40, 62)
	b.size = Vector2(500, 430)
	for n in ["normal_font", "italics_font", "bold_font"]:
		b.add_theme_font_override(n, load("res://assets/fonts/LiberationSerif-Italic.ttf"))
	b.add_theme_font_size_override("normal_font_size", 23)
	b.add_theme_font_size_override("italics_font_size", 23)
	b.add_theme_font_size_override("bold_font_size", 23)
	b.add_theme_color_override("default_color", Color(0.12, 0.14, 0.38))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(b)
	_page.draw.connect(func():
		# Ruled lines and a margin.
		for i in 11:
			_page.draw_line(Vector2(24, 92 + i * 38), Vector2(736, 92 + i * 38), Color(0.55, 0.6, 0.8, 0.35), 1.0)
		_page.draw_line(Vector2(30, 14), Vector2(30, 506), Color(0.85, 0.3, 0.25, 0.5), 1.0)
		if not _page.get_meta("doodles", true):
			return
		var ink := Color(0.1, 0.12, 0.35, 0.85)
		# A little car with a question mark over it, in the right margin.
		_page.draw_rect(Rect2(570, 300, 130, 34), ink, false, 2.0)
		_page.draw_polyline(PackedVector2Array([Vector2(590, 300), Vector2(606, 276), Vector2(664, 276), Vector2(682, 300)]), ink, 2.0)
		_page.draw_arc(Vector2(596, 336), 11, 0, TAU, 14, ink, 2.0)
		_page.draw_arc(Vector2(676, 336), 11, 0, TAU, 14, ink, 2.0)
		_page.draw_arc(Vector2(636, 236), 16, -PI * 0.9, PI * 0.5, 14, ink, 2.0)   # the "?"
		_page.draw_line(Vector2(636, 252), Vector2(636, 262), ink, 2.0)
		_page.draw_circle(Vector2(636, 270), 2.0, ink)
		# A big letter C ringed twice, with an arrow to the car.
		_page.draw_arc(Vector2(630, 420), 28, PI * 0.2, PI * 1.8, 18, ink, 3.0)
		_page.draw_arc(Vector2(630, 420), 44, 0.0, TAU, 24, Color(ink, 0.6), 1.5)
		_page.draw_line(Vector2(630, 372), Vector2(634, 346), ink, 2.0)
		_page.draw_line(Vector2(634, 346), Vector2(626, 354), ink, 2.0)
		_page.draw_line(Vector2(634, 346), Vector2(640, 355), ink, 2.0)
		# Stars and a rain cloud.
		for sp in [Vector2(580, 476), Vector2(700, 470), Vector2(560, 150), Vector2(716, 120)]:
			_page.draw_line(sp + Vector2(-7, 0), sp + Vector2(7, 0), ink, 1.5)
			_page.draw_line(sp + Vector2(0, -7), sp + Vector2(0, 7), ink, 1.5)
		_page.draw_arc(Vector2(640, 190), 18, PI, TAU, 10, ink, 2.0)
		_page.draw_arc(Vector2(666, 192), 14, PI, TAU, 10, ink, 2.0)
		for rx in [624, 640, 656, 672]:
			_page.draw_line(Vector2(rx, 206), Vector2(rx - 4, 222), ink, 1.5))


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
		if e.has("reg"):
			ci.draw_string(_bold, Vector2(sz.x - 112 * s, y + 18 * s), "CAR: " + e.reg, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * s), Color(0.15, 0.15, 0.35))
		ci.draw_line(Vector2(14 * s, y + 27 * s), Vector2(sz.x - 14 * s, y + 27 * s), Color(0.6, 0.7, 0.85, 0.6), 1.0)
		y += 50 * s
	ci.draw_string(_sans, Vector2(18 * s, sz.y - 20 * s), "Cards must be in date. No list, no entry. - D.W.", HORIZONTAL_ALIGNMENT_LEFT, sz.x - 30 * s, int(12 * s), Color(0.6, 0.1, 0.1))


func _draw_plate() -> void:
	var ci := _plate
	var s: float = ci.get_meta("s", 1.0)
	var sz := ci.size
	ci.draw_rect(Rect2(Vector2(-10, -10) * s, sz + Vector2(20, 20) * s), Color(0.05, 0.05, 0.05))
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.96, 0.8, 0.12))
	var fs := int(sz.y * 0.69)
	var txt := _id_car if mode == "id" else _reg
	var w := _bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string(_bold, Vector2((sz.x - w) * 0.5, sz.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.05, 0.05))
	# Dirt and rain.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(txt)
	for i in 40:
		ci.draw_circle(Vector2(rng.randf() * sz.x, rng.randf() * sz.y), rng.randf_range(1, 4) * s, Color(0.3, 0.25, 0.1, 0.25))
