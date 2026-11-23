extends Node
## A co-op guest that plays the night through the same clicks a player makes (testing only):
## it answers the phone, opens the side window, takes each ID card, decides, logs the plate, raises the
## barrier, answers dialog, and dials the hospital. Every one of those goes to the host as a request.
## The host runs `--autoplay=coop_host --host` (it only clocks out), so if the night finishes with the
## right results, the requests and the mirroring both work.
##
##   godot --headless --path . -- --autoplay=coop_host --host=2 --speed=8
##   godot --headless --path . -- --autoplay --join=127.0.0.1 --speed=8
## It prints "GUEST ..." lines and "GUEST RESULT: PASS" once the host's report arrives.

var story
var world
var hud
var inspect
var _done := {}
var _finished := false
var _seen := {}       ## what the guest saw happen (for the result line)


func setup(p_story, p_world, p_hud, p_inspect) -> void:
	story = p_story
	world = p_world
	hud = p_hud
	inspect = p_inspect
	print("GUEST bot start: id=%d label=%s" % [Net.my_id(), Net.label(Net.my_id())])
	Net.event.connect(func(n, _a): _seen[n] = int(_seen.get(n, 0)) + 1)


func _once(key: String) -> bool:
	if _done.has(key):
		return false
	_done[key] = true
	return true


func _process(_delta: float) -> void:
	if _finished or not story.started:
		return
	hud.skip_line()
	if story._phone_ringing and _once("phone%d" % int(_seen.get("ring", 0))):
		print("GUEST %s: answering the phone" % NightClock.time_text())
		world.props.phone_interact.activated.emit()
	if hud._choice_open and hud._choice_can_answer and _once("choice%d" % int(_seen.get("choices", 0))):
		var pick := 1 if hud._choice_count > 1 else 0
		print("GUEST %s: dialog choice %d" % [NightClock.time_text(), pick + 1])
		hud.choice_picked.emit(pick)
	var car = story.current
	if car != null and is_instance_valid(car) and car.state == "waiting":
		_serve(car)
	elif world.booth.side_is_open and _once("shut%d" % int(_seen.get("car_new", 0))):
		world.booth.side_pane_interact.activated.emit()
	if story.hack != null:
		_hack()
	for c in story.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("end_screen.gd"):
			_finish()


func _serve(car) -> void:
	var p: Dictionary = car.person
	var key: String = str(car.name)
	if not world.booth.side_is_open and _once(key + "open"):
		print("GUEST %s: opening the window for %s" % [NightClock.time_text(), p.name])
		world.booth.side_pane_interact.activated.emit()
	if inspect.is_open and inspect.mode == "id":
		if _once(key + "decide"):
			print("GUEST %s: %s -> %s" % [NightClock.time_text(), p.name, "let in" if p.admit else "refuse"])
			inspect.close("ok" if p.admit else "refuse")
		return
	if inspect.is_open:
		return
	if car.card_out and not car.card_with_guard and car.card_interact.enabled and not _done.has(key + "decide") and _once(key + "card"):
		print("GUEST %s: taking %s's card" % [NightClock.time_text(), p.name])
		car.card_interact.activated.emit()
		return
	if _done.has(key + "decide") and p.admit and not car.card_with_guard and _once(key + "raise"):
		story.log_entry(p.reg, p.name)
		world.booth.raise_button.activated.emit()


func _hack() -> void:
	var h = story.hack
	if h.state.dead:
		return
	if not h.state.connected and _once("hconnect"):
		print("GUEST %s: dialling the hospital" % NightClock.time_text())
		h.connect_to(h.GATEWAY_IP, story.local_player_id)
	elif h.state.connected and not h.state.logged_in and _once("hlogin"):
		print("GUEST %s: logging in" % NightClock.time_text())
		h.login(h.USER_ID, h.PASSWORD, story.local_player_id)
	elif h.state.logged_in and h.state.downloading == "" and not ("rota" in h.state.downloaded) and _once("hdl"):
		print("GUEST %s: downloading the rota" % NightClock.time_text())
		h.start_download("rota", story.local_player_id)


func _finish() -> void:
	_finished = true
	var files: Array = story.world.props.desktop.vfs.list("C:\\DOWNLOADS") if story.world.props.desktop.vfs.has_method("list") else []
	print("GUEST RESULT: PASS report received; entries=%d risk=%d hack_logged_in=%s downloaded=%s files=%s events=%s" % [
		story.entries.size(), story.risk, story.hack.state.logged_in if story.hack else false,
		str(story.hack.state.downloaded) if story.hack else "[]", str(files), str(_seen)])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0)
