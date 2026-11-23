extends Node
## A bot that plays a whole night for you, so changes can be tested without sitting through it.
## It uses the same entry points as the player (phone, side window, ID card, barrier, notepad,
## logbook, light switch, door) and watches for the game getting stuck.
##
##   godot --path . -- --autoplay                 # perfect play: right decision, plate logged
##   godot --path . -- --autoplay=sloppy          # lets everyone in, logs nothing
##   godot --path . -- --autoplay=notes_early     # writes the ward's changes down DURING the call
##   godot --path . -- --autoplay=timeout         # lets every dialog timer run out (the safe option is picked)
##   add --speed=20 to run 20x faster, and --night=2 to start on that night
##   (--headless works too). It prints "BOT ..." lines, then "BOT RESULT: PASS" (exit 0) when the
##   night's end screen shows, or "BOT RESULT: STUCK ..." (exit 2) with a dump of the state.

const STUCK_BEFORE := 420.0   ## game seconds with no progress before 07:00 (cars come every 18-36 s)
const STUCK_AFTER := 150.0    ## ... and after 07:00
const MAX_NIGHT := 3000.0     ## game seconds for the whole run

var story
var world
var hud
var inspect
var mode := "perfect"
var _t := 0.0
var _last_sig := ""
var _last_change := 0.0
var _done := {}               ## one-off actions already taken (so we don't repeat them)
var _typing := false
var _finished := false
var _desk_off_sent := false


func setup(p_story, p_world, p_hud, p_inspect, p_mode: String) -> void:
	story = p_story
	world = p_world
	hud = p_hud
	inspect = p_inspect
	mode = p_mode if p_mode != "true" else "perfect"
	print("BOT start: mode=%s night=%d speed=%.1f" % [mode, story.night, Engine.time_scale])


func _process(delta: float) -> void:
	if _finished or not story.started:
		return
	_t += delta
	_act()
	_watchdog()


func _once(key: String) -> bool:
	if _done.has(key):
		return false
	_done[key] = true
	return true


func _act() -> void:
	# Narration and subtitle lines: skip them straight away (clicks through phone calls too).
	if hud.skip_line() and mode != "notes_early":
		pass
	# Phone.
	if story._phone_ringing and not story._phone_answered:
		story._on_phone()
	# Dialog choices: "perfect" asks the dog question (option 2) to get the password clue; "timeout" lets
	# the timer run out (the safe option is picked); the others take option 1.
	if story.dialog != null and story.dialog._awaiting and mode != "timeout":
		var pick := 1 if mode == "perfect" and story.dialog._entries.size() > 1 else 0
		if _once("dlg%d" % story.dialog.get_instance_id() + story.dialog.node_id + str(story.dialog.time_left > 0.0) + str(Time.get_ticks_msec() / 2000)):
			print("BOT %s: dialog choice %d (%s)" % [NightClock.time_text(), pick + 1, story.dialog._entries[pick].text])
			story.dialog.submit_choice(pick, story.local_player_id)
	if story.hack != null and mode == "perfect":
		_hack()
	# The notepad: normally after the ward's call; "notes_early" does it while the call is still playing.
	if mode == "notes_early" and hud.waiting_click and story.notes == "" and not _typing and story.night >= 2:
		_type_notes("Janet Lowe OFF tonight. Kevin Platt ON - B908 RWD.")
	elif _objective_pending("notes") and not _typing and _once("notes_after_call"):
		_type_notes("Janet Lowe OFF tonight. Kevin Platt ON - B908 RWD.")
	# Shut the side window when nobody is at it (rain blows in otherwise).
	if world.booth.side_is_open and (story.current == null or not is_instance_valid(story.current) or story.current.state != "waiting"):
		world.booth.set_side_window(false)
	# A car at the side window.
	var car = story.current
	if car != null and is_instance_valid(car) and car.state == "waiting" and not story.results.is_empty():
		_serve(car)
	# 07:00 onwards: PC off, clock out, get up, light, door.
	if story._shift_done:
		_clock_out()
	# The end screen means the night is over.
	for c in story.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("end_screen.gd"):
			_finish(true, "end screen shown")
			return


func _serve(car) -> void:
	var res: Dictionary = story.results[story.results.size() - 1]
	var p: Dictionary = car.person
	var key := str(car.get_instance_id())
	if not world.booth.side_is_open:
		world.booth.set_side_window(true)
	if inspect.is_open and inspect.mode == "id":
		var ok: bool = p.admit or mode == "sloppy"
		if _once(key + "decide"):
			print("BOT %s: %s -> %s" % [NightClock.time_text(), p.name, "let in" if ok else "refuse"])
			inspect.close("ok" if ok else "refuse")
		return
	if inspect.is_open:
		return
	if car.card_out and not res.checked and car.card_interact.enabled:
		car.card_interact.activated.emit()
		return
	# The card has been looked at and handed back: log the plate and raise the barrier.
	if res.checked and res.decided == "" and not car.card_with_guard and _once(key + "raise"):
		if mode != "sloppy":
			story.log_entry(p.reg, "PIKE, Sandra")
		story._on_raise()


## Night three: connect, log in with the password learned from Kevin, download two files.
func _hack() -> void:
	var h = story.hack
	if h.state.dead:
		return
	if story.flags.get("clue_pet_biscuit", false) and not h.state.connected and _once("hconnect"):
		print("BOT %s: dialling the hospital" % NightClock.time_text())
		h.connect_to(h.GATEWAY_IP, story.local_player_id)
	elif h.state.connected and not h.state.logged_in and _once("hlogin"):
		print("BOT %s: logging in" % NightClock.time_text())
		h.login(h.USER_ID, h.PASSWORD, story.local_player_id)
	elif h.state.logged_in and h.state.downloading == "":
		for id in ["rota", "visitors"]:
			if not (id in h.state.downloaded) and _once("hdl_" + id):
				print("BOT %s: downloading %s" % [NightClock.time_text(), id])
				h.start_download(id, story.local_player_id)
				break


func _type_notes(text: String) -> void:
	_typing = true
	print("BOT %s: writing the changes in the notepad" % NightClock.time_text())
	story.open_notes()
	await get_tree().process_frame
	await get_tree().process_frame
	inspect._notes_edit.text = text
	inspect._notes_edit.text_changed.emit()
	await get_tree().process_frame
	inspect.close("done")
	_typing = false


func _objective_pending(id: String) -> bool:
	for o in hud._objectives:
		if o.id == id and not o.done:
			return true
	return false


func _clock_out() -> void:
	var desk = world.props.desktop
	if desk.state == "running" and not _desk_off_sent:
		_desk_off_sent = true
		print("BOT %s: shutting the PC down" % NightClock.time_text())
		desk.shut_down("shutdown")
	elif desk.state == "off" and not story._pc_off:
		pass   # story notices on its own
	elif story._pc_off and _once("logbook"):
		print("BOT %s: clocking out" % NightClock.time_text())
		story._on_logbook()
	# Standing up, switching the light off, leaving.
	for c in hud.get_children():
		if c is Button and c.text == "GET UP" and _once("getup"):
			print("BOT: getting up")
			c.pressed.emit()
	if _objective_pending("light") and world.booth.light_on and _once("light"):
		print("BOT: light off")
		world.booth.light_switch.activated.emit()
	if _objective_pending("leave") and not world.booth.light_on and _once("door"):
		print("BOT: leaving")
		world.booth.door_interact.key_used.emit()


func _signature() -> String:
	var s := "%d|" % story.results.size()
	for r in story.results:
		s += r.decided + ("c" if r.checked else "-") + ","
	var car = story.current
	s += "|" + (car.state if car != null and is_instance_valid(car) else "none")
	s += "|%s%s%s%s" % [story._phone_ringing, story._phone_answered, story._call_done, story._shift_done]
	s += "|%s%s|%d" % [story._pc_off, inspect.is_open, story.entries.size()]
	for o in hud._objectives:
		s += "|" + o.id + ("1" if o.done else "0")
	s += "|" + world.props.desktop.state
	return s


func _watchdog() -> void:
	var sig := _signature()
	if story.night_flow_done and not story._shift_done:
		_last_change = _t   # nothing left to do but wait for 07:00 (the clock is checked by MAX_NIGHT)
	if sig != _last_sig:
		_last_sig = sig
		_last_change = _t
	var limit := STUCK_AFTER if story._shift_done else STUCK_BEFORE
	if _t - _last_change > limit:
		_finish(false, "no progress for %d game seconds at %s\n%s" % [int(_t - _last_change), NightClock.time_text(), _dump()])
	elif _t > MAX_NIGHT:
		_finish(false, "the night did not finish in %d game seconds\n%s" % [int(MAX_NIGHT), _dump()])


func _dump() -> String:
	var car = story.current
	var objs := []
	for o in hud._objectives:
		objs.append("%s%s" % ["[x]" if o.done else "[ ]", o.id])
	return "  night=%d clock=%s shift_over=%s\n  car=%s inspect=%s/%s\n  phone ringing=%s answered=%s call_done=%s\n  notes=\"%s\"\n  results=%d entries=%d\n  objectives=%s\n  pc=%s pc_off=%s shift_done=%s" % [
		story.night, NightClock.time_text(), NightClock.shift_over,
		car.state if car != null and is_instance_valid(car) else "none", inspect.is_open, inspect.mode,
		story._phone_ringing, story._phone_answered, story._call_done, story.notes.replace("\n", " "),
		story.results.size(), story.entries.size(), ", ".join(objs),
		world.props.desktop.state, story._pc_off, story._shift_done]


func _finish(ok: bool, why: String) -> void:
	if _finished:
		return
	_finished = true
	if ok:
		var ev: Dictionary = story.evaluate()
		var extra := ""
		if story.hack != null:
			extra = " hack(logged_in=%s downloads=%d risk=%d)" % [story.hack.state.logged_in, story.hack.state.downloaded.size(), story.risk]
		print("BOT RESULT: PASS (%s) coins=%d success=%s wrong=%d%s" % [why, ev.total, ev.success, ev.wrong.size(), extra])
		for w in ev.wrong:
			print("BOT   wrong: ", w)
	else:
		print("BOT RESULT: STUCK - " + why)
	get_tree().quit(0 if ok else 2)
