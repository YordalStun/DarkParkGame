extends Control
## GateLog: tonight's expected staff, and the vehicle entry log. Pick the person,
## type the registration you read off the plate, press Log Vehicle.
## Talks to the story director (world.story); works standalone with no story too.

const W95 := preload("res://scripts/desktop/w95.gd")

var os: Node
var story
var _list: ItemList
var _reg: LineEdit
var _log: ItemList
var _status: Label


func setup(p_os: Node, _win: Control, _args: Dictionary) -> void:
	os = p_os
	story = os.world.story if os.world != null and "story" in os.world else null
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_right = -6
	box.offset_top = 4
	box.offset_bottom = -4
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var h := Label.new()
	h.text = "Tonight's list  -  FRI 13-OCT-1989  (select a name)"
	h.add_theme_font_override("font", W95.font("sansb"))
	box.add_child(h)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 116)
	_list.add_theme_font_override("font", W95.font("mono"))
	_list.add_theme_font_size_override("font_size", 12)
	box.add_child(_list)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var rl := Label.new()
	rl.text = "Vehicle reg:"
	row.add_child(rl)
	_reg = LineEdit.new()
	_reg.custom_minimum_size = Vector2(120, 22)
	_reg.max_length = 9
	_reg.placeholder_text = "E123 ABC"
	_reg.text_submitted.connect(func(_t): _submit())
	row.add_child(_reg)
	var b: Button = os.button("Log Vehicle", Vector2(90, 23))
	b.pressed.connect(_submit)
	row.add_child(b)
	_status = Label.new()
	row.add_child(_status)

	var h2 := Label.new()
	h2.text = "Entry log"
	h2.add_theme_font_override("font", W95.font("sansb"))
	box.add_child(h2)
	_log = ItemList.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("font", W95.font("mono"))
	_log.add_theme_font_size_override("font_size", 12)
	box.add_child(_log)
	if story:
		story.list_changed.connect(_fill)
	_fill()
	_reg.grab_focus.call_deferred()


func _names() -> Array:
	return story.staff_list() if story else []


func _fill() -> void:
	var sel := _list.get_selected_items()
	_list.clear()
	var logged := {}
	if story:
		for e in story.entries:
			logged[e.name] = true
	for e in _names():
		_list.add_item("%s %-18s %s  %s" % ["*" if logged.has(e.name) else " ", e.name, e.staff_no, e.dept])
	if sel.size() > 0 and sel[0] < _list.item_count:
		_list.select(sel[0])
	_log.clear()
	if story:
		for e in story.entries:
			_log.add_item("%s  %-9s %s" % [e.time, e.reg, e.name])
	if _log.item_count == 0:
		_log.add_item("(no vehicles logged yet)")


func _submit() -> void:
	var reg := _reg.text.strip_edges().to_upper()
	if reg.length() < 3:
		_status.text = "Type the reg."
		return
	var sel := _list.get_selected_items()
	if sel.is_empty():
		_status.text = "Pick a name."
		return
	var who: String = _names()[sel[0]].name
	if story:
		story.log_entry(reg, who)
	os.log_event("VEHICLE %s - %s" % [reg, who])
	_status.text = "Logged."
	_reg.text = ""
	_fill()
