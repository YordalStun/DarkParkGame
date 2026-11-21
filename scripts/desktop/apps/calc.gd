extends Control
## Calculator.

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")

var os: Node
var win: Control
var display: Label
var entry := "0"
var acc := 0.0
var op := ""
var fresh := true
var mem := 0.0


func setup(p_os: Node, p_win: Control, _args: Dictionary) -> void:
	os = p_os
	win = p_win
	var bar: Control = MBar.new()
	add_child(bar)
	bar.setup(os, [["Edit", func(): return [{"text": "Copy", "dis": true}, {"text": "Paste", "dis": true}]],
		["View", func(): return [{"text": "Standard", "check": true}, {"text": "Scientific", "dis": true}]],
		["Help", func(): return [{"text": "About Calculator", "act": func(): pass}]]])
	bar.size = Vector2(250, 19)
	var dp := Panel.new()
	dp.add_theme_stylebox_override("panel", W95.field())
	dp.position = Vector2(6, 26)
	dp.size = Vector2(242, 24)
	add_child(dp)
	display = Label.new()
	display.position = Vector2(4, 3)
	display.size = Vector2(232, 18)
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	display.add_theme_font_override("font", W95.font("mono"))
	display.add_theme_font_size_override("font_size", 14)
	dp.add_child(display)
	_show()
	var rows := [
		[["", ""], ["Backspace", "bk"], ["CE", "ce"], ["C", "c"]],
		[["MC", "mc"], ["7", "7"], ["8", "8"], ["9", "9"], ["/", "/"], ["sqrt", "sqrt"]],
		[["MR", "mr"], ["4", "4"], ["5", "5"], ["6", "6"], ["*", "*"], ["%", "pct"]],
		[["MS", "ms"], ["1", "1"], ["2", "2"], ["3", "3"], ["-", "-"], ["1/x", "inv"]],
		[["M+", "m+"], ["0", "0"], ["+/-", "neg"], [".", "."], ["+", "+"], ["=", "="]],
	]
	var y := 58.0
	for r in rows:
		var x := 6.0
		for cell in r:
			var is_top: bool = rows.find(r) == 0
			var w := 39.0
			if cell[1] == "":
				x += 41.0
				continue
			if is_top:
				w = 65.0
			var b: Button = os.button(cell[0], Vector2(w, 26))
			b.position = Vector2(x, y)
			b.size = Vector2(w, 26)
			var color := Color(0.6, 0, 0) if cell[1] in ["bk", "ce", "c", "/", "*", "-", "+", "=", "pct", "sqrt", "inv", "neg"] else Color(0, 0, 0.7)
			if cell[1] in ["mc", "mr", "ms", "m+"]:
				color = Color(0.8, 0, 0)
			for c in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(c, color)
			var key: String = cell[1]
			b.pressed.connect(func(): _press(key))
			add_child(b)
			x += 67.0 if is_top else 41.0
		y += 31.0 if rows.find(r) > 0 else 33.0


func _fmt(v: float) -> String:
	if is_inf(v) or is_nan(v):
		return "Cannot divide by zero."
	var s := "%.10f" % v
	s = s.rstrip("0").rstrip(".")
	return s if s != "" and s != "-" else "0"


func _show() -> void:
	display.text = entry


func _apply() -> void:
	var v := float(entry)
	match op:
		"+": acc += v
		"-": acc -= v
		"*": acc *= v
		"/": acc = acc / v if v != 0.0 else INF
		_: acc = v


func _press(k: String) -> void:
	os.play("click2", -16.0)
	if entry == "Cannot divide by zero." and k != "c":
		return
	match k:
		"0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
			entry = k if (fresh or entry == "0") else entry + k
			fresh = false
		".":
			if fresh:
				entry = "0."
				fresh = false
			elif not entry.contains("."):
				entry += "."
		"bk":
			if not fresh:
				entry = entry.substr(0, entry.length() - 1)
				if entry == "" or entry == "-":
					entry = "0"
		"ce":
			entry = "0"
			fresh = true
		"c":
			entry = "0"
			acc = 0.0
			op = ""
			fresh = true
		"neg":
			if entry != "0":
				entry = entry.substr(1) if entry.begins_with("-") else "-" + entry
		"sqrt":
			entry = _fmt(sqrt(maxf(0.0, float(entry))))
			fresh = true
		"inv":
			var v := float(entry)
			entry = _fmt(1.0 / v) if v != 0.0 else "Cannot divide by zero."
			fresh = true
		"pct":
			entry = _fmt(acc * float(entry) / 100.0)
			fresh = true
		"mc": mem = 0.0
		"mr":
			entry = _fmt(mem)
			fresh = true
		"ms":
			mem = float(entry)
			fresh = true
		"m+":
			mem += float(entry)
			fresh = true
		"+", "-", "*", "/", "=":
			if not (fresh and op != "" and k != "="):
				_apply()
			entry = _fmt(acc)
			op = "" if k == "=" else k
			fresh = true
	_show()
