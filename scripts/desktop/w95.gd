extends RefCounted
## The look of the desktop: colours, fonts, bevelled style boxes, a Theme that makes
## every stock Control look like Windows 95, plus generated cursors and glyphs.
## Everything is static; call W95.theme() once and assign it to the desktop root.

const FACE := Color8(192, 192, 192)
const LIGHT := Color8(223, 223, 223)
const WHITE := Color8(255, 255, 255)
const SHADOW := Color8(128, 128, 128)
const BLACK := Color8(0, 0, 0)
const NAVY := Color8(0, 0, 128)
const TEAL := Color8(0, 128, 128)
const FONT_SIZE := 11

const ICON_DIR := "res://assets/desktop/icons/"

static var _theme: Theme
static var _fonts := {}
static var _icons := {}
static var _boxes := {}
static var _tex := {}


# ------------------------------------------------------------------ fonts
static func font(kind := "sans") -> FontFile:
	if _fonts.has(kind):
		return _fonts[kind]
	var path := ""
	match kind:
		"sans": path = "LiberationSans-Regular"
		"sansb": path = "LiberationSans-Bold"
		"serif": path = "LiberationSerif-Regular"
		"serifb": path = "LiberationSerif-Bold"
		"serifi": path = "LiberationSerif-Italic"
		"serifbi": path = "LiberationSerif-BoldItalic"
		"mono": path = "LiberationMono-Regular"
		"monob": path = "LiberationMono-Bold"
		"vga": path = "VT323-Regular"
	var f := load("res://assets/fonts/%s.ttf" % path) as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NORMAL
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.oversampling = 1.0
	_fonts[kind] = f
	return f


# ------------------------------------------------------------------ icons
## name: e.g. "computer"; small=true gives the 16x16 version.
static func icon(name: String, small := false) -> Texture2D:
	var key := name + ("_16" if small else "")
	if _icons.has(key):
		return _icons[key]
	var path := ICON_DIR + key + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if t == null and small:
		t = icon(name, false)
	_icons[key] = t
	return t


# ------------------------------------------------------------ pixel helpers
static func _img(w: int, h: int, fill := Color(0, 0, 0, 0)) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(fill)
	return i


static func _to_tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## Draws a 1px rectangle frame inset by `i` pixels; the top and left edges use `tl`, bottom and right use `br`.
static func _frame(img: Image, i: int, tl: Color, br: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x in range(i, w - 1 - i):
		img.set_pixel(x, i, tl)
	for y in range(i, h - 1 - i):
		img.set_pixel(i, y, tl)
	for x in range(i, w - i):
		img.set_pixel(x, h - 1 - i, br)
	for y in range(i, h - i):
		img.set_pixel(w - 1 - i, y, br)


static func _bevel(key: String, fill: Color, rings: Array, margin: int, content := -1.0) -> StyleBoxTexture:
	if _boxes.has(key):
		return _boxes[key]
	var s := margin * 2 + 4
	var img := _img(s, s, fill)
	for i in rings.size():
		_frame(img, i, rings[i][0], rings[i][1])
	var sb := StyleBoxTexture.new()
	sb.texture = _to_tex(img)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	var c := float(margin + 1) if content < 0.0 else content
	sb.content_margin_left = c
	sb.content_margin_right = c
	sb.content_margin_top = c
	sb.content_margin_bottom = c
	_boxes[key] = sb
	return sb


static func raised() -> StyleBoxTexture:
	return _bevel("raised", FACE, [[WHITE, BLACK], [LIGHT, SHADOW]], 2, 4.0)


static func pressed() -> StyleBoxTexture:
	return _bevel("pressed", FACE, [[BLACK, WHITE], [SHADOW, LIGHT]], 2, 4.0)


static func field() -> StyleBoxTexture:
	return _bevel("field", WHITE, [[SHADOW, WHITE], [BLACK, LIGHT]], 2, 4.0)


static func panel_raised() -> StyleBoxTexture:
	return _bevel("panel_raised", FACE, [[LIGHT, BLACK], [WHITE, SHADOW]], 2, 2.0)


static func thin_raised() -> StyleBoxTexture:
	return _bevel("thin_raised", FACE, [[WHITE, SHADOW]], 1, 2.0)


static func thin_sunken() -> StyleBoxTexture:
	return _bevel("thin_sunken", FACE, [[SHADOW, WHITE]], 1, 2.0)


static func window_frame() -> StyleBoxTexture:
	return _bevel("window_frame", FACE, [[LIGHT, BLACK], [WHITE, SHADOW]], 4, 4.0)


static func menu_frame() -> StyleBoxTexture:
	return _bevel("menu_frame", FACE, [[LIGHT, BLACK], [WHITE, SHADOW]], 2, 2.0)


static func taskbar() -> StyleBoxTexture:
	if _boxes.has("taskbar"):
		return _boxes["taskbar"]
	var img := _img(4, 4, FACE)
	for x in 4:
		img.set_pixel(x, 0, LIGHT)
		img.set_pixel(x, 1, WHITE)
	var sb := StyleBoxTexture.new()
	sb.texture = _to_tex(img)
	sb.texture_margin_top = 2
	sb.content_margin_top = 2
	_boxes["taskbar"] = sb
	return sb


static func flat(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_border_width_all(0)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	return sb


static func empty() -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


static func _checker() -> StyleBoxTexture:
	if _boxes.has("checker"):
		return _boxes["checker"]
	var img := _img(2, 2, FACE)
	img.set_pixel(0, 0, WHITE)
	img.set_pixel(1, 1, WHITE)
	var sb := StyleBoxTexture.new()
	sb.texture = _to_tex(img)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	_boxes["checker"] = sb
	return sb


# ------------------------------------------------------------------ glyphs
## Draws an ASCII pattern ('X' = ink) into a texture.
static func pattern(rows: Array, ink := BLACK, key := "") -> ImageTexture:
	if key != "" and _tex.has(key):
		return _tex[key]
	var h := rows.size()
	var w: int = rows[0].length()
	var img := _img(w, h)
	for y in h:
		for x in w:
			var ch: String = rows[y][x]
			if ch == "X":
				img.set_pixel(x, y, ink)
			elif ch == "o":
				img.set_pixel(x, y, WHITE)
			elif ch == "g":
				img.set_pixel(x, y, SHADOW)
	var t := _to_tex(img)
	if key != "":
		_tex[key] = t
	return t


const _GLYPHS := {
	"close": ["XX....XX", ".XX..XX.", "..XXXX..", "...XX...", "..XXXX..", ".XX..XX.", "XX....XX"],
	"minimize": ["XXXXXX", "XXXXXX"],
	"maximize": ["XXXXXXXXX", "XXXXXXXXX", "X.......X", "X.......X", "X.......X", "X.......X", "X.......X", "XXXXXXXXX"],
	"restore": ["..XXXXXX", "..XXXXXX", "..X....X", "XXXXXX.X", "XXXXXX.X", "X....XXX", "X....X..", "XXXXXX.."],
	"check": ["......X", ".....XX", "X...XXX", "XX.XXX.", "XXXXX..", ".XXX...", "..X...."],
	"arrow_right": ["X...", "XX..", "XXX.", "XXXX", "XXX.", "XX..", "X..."],
	"arrow_up": ["...X...", "..XXX..", ".XXXXX.", "XXXXXXX"],
	"arrow_down": ["XXXXXXX", ".XXXXX.", "..XXX..", "...X..."],
	"arrow_left": ["...X", "..XX", ".XXX", "XXXX", ".XXX", "..XX", "...X"],
}


static func glyph(name: String, ink := BLACK) -> ImageTexture:
	if not _GLYPHS.has(name):
		return null
	return pattern(_GLYPHS[name], ink, "g_%s_%s" % [name, ink.to_html()])


static func _arrow_button(dir: String, is_pressed: bool) -> ImageTexture:
	var key := "sb_%s_%s" % [dir, is_pressed]
	if _tex.has(key):
		return _tex[key]
	var img := _img(16, 16, FACE)
	if is_pressed:
		_frame(img, 0, SHADOW, SHADOW)
		_frame(img, 1, FACE, FACE)
	else:
		_frame(img, 0, WHITE, BLACK)
		_frame(img, 1, LIGHT, SHADOW)
	var g: Image = glyph("arrow_" + dir).get_image()
	var ox := (16 - g.get_width()) / 2 + (1 if is_pressed else 0)
	var oy := (16 - g.get_height()) / 2 + (1 if is_pressed else 0)
	img.blend_rect(g, Rect2i(0, 0, g.get_width(), g.get_height()), Vector2i(ox, oy))
	var t := _to_tex(img)
	_tex[key] = t
	return t


static func _check_icon(kind: String, checked: bool) -> ImageTexture:
	var key := "cb_%s_%s" % [kind, checked]
	if _tex.has(key):
		return _tex[key]
	var img := _img(13, 13)
	if kind == "box":
		img.fill(WHITE)
		_frame(img, 0, SHADOW, WHITE)
		_frame(img, 1, BLACK, LIGHT)
		if checked:
			var g: Image = glyph("check").get_image()
			img.blend_rect(g, Rect2i(0, 0, g.get_width(), g.get_height()), Vector2i(3, 3))
	else:
		for y in 13:
			for x in 13:
				var d := Vector2(x - 6, y - 6).length()
				if d <= 6.0:
					img.set_pixel(x, y, WHITE)
				if d > 5.0 and d <= 6.5:
					img.set_pixel(x, y, SHADOW if (x + y) < 12 else WHITE)
				if d > 4.0 and d <= 5.0 and d > 3.9:
					img.set_pixel(x, y, BLACK if (x + y) < 12 else LIGHT)
		if checked:
			for y in 13:
				for x in 13:
					if Vector2(x - 6, y - 6).length() <= 2.2:
						img.set_pixel(x, y, BLACK)
	var t := _to_tex(img)
	_tex[key] = t
	return t


# ------------------------------------------------------------------- theme
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var f := font("sans")
	t.default_font = f
	t.default_font_size = FONT_SIZE

	# Label
	t.set_color("font_color", "Label", BLACK)
	t.set_font("font", "Label", f)
	t.set_font_size("font_size", "Label", FONT_SIZE)

	# Button
	t.set_stylebox("normal", "Button", raised())
	t.set_stylebox("hover", "Button", raised())
	t.set_stylebox("pressed", "Button", pressed())
	t.set_stylebox("disabled", "Button", raised())
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", BLACK)
	t.set_color("font_disabled_color", "Button", SHADOW)
	t.set_font("font", "Button", f)
	t.set_font_size("font_size", "Button", FONT_SIZE)
	t.set_constant("h_separation", "Button", 4)
	t.set_color("icon_normal_color", "Button", Color.WHITE)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", Color.WHITE)
	t.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.5))

	# A flat toolbar/menu flavour of Button: "FlatButton"
	t.set_type_variation("FlatButton", "Button")
	t.set_stylebox("normal", "FlatButton", empty())
	t.set_stylebox("hover", "FlatButton", thin_raised())
	t.set_stylebox("pressed", "FlatButton", thin_sunken())
	t.set_stylebox("disabled", "FlatButton", empty())

	# Task bar buttons (toggle): "TaskButton"
	t.set_type_variation("TaskButton", "Button")
	t.set_stylebox("normal", "TaskButton", raised())
	t.set_stylebox("hover", "TaskButton", raised())
	t.set_stylebox("pressed", "TaskButton", _bevel("task_down", _checker_face(), [[BLACK, WHITE], [SHADOW, LIGHT]], 2, 4.0))
	t.set_stylebox("hover_pressed", "TaskButton", _bevel("task_down", _checker_face(), [[BLACK, WHITE], [SHADOW, LIGHT]], 2, 4.0))
	t.set_font("font", "TaskButton", font("sans"))

	# CheckBox
	for kind in ["CheckBox", "CheckButton"]:
		t.set_icon("checked", kind, _check_icon("box", true))
		t.set_icon("unchecked", kind, _check_icon("box", false))
		t.set_icon("checked_disabled", kind, _check_icon("box", true))
		t.set_icon("unchecked_disabled", kind, _check_icon("box", false))
		t.set_icon("radio_checked", kind, _check_icon("radio", true))
		t.set_icon("radio_unchecked", kind, _check_icon("radio", false))
		t.set_icon("radio_checked_disabled", kind, _check_icon("radio", true))
		t.set_icon("radio_unchecked_disabled", kind, _check_icon("radio", false))
		t.set_color("font_color", kind, BLACK)
		t.set_color("font_hover_color", kind, BLACK)
		t.set_color("font_pressed_color", kind, BLACK)
		t.set_color("font_hover_pressed_color", kind, BLACK)
		t.set_color("font_focus_color", kind, BLACK)
		t.set_font("font", kind, f)
		t.set_font_size("font_size", kind, FONT_SIZE)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			t.set_stylebox(st, kind, StyleBoxEmpty.new())
		t.set_constant("h_separation", kind, 6)

	# LineEdit / TextEdit
	for kind in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", kind, field())
		t.set_stylebox("focus", kind, field())
		t.set_stylebox("read_only", kind, field())
		t.set_color("font_color", kind, BLACK)
		t.set_color("font_selected_color", kind, WHITE)
		t.set_color("selection_color", kind, NAVY)
		t.set_color("caret_color", kind, BLACK)
		t.set_color("font_placeholder_color", kind, SHADOW)
		t.set_color("font_readonly_color", kind, BLACK)
		t.set_font("font", kind, f)
		t.set_font_size("font_size", kind, FONT_SIZE)
		t.set_constant("caret_width", kind, 1)
	t.set_constant("minimum_character_width", "LineEdit", 4)

	# RichTextLabel (fonts only; apps set their own styles)
	t.set_font("normal_font", "RichTextLabel", f)
	t.set_font("bold_font", "RichTextLabel", font("sansb"))
	t.set_font("mono_font", "RichTextLabel", font("mono"))
	t.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE)
	t.set_font_size("bold_font_size", "RichTextLabel", FONT_SIZE)
	t.set_font_size("mono_font_size", "RichTextLabel", FONT_SIZE)
	t.set_color("default_color", "RichTextLabel", BLACK)
	t.set_color("selection_color", "RichTextLabel", Color(0, 0, 128, 0.7))
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("focus", "RichTextLabel", StyleBoxEmpty.new())

	# Panels
	t.set_stylebox("panel", "Panel", panel_raised())
	t.set_stylebox("panel", "PanelContainer", panel_raised())

	# Scroll bars
	for kind in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", kind, _checker())
		t.set_stylebox("scroll_focus", kind, _checker())
		t.set_stylebox("grabber", kind, raised_thin_grab())
		t.set_stylebox("grabber_highlight", kind, raised_thin_grab())
		t.set_stylebox("grabber_pressed", kind, raised_thin_grab())
	for p in [["VScrollBar", "decrement", "up"], ["VScrollBar", "increment", "down"], ["HScrollBar", "decrement", "left"], ["HScrollBar", "increment", "right"]]:
		t.set_icon(p[1], p[0], _arrow_button(p[2], false))
		t.set_icon(p[1] + "_highlight", p[0], _arrow_button(p[2], false))
		t.set_icon(p[1] + "_pressed", p[0], _arrow_button(p[2], true))

	# Progress bar
	t.set_stylebox("background", "ProgressBar", _bevel("progress_bg", FACE, [[SHADOW, WHITE]], 1, 2.0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = NAVY
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", BLACK)
	t.set_font("font", "ProgressBar", f)
	t.set_font_size("font_size", "ProgressBar", FONT_SIZE)

	# ItemList
	t.set_stylebox("panel", "ItemList", field())
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	var sel := flat(NAVY)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	t.set_stylebox("hovered", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", BLACK)
	t.set_color("font_selected_color", "ItemList", WHITE)
	t.set_color("font_hovered_color", "ItemList", BLACK)
	t.set_font("font", "ItemList", f)
	t.set_font_size("font_size", "ItemList", FONT_SIZE)
	t.set_constant("v_separation", "ItemList", 2)
	t.set_constant("h_separation", "ItemList", 4)
	t.set_constant("icon_margin", "ItemList", 3)
	t.set_constant("line_separation", "ItemList", 1)

	# Popup-ish / separators
	t.set_stylebox("separator", "HSeparator", _bevel("sep_h", FACE, [], 0, 0.0))
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("separation", "VBoxContainer", 4)
	_theme = t
	return t


static func _checker_face() -> Color:
	return Color8(207, 207, 207)


static func raised_thin_grab() -> StyleBoxTexture:
	return _bevel("grab", FACE, [[WHITE, BLACK], [LIGHT, SHADOW]], 2, 0.0)


# ----------------------------------------------------------------- cursors
const _CURSORS := {
	"arrow": [
		"X...........",
		"XX..........",
		"XoX.........",
		"XooX........",
		"XoooX.......",
		"XooooX......",
		"XoooooX.....",
		"XooooooX....",
		"XoooooooX...",
		"XooooooooX..",
		"XoooooXXXXX.",
		"XooXooX.....",
		"XoX.XooX....",
		"XX..XooX....",
		"X....XooX...",
		".....XooX...",
		"......XX....",
	],
	"ibeam": [
		"XXX.XXX",
		"...X...",
		"...X...",
		"...X...",
		"...X...",
		"...X...",
		"...X...",
		"...X...",
		"...X...",
		"...X...",
		"...X...",
		"XXX.XXX",
	],
	"hand": [
		"....XX..........",
		"...XooX.........",
		"...XooX.........",
		"...XooX.........",
		"...XooXXX.......",
		"...XooXooXXX....",
		".XXXooXooXooXX..",
		"XooXooooooooooX.",
		"XooXooooooooooX.",
		".XooooooooooooX.",
		"..XooooooooooooX",
		"..XooooooooooooX",
		"...XoooooooooooX",
		"...XooooooooooX.",
		"....XoooooooooX.",
		"....XoooooooooX.",
		".....XXXXXXXXX..",
	],
	"busy": [
		"XXXXXXXXXXXXX",
		"XoooooooooooX",
		".XoogoogooXX.",
		"..XooogooX...",
		"...XoogoX....",
		"....XoXoX....",
		".....XgX.....",
		"....XoXoX....",
		"...XooXooX...",
		"..XoogXgooX..",
		".XooggXggooX.",
		"XoooggggggooX",
		"XXXXXXXXXXXXX",
	],
	"hsize": [
		"..X......X..",
		".XX......XX.",
		"XXXXXXXXXXXX",
		".XX......XX.",
		"..X......X..",
	],
	"vsize": [
		"..X..",
		".XXX.",
		"XXXXX",
		"..X..",
		"..X..",
		"..X..",
		"..X..",
		"..X..",
		"XXXXX",
		".XXX.",
		"..X..",
	],
}


## Returns {"tex": ImageTexture, "hot": Vector2} for a cursor kind.
static func cursor(kind: String) -> Dictionary:
	var key := "cur_" + kind
	if _tex.has(key):
		return _tex[key]
	var rows: Array = _CURSORS.get(kind, _CURSORS["arrow"])
	var t := pattern(rows, BLACK)
	var hot := Vector2.ZERO
	match kind:
		"ibeam": hot = Vector2(3, 6)
		"hand": hot = Vector2(5, 0)
		"busy": hot = Vector2(6, 6)
		"hsize": hot = Vector2(6, 2)
		"vsize": hot = Vector2(2, 5)
	var d := {"tex": t, "hot": hot}
	_tex[key] = d
	return d


# ----------------------------------------------------------------- helpers
static func rect_style(color: Color, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(bw)
	return sb


## Draws text with a 1px "embossed" shadow, as used by disabled menu items.
static func draw_embossed(ci: CanvasItem, f: Font, pos: Vector2, text: String, size: int) -> void:
	ci.draw_string(f, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, WHITE)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, SHADOW)


## Word-wraps text to `width` pixels with the UI font (Label autowrap is unreliable inside
## free-positioned dialogs, so we break lines ourselves).
static func wrap(text: String, width: float, kind := "sans", size := FONT_SIZE) -> String:
	var f := font(kind)
	var out: PackedStringArray = []
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)
