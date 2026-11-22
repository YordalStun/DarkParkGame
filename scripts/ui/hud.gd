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
var _sub_box: PanelContainer
var _sub: RichTextLabel
var _sub_id := 0
var _sub_skip := false
var waiting_click := false   ## a click-through line is up: any click moves it on
var _note: Label
var _note_id := 0
var look_left_btn: Button   ## main.gd connects this to the camera
var look_back_btn: Button   ## the > arrow in the side-window view


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
	pl.offset_bottom = -230
	_build_mixer()
	_build_story_ui()

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


## Sliders on the pause screen: master volume (shared with the PC's tray volume) and
## one per part of the mix. All saved to disk.
func _build_mixer() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_top = -250
	box.offset_bottom = -40
	box.offset_left = -300
	box.offset_right = 300
	box.add_theme_constant_override("separation", 4)
	_pause.add_child(box)

	var master := _slider_row(box, "VOLUME", Settings.volume, func(v): Settings.set_volume(v))
	var mute := CheckBox.new()
	mute.text = "MUTE"
	mute.add_theme_font_override("font", _font)
	mute.add_theme_font_size_override("font_size", 26)
	mute.button_pressed = Settings.muted
	mute.toggled.connect(func(on): Settings.set_muted(on))
	master.row.add_child(mute)
	Settings.volume_changed.connect(func(v: float, m: bool):
		if not is_equal_approx(master.slider.value, v):
			master.slider.set_value_no_signal(v)
		master.pct.text = "%d%%" % int(round(v * 100.0))
		mute.set_pressed_no_signal(m))
	for key in Settings.CHANNELS:
		var k: String = key
		var r := _slider_row(box, Settings.CHANNELS[k], Settings.mix[k], func(v): Settings.set_mix(k, v))
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(mute.get_combined_minimum_size().x, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.row.add_child(pad)


func _slider_row(parent: Control, title: String, value: float, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var lbl := _label(28, Color(0.85, 0.85, 0.8))
	lbl.reparent(row)
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.custom_minimum_size = Vector2(190, 0)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = value
	sl.custom_minimum_size = Vector2(220, 28)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sl)
	var pct := _label(28, Color(0.85, 0.85, 0.8))
	pct.reparent(row)
	pct.custom_minimum_size = Vector2(60, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pct.text = "%d%%" % int(round(value * 100.0))
	sl.value_changed.connect(func(v):
		pct.text = "%d%%" % int(round(v * 100.0))
		on_change.call(v))
	return {"row": row, "slider": sl, "pct": pct}


# ============================================================ story UI
## Subtitles: one line at a time with the speaker's name. Returns when the line is done
## (after `seconds`, or sooner if the player clicks to skip).
## click_through: stay up until the player clicks (phone calls), however long that takes.
func say(speaker: String, text: String, seconds := -1.0, click_through := false) -> void:
	if seconds < 0.0:
		seconds = clampf(1.6 + text.length() * 0.075, 3.0, 9.0)
	if click_through:
		seconds = INF
	waiting_click = click_through
	_sub_id += 1
	var id := _sub_id
	_sub.text = ("[color=#e8c070]%s:[/color]  %s" % [speaker.to_upper(), text]) if speaker != "" else "[i]%s[/i]" % text
	if click_through:
		_sub.text += "\n[right][color=#8a8a80][font_size=22]click to continue[/font_size][/color][/right]"
	_sub_box.visible = true
	_sub_skip = false
	var left := seconds
	while left > 0.0 and not _sub_skip and id == _sub_id:
		await get_tree().process_frame
		if not get_tree().paused:
			left -= get_process_delta_time()
	if id == _sub_id:
		_sub_box.visible = false
		waiting_click = false


## Click while a line is showing: move on to the next one.
func skip_line() -> bool:
	if _sub_box.visible:
		_sub_skip = true
		return true
	return false


func clear_lines() -> void:
	_sub_id += 1
	_sub_box.visible = false


## A short notice at the top of the screen ("A car has pulled up at the barrier").
func notify(text: String, seconds := 4.0) -> void:
	_note.text = text
	_note_id += 1
	var id := _note_id
	var tw := create_tween()
	tw.tween_property(_note, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(seconds).timeout
	if id == _note_id:
		create_tween().tween_property(_note, "modulate:a", 0.0, 0.8)


## The arrows at the screen edges: < turns to the side window, > turns back to the desk.
func set_look_left(show: bool) -> void:
	look_left_btn.visible = show


func set_look_back(show: bool) -> void:
	look_back_btn.visible = show


## End-of-night report card. Click to dismiss.
signal overlay_changed(open: bool)


func show_report(text: String) -> void:
	overlay_changed.emit(true)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 1)
	var l := _label(28, Color(0.85, 0.95, 0.85))
	l.reparent(bg)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text = text + "\n\n(click to carry on sitting in the booth)"
	bg.modulate.a = 0.0
	create_tween().tween_property(bg, "modulate:a", 1.0, 1.5)
	bg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			overlay_changed.emit(false)
			bg.queue_free())


func _build_story_ui() -> void:
	_sub_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	_sub_box.add_theme_stylebox_override("panel", sb)
	_sub_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_box.offset_left = -430
	_sub_box.offset_right = 430
	_sub_box.offset_top = -190
	_sub_box.offset_bottom = -100
	_sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_box.visible = false
	add_child(_sub_box)
	move_child(_sub_box, 0)
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.fit_content = true
	_sub.scroll_active = false
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_theme_font_override("normal_font", _font)
	_sub.add_theme_font_override("italics_font", _font)
	_sub.add_theme_font_size_override("normal_font_size", 30)
	_sub.add_theme_font_size_override("italics_font_size", 30)
	_sub.add_theme_color_override("default_color", Color(0.92, 0.92, 0.88))
	_sub_box.add_child(_sub)

	_note = _label(30, Color(0.95, 0.85, 0.55))
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note.offset_top = 44
	_note.offset_bottom = 80
	_note.offset_left = -400
	_note.offset_right = 400
	_note.modulate.a = 0.0

	look_left_btn = _edge_button("<", true)
	look_back_btn = _edge_button(">", false)


func _edge_button(text: String, left: bool) -> Button:
	var look_left_btn := Button.new()
	look_left_btn.text = text
	look_left_btn.focus_mode = Control.FOCUS_NONE
	look_left_btn.add_theme_font_override("font", _font)
	look_left_btn.add_theme_font_size_override("font_size", 54)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0.0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0, 0, 0, 0.35)
	look_left_btn.add_theme_stylebox_override("normal", flat)
	look_left_btn.add_theme_stylebox_override("hover", hover)
	look_left_btn.add_theme_stylebox_override("pressed", hover)
	look_left_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.45))
	look_left_btn.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6, 0.95))
	look_left_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if left else Control.PRESET_CENTER_RIGHT)
	look_left_btn.offset_left = 0 if left else -54
	look_left_btn.offset_right = 54 if left else 0
	look_left_btn.offset_top = -70
	look_left_btn.offset_bottom = 70
	look_left_btn.visible = false
	add_child(look_left_btn)
	return look_left_btn
