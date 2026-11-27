extends CanvasLayer
## The storage crate and the buyer's deal, as small panels in the middle of the screen.
##   await crate(stash, carrying, hidden)  -> {"act": "take"|"put"|"put_all"|"hide"|"unhide"|"close", "i": index}
##   await sale(stash)                      -> Array of stash indices to sell (empty = not tonight)

const W := 760.0
var _font: Font
var _dim: ColorRect


func _ready() -> void:
	layer = 12
	_font = load("res://assets/fonts/VT323-Regular.ttf")


func _label(text: String, size: int, col: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(text: String, parent: Control, gold := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.set_border_width_all(1)
		sb.border_color = Color(0.4, 0.4, 0.38)
		sb.bg_color = (Color(0.91, 0.75, 0.44) if gold else Color(0.12, 0.12, 0.12)) if st != "hover" else Color(0.3, 0.28, 0.2)
		if st == "disabled":
			sb.bg_color = Color(0.08, 0.08, 0.08)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05) if gold else Color(0.88, 0.88, 0.82))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.95))
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.33))
	parent.add_child(b)
	return b


func _frame(title: String) -> VBoxContainer:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.065, 0.06, 0.97)
	sb.border_color = Color(0.91, 0.75, 0.44)
	sb.set_border_width_all(2)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(W, 0)
	_dim.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	_label(title, 34, Color(0.91, 0.75, 0.44), v)
	return v


func _row(parent: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	return h


func _spacer(parent: Control) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)


func _close() -> void:
	if _dim:
		_dim.queue_free()
		_dim = null


## The crate: what's in it (take out), what's in your hands (put in), and hiding it.
func crate(stash: Array, carrying: Array, hidden: bool, slots_free: int) -> Dictionary:
	var v := _frame("STORAGE CRATE   %d/%d" % [stash.size(), SaveGame.CRATE_SIZE])
	var picked := [{}]
	if hidden:
		_label("It's pushed under the desk, out of sight. Pull it out to use it.", 24, Color(0.75, 0.75, 0.7), v)
	else:
		_label("IN THE CRATE", 24, Color(0.91, 0.75, 0.44), v)
		if stash.is_empty():
			_label("  (empty)", 22, Color(0.55, 0.55, 0.5), v)
		for i in stash.size():
			var d: Array = BootItems.info(stash[i])
			var h := _row(v)
			_label("  " + str(d[0]) + ("   (yours to keep)" if BootItems.is_story(stash[i]) else "   worth %d" % d[1]), 22, Color(0.88, 0.88, 0.82), h)
			_spacer(h)
			var b := _button("TAKE OUT", h)
			b.disabled = int(d[3]) > slots_free
			var idx := i
			b.pressed.connect(func(): picked[0] = {"act": "take", "i": idx})
		_label("IN YOUR HANDS", 24, Color(0.91, 0.75, 0.44), v)
		if carrying.is_empty():
			_label("  (nothing)", 22, Color(0.55, 0.55, 0.5), v)
		for i in carrying.size():
			var h2 := _row(v)
			_label("  " + str(BootItems.info(carrying[i])[0]), 22, Color(0.88, 0.88, 0.82), h2)
			_spacer(h2)
			var b2 := _button("PUT IN", h2)
			b2.disabled = stash.size() >= SaveGame.CRATE_SIZE
			var idx2 := i
			b2.pressed.connect(func(): picked[0] = {"act": "put", "i": idx2})
	var bottom := _row(v)
	if not hidden and not carrying.is_empty():
		var all := _button("PUT EVERYTHING IN", bottom, true)
		all.disabled = stash.size() >= SaveGame.CRATE_SIZE
		all.pressed.connect(func(): picked[0] = {"act": "put_all"})
	_spacer(bottom)
	var hb := _button("PULL IT OUT" if hidden else "HIDE IT UNDER THE DESK", bottom)
	hb.pressed.connect(func(): picked[0] = {"act": "unhide" if hidden else "hide"})
	var c := _button("CLOSE", bottom)
	c.pressed.connect(func(): picked[0] = {"act": "close"})
	while picked[0].is_empty():
		await get_tree().process_frame
	_close()
	return picked[0]


## The buyer: tick what to sell from the crate. Returns the stash indices chosen.
var auto_sell := false   ## testing: tick the first thing and sell it


func sale(stash: Array, offer_k := 1.0) -> Array:
	var v := _frame("BAXTER")
	_label("\"What've you got for me, then?\"   (from your storage crate)", 24, Color(0.85, 0.85, 0.8), v)
	var ticks := []
	var total_l := [null]   # (filled in below; the closure reads it from here)
	var refresh := func():
		var t := 0
		for tk in ticks:
			if tk[0].button_pressed:
				t += tk[1]
		if total_l[0]:
			total_l[0].text = "HE'LL GIVE YOU: %d coins" % t
	var any := false
	for i in stash.size():
		if BootItems.is_story(stash[i]):
			continue
		any = true
		var d: Array = BootItems.info(stash[i])
		var price := maxi(1, int(round(int(d[1]) * offer_k)))
		var h := _row(v)
		var cb := CheckBox.new()
		cb.text = "  " + str(d[0])
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_override("font", _font)
		cb.add_theme_font_size_override("font_size", 22)
		cb.add_theme_color_override("font_color", Color(0.88, 0.88, 0.82))
		for st in [["checked", true], ["unchecked", false]]:
			var img := Image.create(18, 18, false, Image.FORMAT_RGBA8)
			for y in 18:
				for x in 18:
					if x < 2 or y < 2 or x > 15 or y > 15:
						img.set_pixel(x, y, Color(0.85, 0.85, 0.8))
					elif st[1] and x > 4 and y > 4 and x < 13 and y < 13:
						img.set_pixel(x, y, Color(0.91, 0.75, 0.44))
			cb.add_theme_icon_override(st[0], ImageTexture.create_from_image(img))
		h.add_child(cb)
		_spacer(h)
		_label("%d" % price, 22, Color(0.5, 0.88, 0.54), h)
		ticks.append([cb, price, i])
		cb.toggled.connect(func(_on): refresh.call())
	if not any:
		_label("  Nothing in the crate he'd want.", 22, Color(0.55, 0.55, 0.5), v)
	total_l[0] = _label("", 28, Color(0.91, 0.75, 0.44), v)
	refresh.call()
	var picked := [null]
	var row := _row(v)
	_spacer(row)
	var sell := _button("SELL", row, true)
	sell.disabled = not any
	sell.pressed.connect(func():
		var out := []
		for tk in ticks:
			if tk[0].button_pressed:
				out.append(tk[2])
		picked[0] = out)
	var no := _button("NOT TONIGHT", row)
	no.pressed.connect(func(): picked[0] = [])
	if auto_sell and not ticks.is_empty():
		ticks[0][0].button_pressed = true
		await get_tree().create_timer(1.0).timeout
		sell.pressed.emit()
	while picked[0] == null:
		await get_tree().process_frame
	_close()
	return picked[0]
