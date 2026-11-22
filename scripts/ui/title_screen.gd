extends CanvasLayer
## The title screen: CONTINUE, NEW GAME, LOAD and QUIT, with three save slots.
## Same look as the end-of-shift screen. Emits `chosen` once a slot is ready to play.

signal chosen

const DESIGN := Vector2(1280, 720)
const GOLD := Color(0.91, 0.75, 0.44)
const INK := Color(0.85, 0.84, 0.78)
const DIM := Color(0.54, 0.53, 0.49)
const BG := Color(0.03, 0.035, 0.034)

var _font: Font
var _stage: Control
var _menu: VBoxContainer
var _slots: VBoxContainer
var _slots_title: Label
var _mode := ""          ## "load" | "new"
var _rain: Control
var _drops: Array = []
var _confirm := 0        ## slot waiting for an overwrite confirm


func _ready() -> void:
	layer = 60
	_font = load("res://assets/fonts/VT323-Regular.ttf")
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_rain = Control.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	add_child(_rain)
	for i in 140:
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.4)))
	_stage = Control.new()
	_stage.size = DESIGN
	add_child(_stage)
	get_viewport().size_changed.connect(_fit)
	_fit()

	var t := _label("DARK PARK", 120, GOLD)
	t.position = Vector2(90, 70)
	var s := _label("LOT C  -  NIGHT SECURITY  -  OCTOBER 1989", 30, DIM)
	s.position = Vector2(96, 196)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(96, 300)
	_menu.add_theme_constant_override("separation", 10)
	_stage.add_child(_menu)
	var last := SaveGame.latest()
	if last > 0:
		var d := SaveGame.peek(last)
		_menu_button("CONTINUE", func(): _start(last, false), "Slot %d  -  night %d  -  %d coins" % [last, d.night, d.coins])
	_menu_button("NEW GAME", func(): _show_slots("new"))
	if last > 0:
		_menu_button("LOAD", func(): _show_slots("load"))
	_menu_button("QUIT", func(): get_tree().quit())

	_slots_title = _label("", 30, GOLD)
	_slots_title.position = Vector2(620, 300)
	_slots = VBoxContainer.new()
	_slots.position = Vector2(620, 346)
	_slots.add_theme_constant_override("separation", 12)
	_stage.add_child(_slots)
	var ver := _label("v%s  -  build %s" % [ProjectSettings.get_setting("application/config/version", "?"), load("res://scripts/build_info.gd").BUILD], 22, Color(0.35, 0.35, 0.33))
	ver.position = Vector2(96, 676)
	_stage.modulate.a = 0.0
	create_tween().tween_property(_stage, "modulate:a", 1.0, 1.2)


func _label(text: String, size: int, color: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	(parent if parent else _stage).add_child(l)
	return l


func _menu_button(text: String, act: Callable, sub := "") -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_menu.add_child(row)
	var b := _button(text, 40, 300)
	b.pressed.connect(act)
	row.add_child(b)
	if sub != "":
		_label(sub, 24, DIM, row)


func _button(text: String, size: int, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 0)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.bg_color = Color(0, 0, 0, 0) if st in ["normal", "disabled"] else Color(0.91, 0.75, 0.44, 0.14)
		sb.border_color = GOLD if st in ["hover", "pressed"] else Color(0, 0, 0, 0)
		sb.border_width_left = 4
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.33))
	return b


func _show_slots(mode: String) -> void:
	_mode = mode
	_confirm = 0
	_slots_title.text = "START A NEW GAME IN..." if mode == "new" else "LOAD A GAME"
	for c in _slots.get_children():
		c.queue_free()
	for n in range(1, SaveGame.SLOTS + 1):
		var d := SaveGame.peek(n)
		var text := "SLOT %d   " % n
		if d.is_empty():
			text += "- empty -"
		else:
			var mins := int(float(d.playtime) / 60.0)
			text += "Night %d   %d coins   %dh %02dm\n         saved %s" % [d.night, d.coins, mins / 60, mins % 60, str(d.saved).replace("T", " ").left(16)]
		var b := _button(text, 30, 560)
		b.disabled = mode == "load" and d.is_empty()
		var slot := n
		b.pressed.connect(func(): _slot_pressed(slot, b))
		_slots.add_child(b)


func _slot_pressed(n: int, b: Button) -> void:
	if _mode == "load":
		_start(n, false)
		return
	if SaveGame.exists(n) and _confirm != n:
		_confirm = n
		b.text = "SLOT %d   Overwrite this save? Click again." % n
		return
	_start(n, true)


func _start(n: int, fresh: bool) -> void:
	if fresh:
		SaveGame.new_game(n)
	else:
		SaveGame.load_slot(n)
	var tw := create_tween()
	tw.tween_property(_stage, "modulate:a", 0.0, 0.5)
	await tw.finished
	chosen.emit()
	queue_free()


func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := minf(vs.x / DESIGN.x, vs.y / DESIGN.y)
	_stage.scale = Vector2(k, k)
	_stage.position = (vs - DESIGN * k) * 0.5


func _process(delta: float) -> void:
	for i in _drops.size():
		var d: Vector3 = _drops[i]
		d.y += delta * 0.9 * d.z
		if d.y > 1.05:
			d = Vector3(randf(), -0.05, d.z)
		_drops[i] = d
	_rain.queue_redraw()


func _draw_rain() -> void:
	var vs := _rain.size
	for d in _drops:
		var p := Vector2(d.x * vs.x, d.y * vs.y)
		_rain.draw_line(p, p + Vector2(-2, 18 * d.z), Color(0.5, 0.55, 0.6, 0.18 * d.z), 1.0)
