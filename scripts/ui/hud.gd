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
const VOICE_DB := -9.0
const Babble := preload("res://scripts/ui/babble.gd")
var _voice: AudioStreamPlayer   ## the babble that stands in for speech
var _money_label: Label
var _obj_box: PanelContainer
var _obj_text: RichTextLabel
var _objectives: Array = []     ## [{id, text, done}]
var money := 0
var _money_shown := 0.0
var _money_tween: Tween


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
	pl.text = "- PAUSED -"
	pl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Which build this is (so two downloads can't be mixed up).
	var ver := _label(20, Color(0.55, 0.55, 0.5))
	ver.reparent(_pause)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 14
	ver.offset_top = -30
	ver.offset_right = 600
	ver.offset_bottom = -8
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ver.text = "Dark Park v%s  -  build %s" % [ProjectSettings.get_setting("application/config/version", "?"), load("res://scripts/build_info.gd").BUILD]
	pl.offset_top = 26
	_build_pause_menu()
	_build_story_ui()
	_build_objectives()
	_voice = AudioStreamPlayer.new()
	_voice.bus = "UI"
	_voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_voice)
	Settings.mix_changed.connect(func(): _voice.volume_db = VOICE_DB + Settings.mix_db("voices"))

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


## Small FPS counter in the top-left corner (GRAPHICS > Show FPS).
func show_fps(on: bool) -> void:
	if _fps == null:
		_fps = _label(22, Color(0.6, 1.0, 0.6, 0.85))
		_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_fps.position = Vector2(16, 690)
		_fps.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		_fps.offset_left = 14
		_fps.offset_top = -34
		_fps.offset_right = 200
		_fps.offset_bottom = -8
	_fps.visible = on


var _fps: Label


func toggle_debug() -> void:
	_debug.visible = not _debug.visible


func _process(_delta: float) -> void:
	if _fps and _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if _debug.visible:
		_debug.text = "WEATHER %s%s\nrain %.2f  wind %.2f  fog %.2f  wet %.2f\ntime %s   fps %d" % [
			Weather.profile, " (HEAVY)" if Weather.heavy else "", Weather.rain, Weather.gusty_wind(),
			Weather.fog, Weather.wetness, NightClock.time_text(), Engine.get_frames_per_second()]


## Sliders on the pause screen: master volume (shared with the PC's tray volume) and
## one per part of the mix. All saved to disk.
## The pause screen's panel: SOUND / GRAPHICS / TESTING tabs, plus Resume and Quit.
signal test_action(id: String)
var _pages := {}
var _tab_btns := {}


func _build_pause_menu() -> void:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.05, 0.92)
	sb.border_color = Color(0.3, 0.3, 0.28)
	sb.set_border_width_all(1)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -420
	panel.offset_right = 420
	panel.offset_top = -270
	panel.offset_bottom = 300
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(796, 460)
	v.add_child(holder)
	for t in ["SOUND", "GRAPHICS", "TESTING"]:
		var b := _menu_button(t, 26)
		b.toggle_mode = true
		b.pressed.connect(func(): show_tab(t))
		tabs.add_child(b)
		_tab_btns[t] = b
		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		holder.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 4)
		scroll.add_child(page)
		_pages[t] = scroll
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	var resume := _menu_button("RESUME", 26)
	resume.pressed.connect(func(): set_paused(false))
	tabs.add_child(resume)
	var title := _menu_button("TITLE", 26)
	title.tooltip_text = "Back to the title screen (tonight starts again next time)"
	title.pressed.connect(func():
		get_tree().paused = false
		NightClock.set_time(23, 4)
		NightClock.shift_over = false
		NightClock.running = true
		Settings.set_fade(0.0)
		get_tree().reload_current_scene())
	tabs.add_child(title)
	var quit := _menu_button("QUIT", 26)
	quit.pressed.connect(func(): get_tree().quit())
	tabs.add_child(quit)
	_build_mixer(_pages["SOUND"].get_child(0))
	_build_graphics(_pages["GRAPHICS"].get_child(0))
	_build_testing(_pages["TESTING"].get_child(0))
	show_tab("SOUND")


func show_tab(t: String) -> void:
	for k in _pages:
		_pages[k].visible = k == t
		_tab_btns[k].set_pressed_no_signal(k == t)


func _menu_button(text: String, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var bs := StyleBoxFlat.new()
		bs.content_margin_left = 14
		bs.content_margin_right = 14
		bs.content_margin_top = 2
		bs.content_margin_bottom = 2
		bs.set_border_width_all(1)
		bs.border_color = Color(0.4, 0.4, 0.38)
		bs.bg_color = Color(0.1, 0.1, 0.1) if st == "normal" else (Color(0.91, 0.75, 0.44) if st in ["pressed", "hover_pressed"] else Color(0.2, 0.2, 0.19))
		b.add_theme_stylebox_override(st, bs)
	b.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.95))
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	b.add_theme_color_override("font_hover_pressed_color", Color(0.05, 0.05, 0.05))
	return b


func _caption(parent: Control, text: String) -> void:
	var l := _label(24, Color(0.91, 0.75, 0.44))
	l.reparent(parent)
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _toggle_row(parent: Control, title: String, key: String, note := "") -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var cb := CheckBox.new()
	cb.text = title
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_override("font", _font)
	cb.add_theme_font_size_override("font_size", 26)
	_style_check(cb)
	cb.button_pressed = Settings.graphics[key]
	cb.toggled.connect(func(on): Settings.set_graphics(key, on))
	row.add_child(cb)
	if note != "":
		var n := _label(22, Color(0.55, 0.55, 0.5))
		n.reparent(row)
		n.text = note


## Tick boxes you can see whether they're ticked or not.
func _style_check(cb: CheckBox) -> void:
	for st in [["checked", true], ["unchecked", false]]:
		var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
		for y in 20:
			for x in 20:
				if x < 2 or y < 2 or x > 17 or y > 17:
					img.set_pixel(x, y, Color(0.85, 0.85, 0.8))
				elif st[1] and x >= 5 and y >= 5 and x <= 14 and y <= 14:
					img.set_pixel(x, y, Color(0.91, 0.75, 0.44))
		cb.add_theme_icon_override(st[0], ImageTexture.create_from_image(img))


func _choice_row(parent: Control, title: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := _label(26, Color(0.85, 0.85, 0.8))
	l.reparent(row)
	l.text = title
	l.custom_minimum_size = Vector2(200, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var group := ButtonGroup.new()
	for i in options.size():
		var b := _menu_button(options[i], 22)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = Settings.graphics[key] == i
		b.pressed.connect(func(): Settings.set_graphics(key, i))
		row.add_child(b)


func _build_graphics(page: Control) -> void:
	_caption(page, "PICTURE")
	_choice_row(page, "Pixel size", "pixels", ["PS1 360", "480", "720", "FULL"])
	_choice_row(page, "Frame cap", "fps_cap", ["OFF", "30", "60", "120", "144"])
	_toggle_row(page, "Fullscreen", "fullscreen", "  (F11)")
	_toggle_row(page, "VSync", "vsync")
	_toggle_row(page, "Show FPS", "show_fps")
	_caption(page, "COMFORT")
	_choice_row(page, "Camera motion", "motion", ["FULL", "REDUCED", "MINIMAL"])
	_caption(page, "EFFECTS  (turn off for speed)")
	_toggle_row(page, "Mist and light beams", "mist", "  (biggest cost)")
	_toggle_row(page, "Wet reflections", "reflections")
	_toggle_row(page, "Ambient occlusion", "ao")
	_toggle_row(page, "Glow", "glow")
	_toggle_row(page, "Shadows", "shadows", "  (applies after a restart)")
	_caption(page, "RETRO LOOK")
	_toggle_row(page, "15-bit colour and dither", "retro_colour")
	_toggle_row(page, "Film grain", "grain")


## Buttons for trying things out without playing a whole night. main.gd does the work.
const TESTS := [
	["TIME", [["01:00", "time_1"], ["04:55 sunrise", "time_455"], ["06:58 shift end", "time_658"]]],
	["CARS", [["Next car now", "next_car"], ["Car at the window", "car_now"], ["Send a car home", "leaver"]]],
	["END OF NIGHT", [["Go to clock-out", "clockout"], ["Get up and leave", "leave"], ["End screen", "report"]]],
	["WEATHER", [["Clear", "w_clear"], ["Rain", "w_rain"], ["Storm", "w_storm"], ["Fog", "w_fog"], ["Lightning", "w_flash"]]],
	["BOOTH", [["Night 1 look", "booth_a"], ["Night 2 look", "booth_b"], ["Light flicker", "flicker"], ["Barrier", "gate"]]],
	["SAVE", [["+5 coins", "coins"], ["Reset to night 1", "reset"], ["Weather readout", "readout"]]],
]


func _build_testing(page: Control) -> void:
	for group in TESTS:
		_caption(page, group[0])
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 6)
		page.add_child(row)
		for t in group[1]:
			var b := _menu_button(t[0], 22)
			var id: String = t[1]
			b.pressed.connect(func(): test_action.emit(id))
			row.add_child(b)


func _build_mixer(box: Control) -> void:

	var master := _slider_row(box, "VOLUME", Settings.volume, func(v): Settings.set_volume(v))
	var mute := CheckBox.new()
	mute.text = "MUTE"
	mute.add_theme_font_override("font", _font)
	mute.add_theme_font_size_override("font_size", 26)
	_style_check(mute)
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
	lbl.custom_minimum_size = Vector2(230, 0)
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
	_speak(speaker, text)
	var left := seconds
	while left > 0.0 and not _sub_skip and id == _sub_id:
		await get_tree().process_frame
		if not get_tree().paused:
			left -= get_process_delta_time()
	if id == _sub_id:
		_sub_box.visible = false
		waiting_click = false
		_voice.stop()


## Click while a line is showing: move on to the next one.
func skip_line() -> bool:
	if _sub_box.visible:
		_sub_skip = true
		_voice.stop()
		return true
	return false


func clear_lines() -> void:
	_sub_id += 1
	_sub_box.visible = false
	_voice.stop()


func _speak(speaker: String, text: String) -> void:
	if speaker == "":
		_voice.stop()   # a narrated line: nobody is talking
		return
	_voice.stream = Babble.make(text, speaker)
	_voice.volume_db = VOICE_DB + Settings.mix_db("voices")
	_voice.play()


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
	_obj_box.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	move_child(bg, 1)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 120
	scroll.offset_right = -120
	scroll.offset_top = 30
	scroll.offset_bottom = -30
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS   # clicks still reach the backdrop and close the report
	bg.add_child(scroll)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for n in ["normal_font", "bold_font", "italics_font", "mono_font"]:
		l.add_theme_font_override(n, _font)
	for n in ["normal_font_size", "bold_font_size", "italics_font_size", "mono_font_size"]:
		l.add_theme_font_size_override(n, 26)
	l.add_theme_color_override("default_color", Color(0.85, 0.92, 0.85))
	l.text = text + "\n\n[center][color=#8a8a80](click to carry on sitting in the booth)[/color][/center]"
	scroll.add_child(l)
	bg.modulate.a = 0.0
	create_tween().tween_property(bg, "modulate:a", 1.0, 1.5)
	bg.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			overlay_changed.emit(false)
			bg.queue_free())


# ============================================================ objectives and coins
func _build_objectives() -> void:
	_money_label = _label(32, Color(0.96, 0.84, 0.4))
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_money_label.offset_left = -300
	_money_label.offset_right = -16
	_money_label.offset_top = 10
	_money_label.offset_bottom = 46
	_money_label.modulate.a = 0.55
	_show_money(0.0)

	_obj_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	sb.set_corner_radius_all(3)
	_obj_box.add_theme_stylebox_override("panel", sb)
	_obj_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_obj_box.offset_left = -316
	_obj_box.offset_right = -16
	_obj_box.offset_top = 50
	_obj_box.offset_bottom = 50
	_obj_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_box.visible = false
	add_child(_obj_box)
	_obj_text = RichTextLabel.new()
	_obj_text.bbcode_enabled = true
	_obj_text.fit_content = true
	_obj_text.scroll_active = false
	_obj_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_text.add_theme_font_override("normal_font", _font)
	_obj_text.add_theme_font_size_override("normal_font_size", 22)
	_obj_text.add_theme_color_override("default_color", Color(0.9, 0.9, 0.85))
	_obj_box.add_child(_obj_text)


func _show_money(v: float) -> void:
	_money_shown = v
	_money_label.text = "COINS: %d" % int(round(v))


## How many coins the player has. It counts there slowly (about a third of a second per coin).
func set_money(v: int, animate := true) -> void:
	money = v
	if _money_tween:
		_money_tween.kill()
	if not animate:
		_show_money(float(v))
		return
	_money_tween = create_tween()
	_money_tween.tween_property(_money_label, "modulate:a", 1.0, 0.3)
	_money_tween.tween_method(_show_money, _money_shown, float(v), maxf(0.4, absf(v - _money_shown) * 0.35))
	_money_tween.tween_interval(0.8)
	_money_tween.tween_property(_money_label, "modulate:a", 0.55, 1.2)


func set_objectives(list: Array) -> void:
	_objectives.clear()
	for o in list:
		_objectives.append({"id": o[0], "text": o[1], "done": false})
	_refresh_objectives()


func add_objective(id: String, text: String) -> void:
	for o in _objectives:
		if o.id == id:
			return
	_objectives.append({"id": id, "text": text, "done": false})
	_refresh_objectives()


func complete_objective(id: String) -> void:
	for o in _objectives:
		if o.id == id and not o.done:
			o.done = true
			_refresh_objectives()


func _refresh_objectives() -> void:
	var t := "[color=#e8c070]OBJECTIVES[/color]"
	for o in _objectives:
		if o.done:
			t += "\n[color=#7d8a74][lb]x[rb] [s]%s[/s][/color]" % o.text
		else:
			t += "\n[lb]  [rb] %s" % o.text
	_obj_text.text = t
	_obj_box.visible = not _objectives.is_empty()


## Standing up: a dot in the middle of the view to aim with.
func set_crosshair(on: bool) -> void:
	if _cross == null:
		_cross = ColorRect.new()
		_cross.color = Color(0.92, 0.92, 0.86, 0.85)
		_cross.size = Vector2(4, 4)
		_cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_cross.offset_left = -2
		_cross.offset_top = -2
		_cross.offset_right = 2
		_cross.offset_bottom = 2
		_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_cross)
		move_child(_cross, 0)
	_cross.visible = on


## A big button at the bottom of the screen (e.g. "GET UP"). Returns when it's pressed.
func big_button(text: String) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 34)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.91, 0.75, 0.44) if st != "hover" else Color(1.0, 0.85, 0.55)
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color(0.05, 0.05, 0.05))
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -110
	b.offset_right = 110
	b.offset_top = -150
	b.offset_bottom = -96
	add_child(b)
	await b.pressed
	b.queue_free()


var _cross: ColorRect
var _tip_box: PanelContainer
var _tip_label: Label
var _tips: Array = []
var _tip_busy := false


## A guide tip in the bottom-left corner ("TIP: you can write things down..."). Each one is
## shown once per save slot (id), then never again.
func tip(id: String, text: String, seconds := 11.0) -> void:
	if SaveGame.tip_seen(id):
		return
	SaveGame.mark_tip(id)
	_tips.append([text, seconds])
	if not _tip_busy:
		_next_tip()


func _next_tip() -> void:
	if _tips.is_empty():
		_tip_busy = false
		return
	_tip_busy = true
	if _tip_box == null:
		_tip_box = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.07, 0.06, 0.88)
		sb.border_color = Color(0.91, 0.75, 0.44)
		sb.border_width_left = 4
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 10
		sb.content_margin_bottom = 12
		_tip_box.add_theme_stylebox_override("panel", sb)
		_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tip_box)
		move_child(_tip_box, 0)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tip_box.add_child(v)
		var head := _label(22, Color(0.91, 0.75, 0.44))
		head.reparent(v)
		head.text = "TIP"
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_tip_label = _label(24, Color(0.9, 0.9, 0.85))
		_tip_label.reparent(v)
		_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tip_label.custom_minimum_size = Vector2(420, 0)
	var t: Array = _tips.pop_front()
	_tip_label.text = t[0]
	_tip_box.visible = true
	_tip_box.modulate.a = 0.0
	await get_tree().process_frame
	var h := _tip_box.get_combined_minimum_size().y
	_tip_box.size = Vector2(452, h)
	_tip_box.position = Vector2(18, get_viewport().get_visible_rect().size.y - 70 - h)
	_tip_box.modulate.a = 0.0
	_tip_box.visible = true
	var tw := create_tween()
	tw.tween_property(_tip_box, "modulate:a", 1.0, 0.4)
	tw.tween_interval(t[1])
	tw.tween_property(_tip_box, "modulate:a", 0.0, 0.8)
	await tw.finished
	_tip_box.visible = false
	_next_tip()


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
