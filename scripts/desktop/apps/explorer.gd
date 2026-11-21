extends Control
## My Computer / folder windows / Control Panel / Network Neighborhood / Recycle Bin.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

var os: Node
var win: Control
var list: ItemList
var status: Label
var path := ""
var _entries: Array = []      # parallel to list items: Dictionary {kind, path|name}
var _history: Array = []


func setup(p_os: Node, p_win: Control, args: Dictionary) -> void:
	os = p_os
	win = p_win
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var bar: Control = MBar.new()
	box.add_child(bar)
	bar.setup(os, [["File", _file_items], ["View", _view_items]])
	var tb := HBoxContainer.new()
	tb.custom_minimum_size = Vector2(0, 26)
	box.add_child(tb)
	var up: Button = os.button("Up", Vector2(44, 22))
	up.pressed.connect(go_up)
	tb.add_child(up)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.icon_mode = ItemList.ICON_MODE_TOP
	list.fixed_icon_size = Vector2i(32, 32)
	list.max_columns = 0
	list.same_column_width = true
	list.max_text_lines = 2
	list.item_activated.connect(_activate)
	list.item_clicked.connect(func(i, _p, btn):
		if btn == MOUSE_BUTTON_RIGHT:
			list.select(i)
			os.open_menu([{"text": "Open", "bold": true, "act": func(): _activate(i)}, {"sep": true}, {"text": "Properties", "dis": true}], os._mouse_pos))
	box.add_child(list)
	status = Label.new()
	status.custom_minimum_size = Vector2(0, 18)
	box.add_child(status)
	navigate(args.get("path", ""), false)


func _file_items() -> Array:
	return [
		{"text": "Open", "act": func():
			var s := list.get_selected_items()
			if s.size() > 0:
				_activate(s[0])},
		{"sep": true},
		{"text": "Close", "act": func(): win.request_close()},
	]


func _view_items() -> Array:
	return [
		{"text": "Large Icons", "check": list.icon_mode == ItemList.ICON_MODE_TOP, "act": func(): list.icon_mode = ItemList.ICON_MODE_TOP; list.fixed_icon_size = Vector2i(32, 32)},
		{"text": "List", "check": list.icon_mode == ItemList.ICON_MODE_LEFT, "act": func(): list.icon_mode = ItemList.ICON_MODE_LEFT; list.fixed_icon_size = Vector2i(16, 16)},
	]


func go_up() -> void:
	if path == "" or path == "NET" or path == "CONTROL":
		navigate("")
	elif path.length() <= 3:
		navigate("")
	else:
		navigate(os.vfs.parent_of(path))


func navigate(p: String, _push := true) -> void:
	path = p
	list.clear()
	_entries.clear()
	var title := "My Computer"
	if p == "":
		for d in ["A:", "C:", "D:"]:
			var label: String = {"A:": "3½ Floppy (A:)", "C:": "(C:)", "D:": "(D:)"}[d]
			if d == "D:":
				label = "Audio CD (D:)"
			var ico: String = {"A:": "drive_floppy", "C:": "drive_hd", "D:": "drive_cd"}[d]
			_add(label, ico, {"kind": "dir", "path": d + "\\"})
		_add("Control Panel", "control", {"kind": "ctl"})
		_add("Dial-Up Networking", "modem", {"kind": "dial"})
	elif p == "NET":
		title = "Network Neighborhood"
		_add("Entire Network", "network", {"kind": "net", "name": "Entire Network"})
		for n in ["BOOTH2", "OFFICE", "GATEHOUSE", "CAMSERVER"]:
			_add(n, "computer", {"kind": "net", "name": n})
	elif p == "CONTROL":
		title = "Control Panel"
		for e in [["Display", "computer"], ["Date/Time", "clock"], ["System", "computer"], ["Network", "network"], ["Mouse", "doc"], ["Keyboard", "doc"], ["Sounds", "speaker"], ["Modems", "modem"]]:
			_add(e[0], e[1], {"kind": "cp", "name": e[0]})
	else:
		title = "Recycle Bin" if p.to_upper() == os.vfs.RECYCLE else (os.vfs.base_name(p) if p.length() > 3 else p)
		for n in os.vfs.list(p):
			_add(n.name, os.vfs.icon_for(n), {"kind": "dir" if n.type == "dir" else "file", "path": os.vfs.join(p, n.name)})
	win.set_title(title)
	status.text = " %d object(s)" % list.item_count


func _add(label: String, icon: String, entry: Dictionary) -> void:
	list.add_item(label, W95.icon(icon))
	_entries.append(entry)


func _activate(i: int) -> void:
	var e: Dictionary = _entries[i]
	match e.kind:
		"dir":
			var n: Variant = os.vfs.get_node(e.path)
			if n != null and n.get("notready", false):
				Dialogs.msgbox(os, "My Computer", "%s is not accessible.\n\nThe device is not ready." % e.path, "error")
				return
			navigate(e.path)
		"file":
			Dialogs.open_file(os, e.path)
		"ctl":
			navigate("CONTROL")
		"dial":
			Dialogs.dialup(os, func(_ok): pass)
		"net":
			if e.name == "BOOTH2":
				navigate("C:\\")
			else:
				Dialogs.msgbox(os, "Network Neighborhood", "\\\\%s is not accessible. The network path was not found." % e.name, "error")
		"cp":
			match e.name:
				"Display": Dialogs.display_props(os)
				"Date/Time": Dialogs.datetime_props(os)
				"System": Dialogs.msgbox(os, "System Properties", "NightWin 95\n4.00.950 B\n\nRegistered to:\nNightwatch Security Systems Ltd.\nLot C, Booth 2\n\nComputer:\nGenuine Intel Pentium(r)\n16.0MB RAM", "info")
				_: Dialogs.msgbox(os, e.name, "This item is not available on this computer.", "warn")
