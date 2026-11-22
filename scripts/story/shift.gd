extends Node
## Night one: the story director.
##
## 1. The desk phone rings: Dale (the supervisor) explains the job.
## 2. Night-shift hospital staff arrive one at a time at the side window. For each:
##    slide the window open, take the ID, check it against tonight's list (and the date),
##    read the plate, log the reg in GateLog on the PC, then raise the barrier - or refuse.
## 3. Something arrives at 3am that shouldn't.
##
## Everything the player decides is recorded in `results` and summed up at the end.

signal list_changed   ## the log or the expected list changed (GateLog listens)

const VisitorCar := preload("res://scripts/world/visitor_car.gd")
const DATE_TEXT := "Friday 13th October 1989  -  23:00 to 07:00"

## Tonight's list (what's on Dale's clipboard and in GateLog).
const LIST := [
	{"name": "PIKE, Sandra", "staff_no": "40217", "dept": "Staff Nurse - Ward 7"},
	{"name": "ADEYEMI, Michael", "staff_no": "40388", "dept": "Porter"},
	{"name": "MARSH, Dr Helen", "staff_no": "31105", "dept": "Registrar - A&E"},
	{"name": "BAXTER, Tom", "staff_no": "40562", "dept": "Theatre Technician"},
	{"name": "LOWE, Janet", "staff_no": "40115", "dept": "Pharmacy"},
	{"name": "DOYLE, Mick", "staff_no": "40391", "dept": "Porter"},
]

## Who actually turns up, in order. `admit` is the right call under Dale's rules.
const ARRIVALS := [
	{"name": "Sandra Pike", "role": "Staff Nurse", "dept": "Ward 7", "staff_no": "40217", "expires": "03 / 1990",
		"reg": "E412 KTV", "paint": Color(0.55, 0.06, 0.05), "skin": Color(0.9, 0.72, 0.6), "hair": Color(0.55, 0.32, 0.12),
		"hair_style": "long", "shirt": Color(0.2, 0.3, 0.55), "admit": true, "delay": 14.0,
		"greet": ["Evening, Dave. It's going to be a long night.", "Full moon and Friday the thirteenth. A&E will be heaving."],
		"ok": "Ta, love.", "drive": "See you in the morning, Dave.", "refused": "You what? I'm on the rota! Fine. I'll ring the ward from the payphone."},
	{"name": "Michael Adeyemi", "role": "Porter", "dept": "Portering Services", "staff_no": "40388", "expires": "11 / 1990",
		"reg": "C771 PFM", "paint": Color(0.62, 0.57, 0.45), "skin": Color(0.36, 0.24, 0.16), "hair": Color(0.05, 0.04, 0.03),
		"shirt": Color(0.6, 0.6, 0.62), "admit": true, "delay": 30.0,
		"greet": ["Alright Dave? Chucking it down, isn't it.", "Here you go. Same face as yesterday, I promise."],
		"ok": "Cheers, mate.", "drive": "Don't let the bogeyman in.", "refused": "Seriously? I'm on there, Dave. Check again. ...Unbelievable."},
	{"name": "Kevin Platt", "role": "Porter", "dept": "Portering Services", "staff_no": "40612", "expires": "06 / 1991",
		"reg": "B908 RWD", "paint": Color(0.82, 0.82, 0.8), "kind": "van", "skin": Color(0.88, 0.7, 0.58), "hair": Color(0.15, 0.12, 0.1),
		"shirt": Color(0.6, 0.6, 0.62), "moustache": true, "admit": false, "delay": 34.0,
		"greet": ["Evening. I'm covering for Mick Doyle, he's off sick.", "Nobody told you? Typical."],
		"ok": "Lovely. Knew you'd be sensible.", "drive": "Cheers, pal.", "refused": "You're joking. Right. I'll tell them you sent me home, shall I?"},
	{"name": "Dr Helen Marsh", "role": "Registrar", "dept": "Accident & Emergency", "staff_no": "31105", "expires": "08 / 1990",
		"reg": "F23 HLM", "paint": Color(0.1, 0.2, 0.14), "skin": Color(0.92, 0.76, 0.66), "hair": Color(0.12, 0.1, 0.08),
		"hair_style": "long", "glasses": true, "shirt": Color(0.7, 0.72, 0.75), "card_color": Color(0.55, 0.08, 0.1),
		"admit": true, "delay": 30.0,
		"greet": ["Hello. Marsh, A&E. Sorry, I'm in a terrible hurry."],
		"ok": "Thank you.", "drive": "Thanks. Stay dry.", "refused": "I'm the on-call registrar. If someone dies tonight it's on you."},
	{"name": "Tom Baxter", "role": "Theatre Technician", "dept": "Main Theatres", "staff_no": "40562", "expires": "30 / 09 / 1989",
		"reg": "A456 GNB", "paint": Color(0.33, 0.22, 0.12), "skin": Color(0.85, 0.65, 0.52), "hair": Color(0.45, 0.42, 0.4),
		"shirt": Color(0.15, 0.4, 0.35), "admit": false, "delay": 34.0,
		"greet": ["Evening. Bet you're glad you're inside tonight."],
		"ok": "Ta.", "drive": "Night, Dave.", "refused": "Expired? Oh, for... I've been meaning to get a new one. Fine. Fine."},
	{"name": "Janet Lowe", "role": "Pharmacist", "dept": "Pharmacy", "staff_no": "40115", "expires": "01 / 1991",
		"reg": "D310 YXE", "paint": Color(0.6, 0.62, 0.64), "skin": Color(0.95, 0.8, 0.7), "hair": Color(0.75, 0.72, 0.68),
		"hair_style": "long", "glasses": true, "shirt": Color(0.5, 0.25, 0.45), "admit": true, "delay": 30.0,
		"greet": ["Hiya. Only me.", "Have you heard? Someone's been sitting in a car in Row C all week. Gives me the creeps."],
		"ok": "Lovely.", "drive": "Mind how you go.", "refused": "Me? I've been coming here eleven years, Dave."},
	{"name": "R. Kessler", "role": "Night Security", "dept": "Lot C - Booth 2", "staff_no": "00217", "expires": "29 / 09 / 1989",
		"org": "ASHFORD PARKING AUTHORITY", "card_color": Color(0.25, 0.27, 0.22), "stained": true,
		"reg": "TKM 117", "paint": Color(0.16, 0.17, 0.18), "skin": Color(0.78, 0.78, 0.74), "hair": Color(0.3, 0.3, 0.3),
		"shirt": Color(0.12, 0.14, 0.2), "admit": false, "delay": 40.0, "ghost": true, "bay": Vector3(11.65, -0.15, -27.0),
		"greet": ["...", "It's raining in here, Dave.", "You know me. I used to sit where you're sitting."],
		"ok": "Thank you.", "drive": "Row C. Like always.", "refused": "You'll let me in. Everyone does, in the end."},
]

## Free bays in row A (facing the booth), nearest first.
const BAYS := [4, 5, 6, 2, 8, 9, 1, 10]

var world
var hud
var camera
var inspect
var started := false
var entries: Array = []     ## GateLog: [{time, reg, name}]
var results: Array = []     ## per arrival: {name, admit, decided, checked, logged}
var current                 ## the car at the window (visitor_car.gd), or null
var _bay_i := 0
var _phone_ringing := false
var _phone_answered := false
var _ring: AudioStreamPlayer3D
var _debug_skip := false


func setup(p_world, p_hud, p_inspect) -> void:
	world = p_world
	hud = p_hud
	camera = p_world.camera
	inspect = p_inspect
	world.props.phone_interact.activated.connect(_on_phone)
	world.booth.raise_button.activated.connect(_on_raise)
	world.booth.lower_button.activated.connect(_on_lower)
	world.booth.side_window_moved.connect(func(_o): world.ambience.play_at("window_slide", world.booth.side_pane.global_position, -6.0))
	_ring = AudioStreamPlayer3D.new()
	var rs := load("res://assets/audio/phone_ring.ogg") as AudioStreamOggVorbis
	rs.loop = true
	_ring.stream = rs
	_ring.bus = "Interior"
	_ring.unit_size = 1.5
	_ring.max_db = 0.0
	_ring.volume_db = -6.0
	world.props.add_child(_ring)
	_ring.global_position = world.props.phone_interact.global_position


## Expected names for GateLog.
func staff_list() -> Array:
	return LIST


func log_entry(reg: String, staff: String) -> void:
	entries.append({"time": NightClock.time_text(), "reg": _norm(reg), "name": staff})
	list_changed.emit()


func _norm(r: String) -> String:
	return r.strip_edges().to_upper().replace("  ", " ")


func start() -> void:
	if started:
		return
	started = true
	await _wait(5.0)
	await _phone_call(_dale_call())
	await _wait(2.0)
	hud.notify("Cars arrive at the side window. Click  <  on the left, or the window itself.", 6.0)
	for i in ARRIVALS.size():
		var p: Dictionary = ARRIVALS[i]
		await _wait(p.delay)
		await _visitor(p)
	await _wait(10.0)
	await _phone_call([["", "(You lift the receiver. Nobody speaks. You can hear rain on the line.)"],
		["", "(It isn't raining where the phone is. It's raining in the receiver.)"],
		["", "(The line goes dead.)"]])
	await _wait(3.0)
	_summary()


## Testing: run just one arrival (index into ARRIVALS), starting at the window.
func debug_visitor(i: int, offer := true) -> void:
	started = true
	var p: Dictionary = ARRIVALS[i]
	_debug_skip = true
	_visitor(p)
	if offer:
		await _wait(0.8)
		if current:
			current.offer_card()


func _wait(sec: float) -> void:
	var left := sec
	while left > 0.0:
		await get_tree().process_frame
		if not get_tree().paused:
			left -= get_process_delta_time()


# ------------------------------------------------------------------ phone
func _dale_call() -> Array:
	return [
		["Dale", "Dave? It's Dale. Glad you made it in. Weather's foul."],
		["Dale", "Hospital car park's flooded, so the night lot are coming through our gate tonight."],
		["Dale", "They'll pull up on your left. Slide the side window open and take their staff card."],
		["Dale", "Check the name's on tonight's list, and that the card's in date. The list's on the PC, in GateLog."],
		["Dale", "If they're good, type their reg into GateLog, then the green button lifts the barrier."],
		["Dale", "Not on the list, or the card's out of date? They don't come in. I don't care what they tell you."],
		["Dale", "Right. I'm off to bed. Don't ring me."],
	]


func _phone_call(lines: Array) -> void:
	_phone_ringing = true
	_phone_answered = false
	_ring.play()
	hud.notify("The phone is ringing.", 4.0)
	while not _phone_answered:
		await get_tree().process_frame
	_ring.stop()
	world.ambience.play_ui("handset", -8.0)
	_lift_handset(true)
	for l in lines:
		await hud.say(l[0], l[1])
	world.ambience.play_ui("handset", -8.0)
	_lift_handset(false)


func _on_phone() -> void:
	if _phone_ringing and not _phone_answered:
		_phone_ringing = false
		_phone_answered = true


func _lift_handset(up: bool) -> void:
	var hs: Node3D = world.props.get_node_or_null("Phone/Handset")
	if hs == null:
		return
	var tw := create_tween()
	tw.tween_property(hs, "position:y", 0.3 if up else 0.085, 0.3)
	hs.visible = not up


# ------------------------------------------------------------------ a visitor
func _visitor(p: Dictionary) -> void:
	var bay: Vector3
	if p.has("bay"):
		bay = p.bay
	else:
		var i: int = BAYS[_bay_i % BAYS.size()]
		_bay_i += 1
		bay = Vector3(-16.7 + (i + 0.5) * 2.7, -0.15, -11.9)
	var car = VisitorCar.new()
	car.setup(world, p, bay)
	car.name = "Visitor_" + p.reg.replace(" ", "")
	world.add_child(car)
	current = car
	if _debug_skip:
		_debug_skip = false
		car._dist = car._stop_dist - 0.02
	var res := {"name": p.name, "reg": p.reg, "admit": p.admit, "decided": "", "checked": false}
	results.append(res)
	car.card_interact.activated.connect(func(): _on_card(car, p, res))
	car.plate_interact.activated.connect(func(): _on_plate(car, p))
	await car.arrived
	if camera.focus != world.booth.side_view:
		hud.notify("A car has pulled up at the side window.", 5.0)
	# Wait for the window to open. Knock now and then.
	var waited := 0.0
	var knocked := 0
	while not world.booth.side_is_open and car.state == "waiting":
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > 14.0 + knocked * 16.0 and knocked < 3:
			knocked += 1
			world.ambience.play_at("knock", world.booth.side_pane.global_position + Vector3(-0.05, 0, 0), -6.0)
			hud.say("", "(Knock knock on the side window.)", 2.5)
	if car.state == "waiting":
		await _wait(0.6)
		for l in p.greet:
			if car.state != "waiting":
				break
			await hud.say(_short(p), l)
		if car.state == "waiting" and not res.checked:
			car.offer_card()
	# Until it drives in or reverses away.
	while car.state in ["waiting", "approach"]:
		await get_tree().process_frame
	if car.state == "entering":
		if p.get("ghost", false):
			await _ghost_parks(car)
		else:
			await car.parked
	elif car.state == "leaving":
		await car.gone
	current = null


func _short(p: Dictionary) -> String:
	var n: String = p.name
	return n.split(" ")[0] if not n.begins_with("Dr") else n


func _on_card(car, p: Dictionary, res: Dictionary) -> void:
	if car.state != "waiting" or inspect.is_open:
		return
	car.take_card()
	world.ambience.play_ui("click2", -16.0)
	res.checked = true
	inspect.show_id(p, LIST, DATE_TEXT)
	var choice: String = await inspect.closed
	car.return_card()
	if choice == "refuse":
		res.decided = "refused"
		await hud.say(_short(p), p.refused)
		if car.state == "waiting":
			car.reverse_out()
	else:
		await hud.say(_short(p), p.ok)


func _on_plate(car, p: Dictionary) -> void:
	if inspect.is_open:
		return
	inspect.show_plate(p.reg)
	await inspect.closed


# ------------------------------------------------------------------ the barrier
func _on_raise() -> void:
	world.ambience.play_at("barrier_button", world.booth.raise_button.global_position, -6.0)
	var gate = world.lot.gate
	if not gate.is_open:
		gate.open()
		world.props.terminal.add_log("GATE OPENED - BOOTH")
	var car = current
	if car != null and car.state == "waiting":
		var res: Dictionary = results[results.size() - 1]
		res.decided = "admitted"
		if car.card_with_guard:
			car.return_card()
			inspect.close("ok")
		hud.say(_short(car.person), car.person.drive)
		await _wait(1.0)
		car.drive_in()
		_auto_close(car)


func _on_lower() -> void:
	world.ambience.play_at("barrier_button", world.booth.lower_button.global_position, -6.0)
	var car = current
	if car != null and car.state == "entering" and not car.is_past_barrier():
		return   # safety: won't drop on a car
	if world.lot.gate.is_open:
		world.lot.gate.close()
		world.props.terminal.add_log("GATE CLOSED - BOOTH")


## The induction loop drops the barrier once the car is through.
func _auto_close(car) -> void:
	while is_instance_valid(car) and not car.is_past_barrier():
		await get_tree().process_frame
	await _wait(1.5)
	if world.lot.gate.is_open:
		world.lot.gate.close()


# ------------------------------------------------------------------ 3am
func _ghost_parks(car) -> void:
	await car.parked
	await _wait(6.0)
	world.booth.force_flicker()
	await _wait(0.5)
	world.lot.lamp.level = 0.0
	world.booth.lane_flood.visible = false
	await _wait(1.2)
	if is_instance_valid(car):
		car.queue_free()
	world.booth.force_flicker()
	world.lot.lamp.level = 1.0
	world.booth.lane_flood.visible = true
	world.props.terminal.add_log("VEHICLE TKM 117 - NOT DETECTED")


# ------------------------------------------------------------------ end of night
func _summary() -> void:
	var right := 0
	var lines: Array = []
	for r in results:
		var should: bool = r.admit
		var did: bool = r.decided == "admitted"
		var ok := should == did
		var logged := false
		for e in entries:
			if e.reg == _norm(r.reg):
				logged = true
		var note := ""
		if did and not r.checked:
			note = "  (didn't check the card)"
		if did and should and not logged:
			note += "  (reg not logged)"
			ok = false
		if ok:
			right += 1
		lines.append("%s  %-16s %s%s" % ["OK " if ok else "XX ", r.name, "let in" if did else "turned away", note])
	var text := "END OF NIGHT ONE\n\n%d of %d handled by the book.\n\n%s" % [right, results.size(), "\n".join(lines)]
	world.props.terminal.add_log("SHIFT REPORT: %d/%d CORRECT" % [right, results.size()])
	hud.show_report(text)
