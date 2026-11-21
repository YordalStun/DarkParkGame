extends Control
## Find: All Files. Searches the fake disk by name.

const W95 := preload("res://scripts/desktop/w95.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")

var os: Node
var list: ItemList
var edit: LineEdit
var _paths: Array = []


func setup(p_os: Node, _win: Control, _args: Dictionary) -> void:
	os = p_os
	var l := Label.new()
	l.text = "Named:"
	l.position = Vector2(8, 12)
	add_child(l)
	edit = LineEdit.new()
	edit.position = Vector2(56, 8)
	edit.size = Vector2(220, 22)
	edit.text_submitted.connect(func(_t): _search())
	add_child(edit)
	var b: Button = os.button("Find Now", Vector2(76, 23))
	b.position = Vector2(284, 8)
	b.size = Vector2(76, 23)
	b.pressed.connect(_search)
	add_child(b)
	list = ItemList.new()
	list.position = Vector2(6, 38)
	list.size = Vector2(360, 190)
	list.item_activated.connect(func(i): Dialogs.open_file(os, _paths[i]))
	add_child(list)
	edit.grab_focus()


func _search() -> void:
	list.clear()
	_paths.clear()
	var q := edit.text.strip_edges().to_upper()
	if q == "":
		return
	_walk("", q)


func _walk(p: String, q: String) -> void:
	var items: Array = os.vfs.list(p) if p != "" else (os.vfs.root.kids.values())
	for n in items:
		var full: String = n.name if p == "" else os.vfs.join(p, n.name)
		if p == "":
			full = n.name
		if n.name.to_upper().contains(q):
			list.add_item(full, W95.icon(os.vfs.icon_for(n), true))
			_paths.append(full)
		if n.type == "dir" and not n.get("notready", false):
			_walk(full if p != "" else n.name + "\\", q)
