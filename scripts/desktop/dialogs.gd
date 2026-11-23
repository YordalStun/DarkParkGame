extends RefCounted
## Stock dialogs: message box, Run, Shut Down, Welcome, Display/Date properties,
## dial-up connection and an Open/Save file dialog. All are static and take the DesktopOS.

const W95 := preload("res://scripts/desktop/w95.gd")
const WindowScript := preload("res://scripts/desktop/window.gd")

const WALLPAPERS := {
	"Teal": Color8(0, 128, 128), "Black": Color8(0, 0, 0), "Navy": Color8(0, 0, 128),
	"Green": Color8(0, 100, 0), "Maroon": Color8(128, 0, 0), "Grey": Color8(128, 128, 128),
}

static var _tip := 0
const TIPS := [
	"Your shift notes are in My Documents. Read them before your first patrol.",
	"Gate Control (Programs > Nightwatch) opens and closes the barrier from your desk. No need to go out in the rain.",
	"Camera links 1-4 are down. If CamLink ever shows you a picture, call your supervisor on extension 214.",
	"The Internet works through the modem on the desk. It is slow. Be patient.",
	"To get back to the green Nightwatch terminal: Start > Shut Down > Restart in MS-DOS mode.",
	"Right-click the desktop for a menu. Right-click the screen's edge to sit back.",
]


static func make(os: Node, title: String, icon: String, size: Vector2) -> Control:
	var w: Control = WindowScript.new()
	w.setup(os, title, icon, size, {"min": false, "max": false, "resize": false, "dialog": true})
	return w


static func _label(text: String, pos: Vector2, width := -1.0) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = W95.wrap(text, width) if width > 0.0 else text
	return l


static func _button_row(os: Node, win: Control, labels: Array, y: float, cb: Callable, default := 0) -> void:
	var bw := 75.0
	var total := labels.size() * bw + (labels.size() - 1) * 6.0
	var x: float = (win.client.size.x - total) / 2.0
	for i in labels.size():
		var b: Button = os.button(labels[i], Vector2(bw, 23))
		b.position = Vector2(x + i * (bw + 6.0), y)
		b.size = Vector2(bw, 23)
		var idx := i
		b.pressed.connect(func():
			os.close_dialog(win)
			if cb.is_valid():
				cb.call(idx))
		win.client.add_child(b)


## kind: info | warn | error | question. cb gets the index of the button pressed.
static func msgbox(os: Node, title: String, text: String, kind := "info", buttons := ["OK"], cb := Callable()) -> Control:
	var f := W95.font("sans")
	var tw := 250.0
	text = W95.wrap(text, tw)
	var ts := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, W95.FONT_SIZE)
	var w_ := maxf(tw + 70.0, buttons.size() * 81.0 + 20.0)
	var h_ := maxf(ts.y, 32.0) + 70.0
	var win := make(os, title, kind, Vector2(w_ + 8, h_ + 27))
	var ic := TextureRect.new()
	ic.texture = W95.icon(kind)
	ic.position = Vector2(14, 14)
	win.client.add_child(ic)
	win.client.add_child(_label(text, Vector2(58, 14 + (32 - minf(ts.y, 32.0)) / 2.0 if ts.y < 32.0 else 14), tw))
	_button_row(os, win, buttons, h_ - 34.0, cb)
	os.show_dialog(win)
	os.play("ding", -12.0)
	return win


static func run_dialog(os: Node) -> void:
	var win := make(os, "Run", "run", Vector2(356, 142))
	var c: Control = win.client
	var ic := TextureRect.new()
	ic.texture = W95.icon("run")
	ic.position = Vector2(10, 10)
	c.add_child(ic)
	c.add_child(_label("Type the name of a program, folder, document, or\nInternet address, and NightWin will open it for you.", Vector2(52, 8), 280))
	c.add_child(_label("Open:", Vector2(10, 58)))
	var le := LineEdit.new()
	le.position = Vector2(52, 54)
	le.size = Vector2(278, 22)
	c.add_child(le)
	var go := func():
		var t := le.text.strip_edges()
		os.close_dialog(win)
		if t != "":
			run_command(os, t)
	le.text_submitted.connect(func(_t): go.call())
	var ok: Button = os.button("OK")
	ok.position = Vector2(100, 90)
	ok.size = Vector2(75, 23)
	ok.pressed.connect(go)
	c.add_child(ok)
	var cancel: Button = os.button("Cancel")
	cancel.position = Vector2(181, 90)
	cancel.size = Vector2(75, 23)
	cancel.pressed.connect(func(): os.close_dialog(win))
	c.add_child(cancel)
	os.show_dialog(win)
	le.grab_focus()


static func run_command(os: Node, t: String) -> void:
	var low := t.to_lower()
	var table := {
		"notepad": "notepad", "calc": "calc", "mspaint": "paint", "paint": "paint", "winmine": "mines",
		"explorer": "explorer", "command": "dos", "cmd": "dos", "iexplore": "browser", "nnexplor": "browser",
		"camlink": "camlink", "gatectl": "gatectl", "mail": "mail", "help": "help", "find": "find",
	}
	var key := low.get_basename() if low.contains(".") and not low.begins_with("http") else low
	if low.begins_with("http://") or low.begins_with("https://") or low.begins_with("www."):
		os.open_app("browser", {"url": t})
	elif table.has(key):
		os.open_app(table[key])
	elif os.vfs.is_dir(t):
		os.open_app("explorer", {"path": t})
	elif os.vfs.get_node(t) != null:
		open_file(os, t)
	else:
		msgbox(os, t, "Cannot find the file '%s' (or one of its components). Make sure the path and filename are correct and that all required libraries are available." % t, "error")


## Open a file from the VFS with whatever program suits it.
## A slim progress bar for the dialogs below. Set the value with c.set_meta("v", 0..1) and queue_redraw().
static func _bar(pos: Vector2, size: Vector2, color: Color) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = size
	c.custom_minimum_size = size
	c.set_meta("v", 0.0)
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1))
		c.draw_rect(Rect2(Vector2(1, 1), c.size - Vector2(2, 2)), Color(0.78, 0.78, 0.78))
		c.draw_rect(Rect2(Vector2(1, 1), Vector2((c.size.x - 2) * clampf(c.get_meta("v"), 0.0, 1.0), c.size.y - 2)), color)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.35, 0.35, 0.35), false, 1.0))
	return c


## "File Download": saves `file_name` to C:\DOWNLOADS over a while (a modem is slow, but not that slow).
## You can keep using the computer while it runs.
static func download(os: Node, file_name: String, kb: int, host: String) -> void:
	var secs := clampf(kb / 30.0, 6.0, 60.0)
	var win := make(os, "File Download", "globe", Vector2(340, 150))
	var c: Control = win.client
	c.add_child(_label("Saving %s\nfrom %s" % [file_name, host], Vector2(14, 12)))
	var bar := _bar(Vector2(14, 58), Vector2(290, 14), Color(0.05, 0.1, 0.55))
	c.add_child(bar)
	var eta := _label("Estimated time left: %d sec" % int(secs), Vector2(14, 80))
	c.add_child(eta)
	var cancel: Button = os.button("Cancel", Vector2(75, 23))
	cancel.position = Vector2(130, 106)
	c.add_child(cancel)
	var tw: Tween = os.create_tween()
	tw.tween_method(func(v: float):
		bar.set_meta("v", v)
		bar.queue_redraw()
		eta.text = "Estimated time left: %d sec" % int(ceil(secs * (1.0 - v))), 0.0, 1.0, secs)
	tw.finished.connect(func():
		os.close_dialog(win)
		os.vfs.make_dir("C:\\DOWNLOADS")
		os.vfs._file("C:\\DOWNLOADS\\" + file_name, "MZ", kb * 1024)
		os.play("ding", -12.0)
		msgbox(os, "Download complete", "%s has been saved to C:\\DOWNLOADS.\n\nDouble-click it in My Computer to run it." % file_name, "info"))
	cancel.pressed.connect(func():
		tw.kill()
		os.close_dialog(win))
	os.show_dialog(win, false)


## MCARE95.EXE: the MediCare Remote setup. When it finishes, NightLink is added to the desktop.
static func install_medicare(os: Node) -> void:
	var story = os.world.story if os.world != null and "story" in os.world else null
	if story == null or story.get("hack") == null:
		msgbox(os, "MCARE95.EXE", "MediCare Remote cannot run on this machine.", "error")
		return
	if story.hack.installed:
		msgbox(os, "MediCare Remote Setup", "MediCare Remote is already installed.", "info")
		return
	var win := make(os, "MediCare Remote Setup", "dos", Vector2(340, 140))
	var c: Control = win.client
	c.add_child(_label("Installing MediCare Remote Client v1.2...\nCopying files to C:\\PROGRAM FILES\\MEDICARE", Vector2(14, 12)))
	var bar := _bar(Vector2(14, 62), Vector2(290, 14), Color(0.05, 0.1, 0.55))
	c.add_child(bar)
	var tw: Tween = os.create_tween()
	tw.tween_method(func(v: float):
		bar.set_meta("v", v)
		bar.queue_redraw(), 0.0, 1.0, 6.0)
	tw.finished.connect(func():
		os.close_dialog(win)
		var r: Dictionary = story.hack.install(story.local_player_id)
		if r.ok:
			os.vfs._dir("C:\\PROGRAM FILES\\MEDICARE")
			os.vfs._file("C:\\PROGRAM FILES\\MEDICARE\\NIGHTLNK.EXE", "MZ", 233000)
			os.refresh_hack_icon()
			os.play("ding", -12.0)
			msgbox(os, "MediCare Remote Setup", "Setup is complete.\n\nNightLink has been added to your desktop and the Start menu.", "info")
		else:
			msgbox(os, "MediCare Remote Setup", r.msg, "warn"))
	os.show_dialog(win)


static func open_file(os: Node, path: String) -> void:
	var n: Variant = os.vfs.get_node(path)
	if n == null:
		return
	if n.type == "dir":
		os.open_app("explorer", {"path": path})
		return
	var up: String = n.name.to_upper()
	if up == "MCARE95.EXE":
		install_medicare(os)
		return
	if os.vfs.EXE_APPS.has(up):
		os.open_app(os.vfs.EXE_APPS[up])
		return
	match os.vfs.ext_of(up):
		"TXT", "INI", "BAT", "SYS", "CFG", "LOG", "":
			os.open_app("notepad", {"path": path})
		"BMP":
			os.open_app("paint", {"path": path})
		"EXE", "COM":
			msgbox(os, n.name, "%s has performed an illegal operation and will be shut down." % n.name, "error")
		_:
			msgbox(os, "Open With", "Windows cannot open this file:\n\n%s\n\nTo open this file, Windows needs to know what program created it." % n.name, "warn")


static func shutdown_dialog(os: Node) -> void:
	var win := make(os, "Shut Down Windows", "shutdown", Vector2(330, 196))
	var c: Control = win.client
	var ic := TextureRect.new()
	ic.texture = W95.icon("shutdown")
	ic.position = Vector2(12, 14)
	c.add_child(ic)
	c.add_child(_label("What do you want the computer to do?", Vector2(58, 12)))
	var group := ButtonGroup.new()
	var opts := ["Shut down the computer?", "Restart the computer?", "Restart the computer in MS-DOS mode?"]
	var modes := ["shutdown", "restart", "dos"]
	var checks: Array = []
	for i in 3:
		var cb := CheckBox.new()
		cb.text = opts[i]
		cb.button_group = group
		cb.position = Vector2(60, 38 + i * 22)
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = i == 0
		c.add_child(cb)
		checks.append(cb)
	var yes: Button = os.button("Yes")
	yes.position = Vector2(48, 128)
	yes.size = Vector2(75, 23)
	yes.pressed.connect(func():
		var m := "shutdown"
		for i in 3:
			if checks[i].button_pressed:
				m = modes[i]
		os.close_dialog(win)
		os.shut_down(m))
	c.add_child(yes)
	var no: Button = os.button("No")
	no.position = Vector2(129, 128)
	no.size = Vector2(75, 23)
	no.pressed.connect(func(): os.close_dialog(win))
	c.add_child(no)
	var hp: Button = os.button("Help")
	hp.position = Vector2(210, 128)
	hp.size = Vector2(75, 23)
	hp.pressed.connect(func(): os.close_dialog(win); os.open_app("help"))
	c.add_child(hp)
	os.show_dialog(win)


static func welcome(os: Node) -> void:
	var win := make(os, "Welcome to NightWin 95", "moon", Vector2(400, 232))
	var c: Control = win.client
	var panel := Panel.new()
	panel.position = Vector2(8, 8)
	panel.size = Vector2(c.size.x - 16, 150)
	panel.add_theme_stylebox_override("panel", W95.thin_sunken())
	c.add_child(panel)
	var bulb := TextureRect.new()
	bulb.texture = W95.icon("info")
	bulb.position = Vector2(16, 18)
	c.add_child(bulb)
	var head := _label("Did you know...", Vector2(60, 18))
	head.add_theme_font_override("font", W95.font("sansb"))
	head.add_theme_font_size_override("font_size", 14)
	c.add_child(head)
	var body := _label(TIPS[_tip % TIPS.size()], Vector2(60, 46), 310)
	c.add_child(body)
	var close: Button = os.button("Close")
	close.position = Vector2(c.size.x - 96, 168)
	close.size = Vector2(80, 23)
	close.pressed.connect(func(): os.close_dialog(win))
	c.add_child(close)
	var nxt: Button = os.button("Next Tip")
	nxt.position = Vector2(c.size.x - 96, 194)
	nxt.size = Vector2(80, 23)
	nxt.pressed.connect(func():
		_tip += 1
		body.text = W95.wrap(TIPS[_tip % TIPS.size()], 310.0))
	c.add_child(nxt)
	var cb := CheckBox.new()
	cb.text = "Show this Welcome Screen next\ntime you start NightWin"
	cb.position = Vector2(10, 166)
	cb.button_pressed = true
	cb.focus_mode = Control.FOCUS_NONE
	cb.toggled.connect(func(on): os.welcome_enabled = on)
	c.add_child(cb)
	os.show_dialog(win, false)


static func display_props(os: Node) -> void:
	var win := make(os, "Display Properties", "computer", Vector2(300, 270))
	var c: Control = win.client
	c.add_child(_label("Background", Vector2(12, 10)))
	var prev := ColorRect.new()
	prev.color = os.wall.color
	prev.position = Vector2(70, 34)
	prev.size = Vector2(150, 96)
	c.add_child(prev)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", W95.raised())
	frame.position = Vector2(60, 24)
	frame.size = Vector2(170, 130)
	c.add_child(frame)
	frame.move_to_front()
	prev.move_to_front()
	var list := ItemList.new()
	list.position = Vector2(12, 164)
	list.size = Vector2(160, 70)
	var sel_color: Color = os.wall.color
	for k in WALLPAPERS:
		list.add_item(k)
		if WALLPAPERS[k] == os.wall.color:
			list.select(list.item_count - 1)
	list.item_selected.connect(func(i):
		sel_color = WALLPAPERS[list.get_item_text(i)]
		prev.color = sel_color)
	c.add_child(list)
	var ok: Button = os.button("OK", Vector2(60, 23))
	ok.position = Vector2(182, 166)
	ok.size = Vector2(60, 23)
	ok.pressed.connect(func(): os.set_wallpaper(sel_color); os.close_dialog(win))
	c.add_child(ok)
	var cancel: Button = os.button("Cancel", Vector2(60, 23))
	cancel.position = Vector2(182, 194)
	cancel.size = Vector2(60, 23)
	cancel.pressed.connect(func(): os.close_dialog(win))
	c.add_child(cancel)
	os.show_dialog(win)


static func datetime_props(os: Node) -> void:
	var win := make(os, "Date/Time Properties", "clock", Vector2(280, 190))
	var c: Control = win.client
	var ic := TextureRect.new()
	ic.texture = W95.icon("clock")
	ic.position = Vector2(14, 14)
	c.add_child(ic)
	var nc := os.get_node_or_null("/root/NightClock")
	var date_text: String = nc.DATE_TEXT if nc else ""
	c.add_child(_label("Date:  %s" % date_text, Vector2(64, 16)))
	c.add_child(_label("Time:  %s" % os.clock_text(), Vector2(64, 38)))
	c.add_child(_label("Time zone: (GMT) Greenwich Mean Time", Vector2(14, 78)))
	var ok: Button = os.button("OK")
	ok.position = Vector2(100, 120)
	ok.size = Vector2(75, 23)
	ok.pressed.connect(func(): os.close_dialog(win))
	c.add_child(ok)
	os.show_dialog(win)


static func connection_status(os: Node) -> void:
	msgbox(os, "Connected to NightNet", "Connected at 28800 bps.\n\nDo you want to disconnect?", "question", ["Disconnect", "Stay"], func(i):
		if i == 0:
			os.net_connected = false
			os.set_modem_icon(false))


## Dial-up connection. Calls cb(true) once connected (or immediately if already so).
static func dialup(os: Node, cb: Callable) -> void:
	if os.net_connected:
		cb.call(true)
		return
	var win := make(os, "Connect To", "modem", Vector2(318, 214))
	var c: Control = win.client
	var ic := TextureRect.new()
	ic.texture = W95.icon("modem")
	ic.position = Vector2(12, 10)
	c.add_child(ic)
	c.add_child(_label("NightNet Dial-Up", Vector2(60, 14)))
	c.add_child(_label("User name:", Vector2(14, 52)))
	var user := LineEdit.new()
	user.text = "operator2"
	user.position = Vector2(100, 48)
	user.size = Vector2(190, 22)
	c.add_child(user)
	c.add_child(_label("Password:", Vector2(14, 78)))
	var pw := LineEdit.new()
	pw.text = "********"
	pw.secret = true
	pw.position = Vector2(100, 74)
	pw.size = Vector2(190, 22)
	c.add_child(pw)
	c.add_child(_label("Phone number:", Vector2(14, 104)))
	var ph := LineEdit.new()
	ph.text = "555-0143"
	ph.position = Vector2(100, 100)
	ph.size = Vector2(190, 22)
	c.add_child(ph)
	var status := _label("", Vector2(14, 130), 280)
	c.add_child(status)
	var connect_btn: Button = os.button("Connect")
	connect_btn.position = Vector2(48, 150)
	connect_btn.size = Vector2(90, 23)
	c.add_child(connect_btn)
	var cancel: Button = os.button("Cancel")
	cancel.position = Vector2(174, 150)
	cancel.size = Vector2(90, 23)
	var cancelled := [false]
	cancel.pressed.connect(func():
		cancelled[0] = true
		os.close_dialog(win)
		cb.call(false))
	c.add_child(cancel)
	connect_btn.pressed.connect(func():
		connect_btn.disabled = true
		os.busy = true
		os.play("dialup", -8.0)
		var steps := ["Dialing 555-0143...", "Connecting...", "Verifying user name and password...", "Registering your computer on the network..."]
		for s in steps:
			status.text = s
			await os.get_tree().create_timer(1.6 if s != steps[0] else 2.2).timeout
			if cancelled[0]:
				os.busy = false
				return
		os.busy = false
		os.net_connected = true
		os.set_modem_icon(true)
		os.close_dialog(win)
		cb.call(true))
	os.show_dialog(win)


# ------------------------------------------------------- Open / Save As
## mode: "open" | "save". cb receives the chosen full path.
static func file_dialog(os: Node, mode: String, start_dir: String, default_name: String, cb: Callable) -> void:
	var win := make(os, "Open" if mode == "open" else "Save As", "folder_open", Vector2(340, 280))
	var c: Control = win.client
	var cur := [start_dir if os.vfs.is_dir(start_dir) else "C:\\MY DOCUMENTS"]
	var dir_label := _label("", Vector2(10, 10), 320)
	c.add_child(dir_label)
	var list := ItemList.new()
	list.position = Vector2(10, 30)
	list.size = Vector2(c.size.x - 20, 150)
	c.add_child(list)
	var name_edit := LineEdit.new()
	name_edit.text = default_name
	name_edit.position = Vector2(84, 188)
	name_edit.size = Vector2(150, 22)
	c.add_child(name_edit)
	c.add_child(_label("File name:", Vector2(10, 192)))
	var nodes: Array = []
	var refill := func():
		list.clear()
		nodes.clear()
		dir_label.text = "Look in:  " + cur[0]
		if cur[0].length() > 3:
			list.add_item("..", W95.icon("folder_open", true))
			nodes.append(null)
		for n in os.vfs.list(cur[0]):
			list.add_item(n.name, W95.icon(os.vfs.icon_for(n), true))
			nodes.append(n)
	refill.call()
	var accept := func():
		var nm := name_edit.text.strip_edges()
		if nm == "":
			return
		if mode == "save" and not nm.contains("."):
			nm += ".TXT"
		var path: String = os.vfs.join(cur[0], nm)
		if mode == "open" and os.vfs.get_node(path) == null:
			msgbox(os, "Open", "%s\nFile not found." % nm, "warn")
			return
		os.close_dialog(win)
		cb.call(path)
	var activate := func(i: int):
		if nodes[i] == null:
			cur[0] = os.vfs.parent_of(cur[0])
			if cur[0] == "":
				cur[0] = "C:\\"
			refill.call()
		elif nodes[i].type == "dir":
			cur[0] = os.vfs.join(cur[0], nodes[i].name)
			refill.call()
		else:
			name_edit.text = nodes[i].name
			if mode == "open":
				accept.call()
	list.item_activated.connect(activate)
	list.item_selected.connect(func(i):
		if nodes[i] != null and nodes[i].type == "file":
			name_edit.text = nodes[i].name)
	name_edit.text_submitted.connect(func(_t): accept.call())
	var ok: Button = os.button("Open" if mode == "open" else "Save")
	ok.position = Vector2(246, 186)
	ok.size = Vector2(80, 23)
	ok.pressed.connect(accept)
	c.add_child(ok)
	var cancel: Button = os.button("Cancel")
	cancel.position = Vector2(246, 214)
	cancel.size = Vector2(80, 23)
	cancel.pressed.connect(func(): os.close_dialog(win))
	c.add_child(cancel)
	os.show_dialog(win)
