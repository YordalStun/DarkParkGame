extends RefCounted
## A small, forgiving HTML 3.2-ish renderer that fills a RichTextLabel using its push_*
## API (never BBCode, so page text can't inject anything). No scripting, no CSS.
## Used for both the fake 90s web and real pages fetched from the internet.
##
##   var r := HtmlView.new()
##   var info: Dictionary = await r.render(rtl, html, base_url, cancelled_callable, visited_callable)
##   info = {title: String, bg: Color, fg: Color}

const W95 := preload("res://scripts/desktop/w95.gd")

const BASE := 16
const FONT_SIZES := [10, 13, 16, 18, 24, 32, 48]
const MAX_CHARS := 350000
const VOID := ["br", "hr", "img", "input", "meta", "link", "base", "area", "col", "wbr", "source", "param", "embed"]
const SKIP := ["script", "style", "svg", "template", "iframe", "textarea", "select", "object", "noembed", "canvas", "audio", "video"]
const BLOCK1 := ["div", "section", "article", "header", "footer", "nav", "main", "aside", "form", "figure", "figcaption", "address", "fieldset", "details", "summary", "dl", "tr", "center", "body", "html"]
const HEADS := {"h1": 32, "h2": 24, "h3": 19, "h4": 16, "h5": 13, "h6": 11}
const NAMED := {
	"black": "#000000", "white": "#ffffff", "red": "#ff0000", "lime": "#00ff00", "blue": "#0000ff", "yellow": "#ffff00",
	"aqua": "#00ffff", "cyan": "#00ffff", "fuchsia": "#ff00ff", "magenta": "#ff00ff", "gray": "#808080", "grey": "#808080",
	"silver": "#c0c0c0", "maroon": "#800000", "olive": "#808000", "green": "#008000", "teal": "#008080", "navy": "#000080", "purple": "#800080",
	"orange": "#ffa500",
}
const ENTITIES := {
	"amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ", "copy": "(c)", "reg": "(R)", "trade": "(tm)",
	"mdash": "-", "ndash": "-", "hellip": "...", "laquo": "<<", "raquo": ">>", "bull": "*", "middot": ".", "lsquo": "'", "rsquo": "'",
	"ldquo": "\"", "rdquo": "\"", "times": "x", "deg": "deg", "pound": "GBP", "euro": "EUR", "yen": "JPY", "cent": "c", "sect": "S",
	"para": "P", "eacute": "e", "egrave": "e", "agrave": "a", "uuml": "u", "ouml": "o", "auml": "a", "ntilde": "n", "rarr": "->", "larr": "<-",
}

var rtl: RichTextLabel
var base_url := ""
var link_color := Color8(0, 0, 238)
var vlink_color := Color8(85, 26, 139)
var text_color := Color.BLACK
var bg_color := Color.WHITE
var title := ""

var _stack: Array = []
var _cur_size := BASE
var _nl := 2
var _space := true
var _pre := false
var _list_depth := 0
var _list_stack: Array = []
var _tables: Array = []
var _flat := 0              ## depth of nested tables being flattened into plain lines
var _in_title := false
var _skip_tag := ""
var _skip_depth := 0
var _cancel: Callable
var _visited: Callable
var _re_ws: RegEx
var _re_attr: RegEx
var _re_ent: RegEx
var _re_tbl: RegEx


func _init() -> void:
	_re_ws = RegEx.create_from_string("[ \\t\\r\\n\\f]+")
	_re_attr = RegEx.create_from_string("([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+)))?")
	_re_ent = RegEx.create_from_string("&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z][a-zA-Z0-9]*);?")
	_re_tbl = RegEx.create_from_string("(?i)<(/?)(table|tr|td|th)\\b([^>]*)>")


# ===================================================================== URLs
## {scheme, host, path, query}; path always starts with "/".
static func split_url(url: String) -> Dictionary:
	var scheme := "http"
	var rest := url
	var i := url.find("://")
	if i > 0 and i < 10:
		scheme = url.substr(0, i).to_lower()
		rest = url.substr(i + 3)
	var hash_i := rest.find("#")
	if hash_i >= 0:
		rest = rest.substr(0, hash_i)
	var slash := rest.find("/")
	var q := rest.find("?")
	var host_end := rest.length()
	if slash >= 0:
		host_end = slash
	if q >= 0 and q < host_end:
		host_end = q
	var host := rest.substr(0, host_end).to_lower()
	var tail := rest.substr(host_end)
	var query := ""
	var qi := tail.find("?")
	if qi >= 0:
		query = tail.substr(qi + 1)
		tail = tail.substr(0, qi)
	if tail == "":
		tail = "/"
	return {"scheme": scheme, "host": host, "path": tail, "query": query}


static func _norm_path(p: String) -> String:
	var out: Array = []
	for seg in p.split("/"):
		if seg == "..":
			if out.size() > 1:
				out.pop_back()
		elif seg != "." :
			out.append(seg)
	var r := "/".join(out)
	return r if r.begins_with("/") else "/" + r


static func join_url(u: Dictionary) -> String:
	return "%s://%s%s%s" % [u.scheme, u.host, u.path, ("?" + u.query) if u.query != "" else ""]


## Resolves href against base. Returns "" for things we can't follow (javascript:, fragments only).
static func resolve(base: String, href: String) -> String:
	href = href.strip_edges()
	if href == "" or href.begins_with("#"):
		return ""
	var low := href.to_lower()
	if low.begins_with("javascript:") or low.begins_with("data:"):
		return ""
	if low.begins_with("mailto:"):
		return href
	if low.begins_with("http://") or low.begins_with("https://"):
		var u := split_url(href)
		u.path = _norm_path(u.path)
		return join_url(u)
	var b := split_url(base)
	if href.begins_with("//"):
		return b.scheme + ":" + href
	if href.find(":") > 0 and href.find(":") < href.find("/") + (1 if href.find("/") < 0 else 0) and not href.begins_with("/"):
		return ""  # unknown scheme (ftp:, tel: ...)
	var path: String = b.path
	var query := ""
	if href.begins_with("/"):
		var hq := href.find("?")
		path = href if hq < 0 else href.substr(0, hq)
		query = "" if hq < 0 else href.substr(hq + 1)
	elif href.begins_with("?"):
		query = href.substr(1)
	else:
		var d: String = path.substr(0, path.rfind("/") + 1)
		var hq := href.find("?")
		var rel := href if hq < 0 else href.substr(0, hq)
		query = "" if hq < 0 else href.substr(hq + 1)
		path = d + rel
	var hh := query.find("#")
	if hh >= 0:
		query = query.substr(0, hh)
	var hp := path.find("#")
	if hp >= 0:
		path = path.substr(0, hp)
	return join_url({"scheme": b.scheme, "host": b.host, "path": _norm_path(path), "query": query})


# ================================================================== render
func render(p_rtl: RichTextLabel, html: String, p_base: String, cancelled := Callable(), visited := Callable()) -> Dictionary:
	rtl = p_rtl
	base_url = p_base
	_cancel = cancelled
	_visited = visited
	rtl.clear()
	_stack.clear()
	_cur_size = BASE
	_nl = 2
	_space = true
	_pre = false
	_list_depth = 0
	_list_stack.clear()
	_tables.clear()
	_flat = 0
	_skip_tag = ""
	truncated_note = ""
	if html.length() > MAX_CHARS:
		html = html.substr(0, MAX_CHARS)
		truncated_note = "\n\n[The rest of this page was too large to display.]"
	var pos := 0
	var n := html.length()
	var count := 0
	while pos < n:
		var lt := html.find("<", pos)
		if lt < 0:
			_text(html.substr(pos))
			break
		if lt > pos:
			_text(html.substr(pos, lt - pos))
		if html.substr(lt, 4) == "<!--":
			var e := html.find("-->", lt + 4)
			pos = n if e < 0 else e + 3
			continue
		var nxt := html.substr(lt + 1, 1)
		if nxt == "!" or nxt == "?":
			var e := html.find(">", lt)
			pos = n if e < 0 else e + 1
			continue
		if not (nxt == "/" or (nxt >= "a" and nxt <= "z") or (nxt >= "A" and nxt <= "Z")):
			_text("<")
			pos = lt + 1
			continue
		var gt := _tag_end(html, lt)
		if gt < 0:
			break
		var src := html.substr(lt + 1, gt - lt - 1)
		pos = gt + 1
		var raw_end := _tag(src, html, pos)
		if raw_end >= 0:
			pos = raw_end
		count += 1
		if count % 300 == 0:
			await rtl.get_tree().process_frame
			if _cancel.is_valid() and _cancel.call():
				return {}
	while _stack.size() > 0:
		_close_top()
	if truncated_note != "":
		rtl.add_text(truncated_note)
	return {"title": title.strip_edges(), "bg": bg_color, "fg": text_color}


var truncated_note := ""


func _tag_end(html: String, lt: int) -> int:
	var i := lt + 1
	var n := html.length()
	var q := ""
	while i < n:
		var c := html[i]
		if q != "":
			if c == q:
				q = ""
		elif c == "\"" or c == "'":
			q = c
		elif c == ">":
			return i
		i += 1
	return -1


func _parse_tag(src: String) -> Dictionary:
	var closing := src.begins_with("/")
	if closing:
		src = src.substr(1)
	var i := 0
	while i < src.length() and not (src[i] in [" ", "\t", "\n", "\r", "/"]):
		i += 1
	var name := src.substr(0, i).to_lower()
	var attrs := {}
	if not closing:
		for m in _re_attr.search_all(src.substr(i)):
			var k := m.get_string(1).to_lower()
			var v := m.get_string(2) if m.get_string(2) != "" else (m.get_string(3) if m.get_string(3) != "" else m.get_string(4))
			attrs[k] = _decode(v)
	return {"name": name, "closing": closing, "attrs": attrs}


## Handles one tag. Returns the new html position if the tag swallowed raw content, else -1.
func _tag(src: String, html: String, pos: int) -> int:
	var t := _parse_tag(src)
	var name: String = t.name
	var attrs: Dictionary = t.attrs
	if _skip_tag != "":
		if name == _skip_tag:
			_skip_depth += 1 if not t.closing else -1
			if _skip_depth <= 0:
				_skip_tag = ""
		return -1
	if t.closing:
		_on_close(name)
		return -1
	if name in SKIP:
		var e := html.findn("</" + name, pos)
		if e < 0:
			return html.length()
		var ge := html.find(">", e)
		return html.length() if ge < 0 else ge + 1
	# Hidden elements: skip the whole subtree.
	var style: String = attrs.get("style", "").to_lower().replace(" ", "")
	if (style.contains("display:none") or attrs.has("hidden") or attrs.get("aria-hidden", "") == "true") and not name in VOID:
		_skip_tag = name
		_skip_depth = 1
		return -1
	_on_open(name, attrs, html, pos)
	return -1


# ------------------------------------------------------------------ helpers
func _decode(s: String) -> String:
	if not s.contains("&"):
		return s
	var out := ""
	var last := 0
	for m in _re_ent.search_all(s):
		out += s.substr(last, m.get_start() - last)
		var e := m.get_string(1)
		var rep := m.get_string()
		if e.begins_with("#"):
			var code := 0
			if e.begins_with("#x") or e.begins_with("#X"):
				code = ("0x" + e.substr(2)).hex_to_int()
			else:
				code = int(e.substr(1))
			if code == 160:
				rep = " "
			elif code >= 32 and code < 127:
				rep = char(code)
			elif code in [8211, 8212]:
				rep = "-"
			elif code in [8216, 8217]:
				rep = "'"
			elif code in [8220, 8221]:
				rep = "\""
			elif code == 8230:
				rep = "..."
			elif code == 169:
				rep = "(c)"
			elif code >= 160 and code < 256:
				rep = char(code)
			else:
				rep = "?" if code > 0x2000 else char(code)
		elif ENTITIES.has(e):
			rep = ENTITIES[e]
		out += rep
		last = m.get_end()
	return out + s.substr(last)


func _color(s: String, fallback: Color) -> Color:
	s = s.strip_edges().to_lower()
	if s == "":
		return fallback
	if NAMED.has(s):
		return Color.html(NAMED[s])
	if s.begins_with("#"):
		s = s.substr(1)
	if s.length() == 3 or s.length() == 6:
		if s.is_valid_hex_number():
			return Color.html("#" + s)
	return fallback


func _lines(n: int) -> void:
	if _list_depth > 0:
		n = mini(n, 1)
	while _nl < n:
		rtl.add_text("\n")
		_nl += 1
	_space = true


func _text(s: String) -> void:
	if _skip_tag != "":
		return
	if _in_title:
		title += s
		return
	if _tables.size() > 0 and (_top_is("table") or _top_is("tr")):
		return
	s = _decode(s)
	if not _pre:
		s = _re_ws.sub(s, " ", true)
		if s.begins_with(" ") and _space:
			s = s.substr(1)
		if s == "":
			return
	else:
		s = s.replace("\r", "")
		if _nl >= 1 and s.begins_with("\n"):
			s = s.substr(1)
		if s == "":
			return
	rtl.add_text(s)
	_nl = 1 if s.ends_with("\n") else 0
	_space = s.ends_with(" ") or s.ends_with("\n")


func _push(tag: String, pops: int, after := 0, extra := {}) -> void:
	var e := {"tag": tag, "pops": pops, "after": after}
	e.merge(extra)
	_stack.append(e)


## Pushes a font size and remembers the previous one so closing the tag restores it.
func _size(px: int) -> Dictionary:
	var prev := _cur_size
	rtl.push_font_size(px)
	_cur_size = px
	return {"prev_size": prev}


func _close_top() -> void:
	var e: Dictionary = _stack.pop_back()
	for i in e.pops:
		rtl.pop()
	if e.has("prev_size"):
		_cur_size = e.prev_size
	if e.get("span", 0) > 0 and _tables.size() > 0:
		var tb: Dictionary = _tables[_tables.size() - 1]
		for k in e.span:
			rtl.push_cell()
			rtl.pop()
			tb.col += 1
	match e.tag:
		"ul", "ol":
			_list_depth -= 1
			_list_stack.pop_back()
			if _list_depth == 0:
				# Leave the list's paragraph for good, so whatever follows (a table, say) starts clean.
				rtl.add_text("\n")
				_nl = 1
		"table":
			_tables.pop_back()
		"table_flat":
			_flat -= 1
		"title":
			_in_title = false
		"pre":
			_pre = false
		"button":
			rtl.add_text(" ]")
	if e.after > 0:
		_lines(e.after)


func _close_to(tag: String, stop: Array = []) -> void:
	var idx := -1
	for i in range(_stack.size() - 1, -1, -1):
		var t: String = _stack[i].tag
		if t == tag:
			idx = i
			break
		if t in stop:
			return
	if idx < 0:
		return
	while _stack.size() > idx:
		_close_top()


func _top_is(tag: String) -> bool:
	return _stack.size() > 0 and _stack[_stack.size() - 1].tag == tag


func _on_close(name: String) -> void:
	if _flat > 0:
		if name == "table":
			_close_to("table_flat")
			return
		if name in ["tr", "td", "th"]:
			return
	match name:
		"p", "li", "dt", "dd":
			_close_to(name, ["table", "td", "th", "ul", "ol", "dl"] if name != "li" else ["table", "td", "th"])
		"td", "th":
			_close_to("td", ["table"])
			_close_to("th", ["table"])
		"tr":
			_end_row()
			_close_to("tr", ["table"])
		"br", "hr", "img":
			pass
		_:
			_close_to(name, ["table"] if name != "table" else [])


## Close anything still open (an unclosed tag inside a cell) back to the current
## table or row, so the next cell is added to the table itself.
func _unwind_to_table() -> void:
	var has_table := false
	for e in _stack:
		if e.tag == "table":
			has_table = true
	while has_table and _stack.size() > 0 and not (_top_is("tr") or _top_is("table")):
		_close_top()


func _end_row() -> void:
	if _tables.size() == 0:
		return
	var tb: Dictionary = _tables[_tables.size() - 1]
	_close_to("td", ["table"])
	_close_to("th", ["table"])
	_unwind_to_table()
	if tb.col > 0:
		while tb.col < tb.cols:
			rtl.push_cell()
			rtl.pop()
			tb.col += 1
		tb.col = 0


func _table_cols(html: String, pos: int) -> int:
	var depth := 0
	var best := 1
	var cur := 0
	for m in _re_tbl.search_all(html.substr(pos, 60000)):
		var closing := m.get_string(1) == "/"
		var nm := m.get_string(2).to_lower()
		if nm == "table":
			if closing:
				depth -= 1
				if depth < 0:
					break
			else:
				depth += 1
		elif depth == 0:
			if nm == "tr" and not closing:
				cur = 0
			elif (nm == "td" or nm == "th") and not closing:
				var cs := 1
				var mm := RegEx.create_from_string("(?i)colspan\\s*=\\s*[\"']?(\\d+)").search(m.get_string(3))
				if mm:
					cs = clampi(int(mm.get_string(1)), 1, 12)
				cur += cs
				best = maxi(best, cur)
	return clampi(best, 1, 12)


func _size_from(font_attr: String, current: int) -> int:
	font_attr = font_attr.strip_edges()
	if font_attr == "":
		return current
	if font_attr.begins_with("+") or font_attr.begins_with("-"):
		var idx := clampi(2 + int(font_attr), 0, 6)
		return FONT_SIZES[idx]
	return FONT_SIZES[clampi(int(font_attr) - 1, 0, 6)]


func _align_of(attrs: Dictionary) -> int:
	match str(attrs.get("align", "")).to_lower():
		"center", "middle": return HORIZONTAL_ALIGNMENT_CENTER
		"right": return HORIZONTAL_ALIGNMENT_RIGHT
	return -1


# ----------------------------------------------------------------- open tags
func _on_open(name: String, attrs: Dictionary, html: String, pos: int) -> void:
	# A table inside a table cell is flattened into lines (as text browsers did):
	# RichTextLabel cannot size nested tables, which squeezes them to one letter wide.
	if name == "table" and (_tables.size() > 0 or _flat > 0):
		_flat += 1
		_lines(1)
		_push("table_flat", 0, 1)
		return
	if _flat > 0 and name in ["tr", "td", "th"]:
		if name == "tr":
			_lines(1)
		elif not _space:
			rtl.add_text("  ")
			_space = true
		return

	# implied closings
	match name:
		"p", "div", "ul", "ol", "dl", "table", "pre", "blockquote", "form", "hr", "center":
			_close_to("p", ["table", "td", "th", "li"])
		"li":
			_close_to("li", ["ul", "ol", "table"])
		"dt", "dd":
			_close_to("dt", ["dl"])
			_close_to("dd", ["dl"])
		"td", "th":
			_close_to("td", ["table"])
			_close_to("th", ["table"])
		"tr":
			_end_row()
			_close_to("tr", ["table"])

	# Between table cells (directly inside <table>/<tr>) only table structure is allowed.
	# Real pages often put <font>, <form> or stray text there; browsers ignore it, and
	# pushing it into the RichTextLabel would break the table.
	if _tables.size() > 0 and (_top_is("table") or _top_is("tr")) and not name in ["tr", "td", "th", "table"]:
		return

	var align := _align_of(attrs)
	match name:
		"title":
			_in_title = true
			title = ""
			_push("title", 0)
		"base":
			if attrs.has("href"):
				base_url = attrs["href"]
		"body":
			bg_color = _color(attrs.get("bgcolor", ""), bg_color)
			text_color = _color(attrs.get("text", ""), text_color)
			link_color = _color(attrs.get("link", ""), link_color)
			vlink_color = _color(attrs.get("vlink", ""), vlink_color)
			rtl.push_color(text_color)
			_push("body", 1)
		"br":
			if _list_depth > 0:
				rtl.add_text(char(0x2028))
			else:
				rtl.add_text("\n")
				_nl += 1
			_space = true
		"hr":
			_lines(1)
			var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
			img.fill(W95.SHADOW)
			img.set_pixel(0, 1, W95.WHITE)
			img.set_pixel(1, 1, W95.WHITE)
			rtl.add_image(ImageTexture.create_from_image(img), maxi(40, int(rtl.size.x) - 40), 2)
			rtl.add_text("\n")
			_nl = 1
			_space = true
		"p":
			_lines(2)
			if align >= 0:
				rtl.push_paragraph(align)
				_push("p", 1, 2)
			else:
				_push("p", 0, 2)
		"div", "section", "article", "header", "footer", "nav", "main", "aside", "form", "figure", "figcaption", "address", "fieldset", "details", "summary", "center", "html":
			_lines(1)
			if name == "center":
				rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
				_push(name, 1, 1)
			elif align >= 0:
				rtl.push_paragraph(align)
				_push(name, 1, 1)
			else:
				_push(name, 0, 1)
		"h1", "h2", "h3", "h4", "h5", "h6":
			_lines(2)
			var pops := 2
			if align >= 0:
				rtl.push_paragraph(align)
				pops += 1
			rtl.push_bold()
			_push(name, pops, 2, _size(HEADS[name]))
		"b", "strong":
			rtl.push_bold()
			rtl.push_font_size(_cur_size)
			_push(name, 2)
		"i", "em", "cite", "var", "dfn":
			rtl.push_italics()
			rtl.push_font_size(_cur_size)
			_push(name, 2)
		"u", "ins":
			rtl.push_underline()
			_push(name, 1)
		"s", "strike", "del":
			rtl.push_strikethrough()
			_push(name, 1)
		"tt", "code", "kbd", "samp":
			rtl.push_font(W95.font("mono"), 14)
			var prev := _cur_size
			_cur_size = 14
			_push(name, 1, 0, {"prev_size": prev})
		"big":
			_push(name, 1, 0, _size(19))
		"small", "sub", "sup":
			_push(name, 1, 0, _size(12))
		"mark":
			rtl.push_bgcolor(Color(1, 1, 0.4))
			rtl.push_color(Color.BLACK)
			_push(name, 2)
		"q":
			rtl.add_text("\"")
			_push(name, 0)
		"font":
			var pops := 0
			var col: String = attrs.get("color", "")
			if col != "":
				rtl.push_color(_color(col, text_color))
				pops += 1
			var face: String = str(attrs.get("face", "")).to_lower()
			var sz: String = attrs.get("size", "")
			if sz != "" or face != "":
				var f: Font = W95.font("serif")
				if face.contains("courier") or face.contains("mono") or face.contains("fixed"):
					f = W95.font("mono")
				elif face.contains("arial") or face.contains("helvetica") or face.contains("verdana") or face.contains("sans") or face.contains("tahoma"):
					f = W95.font("sans")
				var fs := _size_from(sz, _cur_size if sz == "" else BASE)
				rtl.push_font(f, fs)
				pops += 1
				var prev2 := _cur_size
				_cur_size = fs
				_push("font", pops, 0, {"prev_size": prev2})
				return
			_push("font", pops)
		"a":
			var href := resolve(base_url, attrs.get("href", "")) if attrs.has("href") else ""
			if href != "":
				var vis: bool = _visited.is_valid() and _visited.call(href)
				rtl.push_meta(href, RichTextLabel.META_UNDERLINE_NEVER)
				rtl.push_color(vlink_color if vis else link_color)
				rtl.push_underline()
				_push("a", 3)
			else:
				_push("a", 0)
		"img":
			_image(attrs)
		"ul", "ol":
			_lines(1)
			_list_depth += 1
			_list_stack.append(name)
			rtl.push_list(_list_depth - 1, RichTextLabel.LIST_NUMBERS if name == "ol" else RichTextLabel.LIST_DOTS, false)
			_push(name, 1, 1)
		"li":
			if _nl < 1:
				rtl.add_text("\n")
				_nl = 1
			_space = true
			_push("li", 0)
		"dl":
			_lines(1)
			_push("dl", 0, 1)
		"dt":
			_lines(1)
			rtl.push_bold()
			_push("dt", 1, 1)
		"dd":
			_lines(1)
			rtl.push_indent(2)
			_push("dd", 1, 1)
		"blockquote":
			_lines(2)
			rtl.push_indent(2)
			_push("blockquote", 1, 2)
		"pre":
			_lines(2)
			rtl.push_font(W95.font("mono"), 13)
			_pre = true
			var prev3 := _cur_size
			_cur_size = 13
			_push("pre", 1, 2, {"prev_size": prev3})
		"button":
			rtl.add_text("[ ")
			_push("button", 0)
		"input":
			var ty := str(attrs.get("type", "text")).to_lower()
			if ty == "submit" or ty == "button":
				rtl.add_text("[ %s ]" % attrs.get("value", "OK"))
				_nl = 0
			elif ty != "hidden":
				rtl.add_text("[ ________ ]")
				_nl = 0
		"table":
			_lines(1)
			var cols := _table_cols(html, pos)
			rtl.push_table(cols)
			for c in cols:
				rtl.set_table_column_expand(c, true, 1)
			var border := int(attrs.get("border", "0")) if str(attrs.get("border", "0")).is_valid_int() else 1
			_tables.append({"cols": cols, "col": 0, "border": border, "pad": int(attrs.get("cellpadding", "2")) if str(attrs.get("cellpadding", "2")).is_valid_int() else 2, "row": 0, "bg": str(attrs.get("bgcolor", "")), "rowbg": ""})
			_push("table", 1, 1)
		"tr":
			if _tables.size() > 0:
				_tables[_tables.size() - 1].row += 1
				_tables[_tables.size() - 1].rowbg = str(attrs.get("bgcolor", ""))
			_push("tr", 0)
		"td", "th":
			if _tables.size() == 0:
				return
			var tb: Dictionary = _tables[_tables.size() - 1]
			if tb.col >= tb.cols:
				tb.col = 0
			_unwind_to_table()
			var w := str(attrs.get("width", ""))
			var fixed_w := w.is_valid_int() and int(w) > 0
			if fixed_w:
				rtl.set_table_column_expand(tb.col, false)   # must be set at table level, before the cell
			rtl.push_cell()
			if tb.border > 0:
				rtl.set_cell_border_color(W95.SHADOW)
			var cell_bg: String = str(attrs.get("bgcolor", ""))
			if cell_bg == "":
				cell_bg = tb.rowbg if tb.rowbg != "" else tb.bg
			if cell_bg != "":
				var bc := _color(cell_bg, Color(0, 0, 0, 0))
				if bc.a > 0.0:
					rtl.set_cell_row_background_color(bc, bc)
			var p: float = float(tb.pad) + 2.0
			rtl.set_cell_padding(Rect2(p, p, p, p))
			if fixed_w:
				rtl.set_cell_size_override(Vector2(int(w), 0), Vector2(int(w), 100000))
			var pops := 1
			if name == "th":
				rtl.push_bold()
				pops += 1
			if align >= 0 or name == "th":
				rtl.push_paragraph(align if align >= 0 else HORIZONTAL_ALIGNMENT_CENTER)
				pops += 1
			var cs := int(attrs.get("colspan", "1")) if str(attrs.get("colspan", "1")).is_valid_int() else 1
			tb.col += 1
			_nl = 2
			_space = true
			_push(name, pops, 0, {"span": clampi(cs, 1, tb.cols - tb.col + 1) - 1})
		_:
			pass


func _image(attrs: Dictionary) -> void:
	var src: String = attrs.get("src", "")
	var fname: String = src.get_file().get_basename()
	var path := "res://assets/desktop/web/%s.png" % fname
	if fname != "" and ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		var w := int(attrs.get("width", "0")) if str(attrs.get("width", "")).is_valid_int() else 0
		var h := int(attrs.get("height", "0")) if str(attrs.get("height", "")).is_valid_int() else 0
		rtl.add_image(tex, w, h)
		_nl = 0
		_space = false
		return
	var alt: String = str(attrs.get("alt", "")).strip_edges()
	if alt != "":
		rtl.push_color(Color(0.4, 0.4, 0.4))
		rtl.add_text("[%s]" % alt)
		rtl.pop()
		_nl = 0
		_space = false
