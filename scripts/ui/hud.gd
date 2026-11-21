extends CanvasLayer
## Minimal on-screen UI: what the cursor is pointing at, a pause screen,
## a custom cursor, and an optional weather readout (F9).

var paused := false
var _prompt: Label
var _hint: Label
var _pause: Control
var _debug: Label
var _font: FontFile
var _cursor_dot: ImageTexture
var _cursor_ring: ImageTexture


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load("res://assets/fonts/VT323-Regular.ttf")

	_prompt = _label(30, Color(0.85, 0.85, 0.8, 0.9))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -86
	_prompt.offset_bottom = -50
	_prompt.offset_left = -300
	_prompt.offset_right = 300

	_hint = _label(22, Color(0.6, 0.6, 0.55, 0.8))
	_hint.modulate.a = 0.0
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -46
	_hint.offset_bottom = -20
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.text = "Right click to sit back"

	_debug = _label(20, Color(0.6, 1.0, 0.6, 0.85))
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_debug.position = Vector2(16, 12)
	_debug.visible = false

	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0, 0, 0, 0.72)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause.visible = false
	add_child(_pause)
	var pl := _label(40, Color(0.85, 0.85, 0.8))
	pl.reparent(_pause)
	pl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pl.text = "- PAUSED -\n\nClick to resume\nQ to quit"

	_make_cursors()
	Input.set_custom_mouse_cursor(_cursor_dot, Input.CURSOR_ARROW, Vector2(8, 8))


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = _font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 0.8)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _make_cursors() -> void:
	var dot := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	var ring := Image.create(17, 17, false, Image.FORMAT_RGBA8)
	for y in 17:
		for x in 17:
			var d := Vector2(x - 8, y - 8).length()
			if d <= 1.6:
				dot.set_pixel(x, y, Color(0.9, 0.9, 0.85, 0.9))
			elif d <= 2.8:
				dot.set_pixel(x, y, Color(0, 0, 0, 0.6))
			if d >= 5.0 and d <= 6.4:
				ring.set_pixel(x, y, Color(0.95, 0.95, 0.85, 0.95))
			elif (d > 6.4 and d <= 7.6) or (d >= 3.8 and d < 5.0):
				ring.set_pixel(x, y, Color(0, 0, 0, 0.55))
			if d <= 1.2:
				ring.set_pixel(x, y, Color(0.95, 0.95, 0.85, 0.95))
	_cursor_dot = ImageTexture.create_from_image(dot)
	_cursor_ring = ImageTexture.create_from_image(ring)


func set_prompt(text: String) -> void:
	_prompt.text = text.to_upper()
	Input.set_custom_mouse_cursor(_cursor_ring if text != "" else _cursor_dot, Input.CURSOR_ARROW, Vector2(8, 8))


## The sit-back hint normally sits at the bottom; while the desktop is up it moves above the
## screen so it doesn't cover the taskbar.
func set_hint(text: String, top := false) -> void:
	_hint.text = text
	if top:
		_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_hint.offset_top = 12
		_hint.offset_bottom = 38
	else:
		_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_hint.offset_top = -46
		_hint.offset_bottom = -20
	_hint.offset_left = -300
	_hint.offset_right = 300


func set_zoomed(z: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_hint, "modulate:a", 1.0 if z else 0.0, 0.5)


func set_paused(p: bool) -> void:
	paused = p
	_pause.visible = p
	get_tree().paused = p


func toggle_debug() -> void:
	_debug.visible = not _debug.visible


func _process(_delta: float) -> void:
	if _debug.visible:
		_debug.text = "WEATHER %s%s\nrain %.2f  wind %.2f  fog %.2f  wet %.2f\ntime %s   fps %d" % [
			Weather.profile, " (HEAVY)" if Weather.heavy else "", Weather.rain, Weather.gusty_wind(),
			Weather.fog, Weather.wetness, NightClock.time_text(), Engine.get_frames_per_second()]
