extends SubViewport
## "NightWin 95": a Windows-95-style desktop that runs on the booth's CRT.
## It is a 640x480 SubViewport whose texture the CRT shader displays. The game
## forwards mouse and keyboard events in with push_input().
##
## Startup:   power_on()  -> BIOS text -> splash -> desktop -> welcome dialog
## Shutdown:  shut_down("shutdown" | "restart" | "dos")

const W95 := preload("res://scripts/desktop/w95.gd")
const WindowScript := preload("res://scripts/desktop/window.gd")
const MenuPopup := preload("res://scripts/desktop/menu_popup.gd")
const DesktopIcon := preload("res://scripts/desktop/desktop_icon.gd")
const VFS := preload("res://scripts/desktop/vfs.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

const W := 640
const H := 480
const TASKBAR_H := 28

signal state_changed(running: bool)
signal sound(name: String, db: float)
signal away_changed(away: bool)  ## the player sat back from (true) or leaned in to (false) the screen

const APPS := {
	"notepad": {"title": "Untitled - Notepad", "icon": "notepad", "size": Vector2(380, 290)},
	"calc": {"title": "Calculator", "icon": "calc", "size": Vector2(262, 262), "max": false, "resize": false},
	"paint": {"title": "untitled - Paint", "icon": "paint", "size": Vector2(470, 350), "min_size": Vector2(300, 220)},
	"dos": {"title": "MS-DOS Prompt", "icon": "dos", "size": Vector2(440, 300)},
	"explorer": {"title": "My Computer", "icon": "computer", "size": Vector2(400, 290)},
	"browser": {"title": "NightNet Explorer", "icon": "globe", "size": Vector2(604, 410), "min_size": Vector2(320, 220)},
	"mail": {"title": "Inbox - Mail", "icon": "inbox", "size": Vector2(520, 340), "min_size": Vector2(320, 220)},
	"mines": {"title": "Minesweeper", "icon": "mine", "size": Vector2(170, 230), "max": false, "resize": false},
	"solitaire": {"title": "Solitaire", "icon": "cards", "size": Vector2(396, 440), "max": false, "resize": false},
	"snake": {"title": "NightSnake", "icon": "snake", "size": Vector2(330, 322), "max": false, "resize": false},
	"camlink": {"title": "CamLink CCTV v1.3", "icon": "cam", "size": Vector2(420, 330), "min_size": Vector2(300, 240)},
	"gatectl": {"title": "Gate Control", "icon": "gate", "size": Vector2(300, 190), "max": false, "resize": false},
	"remote": {"title": "NightLink Remote Connect", "icon": "dos", "size": Vector2(380, 340), "max": false, "resize": false},
	"gatelog": {"title": "GateLog - Vehicle Entry", "icon": "doc", "size": Vector2(470, 370), "min_size": Vector2(380, 300)},
	"help": {"title": "NightWin Help", "icon": "help", "size": Vector2(420, 300)},
	"find": {"title": "Find: All Files", "icon": "find", "size": Vector2(380, 280)},
}

var state := "off"            ## off | boot | running | shutdown
var world: Node               ## the game world (may be null in tests)
var away := true             ## the player is not leaned in to the screen
var web: Node                ## Chromium web engine (web_engine.gd), shared by browser windows
var vfs := VFS.new()
var net_connected := false
var windows: Array = []
var active_window: Control
var busy := false
var welcome_enabled := true
var mailbox: Array = []

var ui: Control
var wall: ColorRect
var icon_layer: Control
var win_layer: Control
var taskbar: Panel
var start_btn: Button
var task_area: Control
var tray_icons: HBoxContainer
var clock_label: Label
var menu_layer: Control
var dialog_layer: Control
var cursor: TextureRect
var boot_layer: Control
var boot_text: Label
var splash: Control

var _menus: Array = []
var _blocker: Control
var _menu_close_cb := Callable()
var _menu_motion_cb := Callable()
var _mouse_pos := Vector2(320, 240)
var _cursor_kind := ""
var _skip := false
var _splash_mode := "start"
var _splash_t := 0.0
var _clouds: Array = []
var _task_buttons := {}
var _selected_icon: Control
var _cascade := 0
var _clock_acc := 0.0
var _icons: Array = []
var modem_icon: TextureRect
var modem_blink := 0.0


func _ready() -> void:
	web = load("res://scripts/desktop/web_engine.gd").new()
	web.name = "WebEngine"
	add_child(web)
	size = Vector2i(W, H)
	transparent_bg = false
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	gui_disable_input = false
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	set_process_input(true)

	ui = Control.new()
	ui.name = "UI"
	ui.theme = W95.theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	wall = ColorRect.new()
	wall.color = W95.TEAL
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_STOP
	wall.gui_input.connect(_wall_input)
	ui.add_child(wall)

	icon_layer = Control.new()
	icon_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(icon_layer)
	_build_icons()

	win_layer = Control.new()
	win_layer.name = "Windows"
	win_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(win_layer)

	_build_taskbar()

	menu_layer = Control.new()
	menu_layer.name = "Menus"
	menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(menu_layer)

	dialog_layer = Control.new()
	dialog_layer.name = "Dialogs"
	dialog_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dialog_layer)

	boot_layer = Control.new()
	boot_layer.name = "Boot"
	boot_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	boot_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	boot_layer.visible = false
	ui.add_child(boot_layer)
	_build_boot()

	cursor = TextureRect.new()
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cursor.stretch_mode = TextureRect.STRETCH_KEEP
	cursor.z_index = 100
	ui.add_child(cursor)
	_set_cursor("arrow")

	ui.visible = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 95
	for i in 14:
		_clouds.append(Vector3(rng.randf_range(-40, W), rng.randf_range(40, 300), rng.randf_range(0.6, 1.6)))
	var clock := get_node_or_null("/root/NightClock")
	if clock:
		clock.minute_changed.connect(func(_h, _m): _update_clock())
	_update_clock()


# ================================================================ power
func is_running() -> bool:
	return state == "running"


func is_on() -> bool:
	return state != "off"


func power_on(quick := false) -> void:
	if state != "off":
		return
	state = "boot"
	_skip = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	state_changed.emit(true)
	_boot_sequence(quick)


func shut_down(mode: String) -> void:
	if state != "running":
		return
	state = "shutdown"
	close_menus()
	for w in windows.duplicate():
		close_window(w, true)
	for c in dialog_layer.get_children():
		c.queue_free()
	_splash_mode = "down"
	boot_layer.visible = true
	boot_text.visible = false
	splash.visible = true
	splash.queue_redraw()
	sound.emit("hdd", -14.0)
	await _wait(1.8 if mode != "dos" else 0.8)
	if mode == "restart":
		state = "off"
		power_on()
		return
	if mode == "shutdown":
		_splash_mode = "safe"
		splash.queue_redraw()
		await _wait(2.4)
	state = "off"
	boot_layer.visible = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED   # nothing to draw while the PC is off
	state_changed.emit(false)


func _wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end and not _skip:
		await get_tree().process_frame


func _boot_sequence(quick: bool) -> void:
	boot_layer.visible = true
	splash.visible = false
	boot_text.visible = true
	boot_text.text = ""
	var lines := [
		"NightBIOS (C) 1994 Nightwatch Systems Ltd.",
		"Pentium-S 90MHz  ...........  OK",
		"",
		"Memory Test :  %dK OK",
		"",
		"Detecting IDE Primary Master   ... QUANTUM FIREBALL 540AT",
		"Detecting IDE Primary Slave    ... None",
		"Detecting IDE Secondary Master ... CD-ROM 4X",
		"Detecting COM2 ................ Hayes 28800 modem",
		"",
		"Starting NightWin 95..._",
	]
	if not quick:
		sound.emit("bios", -12.0)
	var shown := ""
	for ln in lines:
		if ln.contains("%d"):
			var mem := 0
			while mem < 16384:
				mem = mini(16384, mem + 1024)
				boot_text.text = shown + ln % mem
				if not quick and not _skip:
					await _wait(0.04)
			ln = ln % 16384
		shown += ln + "\n"
		boot_text.text = shown
		if not quick:
			await _wait(0.16 if ln != "" else 0.05)
	if not quick:
		await _wait(0.5)
	_splash_mode = "start"
	_skip = false
	boot_text.visible = false
	splash.visible = true
	_splash_t = 0.0
	splash.queue_redraw()
	if not quick:
		sound.emit("hdd", -14.0)
		await _wait(2.6)
	boot_layer.visible = false
	state = "running"
	_skip = false
	sound.emit("chime", -10.0)
	if welcome_enabled and not quick:
		await _wait(0.6)
		Dialogs.welcome(self)


# ================================================================= boot UI
func _build_boot() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boot_layer.add_child(bg)
	boot_text = Label.new()
	boot_text.position = Vector2(14, 12)
	boot_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	ls.font = W95.font("vga")
	ls.font_size = 19
	ls.font_color = Color(0.8, 0.8, 0.8)
	ls.line_spacing = -3
	boot_text.label_settings = ls
	boot_layer.add_child(boot_text)
	splash = Control.new()
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.visible = false
	splash.draw.connect(_draw_splash)
	boot_layer.add_child(splash)


func _draw_splash() -> void:
	var f := W95.font("sansb")
	var f2 := W95.font("sans")
	if _splash_mode == "safe":
		splash.draw_rect(Rect2(0, 0, W, H), Color.BLACK)
		var t := "It's now safe to turn off\nyour computer."
		splash.draw_multiline_string(f, Vector2(0, 210), t, HORIZONTAL_ALIGNMENT_CENTER, W, 22, 2, Color(1.0, 0.62, 0.1))
		return
	# Sky gradient in visible bands.
	var bands := 30
	for i in bands:
		var k := float(i) / (bands - 1)
		var c := Color(0.0, 0.5, 0.62).lerp(Color(0.62, 0.82, 0.95), k)
		splash.draw_rect(Rect2(0, i * (H / bands), W, H / bands + 1), c)
	for cl in _clouds:
		var x: float = cl.x + _splash_t * 6.0 * cl.z
		x = fposmod(x + 60.0, W + 160.0) - 80.0
		for j in 5:
			splash.draw_circle(Vector2(x + j * 14.0 * cl.z, cl.y + sin(j * 1.7) * 6.0), (14.0 + (j % 3) * 4.0) * cl.z, Color(1, 1, 1, 0.55))
	var title := "NightWin"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	var x0 := (W - tw - 70.0) / 2.0
	splash.draw_string(f, Vector2(x0 + 3, 213), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0, 0, 0, 0.45))
	splash.draw_string(f, Vector2(x0, 210), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color.WHITE)
	splash.draw_string(f, Vector2(x0 + tw + 8 + 3, 213), "95", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(0, 0, 0, 0.45))
	splash.draw_string(f, Vector2(x0 + tw + 8, 210), "95", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color(1.0, 0.9, 0.35))
	splash.draw_texture_rect(W95.icon("moon"), Rect2(W / 2.0 - 16, 118, 32, 32), false)
	var msg := "Starting NightWin 95..." if _splash_mode == "start" else "NightWin 95 is shutting down..."
	splash.draw_string(f2, Vector2(0, 280), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 13, Color.WHITE)
	# Moving stripe at the bottom.
	var bar := Rect2(0, 456, W, 14)
	splash.draw_rect(bar, Color(0, 0, 0, 0.35))
	var bx := fposmod(_splash_t * 260.0, W + 160.0) - 160.0
	for i in 8:
		splash.draw_rect(Rect2(bx + i * 16.0, 458, 12, 10), Color(0.2, 0.3, 1.0).lerp(Color(0.5, 0.8, 1.0), i / 7.0))


# ============================================================== desktop icons
func _build_icons() -> void:
	var defs := [
		["My Computer", "computer", func(): open_app("explorer", {"path": ""})],
		["Network Neighborhood", "network", func(): open_app("explorer", {"path": "NET"})],
		["Inbox", "inbox", func(): open_app("mail")],
		["Recycle Bin", "trash_full", func(): open_app("explorer", {"path": VFS.RECYCLE})],
		["The Internet", "globe", func(): open_app("browser")],
		["My Documents", "documents", func(): open_app("explorer", {"path": "C:\\MY DOCUMENTS"})],
		["CamLink", "cam", func(): open_app("camlink")],
		["Gate Control", "gate", func(): open_app("gatectl")],
		["GateLog", "doc", func(): open_app("gatelog")],
		["Solitaire", "cards", func(): open_app("solitaire")],
		["NightSnake", "snake", func(): open_app("snake")],
	]
	if SaveGame.night() >= 3:   # the side hustle's dial-up tool (night three on)
		defs.append(["NightLink", "dos", func(): open_app("remote")])
	var i := 0
	for d in defs:
		var ic: Control = DesktopIcon.new()
		ic.setup(d[0], d[1], d[2])
		var col := i / 6
		var row := i % 6
		ic.position = Vector2(6 + col * 78, 6 + row * 74)
		ic.picked.connect(_icon_picked)
		ic.opened.connect(func(c): c.action.call())
		ic.context.connect(func(c, pos): open_menu([
			{"text": "Open", "bold": true, "act": c.action},
			{"sep": true},
			{"text": "Properties", "dis": true},
		], pos))
		icon_layer.add_child(ic)
		_icons.append(ic)
		i += 1


func _icon_picked(ic: Control) -> void:
	if _selected_icon != null and is_instance_valid(_selected_icon):
		_selected_icon.set_selected(false)
	_selected_icon = ic
	ic.set_selected(true)


func _wall_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if _selected_icon != null:
			_selected_icon.set_selected(false)
			_selected_icon = null
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			open_menu([
				{"text": "Arrange Icons", "sub": [{"text": "by Name", "act": func(): pass}, {"text": "Auto Arrange", "act": func(): pass}]},
				{"text": "Line Up Icons", "act": func(): pass},
				{"sep": true},
				{"text": "Paste", "dis": true},
				{"sep": true},
				{"text": "New", "sub": [
					{"text": "Folder", "act": func(): Dialogs.msgbox(self, "New Folder", "Folders can only be created from My Computer.", "info")},
					{"text": "Text Document", "act": func(): open_app("notepad")},
				]},
				{"sep": true},
				{"text": "Properties", "act": func(): Dialogs.display_props(self)},
			], ev.global_position)


# ================================================================= taskbar
func _build_taskbar() -> void:
	taskbar = Panel.new()
	taskbar.name = "Taskbar"
	taskbar.add_theme_stylebox_override("panel", W95.taskbar())
	taskbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_top = -TASKBAR_H
	taskbar.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(taskbar)

	start_btn = Button.new()
	start_btn.text = "Start"
	start_btn.icon = W95.icon("moon", true)
	start_btn.toggle_mode = true
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	start_btn.add_theme_font_override("font", W95.font("sansb"))
	start_btn.add_theme_stylebox_override("hover_pressed", W95.pressed())
	start_btn.add_theme_stylebox_override("pressed", W95.pressed())
	start_btn.position = Vector2(2, 4)
	start_btn.size = Vector2(58, 22)
	start_btn.add_theme_constant_override("h_separation", 3)
	start_btn.pressed.connect(toggle_start)
	taskbar.add_child(start_btn)

	var sep := Panel.new()
	sep.add_theme_stylebox_override("panel", W95.thin_sunken())
	sep.position = Vector2(63, 4)
	sep.size = Vector2(3, 22)
	taskbar.add_child(sep)

	task_area = Control.new()
	task_area.position = Vector2(70, 4)
	task_area.size = Vector2(W - 70 - 92, 22)
	task_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	taskbar.add_child(task_area)

	var tray := Panel.new()
	tray.add_theme_stylebox_override("panel", W95.thin_sunken())
	tray.position = Vector2(W - 88, 4)
	tray.size = Vector2(86, 22)
	taskbar.add_child(tray)
	tray_icons = HBoxContainer.new()
	tray_icons.position = Vector2(4, 3)
	tray_icons.add_theme_constant_override("separation", 3)
	tray.add_child(tray_icons)
	var sp := TextureRect.new()
	sp.name = "Speaker"
	sp.texture = W95.icon("speaker", true)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray_icons.add_child(sp)
	clock_label = Label.new()
	clock_label.position = Vector2(40, 4)
	clock_label.size = Vector2(44, 14)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tray.add_child(clock_label)
	var hit := Control.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.mouse_filter = Control.MOUSE_FILTER_PASS
	tray.add_child(hit)
	hit.gui_input.connect(func(ev):
		if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			return
		if sp.get_global_rect().grow(2).has_point(hit.get_global_transform() * ev.position):
			_volume_popup()
		elif ev.double_click and net_connected:
			Dialogs.connection_status(self))


## The Windows 95 tray volume control: a vertical slider and a Mute box.
## Changes the game's master volume (shared with the pause menu, saved to disk).
func _volume_popup() -> void:
	close_menus()
	_ensure_blocker()
	var settings := get_node("/root/Settings")
	var pnl := Panel.new()
	pnl.add_theme_stylebox_override("panel", W95.raised())
	pnl.size = Vector2(70, 132)
	pnl.position = Vector2(W - 92, H - TASKBAR_H - pnl.size.y - 2)
	pnl.mouse_filter = Control.MOUSE_FILTER_STOP
	var title := Label.new()
	title.text = "Volume"
	title.position = Vector2(0, 6)
	title.size = Vector2(70, 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pnl.add_child(title)
	var sl := VSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = settings.volume
	sl.position = Vector2(25, 26)
	sl.size = Vector2(20, 72)
	sl.value_changed.connect(func(v): settings.set_volume(v))
	sl.drag_ended.connect(func(_c): play("ding", -14.0))
	pnl.add_child(sl)
	var mute := CheckBox.new()
	mute.text = "Mute"
	mute.button_pressed = settings.muted
	mute.position = Vector2(6, 104)
	mute.toggled.connect(func(on): settings.set_muted(on))
	pnl.add_child(mute)
	add_menu_node(pnl)
	play("click2", -16.0)


func set_modem_icon(on: bool) -> void:
	if on and modem_icon == null:
		modem_icon = TextureRect.new()
		modem_icon.texture = W95.icon("modem", true)
		modem_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tray_icons.add_child(modem_icon)
		tray_icons.move_child(modem_icon, 0)
	elif not on and modem_icon != null:
		modem_icon.queue_free()
		modem_icon = null


func _update_clock() -> void:
	var clock := get_node_or_null("/root/NightClock")
	var h := 23
	var m := 4
	if clock:
		h = clock.hour()
		m = clock.minute()
	var ap := "PM" if h >= 12 else "AM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	if clock_label:
		clock_label.text = "%d:%02d %s" % [h12, m, ap]


func clock_text() -> String:
	return clock_label.text if clock_label else ""


func refresh_taskbar() -> void:
	var live := {}
	for w in windows:
		if w.dialog:
			continue
		live[w] = true
		if not _task_buttons.has(w):
			var b := Button.new()
			b.theme_type_variation = "TaskButton"
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.clip_text = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.icon = w.icon
			b.add_theme_constant_override("h_separation", 3)
			b.pressed.connect(func(): _task_clicked(w))
			task_area.add_child(b)
			_task_buttons[w] = b
	for w in _task_buttons.keys():
		if not live.has(w):
			_task_buttons[w].queue_free()
			_task_buttons.erase(w)
	var n := _task_buttons.size()
	if n == 0:
		return
	var bw := minf(160.0, (task_area.size.x - 2.0 * (n - 1)) / n)
	var x := 0.0
	for w in windows:
		if not _task_buttons.has(w):
			continue
		var b: Button = _task_buttons[w]
		b.position = Vector2(x, 0)
		b.size = Vector2(bw, 22)
		b.text = w.title
		b.set_pressed_no_signal(w == active_window and not w.minimized)
		x += bw + 2.0


func _task_clicked(w: Control) -> void:
	close_menus()
	if w == active_window and not w.minimized:
		minimize_window(w)
	else:
		focus_window(w)


# ================================================================= windows
func open_app(id: String, args := {}) -> Control:
	if not APPS.has(id):
		return null
	var def: Dictionary = APPS[id]
	close_menus()
	var win: Control = WindowScript.new()
	var s: Vector2 = def.get("size", Vector2(400, 300))
	win.setup(self, def.title, def.icon, s, def)
	var app: Control = load("res://scripts/desktop/apps/%s.gd" % id).new()
	app.name = id
	win.app = app
	win.client.add_child(app)
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	app.mouse_filter = Control.MOUSE_FILTER_PASS
	var p := Vector2(24, 14) + Vector2(_cascade % 5, _cascade % 5) * 24.0
	_cascade += 1
	win.position = p.clamp(Vector2.ZERO, Vector2(W - s.x, H - TASKBAR_H - s.y).max(Vector2.ZERO))
	add_window(win)
	app.setup(self, win, args)
	sound.emit("click2", -14.0)
	return win


func add_window(win: Control) -> void:
	win_layer.add_child(win)
	windows.append(win)
	focus_window(win)


func close_window(win: Control, silent := false) -> void:
	if not windows.has(win):
		return
	windows.erase(win)
	var was_active := win == active_window
	if win.app != null and win.app.has_method("on_closed"):
		win.app.on_closed()
	win.queue_free()
	if was_active:
		active_window = null
		for i in range(windows.size() - 1, -1, -1):
			if not windows[i].minimized and not windows[i].dialog:
				focus_window(windows[i])
				break
	if not silent:
		refresh_taskbar()
	else:
		refresh_taskbar()


func minimize_window(win: Control) -> void:
	win.minimized = true
	win.visible = false
	if win == active_window:
		active_window = null
		for i in range(windows.size() - 1, -1, -1):
			var w: Control = windows[i]
			if not w.minimized and not w.dialog:
				focus_window(w)
				break
	_refresh_active()
	refresh_taskbar()


func focus_window(win: Control) -> void:
	if win == null or not windows.has(win):
		return
	win.minimized = false
	win.visible = true
	if win.get_parent() == win_layer:
		win_layer.move_child(win, win_layer.get_child_count() - 1)
	active_window = win
	_refresh_active()
	refresh_taskbar()


func _refresh_active() -> void:
	for w in windows:
		w.set_active(w == active_window)


## Show a dialog window (already built) centred, optionally blocking everything else.
func show_dialog(win: Control, modal := true) -> void:
	win.dialog = true
	win.position = ((Vector2(W, H - TASKBAR_H) - win.size) / 2.0).floor()
	if modal:
		var blk := Control.new()
		blk.set_anchors_preset(Control.PRESET_FULL_RECT)
		blk.mouse_filter = Control.MOUSE_FILTER_STOP
		dialog_layer.add_child(blk)
		win.set_meta("blocker", blk)
		win.closed.connect(func(_w): if is_instance_valid(blk): blk.queue_free())
	dialog_layer.add_child(win)
	win.os_ref = self
	win.active = true
	win.queue_redraw()
	close_menus()
	sound.emit("ding", -12.0)


func close_dialog(win: Control) -> void:
	if not is_instance_valid(win):
		return
	win.closed.emit(win)
	win.queue_free()


## Called by windows.close; dialogs live in dialog_layer and are not in `windows`.
func _top_dialog() -> Control:
	for i in range(dialog_layer.get_child_count() - 1, -1, -1):
		var c := dialog_layer.get_child(i)
		if c.has_method("request_close") and not c.is_queued_for_deletion():
			return c
	return null


# =================================================================== menus
func open_menu(items: Array, pos: Vector2, opts := {}) -> Control:
	close_menus()
	_ensure_blocker()
	_menu_close_cb = opts.get("on_close", Callable())
	_menu_motion_cb = opts.get("motion", Callable())
	var m: Control = MenuPopup.new()
	m.setup(self, items, opts.get("big", false), opts.get("banner", ""))
	var p := pos
	if opts.get("above", false):
		p.y = pos.y - m.size.y
	if p.x + m.size.x > W:
		p.x = W - m.size.x
	if p.y + m.size.y > H - TASKBAR_H:
		p.y = maxf(0.0, H - TASKBAR_H - m.size.y)
	m.position = p
	add_menu_node(m)
	return m


func add_menu_node(m: Control) -> void:
	menu_layer.add_child(m)
	_menus.append(m)


func _ensure_blocker() -> void:
	if _blocker != null and is_instance_valid(_blocker):
		return
	_blocker = Control.new()
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			close_menus()
		elif ev is InputEventMouseMotion and _menu_motion_cb.is_valid():
			_menu_motion_cb.call(ev.global_position))
	menu_layer.add_child(_blocker)
	menu_layer.move_child(_blocker, 0)


func close_menus() -> void:
	for m in _menus:
		if is_instance_valid(m):
			m.queue_free()
	_menus.clear()
	for c in menu_layer.get_children():
		c.queue_free()
	_blocker = null
	if start_btn:
		start_btn.set_pressed_no_signal(false)
	var cb := _menu_close_cb
	_menu_close_cb = Callable()
	_menu_motion_cb = Callable()
	if cb.is_valid():
		cb.call()


func has_open_menu() -> bool:
	return menu_layer.get_child_count() > 0


func toggle_start() -> void:
	if has_open_menu():
		close_menus()
		return
	start_btn.set_pressed_no_signal(true)
	open_menu(_start_items(), Vector2(0, H - TASKBAR_H), {"big": true, "banner": "95", "above": true})
	start_btn.set_pressed_no_signal(true)


func _ico(name: String) -> Texture2D:
	return W95.icon(name, true)


func _start_items() -> Array:
	var app := func(id: String, args := {}): return func(): open_app(id, args)
	var accessories := [
		{"text": "Calculator", "icon": _ico("calc"), "act": app.call("calc")},
		{"text": "MS-DOS Prompt", "icon": _ico("dos"), "act": app.call("dos")},
		{"text": "Notepad", "icon": _ico("notepad"), "act": app.call("notepad")},
		{"text": "Paint", "icon": _ico("paint"), "act": app.call("paint")},
		{"text": "Windows Explorer", "icon": _ico("computer"), "act": app.call("explorer", {"path": "C:\\"})},
	]
	var programs := [
		{"text": "Accessories", "icon": _ico("folder"), "sub": accessories},
		{"text": "Games", "icon": _ico("folder"), "sub": [
			{"text": "Minesweeper", "icon": _ico("mine"), "act": app.call("mines")},
			{"text": "NightSnake", "icon": _ico("snake"), "act": app.call("snake")},
			{"text": "Solitaire", "icon": _ico("cards"), "act": app.call("solitaire")},
		]},
		{"text": "Internet", "icon": _ico("folder"), "sub": [
			{"text": "NightNet Explorer", "icon": _ico("globe"), "act": app.call("browser")},
			{"text": "Mail", "icon": _ico("inbox"), "act": app.call("mail")},
		]},
		{"text": "Nightwatch", "icon": _ico("folder"), "sub": [
			{"text": "CamLink CCTV", "icon": _ico("cam"), "act": app.call("camlink")},
			{"text": "Gate Control", "icon": _ico("gate"), "act": app.call("gatectl")},
			{"text": "GateLog", "icon": _ico("doc"), "act": app.call("gatelog")},
		] + ([{"text": "NightLink Remote", "icon": _ico("dos"), "act": app.call("remote")}] if SaveGame.night() >= 3 else [])},
		{"sep": true},
		{"text": "MS-DOS Prompt", "icon": _ico("dos"), "act": app.call("dos")},
		{"text": "NightNet Explorer", "icon": _ico("globe"), "act": app.call("browser")},
		{"text": "Windows Explorer", "icon": _ico("computer"), "act": app.call("explorer", {"path": "C:\\"})},
	]
	var docs := []
	for n in vfs.list("C:\\MY DOCUMENTS"):
		var path: String = "C:\\MY DOCUMENTS\\" + n.name
		docs.append({"text": n.name, "icon": _ico("doc"), "act": app.call("notepad", {"path": path})})
	docs.append({"sep": true})
	docs.append({"text": "My Documents", "icon": _ico("folder"), "act": app.call("explorer", {"path": "C:\\MY DOCUMENTS"})})
	return [
		{"text": "Programs", "icon": W95.icon("programs"), "sub": programs},
		{"text": "Documents", "icon": W95.icon("documents"), "sub": docs},
		{"text": "Settings", "icon": W95.icon("settings"), "sub": [
			{"text": "Control Panel", "icon": _ico("control"), "act": app.call("explorer", {"path": "CONTROL"})},
			{"text": "Display", "icon": _ico("computer"), "act": func(): Dialogs.display_props(self)},
			{"text": "Date/Time", "icon": _ico("clock"), "act": func(): Dialogs.datetime_props(self)},
		]},
		{"text": "Find", "icon": W95.icon("find"), "sub": [
			{"text": "Files or Folders...", "icon": _ico("find"), "act": app.call("find")},
		]},
		{"text": "Help", "icon": W95.icon("help"), "act": app.call("help")},
		{"text": "Run...", "icon": W95.icon("run"), "act": func(): Dialogs.run_dialog(self)},
		{"sep": true},
		{"text": "Shut Down...", "icon": W95.icon("shutdown"), "act": func(): Dialogs.shutdown_dialog(self)},
	]


# ============================================================ input / cursor
func _input(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		_mouse_pos = ev.position
		if cursor:
			var c: Dictionary = W95.cursor(_cursor_kind if _cursor_kind != "" else "arrow")
			cursor.position = _mouse_pos - c.hot
	if state == "boot":
		if ev is InputEventMouseButton and ev.pressed or ev is InputEventKey and ev.pressed:
			_skip = true
		return
	if state != "running":
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if dialog_layer.get_child_count() > 0 or has_open_menu():
			return
		for i in range(windows.size() - 1, -1, -1):
			var w: Control = windows[i]
			if w.visible and Rect2(w.position, w.size).has_point(ev.position):
				if w != active_window:
					focus_window(w)
				break


func _process(delta: float) -> void:
	if state == "boot" or state == "shutdown":
		_splash_t += delta
		if splash.visible:
			splash.queue_redraw()
	if state == "running":
		modem_blink += delta
		if modem_icon:
			modem_icon.modulate = Color.WHITE if int(modem_blink * 4.0) % 3 != 0 else Color(0.55, 0.55, 0.55)
	if state == "off":
		return
	var kind := "arrow"
	if busy:
		kind = "busy"
	else:
		var h := gui_get_hovered_control()
		if h != null and h.visible:
			var local := h.get_global_transform().affine_inverse() * _mouse_pos
			if h.has_method("edge_at"):
				var e: int = h.edge_at(local)
				if e & 3 and e & 12:
					kind = "hsize"
				elif e & 3:
					kind = "hsize"
				elif e & 12:
					kind = "vsize"
			if kind == "arrow":
				match h.get_cursor_shape(local):
					Control.CURSOR_IBEAM: kind = "ibeam"
					Control.CURSOR_POINTING_HAND: kind = "hand"
					Control.CURSOR_BUSY, Control.CURSOR_WAIT: kind = "busy"
					Control.CURSOR_HSIZE, Control.CURSOR_FDIAGSIZE, Control.CURSOR_BDIAGSIZE: kind = "hsize"
					Control.CURSOR_VSIZE: kind = "vsize"
	_set_cursor(kind)


func _set_cursor(kind: String) -> void:
	if kind == _cursor_kind:
		return
	_cursor_kind = kind
	var c: Dictionary = W95.cursor(kind)
	cursor.texture = c.tex
	cursor.position = _mouse_pos - c.hot
	cursor.size = c.tex.get_size()


func set_pointer_visible(v: bool) -> void:
	if cursor:
		cursor.visible = v


## Escape closes menus and dialogs first. Returns true if it consumed the key.
func escape() -> bool:
	if has_open_menu():
		close_menus()
		return true
	var d := _top_dialog()
	if d != null:
		d.request_close()
		return true
	return false


# ============================================================== world links
## Called by the game when the player leans in to (false) or sits back from (true) the CRT.
func set_away(a: bool) -> void:
	if a == away:
		return
	away = a
	away_changed.emit(a)


func play(name: String, db := -10.0) -> void:
	sound.emit(name, db)


func log_event(text: String) -> void:
	if world != null and world.props != null and world.props.terminal != null:
		world.props.terminal.add_log(text)


func gate_is_open() -> bool:
	return world != null and world.lot != null and world.lot.gate.is_open


func set_gate(open: bool) -> void:
	if world == null or world.lot == null:
		return
	if open:
		world.lot.gate.open()
	else:
		world.lot.gate.close()
	log_event("GATE %s - REMOTE" % ("OPENED" if open else "CLOSED"))


func set_wallpaper(c: Color) -> void:
	wall.color = c


# ===================================================== shared UI helpers
## Builds a labelled Button the way every app wants it.
func button(text: String, min_size := Vector2(75, 23)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	return b
