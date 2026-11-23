extends Control
## NightNet Explorer: a web browser for the booth PC. Shows the fake 1990s web by
## default and can fetch real pages over the dial-up "modem" (plain HTTP/HTTPS, no scripts).

const W95 := preload("res://scripts/desktop/w95.gd")
const MBar := preload("res://scripts/desktop/menu_bar.gd")
const Dialogs := preload("res://scripts/desktop/dialogs.gd")
const HtmlView := preload("res://scripts/desktop/html_view.gd")
const Pages := preload("res://scripts/desktop/web_pages.gd")

const UA := "Mozilla/2.0 (compatible; NightNet Explorer 1.0; NightWin 95)"
const MAX_BODY := 2_000_000

static var _favorites: Array = []
static var _visitors := 4207

var os: Node
var win: Control
var rtl: RichTextLabel
var addr: LineEdit
var status: Label
var progress: ProgressBar
var zone: Label
var back_btn: Button
var fwd_btn: Button
var throbber: Control
var history: Array = []
var hist_i := -1
var visited := {}
var loading := false
var _gen := 0
var _http: HTTPRequest
var _title := ""
var _last_html := ""
var _t := 0.0
var _fake_progress := false
var _renderer: RefCounted

# Real sites go through Chromium (see web_engine.gd) when it is installed.
const WEB_FILTER := preload("res://shaders/web_256.gdshader")
var web: TextureRect          ## shows the Chromium page
var view: Object              ## the Chromium page view (GdBrowserView), or null
var _web_audio: Node          ## AudioStreamPlayer(3D) the page's sound plays through
var _web_mat: ShaderMaterial
var _web_url := ""


func setup(p_os: Node, p_win: Control, args: Dictionary) -> void:
	os = p_os
	win = p_win
	if _favorites.is_empty():
		_favorites = Pages.FAVORITES.duplicate(true)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 1)
	add_child(box)

	var bar: Control = MBar.new()
	box.add_child(bar)
	bar.setup(os, [["File", _file_items], ["View", _view_items], ["Go", _go_items], ["Favorites", _fav_items], ["Help", _help_items]])

	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 1)
	box.add_child(tb)
	back_btn = _tool("Back", "back", func(): go_back())
	fwd_btn = _tool("Forward", "forward", func(): go_forward())
	tb.add_child(back_btn)
	tb.add_child(fwd_btn)
	tb.add_child(_tool("Stop", "stop", func(): stop()))
	tb.add_child(_tool("Refresh", "refresh", func(): navigate(addr.text, false)))
	tb.add_child(_tool("Home", "home", func(): navigate(Pages.HOME)))
	tb.add_child(_tool("Search", "search", func(): navigate("http://www.findit.com/")))
	tb.add_child(_tool("Favorites", "star", func(): os.open_menu(_fav_items(), os._mouse_pos)))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(sp)
	throbber = Control.new()
	throbber.custom_minimum_size = Vector2(40, 38)
	throbber.draw.connect(_draw_throbber)
	tb.add_child(throbber)

	var ar := HBoxContainer.new()
	box.add_child(ar)
	var al := Label.new()
	al.text = " Address "
	al.custom_minimum_size = Vector2(0, 22)
	al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ar.add_child(al)
	addr = LineEdit.new()
	addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr.custom_minimum_size = Vector2(0, 22)
	addr.text_submitted.connect(func(t): navigate(t))
	addr.focus_entered.connect(func(): addr.select_all.call_deferred())
	ar.add_child(addr)
	var go: Button = os.button("Go", Vector2(34, 22))
	go.pressed.connect(func(): navigate(addr.text))
	ar.add_child(go)

	var frame := Panel.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", W95.field())
	box.add_child(frame)
	rtl = RichTextLabel.new()
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.offset_left = 2
	rtl.offset_top = 2
	rtl.offset_right = -2
	rtl.offset_bottom = -2
	rtl.bbcode_enabled = false
	rtl.selection_enabled = true
	rtl.context_menu_enabled = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.scroll_active = true
	rtl.add_theme_font_override("normal_font", W95.font("serif"))
	rtl.add_theme_font_override("bold_font", W95.font("serifb"))
	rtl.add_theme_font_override("italics_font", W95.font("serifi"))
	rtl.add_theme_font_override("bold_italics_font", W95.font("serifbi"))
	rtl.add_theme_font_override("mono_font", W95.font("mono"))
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		rtl.add_theme_font_size_override(k, 16)
	rtl.meta_clicked.connect(_link_clicked)
	rtl.meta_hover_started.connect(func(m): status.text = str(m))
	rtl.meta_hover_ended.connect(func(_m): status.text = "Done" if not loading else status.text)
	frame.add_child(rtl)
	_set_bg(Color.WHITE)

	web = TextureRect.new()
	web.set_anchors_preset(Control.PRESET_FULL_RECT)
	web.offset_left = 2
	web.offset_top = 2
	web.offset_right = -2
	web.offset_bottom = -2
	web.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	web.stretch_mode = TextureRect.STRETCH_SCALE
	web.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	web.focus_mode = Control.FOCUS_CLICK
	web.mouse_filter = Control.MOUSE_FILTER_STOP
	web.visible = false
	_web_mat = ShaderMaterial.new()
	_web_mat.shader = WEB_FILTER
	web.material = _web_mat
	web.gui_input.connect(_web_input)
	web.resized.connect(func():
		if view and web.size.x > 4 and web.size.y > 4:
			view.resize(web.size))
	frame.add_child(web)

	var sb := HBoxContainer.new()
	box.add_child(sb)
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	status.text = "Done"
	sb.add_child(status)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(110, 14)
	progress.show_percentage = false
	progress.visible = false
	sb.add_child(progress)
	zone = Label.new()
	zone.text = " Internet zone "
	sb.add_child(zone)

	_http = HTTPRequest.new()
	_http.max_redirects = 6
	_http.body_size_limit = MAX_BODY
	_http.timeout = 25.0
	_http.accept_gzip = true
	_http.request_completed.connect(_on_response)
	add_child(_http)
	_apply_proxy()

	_renderer = HtmlView.new()
	_update_nav()
	navigate(args.get("url", Pages.HOME))


func _tool(text: String, icon: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.text = text
	b.icon = load("res://assets/desktop/icons/tb_%s.png" % icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(50, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _apply_proxy() -> void:
	for k in ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy"]:
		if OS.has_environment(k):
			var v := OS.get_environment(k).replace("http://", "").replace("https://", "")
			if v.contains("@"):
				v = v.substr(v.rfind("@") + 1)
			v = v.rstrip("/")
			var parts := v.split(":")
			if parts.size() == 2 and parts[1].is_valid_int():
				_http.set_http_proxy(parts[0], int(parts[1]))
				_http.set_https_proxy(parts[0], int(parts[1]))
				return


# ----------------------------------------------------------------- menus
func _file_items() -> Array:
	return [
		{"text": "New Window", "act": func(): os.open_app("browser", {"url": Pages.HOME})},
		{"text": "Open...", "act": func(): addr.grab_focus()},
		{"sep": true},
		{"text": "Close", "act": func(): win.request_close()},
	]


func _view_items() -> Array:
	return [
		{"text": "Stop", "act": stop},
		{"text": "Refresh", "act": func(): navigate(addr.text, false)},
		{"sep": true},
		{"text": "Source", "act": _view_source},
		{"sep": true},
		{"text": ("[x] " if _web_mat.get_shader_parameter("enabled") != false else "[ ] ") + "256 Colours", "act": func():
			_web_mat.set_shader_parameter("enabled", _web_mat.get_shader_parameter("enabled") == false)},
	]


func _go_items() -> Array:
	return [
		{"text": "Back", "dis": hist_i <= 0, "act": go_back},
		{"text": "Forward", "dis": hist_i >= history.size() - 1, "act": go_forward},
		{"text": "Home Page", "act": func(): navigate(Pages.HOME)},
		{"text": "Search the Web", "act": func(): navigate("http://www.findit.com/")},
	]


func _fav_items() -> Array:
	var items: Array = [
		{"text": "Add To Favorites", "act": func(): _favorites.append([_title if _title != "" else addr.text, addr.text])},
		{"sep": true},
	]
	for f in _favorites:
		var url: String = f[1]
		items.append({"text": f[0], "icon": W95.icon("globe", true), "act": func(): navigate(url)})
	return items


func _help_items() -> Array:
	return [{"text": "About NightNet Explorer", "act": func(): Dialogs.msgbox(os, "About NightNet Explorer", "NightNet Explorer 1.0\nFor NightWin 95\n\nReal pages are fetched through the modem.\nNo scripts, no plug-ins, no cookies.", "info")}]


func _view_source() -> void:
	os.vfs.write("C:\\TEMP\\SOURCE.TXT", _last_html)
	os.open_app("notepad", {"path": "C:\\TEMP\\SOURCE.TXT"})


# ------------------------------------------------------------- navigation
func _normalize(text: String) -> String:
	var t := text.strip_edges()
	if t == "":
		return Pages.HOME
	var low := t.to_lower()
	if low.begins_with("http://") or low.begins_with("https://") or low.begins_with("about:"):
		return t
	if low.begins_with("file:") or low.begins_with("ftp:"):
		return t
	if t.contains(" ") or not (t.contains(".") or low.begins_with("localhost")):
		return "http://www.findit.com/search?q=" + t.uri_encode()
	return "http://" + t


func navigate(text: String, push := true) -> void:
	var url := _normalize(text)
	var dl := Pages.download_info(url)
	if not dl.is_empty():   # a file, not a page: show the download window and stay on this page
		os.play("click2", -14.0)
		Dialogs.download(os, dl.name, dl.kb, HtmlView.split_url(url).host)
		return
	if push:
		if hist_i >= 0 and history[hist_i] == url:
			push = false
		else:
			history = history.slice(0, hist_i + 1)
			history.append(url)
			hist_i = history.size() - 1
	_update_nav()
	_load(url)


func go_back() -> void:
	if _web_showing() and view.has_previous_page():
		view.previous_page()
		return
	if hist_i > 0:
		hist_i -= 1
		_update_nav()
		_load(history[hist_i])


func go_forward() -> void:
	if _web_showing() and view.has_next_page():
		view.next_page()
		return
	if hist_i < history.size() - 1:
		hist_i += 1
		_update_nav()
		_load(history[hist_i])


func _update_nav() -> void:
	if back_btn:
		back_btn.disabled = hist_i <= 0 and not (_web_showing() and view.has_previous_page())
		fwd_btn.disabled = hist_i >= history.size() - 1 and not (_web_showing() and view.has_next_page())


func stop() -> void:
	_gen += 1
	if _http:
		_http.cancel_request()
	_finish("Stopped")


func _link_clicked(meta: Variant) -> void:
	var m := str(meta)
	if m.to_lower().begins_with("mailto:"):
		Dialogs.msgbox(os, "NightNet Explorer", "No mail program is set up for mailto: links.\n\nUse Mail from the Start menu instead.", "info")
		return
	os.play("click2", -14.0)
	navigate(m)


func _finish(msg := "Done") -> void:
	loading = false
	_fake_progress = false
	progress.visible = false
	status.text = msg
	throbber.queue_redraw()
	os.busy = false


func _begin(url: String) -> void:
	loading = true
	addr.text = url
	progress.visible = true
	progress.value = 0
	throbber.queue_redraw()


func _load(url: String) -> void:
	_gen += 1
	var g := _gen
	if _http:
		_http.cancel_request()
	_begin(url)
	if url.to_lower().begins_with("about:"):
		_show_html(_about(url), url, g)
		return
	var low := url.to_lower()
	if not (low.begins_with("http://") or low.begins_with("https://")):
		_show_error(url, "The page cannot be displayed", "Only http: and https: addresses can be opened.", g)
		return
	var host: String = HtmlView.split_url(url).host
	status.text = "Looking for site %s..." % host
	if not os.net_connected:
		Dialogs.dialup(os, func(ok):
			if g != _gen:
				return
			if ok:
				_fetch(url, host, g)
			else:
				_show_error(url, "Cannot connect to the Internet", "The modem was not connected.", g))
		return
	_fetch(url, host, g)


func _about(url: String) -> String:
	if url.to_lower() == "about:blank":
		return "<html><body></body></html>"
	return "<html><head><title>NightNet Start Page</title></head><body><meta http-equiv=refresh><p>Redirecting...</p></body></html>"


func _fetch(url: String, host: String, g: int) -> void:
	if Pages.has_host(host):
		_show_web(false)
		_fake_fetch(url, g)
		return
	if _web_load(url, host):
		return
	status.text = "Connecting to site %s..." % host
	os.busy = true
	var err := _http.request(url, PackedStringArray(["User-Agent: " + UA, "Accept: text/html, text/plain;q=0.9, image/png;q=0.5, */*;q=0.1", "Accept-Language: en", "Accept-Encoding: gzip"]))
	if err != OK:
		_show_error(url, "The page cannot be displayed", "The address could not be opened (error %d)." % err, g)


func _fake_fetch(url: String, g: int) -> void:
	_fake_progress = true
	progress.value = 0
	status.text = "Web site found. Waiting for reply..."
	var steps := 10
	var delay := randf_range(0.5, 1.3) / steps
	for i in steps:
		await get_tree().create_timer(delay).timeout
		if g != _gen:
			return
		progress.value = (i + 1) * 100.0 / steps
		if i == 3:
			status.text = "Opening page %s" % url
	_visitors += 1
	var html := Pages.get_page(url, {"TIME": os.clock_text(), "DATE": os.get_node("/root/NightClock").DATE_TEXT, "WEATHER": _weather(), "VISITORS": "%06d" % _visitors})
	_show_html(html, url, g)


func _weather() -> String:
	var w := os.get_node_or_null("/root/Weather")
	return w.describe() if w else "Rain"


func _process(delta: float) -> void:
	if not loading:
		return
	_t += delta
	if int(_t * 8.0) != int((_t - delta) * 8.0):
		throbber.queue_redraw()
	if not _fake_progress and _http and _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		var total := _http.get_body_size()
		if total > 0:
			progress.value = 100.0 * _http.get_downloaded_bytes() / total
		else:
			progress.value = fmod(progress.value + delta * 60.0, 100.0)


func _on_response(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var g := _gen
	var url := str(addr.text)
	os.busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		var msg := "The page cannot be displayed."
		var why := "The page might be temporarily unavailable, or the connection failed."
		match result:
			HTTPRequest.RESULT_CANT_RESOLVE:
				msg = "Cannot find server or DNS Error"
				why = "The address %s could not be found. Check the spelling." % HtmlView.split_url(url).host
			HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR:
				msg = "Cannot connect to the server"
				why = "The server is not answering. The phone line may be noisy."
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				msg = "Secure connection failed"
				why = "This old browser could not set up a secure connection."
			HTTPRequest.RESULT_TIMEOUT:
				msg = "The operation timed out"
				why = "The server took too long to respond."
		_show_error(url, msg, why, g)
		return
	var ctype := ""
	for h in headers:
		if h.to_lower().begins_with("content-type:"):
			ctype = h.substr(13).strip_edges().to_lower()
	if code >= 400:
		_show_error(url, "HTTP %d" % code, "The server returned an error: %s" % _code_name(code), g)
		return
	if ctype.begins_with("image/"):
		_show_image(body, ctype, url, g)
		return
	if ctype != "" and not (ctype.begins_with("text/") or ctype.contains("html") or ctype.contains("xml")):
		_show_error(url, "File cannot be displayed", "This page is a %s file, which NightNet Explorer cannot open." % ctype.split(";")[0], g)
		return
	var text := body.get_string_from_utf8()
	if text == "" and body.size() > 0:
		text = body.get_string_from_ascii()
	if ctype.begins_with("text/plain"):
		text = "<html><body><pre>%s</pre></body></html>" % text.xml_escape()
	_show_html(text, url, g)


func _code_name(c: int) -> String:
	match c:
		400: return "Bad Request"
		401: return "Unauthorized"
		403: return "Forbidden"
		404: return "Not Found"
		410: return "Gone"
		429: return "Too Many Requests"
		500: return "Internal Server Error"
		503: return "Service Unavailable"
	return "Error"


func _set_bg(c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	rtl.add_theme_stylebox_override("normal", sb)


func _show_error(url: String, head: String, why: String, g: int) -> void:
	var html := "<html><head><title>%s</title></head><body bgcolor=#ffffff><h2>%s</h2><hr><p>%s</p><ul><li>Click the <b>Refresh</b> button, or try again later.<li>If you typed the page address, check that it is spelled correctly.<li>Open the <a href='%s'>NightNet Start Page</a> and look for links to the information you want.</ul><p><font size=2>%s</font></p></body></html>" % [head.xml_escape(), head.xml_escape(), why.xml_escape(), Pages.HOME, url.xml_escape()]
	await _show_html(html, url, g, true)
	_finish("Done")


func _show_image(body: PackedByteArray, ctype: String, url: String, g: int) -> void:
	if g != _gen:
		return
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if ctype.contains("png"):
		err = img.load_png_from_buffer(body)
	elif ctype.contains("jpeg") or ctype.contains("jpg"):
		err = img.load_jpg_from_buffer(body)
	elif ctype.contains("webp"):
		err = img.load_webp_from_buffer(body)
	if err != OK:
		_show_error(url, "File cannot be displayed", "NightNet Explorer cannot show this kind of picture (%s)." % ctype, g)
		return
	_set_bg(Color.WHITE)
	rtl.clear()
	var w := mini(img.get_width(), 540)
	rtl.add_image(ImageTexture.create_from_image(img), w, int(img.get_height() * float(w) / img.get_width()))
	_last_html = ""
	_title = url.get_file()
	win.set_title("%s - NightNet Explorer" % _title)
	visited[url] = true
	_finish("Done")


func _show_html(html: String, url: String, g: int, is_error := false) -> void:
	if g != _gen:
		return
	_show_web(false)
	status.text = "Reading page..."
	_last_html = html
	var r: RefCounted = HtmlView.new()
	var info: Dictionary = await r.render(rtl, html, url, func(): return g != _gen, func(u): return visited.has(u))
	if g != _gen or info.is_empty():
		return
	_set_bg(info.bg)
	var t: String = info.title if info.title != "" else url
	_title = t
	win.set_title("%s - NightNet Explorer" % t)
	if not is_error:
		visited[url] = true
		_finish("Done")
	rtl.scroll_to_line(0)


func _draw_throbber() -> void:
	var c := Vector2(20, 19)
	throbber.draw_texture(W95.icon("globe"), c - Vector2(16, 16))
	if loading:
		var a := _t * 5.0
		for i in 3:
			var p := c + Vector2(cos(a + i * 2.1), sin(a + i * 2.1)) * 17.0
			throbber.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 0) if i == 0 else Color.WHITE)


func on_closed() -> void:
	if view:
		view.close()
		view = null
	if _web_audio:
		_web_audio.queue_free()
		_web_audio = null
	_gen += 1
	if _http:
		_http.cancel_request()
	os.busy = false


# ================================================================ Chromium
func _web_showing() -> bool:
	return view != null and web.visible


func _show_web(on: bool) -> void:
	web.visible = on
	rtl.visible = not on
	if not on and view:
		view.set_muted(true)       # a video left playing must not carry on behind a fake page
	elif on and view:
		view.set_muted(false)


## Opens a real site in Chromium. Returns false if the engine isn't available.
func _web_load(url: String, host: String) -> bool:
	if os.web == null or not os.web.ensure():
		return false
	status.text = "Connecting to site %s..." % host
	_web_url = url
	if view == null:
		view = os.web.create_view(url, web)
		if view == null:
			return false
		view.on_page_loaded.connect(func(_a = null, _b = null): _web_loaded())
		view.on_page_failed_loading.connect(func(code = 0, msg = "", _b = null):
			if code != -3:   # -3 = aborted (a new page was opened): not an error
				_finish("Error loading page"))
		view.resize(web.size if web.size.x > 4 else Vector2(560, 300))
		_web_sound()
	else:
		view.load_url(url)
	_show_web(true)
	return true


func _web_loaded() -> void:
	var u: String = view.get_url()
	var t: String = view.get_title()
	addr.text = u
	_title = t if t != "" else u
	win.set_title("%s - NightNet Explorer" % _title)
	visited[u] = true
	_update_nav()
	_finish("Done")


## The page's sound plays from the monitor itself (3D) when the game world is there.
func _web_sound() -> void:
	var gen := AudioStreamGenerator.new()
	gen.buffer_length = 1.0
	var crt: Node3D = os.world.props.crt if os.world != null and os.world.get("props") != null else null
	if crt:
		var p := AudioStreamPlayer3D.new()
		p.stream = gen
		p.bus = "Interior"
		p.unit_size = 1.2
		p.max_db = 0.0
		p.volume_db = -6.0
		crt.add_child(p)
		p.position = Vector3(0, 0.25, 0.1)
		p.play()
		view.audio_stream = p.get_stream_playback()
		_web_audio = p
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = gen
		p2.volume_db = -6.0
		add_child(p2)
		p2.play()
		view.audio_stream = p2.get_stream_playback()
		_web_audio = p2


## Mouse, wheel and keys on the page go to Chromium.
func _web_input(ev: InputEvent) -> void:
	if view == null:
		return
	if ev is InputEventMouseMotion:
		view.set_mouse_moved(int(ev.position.x), int(ev.position.y))
	elif ev is InputEventMouseButton:
		view.set_mouse_moved(int(ev.position.x), int(ev.position.y))
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				if ev.pressed:
					web.grab_focus()
					view.set_mouse_left_down()
				else:
					view.set_mouse_left_up()
			MOUSE_BUTTON_RIGHT:
				if ev.pressed:
					view.set_mouse_right_down()
				else:
					view.set_mouse_right_up()
			MOUSE_BUTTON_WHEEL_UP:
				if ev.pressed:
					view.set_mouse_wheel_vertical(2, ev.shift_pressed, ev.ctrl_pressed, ev.alt_pressed)
			MOUSE_BUTTON_WHEEL_DOWN:
				if ev.pressed:
					view.set_mouse_wheel_vertical(-2, ev.shift_pressed, ev.ctrl_pressed, ev.alt_pressed)
	elif ev is InputEventKey:
		view.set_key_pressed(ev.unicode if ev.unicode != 0 else ev.keycode, ev.pressed, ev.shift_pressed, ev.alt_pressed, ev.ctrl_pressed)
		accept_event()
