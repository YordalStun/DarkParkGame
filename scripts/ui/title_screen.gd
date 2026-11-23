extends CanvasLayer
## The title screen: CONTINUE, NEW GAME, LOAD, MULTIPLAYER and QUIT, with three save slots.
## Same look as the end-of-shift screen. Emits `chosen` once a slot is ready to play.
##
## MULTIPLAYER (co-op, night three on): HOST from a save that has co-op unlocked (night two done),
## or, for players who haven't got that far, a new game that skips straight to night three.
## JOIN types in the host's IP and port. Both lead to the lobby; the host presses START.

signal chosen

const DESIGN := Vector2(1280, 720)
const GOLD := Color(0.91, 0.75, 0.44)
const INK := Color(0.85, 0.84, 0.78)
const DIM := Color(0.54, 0.53, 0.49)
const BG := Color(0.03, 0.035, 0.034)

var _font: Font
var _stage: Control
var _menu: VBoxContainer
var _slots: VBoxContainer
var _slots_title: Label
var _mode := ""          ## "load" | "new" | "coop_new"
var _msg: Label          ## errors and connection status (under the right-hand panel)
var _rain: Control
var _drops: Array = []
var _confirm := 0        ## slot waiting for an overwrite confirm


func _ready() -> void:
	layer = 60
	_font = load("res://assets/fonts/VT323-Regular.ttf")
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_rain = Control.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	add_child(_rain)
	for i in 140:
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.4)))
	_stage = Control.new()
	_stage.size = DESIGN
	add_child(_stage)
	get_viewport().size_changed.connect(_fit)
	_fit()

	var t := _label("DARK PARK", 120, GOLD)
	t.position = Vector2(90, 70)
	var s := _label("LOT C  -  NIGHT SECURITY  -  OCTOBER 1989", 30, DIM)
	s.position = Vector2(96, 196)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(96, 300)
	_menu.add_theme_constant_override("separation", 10)
	_stage.add_child(_menu)
	var last := SaveGame.latest()
	if last > 0:
		var d := SaveGame.peek(last)
		_menu_button("CONTINUE", func(): _start(last, false), "Slot %d  -  night %d  -  %d coins" % [last, d.night, d.coins])
	_menu_button("NEW GAME", func(): _show_slots("new"))
	if last > 0:
		_menu_button("LOAD", func(): _show_slots("load"))
	_menu_button("MULTIPLAYER", _show_mp, "Co-op from night 3  -  up to 4 guards" if SaveGame.any_coop_unlocked() else "Unlocks after night 2  -  or skip to night 3")
	_menu_button("QUIT", func(): get_tree().quit())

	_slots_title = _label("", 30, GOLD)
	_slots_title.position = Vector2(620, 300)
	_slots = VBoxContainer.new()
	_slots.position = Vector2(620, 346)
	_slots.add_theme_constant_override("separation", 12)
	_stage.add_child(_slots)
	_msg = _label("", 26, Color(1.0, 0.55, 0.4))
	_msg.position = Vector2(620, 620)
	_msg.size = Vector2(600, 50)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Net.last_error != "":
		_msg.text = Net.last_error
		Net.last_error = ""
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.joined.connect(_show_lobby)
	Net.join_failed.connect(func(why): _show_join(why))
	Net.disconnected.connect(func(why):
		_show_mp()
		_msg.text = why)
	Net.begin.connect(_on_begin)
	var ver := _label("v%s  -  build %s" % [ProjectSettings.get_setting("application/config/version", "?"), load("res://scripts/build_info.gd").BUILD], 22, Color(0.35, 0.35, 0.33))
	ver.position = Vector2(96, 676)
	_stage.modulate.a = 0.0
	create_tween().tween_property(_stage, "modulate:a", 1.0, 1.2)


func _label(text: String, size: int, color: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	(parent if parent else _stage).add_child(l)
	return l


func _menu_button(text: String, act: Callable, sub := "") -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	_menu.add_child(row)
	var b := _button(text, 40, 300)
	b.pressed.connect(act)
	row.add_child(b)
	if sub != "":
		_label(sub, 24, DIM, row)


func _button(text: String, size: int, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 0)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", size)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.bg_color = Color(0, 0, 0, 0) if st in ["normal", "disabled"] else Color(0.91, 0.75, 0.44, 0.14)
		sb.border_color = GOLD if st in ["hover", "pressed"] else Color(0, 0, 0, 0)
		sb.border_width_left = 4
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.35, 0.33))
	return b


func _clear_panel(title: String) -> void:
	_slots_title.text = title
	_msg.text = ""
	for c in _slots.get_children():
		c.queue_free()


func _show_slots(mode: String) -> void:
	if Net.active():
		Net.leave()
	_mode = mode
	_confirm = 0
	_clear_panel({"new": "START A NEW GAME IN...", "load": "LOAD A GAME", "coop_new": "NEW CO-OP GAME (NIGHT 3) IN..."}[mode])
	for n in range(1, SaveGame.SLOTS + 1):
		var d := SaveGame.peek(n)
		var text := "SLOT %d   " % n
		if d.is_empty():
			text += "- empty -"
		else:
			var mins := int(float(d.playtime) / 60.0)
			text += "Night %d   %d coins   %dh %02dm\n         saved %s" % [d.night, d.coins, mins / 60, mins % 60, str(d.saved).replace("T", " ").left(16)]
		var b := _button(text, 30, 560)
		b.disabled = mode == "load" and d.is_empty()
		var slot := n
		b.pressed.connect(func(): _slot_pressed(slot, b))
		_slots.add_child(b)


func _slot_pressed(n: int, b: Button) -> void:
	if _mode == "load":
		_start(n, false)
		return
	if SaveGame.exists(n) and _confirm != n:
		_confirm = n
		b.text = "SLOT %d   Overwrite this save? Click again." % n
		return
	if _mode == "coop_new":
		SaveGame.new_coop_game(n)
		_host()
		return
	_start(n, true)


# ------------------------------------------------------------------ multiplayer
func _show_mp() -> void:
	if Net.active():
		Net.leave()
	_clear_panel("MULTIPLAYER")
	var unlocked := SaveGame.any_coop_unlocked()
	var info := "Co-op: up to 4 guards share the shift. One of you hosts (their save is the one that counts); friends join with the host's IP address."
	if not unlocked:
		info = "Co-op unlocks when you finish night two.\nHosting now starts a NEW game that skips straight to night three. Your other saves are kept. Joining a friend needs nothing unlocked."
	_info(info)
	var h := _button("HOST A GAME", 34, 560)
	h.pressed.connect(_show_host)
	_slots.add_child(h)
	var j := _button("JOIN A GAME", 34, 560)
	j.pressed.connect(func(): _show_join())
	_slots.add_child(j)


func _info(text: String) -> Label:
	var l := _label(text, 26, DIM, _slots)
	l.custom_minimum_size = Vector2(560, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Host from a save with co-op unlocked, or start a new one on night three.
func _show_host() -> void:
	_clear_panel("HOST A GAME")
	var any := false
	for n in range(1, SaveGame.SLOTS + 1):
		var d := SaveGame.peek(n)
		if not SaveGame.coop_ready(d):
			continue
		any = true
		var b := _button("SLOT %d   Night %d   %d coins" % [n, d.night, d.coins], 30, 560)
		var slot := n
		b.pressed.connect(func():
			SaveGame.load_slot(slot)
			if SaveGame.night() < SaveGame.COOP_NIGHT:
				SaveGame.set_progress(SaveGame.coins(), SaveGame.COOP_NIGHT)
			_host())
		_slots.add_child(b)
	if not any:
		_show_slots("coop_new")
		_info("You haven't finished night two yet, so this skips to night three in a new game.")
		return
	var nb := _button("NEW GAME AT NIGHT 3...", 30, 560)
	nb.pressed.connect(func(): _show_slots("coop_new"))
	_slots.add_child(nb)
	_slots.add_child(_back_button())


func _back_button() -> Button:
	var b := _button("BACK", 30, 560)
	b.add_theme_color_override("font_color", DIM)
	b.pressed.connect(_show_mp)
	return b


func _host() -> void:
	var why := Net.host(Net.DEFAULT_PORT)
	if why != "":
		_show_mp()
		_msg.text = why
		return
	_show_lobby()


func _show_join(error := "") -> void:
	_clear_panel("JOIN A GAME")
	_info("Ask the host for the IP address and port shown in their lobby.")
	var ip := _field("Host IP address", "", 560)
	ip.text = Settings.last_join_ip
	var port := _field("Port", str(Net.DEFAULT_PORT), 200)
	port.text = str(Net.DEFAULT_PORT)
	var go := _button("CONNECT", 34, 560)
	_slots.add_child(go)
	var connect := func():
		var p := int(port.text) if port.text.is_valid_int() else Net.DEFAULT_PORT
		var why := Net.join(ip.text, p)
		if why != "":
			_msg.text = why
			return
		Settings.last_join_ip = ip.text.strip_edges()
		Settings.save()
		_msg.add_theme_color_override("font_color", DIM)
		_msg.text = "Connecting to %s:%d..." % [ip.text.strip_edges(), p]
	go.pressed.connect(connect)
	ip.text_submitted.connect(func(_t): connect.call())
	_slots.add_child(_back_button())
	ip.grab_focus()
	if error != "":
		_msg.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
		_msg.text = error


func _field(placeholder: String, text: String, width: float) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(width, 48)
	e.add_theme_font_override("font", _font)
	e.add_theme_font_size_override("font_size", 32)
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(0.35, 0.35, 0.33))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.border_color = Color(0.91, 0.75, 0.44, 0.5)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	e.add_theme_stylebox_override("normal", sb)
	var sf := sb.duplicate()
	sf.border_color = GOLD
	e.add_theme_stylebox_override("focus", sf)
	_slots.add_child(e)
	return e


func _show_lobby() -> void:
	var night := SaveGame.night() if Net.is_host() else 0
	_clear_panel("LOBBY" + ("  -  NIGHT %d" % night if night > 0 else ""))
	if Net.is_host():
		var ips := Net.local_ips()
		var where := "Friends join with\n  IP:   %s\n  PORT: %d" % [ips[0] if not ips.is_empty() else "(no network found)", Net.port]
		if ips.size() > 1:
			where += "\n  (or: %s)" % ", ".join(ips.slice(1, 3))
		var l := _label(where, 30, INK, _slots)
		l.custom_minimum_size = Vector2(560, 0)
		_info("Same house or LAN: that's all. Over the internet: forward UDP port %d on your router to this PC, and give friends your public IP (or use Hamachi / ZeroTier)." % Net.port)
	else:
		_info("Connected. Waiting for the host to start the night...")
	var list := VBoxContainer.new()
	list.name = "Players"
	list.add_theme_constant_override("separation", 2)
	_slots.add_child(list)
	_fill_players(list)
	if Net.is_host():
		var st := _button("START NIGHT %d" % night, 38, 560)
		st.pressed.connect(func(): Net.start_game(SaveGame.night(), SaveGame.coins()))
		_slots.add_child(st)
	var lv := _button("LEAVE", 30, 560)
	lv.add_theme_color_override("font_color", DIM)
	lv.pressed.connect(_show_mp)
	_slots.add_child(lv)


func _fill_players(list: VBoxContainer) -> void:
	for c in list.get_children():
		c.queue_free()
	var PM := load("res://scripts/world/player_model.gd")
	for id in Net.ids():
		var g := Net.guard_of(id)
		var d: Dictionary = PM.DESIGNS[g]
		var who := "host" if id == 1 else ""
		if id == Net.my_id():
			who = "you" + (", host" if id == 1 else "")
		var l := _label("  %s   %-7s %s" % [Net.label(id), d.colour, "(%s)" % who if who != "" else ""], 32, d.accent, list)
		l.custom_minimum_size = Vector2(560, 0)
	for i in range(Net.ids().size(), Net.MAX_PLAYERS):
		_label("  P%d   - free -" % (i + 1), 32, Color(0.3, 0.3, 0.28), list)


func _on_lobby_changed() -> void:
	var list := _slots.get_node_or_null("Players")
	if list:
		_fill_players(list)


func _on_begin(night: int, coins: int) -> void:
	if not Net.is_host():
		SaveGame.start_guest(night, coins)
	_go()


func _start(n: int, fresh: bool) -> void:
	if fresh:
		SaveGame.new_game(n)
	else:
		SaveGame.load_slot(n)
	_go()


func _go() -> void:
	var tw := create_tween()
	tw.tween_property(_stage, "modulate:a", 0.0, 0.5)
	await tw.finished
	chosen.emit()
	queue_free()


func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var k := minf(vs.x / DESIGN.x, vs.y / DESIGN.y)
	_stage.scale = Vector2(k, k)
	_stage.position = (vs - DESIGN * k) * 0.5


func _process(delta: float) -> void:
	for i in _drops.size():
		var d: Vector3 = _drops[i]
		d.y += delta * 0.9 * d.z
		if d.y > 1.05:
			d = Vector3(randf(), -0.05, d.z)
		_drops[i] = d
	_rain.queue_redraw()


func _draw_rain() -> void:
	var vs := _rain.size
	for d in _drops:
		var p := Vector2(d.x * vs.x, d.y * vs.y)
		_rain.draw_line(p, p + Vector2(-2, 18 * d.z), Color(0.5, 0.55, 0.6, 0.18 * d.z), 1.0)
