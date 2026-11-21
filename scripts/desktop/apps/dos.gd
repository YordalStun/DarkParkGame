extends Control
## MS-DOS Prompt with a handful of working commands against the fake disk.

const W95 := preload("res://scripts/desktop/w95.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

var os: Node
var win: Control
var lines: Array = []
var input := ""
var cwd := "C:\\WINDOWS"
var history: Array = []
var hist_i := 0
var _blink := 0.0
var _font: Font
var _fs := 18
var _cw := 7.0
var _lh := 13.0


func setup(p_os: Node, p_win: Control, _args: Dictionary) -> void:
	os = p_os
	win = p_win
	_font = W95.font("vga")
	_cw = _font.get_char_size(77, _fs).x
	_lh = _font.get_height(_fs) - 2.0
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	lines = ["NightWin 95  [Version 4.00.950]", "(C)Copyright Nightwatch Systems 1981-1994.", ""]
	grab_focus()
	gui_input.connect(_on_input)


func _prompt() -> String:
	return cwd + ">"


func out(t: String) -> void:
	for l in t.split("\n"):
		lines.append(l)
	while lines.size() > 300:
		lines.pop_front()
	queue_redraw()


func _process(d: float) -> void:
	_blink += d
	if _blink > 0.5:
		_blink = 0.0
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var cols := maxi(10, int((size.x - 8) / _cw))
	var rows := maxi(1, int((size.y - 4) / _lh))
	var all: Array = []
	for l in lines:
		var s: String = l
		if s.length() == 0:
			all.append("")
		while s.length() > 0:
			all.append(s.substr(0, cols))
			s = s.substr(cols)
	var cur := _prompt() + input
	var cl: Array = []
	while true:
		cl.append(cur.substr(0, cols))
		cur = cur.substr(cols)
		if cur.length() == 0:
			break
	all.append_array(cl)
	var start := maxi(0, all.size() - rows)
	var y := _lh
	for i in range(start, all.size()):
		draw_string(_font, Vector2(4, y), all[i], HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, Color(0.75, 0.75, 0.75))
		y += _lh
	if has_focus() and _blink < 0.3 or not has_focus():
		var last: String = all[all.size() - 1]
		var cx := 4.0 + last.length() * _cw
		var cy := _lh * (all.size() - start) - _lh * 0.3
		draw_rect(Rect2(cx, cy, _cw, 3), Color(0.75, 0.75, 0.75))


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		grab_focus()
		return
	if not (ev is InputEventKey and ev.pressed):
		return
	accept_event()
	match ev.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			var cmd := input
			lines.append(_prompt() + cmd)
			input = ""
			if cmd.strip_edges() != "":
				history.append(cmd)
			hist_i = history.size()
			run(cmd.strip_edges())
		KEY_BACKSPACE:
			input = input.substr(0, input.length() - 1)
		KEY_UP:
			if hist_i > 0:
				hist_i -= 1
				input = history[hist_i]
		KEY_DOWN:
			if hist_i < history.size() - 1:
				hist_i += 1
				input = history[hist_i]
			else:
				hist_i = history.size()
				input = ""
		_:
			if ev.unicode >= 32 and ev.unicode < 127:
				input += char(ev.unicode)
	queue_redraw()


func _abs(p: String) -> String:
	if p.length() >= 2 and p[1] == ":":
		return p
	if p.begins_with("\\"):
		return cwd.substr(0, 2) + p
	return os.vfs.join(cwd, p)


func run(cmd: String) -> void:
	if cmd == "":
		return
	var parts := cmd.split(" ", false, 1)
	var c := parts[0].to_lower()
	var a := parts[1].strip_edges() if parts.size() > 1 else ""
	match c:
		"help", "?":
			out("DIR  CD  TYPE  CLS  VER  DATE  TIME  ECHO  MEM  VOL  MD  DEL  EDIT  START  PING  WHO  EXIT")
		"ver":
			out("\nNightWin 95 [Version 4.00.950]")
		"cls":
			lines.clear()
		"echo":
			out(a)
		"date":
			out("Current date is " + os.get_node("/root/NightClock").DATE_TEXT)
		"time":
			out("Current time is " + os.clock_text())
		"vol":
			out(" Volume in drive C has no label\n Volume Serial Number is 1989-0A13")
		"mem":
			out("\nMemory Type        Total       Used       Free\n----------------  --------  --------  --------\nConventional          640K      121K      519K\nExtended (XMS)     15,744K    4,310K   11,434K")
		"who", "users", "whoami":
			out("OPERATOR2    BOOTH 2    logged on\nR.KESSLER    BOOTH 2    (idle 14 days)")
		"exit":
			win.request_close()
		"cd", "chdir":
			if a == "" or a == ".":
				out(cwd)
			elif a == "..":
				var p: String = os.vfs.parent_of(cwd)
				cwd = p if p != "" else cwd
			elif os.vfs.is_dir(_abs(a)):
				cwd = _abs(a).to_upper()
			else:
				out("Invalid directory")
		"dir":
			var path := cwd if a == "" else _abs(a)
			if not os.vfs.is_dir(path):
				out("File not found")
				return
			out(" Volume in drive C has no label\n Directory of %s\n" % path.to_upper())
			var nf := 0
			var nd := 0
			var bytes := 0
			for n in os.vfs.list(path):
				var nm: String = n.name.to_upper()
				if n.type == "dir":
					nd += 1
					out("%-13s <DIR>        10-13-89  11:04p" % nm)
				else:
					nf += 1
					var sz: int = os.vfs.size_of(n)
					bytes += sz
					out("%-13s %10s  10-13-89  11:04p" % [nm, str(sz)])
			out("      %d file(s)  %d bytes\n      %d dir(s)   87,203,840 bytes free" % [nf, bytes, nd])
		"type":
			var path := _abs(a)
			var n: Variant = os.vfs.get_node(path)
			if n == null or n.type != "file":
				out("File not found - " + a.to_upper())
			else:
				out(n.text)
		"md", "mkdir":
			if not os.vfs.make_dir(_abs(a)):
				out("Unable to create directory")
		"del", "erase":
			if not os.vfs.delete(_abs(a)):
				out("File not found")
		"edit":
			os.open_app("notepad", {"path": _abs(a)} if a != "" else {})
		"start":
			Dialogs.run_command(os, a)
		"ping":
			out("\nPinging %s with 32 bytes of data:\n" % a)
			for i in 3:
				out("Request timed out.")
			out("\nPing statistics: Packets: Sent = 3, Received = 0, Lost = 3 (100%)")
		"win":
			out("Windows is already running.")
		_:
			if os.vfs.EXE_APPS.has((c + ".exe").to_upper()) or os.vfs.EXE_APPS.has(c.to_upper()):
				Dialogs.run_command(os, c.get_basename())
			else:
				out("Bad command or file name")
