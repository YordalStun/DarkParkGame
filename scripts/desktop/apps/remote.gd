extends Control
## NightLink Remote: dial into the hospital's gateway, log in and download files.
## Talks to the story's Hack node (world.story.hack). All actions go through it with this player's id,
## and only the player who owns the PC can act (the others see the same screen but get a message).

const W95 := preload("res://scripts/desktop/w95.gd")

var os: Node
var story
var hack
var _dial: Control
var _login: Control
var _files: Control
var _ip: LineEdit
var _user: LineEdit
var _pass: LineEdit
var _msg: Label
var _clues: Label
var _lock: Label
var _risk: Control
var _risk_lbl: Label
var _log: Label
var _rows := {}      ## file id -> {name: Label, btn: Button, bar: Control}


func setup(p_os: Node, _win: Control, _args: Dictionary) -> void:
	os = p_os
	story = os.world.story if os.world != null and "story" in os.world else null
	if story == null or story.get("hack") == null:
		var l := Label.new()
		l.text = "NightLink is not installed on this machine."
		l.position = Vector2(16, 16)
		add_child(l)
		return
	hack = story.hack
	_build()
	hack.changed.connect(_refresh)
	_refresh()


func _label(text: String, pos: Vector2, parent: Control, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	if bold:
		l.add_theme_font_override("font", W95.font("sansb"))
	parent.add_child(l)
	return l


## A slim progress bar (the theme's ProgressBar is too tall for these rows). Set value with set_meta("v", 0..1).
func _bar(pos: Vector2, size: Vector2, color: Color) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = size
	c.custom_minimum_size = size
	c.set_meta("v", 0.0)
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1))
		c.draw_rect(Rect2(Vector2(1, 1), c.size - Vector2(2, 2)), Color(0.78, 0.78, 0.78))
		c.draw_rect(Rect2(Vector2(1, 1), Vector2((c.size.x - 2) * clampf(c.get_meta("v"), 0.0, 1.0), c.size.y - 2)), color)
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.35, 0.35, 0.35), false, 1.0))
	return c


func _set_bar(c: Control, v: float) -> void:
	c.set_meta("v", v)
	c.queue_redraw()


func _build() -> void:
	# ---- page 1: dial
	_dial = Control.new()
	_dial.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dial)
	_label("NightLink Remote Connect", Vector2(14, 10), _dial, true)
	_label("Dial a remote host by its IP address.", Vector2(14, 34), _dial)
	_label("Host address:", Vector2(14, 66), _dial)
	_ip = LineEdit.new()
	_ip.position = Vector2(100, 62)
	_ip.size = Vector2(150, 23)
	_ip.placeholder_text = "000.000.000.000"
	_ip.max_length = 15
	_ip.text_submitted.connect(func(_t): _on_connect())
	_dial.add_child(_ip)
	var cb: Button = os.button("Connect", Vector2(80, 25))
	cb.position = Vector2(262, 61)
	cb.pressed.connect(_on_connect)
	_dial.add_child(cb)
	_label("Modem: 2400 baud on COM2   -   Each call is logged by the phone company.", Vector2(14, 100), _dial)

	# ---- page 2: login
	_login = Control.new()
	_login.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_login)
	_label("ASHFORD GENERAL HOSPITAL", Vector2(14, 10), _login, true)
	_label("Remote clinic gateway  -  authorised staff only", Vector2(14, 30), _login)
	_label("User ID:", Vector2(14, 64), _login)
	_user = LineEdit.new()
	_user.position = Vector2(90, 60)
	_user.size = Vector2(150, 23)
	_login.add_child(_user)
	_label("Password:", Vector2(14, 92), _login)
	_pass = LineEdit.new()
	_pass.position = Vector2(90, 88)
	_pass.size = Vector2(150, 23)
	_pass.secret = true
	_pass.text_submitted.connect(func(_t): _on_login())
	_login.add_child(_pass)
	var lb: Button = os.button("Log in", Vector2(80, 25))
	lb.position = Vector2(256, 86)
	lb.pressed.connect(_on_login)
	_login.add_child(lb)
	_lock = _label("", Vector2(14, 118), _login, true)
	_label("What you know:", Vector2(14, 144), _login, true)
	_clues = _label("", Vector2(14, 162), _login)

	# ---- page 3: files
	_files = Control.new()
	_files.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_files)
	_label("Logged in as %s" % hack.USER_ID, Vector2(14, 10), _files, true)
	_label("Files on the gateway:", Vector2(14, 32), _files)
	var y := 56
	for id in hack.FILES:
		var f: Dictionary = hack.FILES[id]
		var n := _label("%-12s %s" % [f.name, f.what.substr(0, 22)], Vector2(14, y), _files)
		n.add_theme_font_override("font", W95.font("mono"))
		var bar := _bar(Vector2(14, y + 18), Vector2(250, 10), Color(0.05, 0.1, 0.55))
		_files.add_child(bar)
		var b: Button = os.button("Download", Vector2(86, 24))
		b.position = Vector2(274, y + 4)
		b.pressed.connect(_on_download.bind(id))
		_files.add_child(b)
		_rows[id] = {"name": n, "btn": b, "bar": bar}
		y += 50
	var hb: Button = os.button("Hang up", Vector2(80, 24))
	hb.position = Vector2(14, y + 4)
	hb.pressed.connect(func(): hack.hang_up("HUNG UP"))
	_files.add_child(hb)

	# ---- always visible: status line, risk meter, call log
	_msg = _label("", Vector2(14, 218), self, true)
	_risk_lbl = _label("Risk of being caught:", Vector2(14, 244), self)
	_risk = _bar(Vector2(160, 248), Vector2(190, 10), Color(0.75, 0.1, 0.1))
	add_child(_risk)
	_log = _label("", Vector2(14, 266), self)
	_log.add_theme_font_override("font", W95.font("mono"))
	_log.add_theme_font_size_override("font_size", 11)


func _pid() -> int:
	return story.local_player_id


func _on_connect() -> void:
	_msg.text = hack.connect_to(_ip.text, _pid()).msg
	_refresh()


func _on_login() -> void:
	var r: Dictionary = hack.login(_user.text, _pass.text, _pid())
	_msg.text = r.msg
	_pass.text = ""
	_refresh()


func _on_download(id: String) -> void:
	_msg.text = hack.start_download(id, _pid()).msg
	_refresh()


func on_closed() -> void:
	if hack and hack.state.connected:
		hack.hang_up("DISCONNECTED")


func _refresh() -> void:
	if hack == null or _dial == null:
		return
	var st: Dictionary = hack.state
	_dial.visible = not st.connected
	_login.visible = st.connected and not st.logged_in
	_files.visible = st.logged_in
	# Clues the player has picked up.
	var text := ""
	for flag in hack.CLUES:
		if story.flags.get(flag, false):
			text += "- " + hack.CLUES[flag] + "\n"
	_clues.text = text if text != "" else "(nothing yet. Talk to people at the window and write it down.)"
	_lock.text = ("LOCKED OUT - %d s" % int(ceil(st.lock_left))) if st.lock_left > 0.0 else "User IDs look like K.PLATT (first initial, dot, surname)."
	for id in _rows:
		var r: Dictionary = _rows[id]
		var done: bool = id in st.downloaded
		var busy: bool = st.downloading == id
		_set_bar(r.bar, 1.0 if done else (st.progress if busy else 0.0))
		(r.btn as Button).disabled = done or st.downloading != ""
		(r.btn as Button).text = "Saved" if done else ("..." if busy else "Download")
	_set_bar(_risk, story.risk / 100.0)
	_risk_lbl.text = "Risk of being caught: %d%%" % story.risk
	_log.text = "\n".join(st.log.slice(maxi(0, st.log.size() - 4)))
