extends Control
## Notepad: edits text files on the fake disk.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

var os: Node
var win: Control
var edit: TextEdit
var path := ""
var modified := false
var _closing_ok := false


func setup(p_os: Node, p_win: Control, args: Dictionary) -> void:
	os = p_os
	win = p_win
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	var bar: Control = MBar.new()
	box.add_child(bar)
	bar.setup(os, [["File", _file_items], ["Edit", _edit_items], ["Help", _help_items]])
	edit = TextEdit.new()
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_override("font", W95.font("mono"))
	edit.add_theme_font_size_override("font_size", 12)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	edit.text_changed.connect(func():
		modified = true
		_update_title())
	box.add_child(edit)
	if args.has("path"):
		load_file(args["path"])
	else:
		_update_title()
	edit.grab_focus()


func _update_title() -> void:
	var nm: String = "Untitled" if path == "" else os.vfs.base_name(path)
	win.set_title("%s - Notepad" % nm)


func load_file(p: String) -> void:
	path = p
	edit.text = os.vfs.read(p)
	modified = false
	_update_title()


func _file_items() -> Array:
	return [
		{"text": "New", "act": func(): _if_saved(func(): path = ""; edit.text = ""; modified = false; _update_title())},
		{"text": "Open...", "act": func(): Dialogs.file_dialog(os, "open", "C:\\MY DOCUMENTS", "", func(p): load_file(p))},
		{"text": "Save", "act": save},
		{"text": "Save As...", "act": save_as},
		{"sep": true},
		{"text": "Exit", "act": func(): win.request_close()},
	]


func _edit_items() -> Array:
	return [
		{"text": "Select All", "act": func(): edit.select_all()},
		{"text": "Time/Date", "act": func(): edit.insert_text_at_caret("%s %s" % [os.clock_text(), os.get_node("/root/NightClock").DATE_TEXT])},
		{"sep": true},
		{"text": "Word Wrap", "check": edit.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY, "act": func():
			edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE if edit.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY else TextEdit.LINE_WRAPPING_BOUNDARY},
	]


func _help_items() -> Array:
	return [{"text": "About Notepad", "act": func(): Dialogs.msgbox(os, "About Notepad", "NightWin 95 Notepad\nCopyright (C) 1994 Nightwatch Systems Ltd.", "info")}]


func save() -> void:
	if path == "":
		save_as()
		return
	os.vfs.write(path, edit.text)
	modified = false
	_update_title()


func save_as() -> void:
	Dialogs.file_dialog(os, "save", "C:\\MY DOCUMENTS", "" if path == "" else os.vfs.base_name(path), func(p):
		path = p
		save())


func _if_saved(next: Callable) -> void:
	if not modified:
		next.call()
		return
	Dialogs.msgbox(os, "Notepad", "The text in the file has changed.\n\nDo you want to save the changes?", "question", ["Yes", "No", "Cancel"], func(i):
		if i == 0:
			save()
			next.call()
		elif i == 1:
			next.call())


func on_close() -> bool:
	if _closing_ok or not modified:
		return true
	_if_saved(func():
		_closing_ok = true
		win.request_close())
	return false
