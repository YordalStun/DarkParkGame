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
signal clocked_out    ## the player signed out in the logbook after the shift ended

const START_MONEY := 8
const BONUS_PLATES := 3

const VisitorCar := preload("res://scripts/world/visitor_car.gd")
const DATE_TEXT := "Friday 13th October 1989  -  23:00 to 07:00"

## Tonight's list (what's on Dale's clipboard and in GateLog).
## Alphabetical, like a real rota, so it never hints at who turns up when.
const LIST := [
	{"name": "ADEYEMI, Michael", "staff_no": "40388", "dept": "Porter"},
	{"name": "BAXTER, Tom", "staff_no": "40562", "dept": "Theatre Technician"},
	{"name": "DOYLE, Mick", "staff_no": "40391", "dept": "Porter"},
	{"name": "LOWE, Janet", "staff_no": "40115", "dept": "Pharmacy"},
	{"name": "MARSH, Dr Helen", "staff_no": "31105", "dept": "Registrar - A&E"},
	{"name": "PIKE, Sandra", "staff_no": "40217", "dept": "Staff Nurse - Ward 7"},
]

## Who actually turns up, in order. `admit` is the right call under Dale's rules.
const ARRIVALS := [
	{"name": "Sandra Pike", "role": "Staff Nurse", "dept": "Ward 7", "staff_no": "40217", "expires": "03 / 1990",
		"reg": "E412 KTV", "paint": Color(0.55, 0.06, 0.05), "style": "supermini", "skin": Color(0.9, 0.72, 0.6), "hair": Color(0.55, 0.32, 0.12),
		"hair_style": "long", "shirt": Color(0.2, 0.3, 0.55), "admit": true, "delay": 14.0,
		"greet": ["Evening, Dave. Still flooded over our side, then?", "It's going to be a long night. Full moon and Friday the thirteenth. A&E will be heaving."],
		"ok": "Ta, love.", "drive": "See you in the morning, Dave.", "refused": "You what? I'm on the rota! Fine. I'll ring the ward from the payphone."},
	{"name": "Michael Adeyemi", "role": "Porter", "dept": "Portering Services", "staff_no": "40388", "expires": "11 / 1990",
		"reg": "C771 PFM", "paint": Color(0.62, 0.57, 0.45), "style": "estate", "skin": Color(0.36, 0.24, 0.16), "hair": Color(0.05, 0.04, 0.03),
		"shirt": Color(0.6, 0.6, 0.62), "admit": true, "delay": 30.0,
		"greet": ["Alright Dave? Night four of the swimming pool.", "Here you go. Same face as yesterday, I promise."],
		"ok": "Cheers, mate.", "drive": "Don't let the bogeyman in.", "refused": "Seriously? I'm on there, Dave. Check again. ...Unbelievable."},
	{"name": "Kevin Platt", "role": "Porter", "dept": "Portering Services", "staff_no": "40612", "expires": "06 / 1991",
		"reg": "B908 RWD", "paint": Color(0.82, 0.82, 0.8), "style": "van", "skin": Color(0.88, 0.7, 0.58), "hair": Color(0.15, 0.12, 0.1),
		"shirt": Color(0.6, 0.6, 0.62), "moustache": true, "admit": false, "delay": 34.0,
		"why": "Not on tonight's list. He said he was covering for Mick Doyle, but nobody had told you.",
		"greet": ["Evening. Don't think we've met. I'm covering for Mick Doyle, he's off sick.", "Nobody told you? Typical."],
		"ok": "Lovely. Knew you'd be sensible.", "drive": "Cheers, pal.", "refused": "You're joking. Right. I'll tell them you sent me home, shall I?"},
	{"name": "Dr Helen Marsh", "role": "Registrar", "dept": "Accident & Emergency", "staff_no": "31105", "expires": "08 / 1990",
		"reg": "F23 HLM", "paint": Color(0.1, 0.2, 0.14), "style": "exec", "skin": Color(0.92, 0.76, 0.66), "hair": Color(0.12, 0.1, 0.08),
		"hair_style": "long", "glasses": true, "shirt": Color(0.7, 0.72, 0.75), "card_color": Color(0.55, 0.08, 0.1),
		"admit": true, "delay": 30.0,
		"greet": ["Hello again. Marsh, A&E. Sorry, I'm in a terrible hurry. Again."],
		"ok": "Thank you.", "drive": "Thanks. Stay dry.", "refused": "I'm the on-call registrar. If someone dies tonight it's on you."},
	{"name": "Tom Baxter", "role": "Theatre Technician", "dept": "Main Theatres", "staff_no": "40562", "expires": "30 / 09 / 1989",
		"reg": "A456 GNB", "paint": Color(0.33, 0.22, 0.12), "style": "coupe", "skin": Color(0.85, 0.65, 0.52), "hair": Color(0.45, 0.42, 0.4),
		"shirt": Color(0.15, 0.4, 0.35), "admit": false, "delay": 34.0,
		"why": "His ID card had expired (30 / 09 / 1989), and tonight is 13th October.",
		"greet": ["Evening, Dave. Bet you're glad you're inside tonight.", "You didn't look at my card last night, you know. Very trusting."],
		"ok": "Ta.", "drive": "Night, Dave.", "refused": "Expired? Oh, for... I've been meaning to get a new one. Fine. Fine."},
	{"name": "Janet Lowe", "role": "Pharmacist", "dept": "Pharmacy", "staff_no": "40115", "expires": "01 / 1991",
		"reg": "D310 YXE", "paint": Color(0.6, 0.62, 0.64), "style": "hatch", "skin": Color(0.95, 0.8, 0.7), "hair": Color(0.75, 0.72, 0.68),
		"hair_style": "long", "glasses": true, "shirt": Color(0.5, 0.25, 0.45), "admit": true, "delay": 30.0,
		"greet": ["Hiya Dave. Only me. Your fourth night of this, isn't it?", "Have you noticed? Someone's been sitting in a car in Row C every night since the flood. Gives me the creeps."],
		"ok": "Lovely.", "drive": "Mind how you go.", "refused": "Me? I've been coming here eleven years, Dave."},
	{"name": "R. Kessler", "role": "Night Security", "dept": "Lot C - Booth 2", "staff_no": "00217", "expires": "29 / 09 / 1989",
		"org": "ASHFORD PARKING AUTHORITY", "card_color": Color(0.25, 0.27, 0.22), "stained": true,
		"reg": "TKM 117", "paint": Color(0.16, 0.17, 0.18), "style": "saloon", "skin": Color(0.78, 0.78, 0.74), "hair": Color(0.3, 0.3, 0.3),
		"shirt": Color(0.12, 0.14, 0.2), "admit": false, "delay": 40.0, "ghost": true, "bay": Vector3(12.95, -0.15, -27.0),
		"why": "Not on the list, an expired card (29 / 09 / 1989), the wrong organisation, and not a real person.",
		"greet": ["...", "It's raining in here, Dave.", "You know me. I used to sit where you're sitting."],
		"ok": "Thank you.", "drive": "Row C. Like always.", "refused": "You'll let me in. Everyone does, in the end."},
]

## Free bays in row A (facing the booth) for arrivals; the leavers start in LEAVER_BAYS.
## (Bays 1 and 2 are clipped by the lamp island.)
const BAYS := [4, 5, 6, 8, 9, 0]
const LEAVER_BAYS := [10, 11]
## Evening staff still parked when you come on, who go home during the night.
const LEAVERS := [
	{"reg": "D88 OPW", "style": "4x4", "paint": Color(0.2, 0.22, 0.25)},
	{"reg": "B227 TRE", "style": "sports", "paint": Color(0.75, 0.75, 0.72)},
	{"reg": "E640 MBC", "style": "mpv", "paint": Color(0.35, 0.08, 0.1)},
]
const LeavingCar := preload("res://scripts/world/leaving_car.gd")

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
var start_money := START_MONEY   ## coins brought forward from the last night (user://progress.cfg)
var night := 1
var money := START_MONEY   ## the coins shown top right; wages are settled when you clock out
const EndScreen := preload("res://scripts/ui/end_screen.gd")
var _shift_done := false
var _pc_off := false
var _order: Array = []       ## tonight's arrivals, shuffled (the 3am car always last)
var _bays: Array = []
var _leavers: Array = []
var _kessler_res: Dictionary = {}
const NightTwo := preload("res://scripts/story/night_two.gd")
## The previous operator's margin notes (the logbook on the desk, night two on).
const LOGBOOK_PAGE := "Mon   Quiet. Rain. Out of milk again.\n\nTue   Access road under water. Dale rang three times to ask if I was awake.\n\nWed   ROW C. Grey saloon. Been there since the flood. Nobody got out. Nobody got in. Bonnet was cold.\n\nThu   Still there. Counted the bays twice. Don't tell Dale.\n\nFri   It moved. Not far. Closer to the barrier. Light's on in the car, but nobody's in it.\n\n[i]... don't look at it for too long.[/i]"
const Dialog := preload("res://scripts/story/dialog.gd")
const Hack := preload("res://scripts/story/hack.gd")
const Samples := preload("res://scripts/story/dialogs/samples.gd")
const Doris := preload("res://scripts/story/dialogs/doris.gd")
var hack: Node                ## the hospital side hustle (night three on)
## Selectable dialog (night three on). Shared state: in co-op it is the HOST's copy that counts.
var dialog: Node
var flags := {}               ## story flags set by dialog effects (clues learned, favours owed...)
var dialog_coins := 0         ## coins won or lost in conversations (part of the shared team result)
var risk := 0                 ## the hacking side hustle's "getting caught" meter (0-100)
var local_player_id := 1      ## this machine's player (the host is always 1)
var player_ids := [1]         ## everyone in the booth; co-op will fill this in
var _phone_owner := 1         ## who answered the phone (they answer the replies in that call)
## Co-op (scripts/net/coop.gd). The host's story runs the night; a guest's only mirrors it.
var guest := false            ## this machine is a friend in someone else's game
var net_cars := {}            ## name -> visitor car (host and guests use the same names)
var _window_opener := 1       ## who last opened the side window (they talk to the next visitor)
## Leaving the hut (night three on, scripts/player/roam.gd). One desk chair: who is sitting in it
## (0 = nobody). The host decides; P1 starts in it.
const Roam := preload("res://scripts/player/roam.gd")
var roam: Node
var chair_owner := 1
var _choice_tick := 0.0
## Tonight's data (night one's constants, or night two's from night_two.gd).
var arrivals: Array = []     ## who turns up
var list_now: Array = []     ## the printed list you check IDs against
var log_list: Array = []     ## names you can log in GateLog / the clipboard (the ward can add one)
var date_text := DATE_TEXT
var date_short := "FRI 13 OCT 1989"
var notes := ""              ## the player's notepad (N)
var _call_done := false


func setup(p_world, p_hud, p_inspect) -> void:
	world = p_world
	hud = p_hud
	camera = p_world.camera
	inspect = p_inspect
	guest = Net.is_guest() and Net.in_game
	if Net.active():
		local_player_id = Net.my_id()
		player_ids = Net.ids()
	_load_progress()
	if night >= 2:
		arrivals = NightTwo.arrivals(ARRIVALS)
		list_now = NightTwo.LIST.duplicate(true)
		date_text = NightTwo.DATE_TEXT
		date_short = NightTwo.DATE_SHORT
	else:
		arrivals = ARRIVALS.duplicate(true)
		list_now = LIST.duplicate(true)
	if night >= 3:   # night three is the Sunday (it used to borrow night two's date)
		date_text = "Sunday 15th October 1989  -  23:00 to 07:00"
		date_short = "SUN 15 OCT 1989"
	if night >= 3:   # Doris Fenn, Ward 7's clerk, who hands over the staff newsletter (the hospital's address)
		var d: Dictionary = Doris.ARRIVAL.duplicate(true)
		d["convo"] = Doris.window()
		arrivals.append(d)
		list_now.append(Doris.LIST.duplicate())
		list_now.sort_custom(func(a, b): return str(a.name) < str(b.name))
		world.props.newsletter_interact.activated.connect(_read_newsletter)
	log_list = list_now.duplicate(true)
	for i in arrivals.size():
		arrivals[i]["idx"] = i   # the same on every machine, so a car can be named by number
	if night >= 2:
		world.props.logbook_interact.prompt = "Read the logbook"
	if guest:
		world.props.phone_interact.activated.connect(func(): Net.request("phone"))
	else:
		world.props.phone_interact.activated.connect(_on_phone.bind(local_player_id))
	_setup_dialog()
	if night >= 3:
		_setup_hack()
	if world.props.notepad_interact:
		world.props.notepad_interact.activated.connect(open_notes)
	world.props.logbook_interact.activated.connect(_on_logbook)
	hud.set_money(money, false)
	hud.set_night(night, "", false)
	if guest:
		world.booth.raise_button.activated.connect(func(): Net.request("raise"))
		world.booth.lower_button.activated.connect(func(): Net.request("lower"))
		# The side window opens on the host's say-so (so everyone sees the same window).
		var pane: Interactable = world.booth.side_pane_interact
		for c in pane.activated.get_connections():
			pane.activated.disconnect(c.callable)
		pane.activated.connect(func(): Net.request("window", [not world.booth.side_is_open]))
	else:
		world.booth.raise_button.activated.connect(_on_raise)
		world.booth.lower_button.activated.connect(_on_lower)
		world.booth.side_window_moved.connect(func(o: bool):
			Net.send("window", [o])
			if not _remote_window:
				_window_opener = local_player_id)
		world.lot.gate.moved.connect(func(o: bool): Net.send("gate", [o]))
	if world.booth.vehicle_log:   # bought as an upgrade after a shift
		world.booth.vehicle_log.activated.connect(_open_log)
		inspect._log_ready = true
	if Net.active():
		camera.zoom_guard = _may_zoom
	if night >= Roam.FROM_NIGHT:
		roam = Roam.new()
		roam.name = "Roam"
		add_child(roam)
		roam.setup(self)
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
	# Tonight's order: everyone but the 3am car, shuffled. On night two the ward's call comes
	# after the first two cars, and the people it's about only turn up after it.
	var before := []
	var after := []
	for p in arrivals:
		if p.get("ghost", false):
			continue
		(after if p.get("after_call", false) else before).append(p)
	before.shuffle()
	if night >= 2:
		var first := before.slice(0, 2)
		var rest: Array = before.slice(2) + after
		rest.shuffle()
		_order = first + [{"ward_call": true}] + rest
	else:
		_order = before + after
		_order.shuffle()
	for p in arrivals:
		if p.get("ghost", false):
			_order.append(p)
	_bays = BAYS.duplicate()
	_bays.shuffle()
	_spawn_leavers()


func _bay_pos(i: int, nose_out := false) -> Vector3:
	return Vector3(-16.7 + (i + 0.5) * 2.7, -0.15, -11.7 if nose_out else -11.9)


func _spawn_leavers() -> void:
	var bays := LEAVER_BAYS.duplicate()
	bays.append(BAYS[-1])   # one more in the far west bay
	_bays.erase(BAYS[-1])
	for i in LEAVERS.size():
		var c = LeavingCar.new()
		var d: Dictionary = LEAVERS[i]
		c.world = world
		c.style = d.style
		c.paint = d.paint
		c.reg = d.reg
		c.name = "Leaver_%d" % i
		world.add_child(c)
		c.park_at(_bay_pos(bays[i], true))
		_leavers.append(c)


## Everyone from the evening shift has gone home (sends any stragglers off now).
func _all_leavers_gone() -> void:
	for c in _leavers:
		if is_instance_valid(c) and c.state == "parked":
			_leaver_go(c)
	for c in _leavers:
		while is_instance_valid(c):
			await _wait(0.5)


## Sends the evening staff home at random moments, never while someone is driving in.
func _run_leavers() -> void:
	var left := _leavers.duplicate()
	left.shuffle()
	for c in left:
		await _wait(randf_range(35.0, 110.0))
		while current != null and is_instance_valid(current) and current.state == "entering":
			await _wait(1.0)
		if is_instance_valid(c):
			_leaver_go(c)


func _leaver_go(c) -> void:
	Net.send("leaver", [_leavers.find(c)])
	c.go()


## Expected names for GateLog.
func staff_list() -> Array:
	return log_list


func log_entry(reg: String, staff: String) -> void:
	if guest:
		Net.request("log", [reg, staff])   # the host's log is the one that counts
		return
	var shown := reg.strip_edges().to_upper()
	entries.append({"time": NightClock.time_text(), "reg": shown, "key": _norm(reg), "name": staff})
	Net.send("entries", [entries])
	list_changed.emit()


## A plate with the spaces taken out, so "E412 KTV" and "E412KTV" are the same plate.
func _norm(r: String) -> String:
	var out := ""
	for ch in r.to_upper():
		if ch != " " and ch != "\t" and ch != "\u00a0":
			out += ch
	return out


func start() -> void:
	if started:
		return
	started = true
	hud.set_night(night, date_text.split("  -  ")[0])
	hud.set_objectives([["phone", "Answer the phone (click it)"] if night >= 2 else ["phone", "Answer the phone"]])
	await _wait(5.0)
	await _phone_call(NightTwo.dale_call() if night >= 2 else _dale_call())
	hud.complete_objective("phone")
	if night >= 2:
		hud.add_objective("ids", "Check each ID against tonight's list")
		hud.add_objective("plate", "Their plate must match the car on the list (click the car to read it)")
		hud.add_objective("log", "Log the plate of every car you let in")
		hud.add_objective("shift", "Stay at your post until 07:00")
		hud.tip("n2_plates", "NEW TONIGHT: the list shows each person's car. At the side window, click their car to read the plate. A different car means no entry.")
		hud.tip("notepad", "You can write things down. Press N (or click the notepad on the desk) and type. Your notes show next to every ID card you check.")
	else:
		hud.add_objective("ids", "Check each visitor's ID against tonight's list")
		hud.add_objective("log", "Log the plate of every car you let in")
		hud.add_objective("shift", "Stay at your post until 07:00")
	if night >= 3:
		hud.add_objective("hack", "Side hustle: find the hospital's address on the PC and get in")
		_watch_hack()
	_watch_wet()
	await _wait(2.0)
	hud.notify("Cars arrive at the side window. Click  <  on the left, or the window itself.", 6.0)
	_run_leavers()
	for i in _order.size():
		var p: Dictionary = _order[i]
		if p.get("ward_call", false):
			await _wait(randf_range(12.0, 20.0))
			await _ward_call()
			continue
		if p.get("ghost", false):
			await _all_leavers_gone()
		await _wait(p.delay if p.get("ghost", false) else (14.0 if i == 0 else randf_range(18.0, 36.0)))
		await _visitor(p)
	await _wait(10.0)
	await _phone_call(_kessler_call())
	await _wait(3.0)
	night_flow_done = true   # every car and call is done: all that's left is waiting for 07:00
	await _shift_over()
	_summary()


func _watch_hack() -> void:
	while not _shift_done:
		if hack and hack.state.logged_in:
			hud.complete_objective("hack")
			return
		await _wait(1.0)


## A hint (once) when rain is blowing in through the open side window.
func _watch_wet() -> void:
	while not _shift_done:
		if world.booth.sill_wet > 0.5:
			hud.notify("Rain is blowing in through the open window. The sill is getting soaked.", 6.0)
			return
		await _wait(1.0)


## Testing (--carstyle=<style>): a car of that style at the side window with its driver, window open.
func debug_car(style: String) -> void:
	started = true
	var p: Dictionary = arrivals[0].duplicate(true)
	p["style"] = style
	_debug_skip = true
	world.booth.set_side_window(true)
	camera.zoom_to(world.booth.side_view)
	_visitor(p)
	await _wait(0.8)
	if current:
		_car(current, "offer_card")


## Testing (--dialog=window|phone|patrol): plays a sample conversation right now.
func debug_dialog(which: String) -> void:
	started = true
	var S := load("res://scripts/story/dialogs/samples.gd")
	var tree: Dictionary = S.call(which)
	var res := await talk(tree)
	print("DIALOG RESULT ", res)


## Testing (--walker): someone has just got out of their car and is walking to the hospital,
## already most of the way along the aisle.
func debug_walker(idx := 0, x := -52.0) -> void:
	started = true
	var p: Dictionary = ARRIVALS[idx]
	var car = VisitorCar.new()
	car.setup(world, p, Vector3(-9.0, -0.15, -11.9))
	world.add_child(car)
	await _frame()
	await _frame()
	car._start_walk()
	car._walker.global_position = Vector3(x, -0.15, -7.4)
	car._walk_path.pop_front()   # skip the leg from the car to the aisle


## Testing (--shiftend, with --time=6.98): the 07:00 hand-over, clocking out by itself after a few seconds.
func debug_shift_end() -> void:
	started = true
	hud.set_objectives([["ids", "Check each visitor's ID"], ["log", "Log the plate of every car you let in"], ["shift", "Stay at your post until 07:00"]])
	get_tree().create_timer(4.0).timeout.connect(_on_logbook)
	await _shift_over()
	debug_report()


var _skip := false


## Night two: the ward rings mid-shift with changes to the list. The printed list doesn't change,
## so the player has to remember them, or (better) write them down.
func _ward_call() -> void:
	var notes_before_call := notes
	_notes_opened_since_call = false
	hud.add_objective("ward", "Answer the phone: the ward is ringing")
	await _phone_call(NightTwo.ward_call())
	hud.complete_objective("ward")
	_call_done = true
	log_list.append(NightTwo.ADDED.duplicate())   # GateLog can log the new porter
	Net.send("log_list", [log_list])
	list_changed.emit()
	hud.add_objective("notes", "Write down the changes: press N for your notepad")
	hud.tip("notepad_call", "Changes to the list come by phone. Press N, type what you were told, then close it (Esc or N). It stays beside every ID card you check.")
	# The night must never wait on this: it's ticked off whenever the notes change or the pad is
	# opened (even if you'd already written them down during the call), and the next car comes anyway.
	_watch_notes(notes_before_call)


func _watch_notes(before: String) -> void:
	while not _shift_done:
		if notes != before or _notes_opened_since_call:
			hud.complete_objective("notes")
			return
		await _wait(0.5)


var _notes_opened_since_call := false
var ending := false             ## the end-of-night screen is up (the mouse must be free to click it)
var night_flow_done := false   ## the cars and phone calls are over; only 07:00 is left (used by the autoplay watchdog)


## The notepad (N, or the pad on the desk): type anything; shown beside the ID card.
func open_notes() -> void:
	if _call_done:
		_notes_opened_since_call = true
	if inspect.is_open:
		if inspect.mode == "notes":
			inspect.close("done")
		return
	world.ambience.play_ui("click2", -16.0)
	inspect.show_notes(notes, func(t): notes = t)


## Testing menu: cut the current wait short (the next car comes now).
func skip_wait() -> void:
	_skip = true


## Testing menu: send one of the evening cars home now.
func debug_send_leaver() -> void:
	for c in _leavers:
		if is_instance_valid(c) and c.state == "parked":
			_leaver_go(c)
			return
	hud.notify("No evening cars left to go home.", 3.0)


## Testing menu: jump straight to 07:00's clock-out (turn off the PC, sign the logbook, leave).
func debug_shift_end_now() -> void:
	if _shift_done:
		return
	started = true
	await _shift_over()
	_summary()


## Testing (--leave_booth): skip to clocking out, then get up, switch off and leave by itself.
func debug_leave() -> void:
	started = true
	_shift_done = true
	_pc_off = true
	var auto := func():
		await _wait(1.0)
		for c in hud.get_children():
			if c is Button and c.text == "GET UP":
				c.pressed.emit()
		await _wait(3.5)
		world.booth.light_switch.activate()
		await _wait(1.0)
		world.booth.door_interact.key_used.emit()
	auto.call()
	await _leave_booth()
	debug_report()


## Testing (--report): a made-up night, ending on the report screen.
func debug_report() -> void:
	started = true
	var plan := ["admitted", "admitted", "admitted", "refused", "admitted", "refused", "refused"]
	for i in arrivals.size():
		var p: Dictionary = arrivals[i]
		results.append({"name": p.name, "reg": p.reg, "admit": p.admit, "decided": plan[i], "checked": i != 1, "why": p.get("why", "")})
	log_entry("e412ktv", "PIKE, Sandra")
	log_entry("C771PMF", "ADEYEMI, Michael")
	log_entry("F23 HLM", "MARSH, Dr Helen")
	_summary()


## Testing: run just one arrival (index into ARRIVALS), starting at the window.
func debug_visitor(i: int, offer := true) -> void:
	started = true
	var p: Dictionary = arrivals[i]
	_debug_skip = true
	_visitor(p)
	if offer:
		await _wait(0.8)
		if current:
			_car(current, "offer_card")


signal _never   ## never emitted: a coroutine waiting on it is parked for good


## Waits one frame. If this node has left the scene tree (the night was restarted or the scene reloaded)
## the coroutine is parked for good instead of spinning: calling get_tree() on a node outside the tree
## fails instantly, which turned every wait loop into an endless busy loop and hung the game.
func _frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		await _never


func _wait(sec: float) -> void:
	var left := sec
	_skip = false
	while left > 0.0:
		await _frame()
		if _skip:
			_skip = false
			return
		if not get_tree().paused:
			left -= get_process_delta_time()


# ------------------------------------------------------------------ the hospital side hustle
func _setup_hack() -> void:
	hack = Hack.new()
	hack.name = "Hack"
	add_child(hack)
	hack.setup(self)
	hack.remote = guest
	hack.persist = not guest   # a guest's install is the host's (only the host's save changes)
	hack.installed = SaveGame.has_upgrade("medicare")   # installed on an earlier night
	# Placeholder until night three's real conversations are written: Kevin Platt's window chat
	# (his dog's name is the hospital gateway's password).
	for p in arrivals:
		if p.name == "Kevin Platt":
			p["convo"] = Samples.window()
	# Whoever started using the PC first owns it until they stop (co-op rule): sitting back or shutting
	# down frees it. Everyone else can watch the screen but not act.
	var desk = world.props.desktop
	desk.away_changed.connect(func(away: bool): _pc_use(not away))
	desk.state_changed.connect(func(on: bool):
		if not on:
			_pc_use(false))
	hack.installed_changed.connect(desk.refresh_hack_icon)
	hack.download_finished.connect(func(id: String):
		_save_download(id)
		hud.notify("Download finished: " + Hack.FILES[id].name, 4.0)
		Net.send("download", [id])
		flags["got_" + id] = true)
	if not guest:
		hack.changed.connect(func(): _hack_dirty = true)


var _hack_dirty := false
var _hack_sent := 0.0


func _save_download(id: String) -> void:
	var desk = world.props.desktop
	desk.vfs.make_dir("C:\\DOWNLOADS")
	desk.vfs.write("C:\\DOWNLOADS\\" + Hack.FILES[id].name, hack.file_text(id))


## This player started or stopped using the PC.
func _pc_use(on: bool) -> void:
	if guest:
		Net.request("pc", [on])
	else:
		_set_pc_owner(local_player_id if on else 0, local_player_id)


## Whoever started using the PC first owns it until they free it up. `who` is the player asking.
func _set_pc_owner(id: int, who := 1) -> void:
	if hack == null:
		return
	var before: int = hack.pc_owner
	if id == 0:
		if hack.pc_owner == who:
			hack.pc_owner = 0
	elif hack.pc_owner == 0:
		hack.pc_owner = id
	elif hack.pc_owner != id:
		Net.send_to(who, "pc_taken", [hack.pc_owner])   # someone got there first: sit them back
	if hack.pc_owner != before:
		Net.send("pc_owner", [hack.pc_owner])


func pc_owner() -> int:
	return hack.pc_owner if hack else 0


## Co-op: leaning in to the PC is only allowed when nobody else is using it.
func _may_zoom(it) -> bool:
	if it != world.props.crt_interact:
		return true
	var o := pc_owner()
	if o != 0 and o != local_player_id:
		hud.notify_local("%s is using the PC. You can watch over their shoulder; it's yours once they sit back." % Net.label(o), 4.0)
		return false
	return true


## The risk of being caught goes up with each hacking action (0-100). At 100 the session is cut.
func add_risk(n: int) -> void:
	if n > 0 and Net.count() > 1:   # co-op: more guards, faster-rising risk (numbers still to tune)
		n = int(ceil(n * (1.0 + 0.25 * (Net.count() - 1))))
	risk = clampi(risk + n, 0, 100)
	if risk >= 100 and hack and not hack.state.dead:
		hack.caught()
		hud.notify("SECURITY ALERT: the hospital has cut your session.", 6.0)


# ------------------------------------------------------------------ selectable dialog
func _setup_dialog() -> void:
	dialog = Dialog.new()
	dialog.name = "Dialog"
	dialog.say_fn = _dialog_say
	dialog.effect_fn = _apply_effect
	dialog.flag_fn = func(f: String) -> bool: return bool(flags.get(f, false))
	add_child(dialog)
	dialog.options_ready.connect(func(_nid, ents, owner_id, seconds):
		Net.send("choices", [ents, owner_id, seconds])
		hud.show_choices(ents, seconds, owner_id == local_player_id, _player_label(owner_id)))
	dialog.tick.connect(func(left: float, total: float):
		hud.update_choice_time(left, total)
		_choice_tick -= get_process_delta_time()
		if _choice_tick <= 0.0:
			_choice_tick = 0.2
			Net.send("choice_time", [left, total]))
	dialog.chosen.connect(func(_nid, _i, _o, _auto):
		Net.send("choices_hide")
		hud.hide_choices())
	if guest:
		hud.choice_picked.connect(func(i): Net.request("choice", [i]))
	else:
		hud.choice_picked.connect(func(i): dialog.submit_choice(i, local_player_id))


func _player_label(id: int) -> String:
	return "YOU" if id == local_player_id else (Net.label(id) if Net.active() else "P%d" % id)


## Plays a conversation (see dialog.gd). `owner_id` is whoever is talking: the player who opened the
## window or took the ID, answered the phone, or walked up to the NPC. Returns the result dictionary.
func talk(tree: Dictionary, owner_id := -1) -> Dictionary:
	if owner_id < 0:
		owner_id = local_player_id
	var t := tree.duplicate()
	t["player"] = _player_label(owner_id)
	return await dialog.run(t, owner_id)


func _dialog_say(speaker: String, text: String, auto: bool, is_player: bool) -> void:
	if is_player:
		Net.send("say_player", [dialog.talker, text, auto])
		await hud.say_player(speaker, text, auto)
	else:
		await hud.say(speaker, text)


## Applies one dialog effect. Runs on the host only; the result is what everyone shares.
func _apply_effect(e: Dictionary) -> void:
	if e.has("flag"):
		flags[e.flag] = e.get("value", true)
	if e.has("coins"):
		dialog_coins += int(e.coins)
	if e.has("risk"):
		add_risk(int(e.risk))
	if e.has("note"):
		notes += ("\n" if notes != "" else "") + str(e.note)
		list_changed.emit()


# ------------------------------------------------------------------ end of the shift
## Waits for 07:00, then tells the player to turn off the PC and clock out (sign the logbook).
func _shift_over() -> void:
	while not NightClock.shift_over:
		await _frame()
	_shift_done = true
	hud.complete_objective("ids")
	hud.complete_objective("log")
	hud.complete_objective("shift")
	hud.complete_objective("notes")
	Net.send("chime")
	if Net.active():
		Net.send("hud", ["notify", ["07:00. The shift is over. %s clocks out for the team." % Net.label(1), 9.0]])
		hud.relay_paused = true   # the clock-out is the host's job (they press NEXT NIGHT too)
	hud.add_objective("pc", "Shut down the PC")
	hud.add_objective("out", "Clock out: sign the logbook")
	world.ambience.play_ui("chime", -6.0)
	world.props.logbook_interact.prompt = "Logbook (clock out)"
	hud.notify("07:00. Your shift is over. Turn off the PC and clock out.", 9.0)
	hud.say("", "(07:00. The shift is over. Turn off the PC, then clock out in the logbook.)", 6.0)
	var desk = world.props.desktop
	while desk.is_on():
		await _frame()
	_pc_off = true
	hud.complete_objective("pc")
	hud.notify("PC off. Now clock out in the logbook.", 5.0)
	if roam and roam.outside:
		hud.notify_local("You're outside. Go back in through the door to sign the logbook.", 6.0)
	await clocked_out
	hud.complete_objective("out")
	world.ambience.play_ui("click2", -10.0)
	await _wait(1.0)
	await _leave_booth()


## Get up, turn the light off by the door, and walk out. The door's sound plays as the
## night fades out (the end-of-shift screen takes over from there).
func _leave_booth() -> void:
	if roam:
		roam.finish()   # from here the door is the way home
	hud.set_look_left(false)
	if camera.state == camera.State.ZOOMED:
		camera.unzoom()
		await camera.zoom_changed
	if camera.state != camera.State.WALK:   # still at the desk: get up as before
		hud.add_objective("getup", "Get up from the desk")
		await hud.big_button("GET UP")
		hud.complete_objective("getup")
		inspect.close()
		world.booth.push_chair_back()
		world.ambience.play_at("window_slide", world.booth.chair.global_position + Vector3(0, 0.3, 0), -16.0)
		await camera.stand_up()
	hud.set_look_left(false)
	hud.set_look_back(false)
	hud.set_crosshair(true)
	hud.add_objective("light", "Turn off the light (switch by the door)")
	hud.add_objective("leave", "Leave by the door behind you")
	hud.notify("WASD to walk, mouse to look, click or E to use.", 6.0)
	var booth = world.booth
	booth.door_interact.enabled = true
	booth.door_interact.prompt = "Leave  [E]"
	booth.door_interact.activated.connect(func():
		hud.notify("Press E to leave." if not booth.light_on else "Turn the light off first.", 3.0))
	booth.light_switch.activated.connect(func():
		world.ambience.play_at("radio_click", booth.light_switch.global_position, -4.0)
		if not booth.light_on:
			hud.complete_objective("light"))
	while true:
		await booth.door_interact.key_used
		if booth.light_on:
			hud.notify("Turn the light off first.", 3.0)
			continue
		break
	hud.complete_objective("leave")
	booth.door_interact.enabled = false
	camera.blocked = true
	hud.set_crosshair(false)
	# The door: latch, creak open (a breath of rain), then it bangs shut as everything fades.
	world.ambience.play_at("door_open_close", booth.door.global_position + Vector3(-0.4, 1.0, 0), -2.0, "Interior", 3.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(booth.door, "rotation:y", deg_to_rad(80.0), 1.2)
	tw.tween_interval(0.6)
	tw.tween_property(booth.door, "rotation:y", 0.0, 0.45).set_ease(Tween.EASE_IN)
	await _wait(0.5)


func _on_logbook() -> void:
	if not _shift_done:
		if night >= 2 and not inspect.is_open:
			world.ambience.play_ui("click2", -16.0)
			inspect.show_page("LOGBOOK  -  BOOTH 2  -  the last operator's notes", LOGBOOK_PAGE)
		else:
			hud.notify_local("Your shift isn't over yet.", 3.0)
	elif guest:
		hud.notify_local("%s clocks out for the team." % Net.label(1), 3.0)
	elif not _pc_off:
		hud.notify_local("Shut down the PC before you clock out.", 4.0)
	else:
		clocked_out.emit()


# ------------------------------------------------------------------ phone
## After the 3am car: Roy Kessler's wife, looking for him.
func _kessler_call() -> Array:
	var lines := [
		["Woman", "Hello? Is that Booth 2? Lot C?"],
		["Woman", "I'm sorry to ring so late. It's Margaret Kessler. Roy's wife."],
		["Woman", "He hasn't been home since the twenty-ninth. The police say he just drove off. People do, they said."],
		["Woman", "But he rang me tonight. Just now. First time in two weeks."],
	]
	if _kessler_res.get("decided", "") == "admitted":
		lines.append(["Woman", "He said he was back at work. He said the new lad let him in, and he'd parked in Row C."])
		lines.append(["Woman", "He sounded so cold. Is he there? Can you go and look? ...Please?"])
	else:
		lines.append(["Woman", "He said he was at work, but the new lad wouldn't let him in. He said he'd wait."])
		lines.append(["Woman", "He said it's ever so cold, waiting. Is he out there? ...Can you see him?"])
	lines.append(["", "(Before you can answer, she hangs up.)"])
	return lines


func _dale_call() -> Array:
	return [
		["Dale", "Dave? It's Dale. You got in alright, then. Roads are like rivers."],
		["Dale", "Hospital car park's still under water. Fourth night now, so you know the drill."],
		["Dale", "Their night lot come through our gate. They'll pull up on your left. Slide the window open, take the card."],
		["Dale", "Name on tonight's list, card in date. The list's in GateLog on the PC, same as the last few nights."],
		["Dale", "If they're good, type the reg into GateLog, then the green button lifts the barrier."],
		["Dale", "Not on the list, or the card's out of date? They don't come in. I don't care how nice they are."],
		["Dale", "Take your time with them, mind. Nobody gets in till you press that button."],
		["Dale", "Facilities reckon the water'll be gone by Monday. Don't hold your breath."],
		["Dale", "Right. I'm off to bed. Don't ring me."],
	]


func _phone_call(lines: Array) -> void:
	_phone_ringing = true
	_phone_answered = false
	_ring.play()
	Net.send("ring", [true])
	hud.notify("The phone is ringing.", 4.0)
	while not _phone_answered:
		await _frame()
	_ring.stop()
	Net.send("ring", [false])
	if Net.active() and _phone_owner != local_player_id:
		hud.notify_local("%s answered the phone." % Net.label(_phone_owner), 3.0)
	world.ambience.play_ui("handset", -8.0)
	_lift_handset(true)
	for l in lines:
		if l is Dictionary:   # a conversation with replies: the person who answered the phone answers
			await talk(l, _phone_owner)
		else:
			await hud.say(l[0], l[1], -1.0, true)
	world.ambience.play_ui("handset", -8.0)
	_lift_handset(false)


func _on_phone(from_player := 1) -> void:
	if _phone_ringing and not _phone_answered:
		_phone_owner = from_player
		_phone_ringing = false
		_phone_answered = true


func _lift_handset(up: bool) -> void:
	Net.send("handset", [up])
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
		var i: int = _bays[_bay_i % _bays.size()]
		_bay_i += 1
		bay = _bay_pos(i)
	var car = VisitorCar.new()
	car.setup(world, p, bay)
	car.name = "Visitor_" + p.reg.replace(" ", "")
	world.add_child(car)
	current = car
	net_cars[car.name] = car
	car.tree_exiting.connect(func(): net_cars.erase(car.name))
	Net.send("car_new", [int(p.get("idx", -1)), bay, car.name])
	if _debug_skip:
		_debug_skip = false
		car._dist = car._stop_dist - 0.02
	var res := {"name": p.name, "reg": p.reg, "admit": p.admit, "decided": "", "checked": false, "why": p.get("why", "")}
	results.append(res)
	car.set_meta("res", res)
	if p.get("ghost", false):
		_kessler_res = res
	car.card_interact.activated.connect(func(): _on_card(car, p, res))
	car.plate_interact.activated.connect(func(): _on_plate(car, p))
	await car.arrived
	if camera.focus != world.booth.side_view:
		hud.notify("A car has pulled up at the side window.", 5.0)
	# Wait for the window to open. Knock now and then.
	var waited := 0.0
	var knocked := 0
	while not world.booth.side_is_open and car.state == "waiting":
		await _frame()
		waited += get_process_delta_time()
		if waited > 14.0 + knocked * 16.0 and knocked < 3:
			knocked += 1
			_knock()
			hud.say("", "(Knock knock on the side window.)", 2.5)
	_claim_talker(car, _window_opener)
	if car.state == "waiting":
		await _wait(0.6)
		for l in p.greet:
			if car.state != "waiting":
				break
			await hud.say(_short(p), l)
		# Night three on: some visitors have a conversation with replies instead of fixed lines.
		if car.state == "waiting" and p.has("convo"):
			await talk(p.convo, _talker_of(car))
		if car.state == "waiting" and p.get("hands", "") == "newsletter":
			_hand_newsletter(_short(p))
		if car.state == "waiting" and not res.checked:
			_car(car, "offer_card")
	# Until it drives in or reverses away.
	while car.state in ["waiting", "approach"]:
		await _frame()
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


## Whoever opens the window or takes the ID first owns the conversation with that visitor.
func _claim_talker(car, player_id: int) -> void:
	if not car.has_meta("talker"):
		car.set_meta("talker", player_id)


func _talker_of(car) -> int:
	return int(car.get_meta("talker", local_player_id))


func _on_card(car, p: Dictionary, res: Dictionary) -> void:
	if car.state != "waiting" or inspect.is_open:
		return
	_claim_talker(car, local_player_id)
	_car(car, "take_card")
	world.ambience.play_ui("click2", -16.0)
	res.checked = true
	var choice: String = await _show_card(p)
	await _card_choice(car, p, res, choice, local_player_id)


func _show_card(p: Dictionary) -> String:
	inspect.smudge = night >= 2 and Weather.rain > 0.3   # rain-soaked paperwork
	inspect.show_id(p, list_now, date_text, p.reg if night >= 2 else "", notes)
	return await inspect.closed


## What the guard holding the ID card decided (`from` is that player). Runs on the host.
func _card_choice(car, p: Dictionary, res: Dictionary, choice: String, from: int) -> void:
	if not is_instance_valid(car) or car.state != "waiting":
		return   # the barrier went up meanwhile (that hands the card back)
	match choice:
		"refuse":
			_car(car, "return_card")
			res.decided = "refused"
			await hud.say(_short(p), p.refused)
			if car.state == "waiting":
				_car(car, "reverse_out")
		"ok":
			# Handed back, but nothing is decided until the barrier goes up.
			_car(car, "return_card")
			_card_prompt(car, "Ask for the ID again")
			await hud.say(_short(p), p.ok)
		_:
			# Kept hold of it to go and check something. The driver waits.
			_card_prompt(car, "Look at the ID card again")
			_tell(from, "You keep hold of the card. The driver waits.", 3.5)


## A car does something (offer_card, take_card, drive_in...): here, and on every guest's screen.
func _car(car, method: String) -> void:
	if not is_instance_valid(car):
		return
	Net.send("car", [car.name, method])
	car.call(method)


func _card_prompt(car, prompt: String) -> void:
	car.card_interact.prompt = prompt
	car.card_interact.enabled = true
	Net.send("car_prompt", [car.name, prompt])


func _knock() -> void:
	Net.send("knock")
	world.ambience.play_at("knock", world.booth.side_pane.global_position + Vector3(-0.05, 0, 0), -6.0)


func _term(text: String) -> void:
	Net.send("term", [text])
	world.props.terminal.add_log(text)


## A notice for one player (on their screen only).
func _tell(id: int, text: String, seconds := 4.0) -> void:
	if id == local_player_id:
		hud.notify_local(text, seconds)
	else:
		Net.send_to(id, "hud", ["notify", [text, seconds]])


func _on_plate(car, p: Dictionary) -> void:
	if inspect.is_open:
		return
	inspect.show_plate(p.reg)
	var choice: String = await inspect.closed
	if choice == "log":
		_open_log()


## The vehicle log clipboard under the side window: logs straight into GateLog.
func _open_log() -> void:
	if inspect.is_open:
		return
	var reg := ""
	if current != null and is_instance_valid(current) and current.state == "waiting":
		reg = current.person.reg
	world.ambience.play_ui("click2", -16.0)
	inspect.show_log(reg, log_list, date_text, log_entry, func(): return entries)
	await inspect.closed


# ------------------------------------------------------------------ the barrier
func _on_raise() -> void:
	world.ambience.play_at("barrier_button", world.booth.raise_button.global_position, -6.0)
	var gate = world.lot.gate
	if not gate.is_open:
		gate.open()
		_term("GATE OPENED - BOOTH")
	var car = current
	if car != null and car.state == "waiting":
		var res: Dictionary = results[results.size() - 1]
		res.decided = "admitted"
		Net.send("close_inspect")
		if inspect.is_open:
			inspect.close("ok")
		if car.card_with_guard:
			_car(car, "return_card")
		hud.say(_short(car.person), car.person.drive)
		await _wait(1.0)
		_car(car, "drive_in")
		_auto_close(car)


func _on_lower() -> void:
	world.ambience.play_at("barrier_button", world.booth.lower_button.global_position, -6.0)
	var car = current
	if car != null and car.state == "entering" and not car.is_past_barrier():
		return   # safety: won't drop on a car
	if world.lot.gate.is_open:
		world.lot.gate.close()
		_term("GATE CLOSED - BOOTH")


## The induction loop drops the barrier once the car is through.
func _auto_close(car) -> void:
	while is_instance_valid(car) and not car.is_past_barrier():
		await _frame()
	await _wait(1.5)
	if world.lot.gate.is_open:
		world.lot.gate.close()


# ------------------------------------------------------------------ 3am
func _ghost_parks(car) -> void:
	await car.parked
	Net.send("ghost", [car.name])
	await _ghost_fx(car)


func _ghost_fx(car) -> void:
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
	if not guest:
		_term("VEHICLE TKM 117 - NOT DETECTED")


# ------------------------------------------------------------------ end of night
## Scores the night. Coins: +1 for each correct car let in, -2 for each one let in who shouldn't
## have been, +3 if every car let in had its plate logged right (spaces in the reg don't matter).
func evaluate() -> Dictionary:
	var rows: Array = []
	var wrong: Array = []
	var earned := 0
	var right_in := 0
	var wrong_in := 0
	var admitted := 0
	var plates_ok := 0
	for r in results:
		var in_: bool = r.decided == "admitted"
		var key := _norm(r.reg)
		var logged := false
		for e in entries:
			if e.key == key:
				logged = true
		var delta := 0
		var verdict := ""
		if in_ and r.admit:
			delta = 1
			right_in += 1
			verdict = "let in - correct"
		elif in_ and not r.admit:
			delta = -2
			wrong_in += 1
			verdict = "let in - [color=#ff7060]should have been turned away[/color]"
			wrong.append("[color=#ff7060]You let in %s.[/color] %s" % [r.name, r.why])
		elif not in_ and not r.admit:
			verdict = "turned away - correct"
		else:
			verdict = "turned away - [color=#ff7060]they were allowed in[/color]"
			wrong.append("[color=#ffb060]You turned away %s,[/color] who was on the list with a card in date. (No coins lost, but they are stuck outside in the rain.)" % r.name)
		if in_ and not r.checked:
			wrong.append("[color=#ffb060]You let in %s without looking at their ID card.[/color]" % r.name)
		if in_:
			admitted += 1
			if logged:
				plates_ok += 1
			else:
				wrong.append("[color=#ffb060]The plate of %s's car (%s) was never logged correctly.[/color]" % [r.name, r.reg])
		earned += delta
		rows.append({"name": r.name, "delta": delta, "verdict": verdict})
	# Plates typed into GateLog that match no car at all.
	var real := {}
	for r in results:
		real[_norm(r.reg)] = true
	for e in entries:
		if not real.has(e.key):
			wrong.append("[color=#ffb060]You logged the plate '%s', which didn't match any car that came.[/color]" % e.reg)
	if dialog_coins != 0:
		earned += dialog_coins
		rows.append({"name": "Conversations", "delta": dialog_coins, "verdict": "coins from what you said"})
	if world.booth.peak_wet > 0.75:
		wrong.append("[color=#ffb060]You left the side window open in the rain. The sill and floor were soaked; Dale noticed the puddle in the morning.[/color]")
	var bonus := BONUS_PLATES if admitted > 0 and plates_ok == admitted else 0
	var total := start_money + earned + bonus
	return {"rows": rows, "wrong": wrong, "earned": earned, "bonus": bonus, "total": total,
		"right_in": right_in, "wrong_in": wrong_in, "admitted": admitted, "plates_ok": plates_ok,
		"start": start_money, "success": wrong_in == 0 and total > start_money}


const NIGHT_WORDS := ["ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN"]


func _summary() -> void:
	ending = true
	var ev := evaluate()
	money = ev.total
	_term("SHIFT REPORT: WAGES %+d" % (ev.earned + ev.bonus))
	var word: String = NIGHT_WORDS[night - 1] if night <= NIGHT_WORDS.size() else str(night)
	hud.visible = false
	var es = EndScreen.new()
	add_child(es)
	es.next_night.connect(func(coins):
		for u in es.bought_upgrades():
			SaveGame.add_upgrade(u)
		SaveGame.finish_night(coins, ev.earned + ev.bonus, es.skipped_bills())
		Net.ready_ids = {1: true}
		Net.send("next_night", [coins, SaveGame.night()])
		_restart())
	es.start_again.connect(func():
		SaveGame.set_progress(START_MONEY, 1)
		if Net.active():   # night one isn't a co-op night: everyone else goes back to the title screen
			Net.send("ended", ["The host started again from night one."])
			await _wait(0.3)
			Net.leave()
		_restart())
	es.show_night(ev, "END OF NIGHT %s" % word, date_short, _dale_note(ev))
	Net.send("report", [ev, "END OF NIGHT %s" % word, date_short, _dale_note(ev)])
	if night == 2 and not SaveGame.data.get("coop_unlocked", false):
		SaveGame.data["coop_unlocked"] = true
		await _wait(6.0)
		es.show_unlock("CO-OP UNLOCKED", "From night three you'll be leaving the hut: boot checks, patrols and more.\nA second guard can join you for those nights.")


## One line from Dale about the night (the first thing that went wrong, or a nod).
func _dale_note(ev: Dictionary) -> String:
	if ev.wrong.is_empty():
		return "Dale: \"Not bad, Dave. Same again tonight.\""
	var re := RegEx.new()
	re.compile("\\[[^\\]]*\\]")
	var first: String = re.sub(str(ev.wrong[0]), "", true)
	return "Dale: \"%s\"" % first.strip_edges()


func _load_progress() -> void:
	SaveGame.ensure_slot()
	start_money = SaveGame.coins()
	night = SaveGame.night()
	money = start_money


## Testing menu: set the coins and night in the current save slot.
func _save_progress(coins: int, next_night: int) -> void:
	SaveGame.set_progress(coins, next_night)


## Start the next night from the top (only night one's story exists so far).
func _restart() -> void:
	NightClock.set_time(23, 4)
	NightClock.shift_over = false
	NightClock.running = true
	Settings.set_fade(0.0)
	get_tree().paused = false
	SaveGame.skip_title = true
	get_tree().reload_current_scene()


# ================================================================== co-op
# The host's story runs the night. These are the entry points for the other guards' actions
# (remote_action, with their player id) and, on a guest's machine, for what the host sends
# (guest_event). See scripts/net/coop.gd and docs/design/coop-notes.md.

var _remote_window := false


## Host: another guard did something.
func remote_action(from: int, what: String, args: Array) -> void:
	match what:
		"phone":
			_on_phone(from)
		"window":
			_remote_window = true
			if bool(args[0]):
				_window_opener = from
			world.booth.set_side_window(bool(args[0]))
			_remote_window = false
		"raise":
			_on_raise()
		"lower":
			_on_lower()
		"card":
			var car = net_cars.get(str(args[0]))
			if car != null and is_instance_valid(car) and car.state == "waiting" and car.card_interact.enabled:
				_claim_talker(car, from)
				_car(car, "take_card")
				car.get_meta("res").checked = true
				Net.send_to(from, "show_id", [car.name])
		"card_choice":
			var car = net_cars.get(str(args[0]))
			if car != null and is_instance_valid(car) and car.card_with_guard:
				_card_choice(car, car.person, car.get_meta("res"), str(args[1]), from)
		"choice":
			dialog.submit_choice(int(args[0]), from)
		"log":
			log_entry(str(args[0]), str(args[1]))
		"pc":
			_set_pc_owner(from if bool(args[0]) else 0, from)
		"chair":
			_set_chair(from, bool(args[0]))
			Net.send_to(from, "chair_answer", [chair_owner])
		"hack":
			if hack == null:
				return
			var r := {}
			match str(args[0]):
				"connect":
					r = hack.connect_to(str(args[1]), from)
				"login":
					r = hack.login(str(args[1]), str(args[2]), from)
				"download":
					r = hack.start_download(str(args[1]), from)
				"install":
					r = hack.install(from)
				"hang_up":
					if hack.pc_owner == 0 or hack.pc_owner == from:
						hack.hang_up(str(args[1]))
			if r.has("msg"):
				Net.send_to(from, "hack_msg", [r.msg])
			_send_hack()


## Host: a guard who has just loaded the night gets anything that has already changed.
func send_state_to(id: int) -> void:
	Net.send_to(id, "log_list", [log_list])
	Net.send_to(id, "entries", [entries])
	Net.send_to(id, "window", [world.booth.side_is_open])
	Net.send_to(id, "gate", [world.lot.gate.is_open])


## Host: someone left mid-night. Their guard goes, and whatever they were using is freed.
func player_gone(id: int) -> void:
	player_ids.erase(id)
	if hack and hack.pc_owner == id:
		hack.pc_owner = 0
		Net.send("pc_owner", [0])
	if _phone_owner == id:
		_phone_owner = local_player_id
	if chair_owner == id:
		chair_owner = 0
		Net.send("chair_owner", [0])
	for nm in net_cars:
		var c = net_cars[nm]
		if is_instance_valid(c) and int(c.get_meta("talker", 0)) == id:
			c.remove_meta("talker")
	# Mid-conversation: the safe option is chosen for them, then the conversation is free (the host
	# carries it on).
	if dialog.active and dialog.talker == id:
		if dialog._awaiting:
			for i in dialog._entries.size():
				if dialog._entries[i].safe:
					dialog.submit_choice(i, id)
		dialog.talker = local_player_id


func _send_hack() -> void:
	if hack and not guest:
		_hack_dirty = false
		_hack_sent = 0.0
		_hack_last = var_to_str([hack.state, risk, hack.installed])
		Net.send("hack_state", [hack.state, risk, hack.installed])


var _hack_last := ""


func _process(delta: float) -> void:
	if guest or hack == null or not Net.active():
		return
	_hack_sent += delta
	# The gateway's state changes every frame while a download or a lock-out runs: send it at most
	# four times a second, and only when something is different.
	if _hack_dirty and _hack_sent > 0.25:
		_hack_dirty = false
		if var_to_str([hack.state, risk, hack.installed]) != _hack_last:
			_send_hack()


## Guest: the night starts (the host is running it).
func guest_start() -> void:
	started = true
	hud.set_night(night, date_text.split("  -  ")[0])


## Guest: what the host's game says happened.
func guest_event(what: String, a: Array) -> void:
	match what:
		"car_new":
			_guest_car(int(a[0]), a[1], str(a[2]))
		"car":
			var c = net_cars.get(str(a[0]))
			if c != null and is_instance_valid(c):
				var m := str(a[1])
				if m in ["drive_in", "reverse_out", "offer_card", "take_card"] and c.state == "approach":
					_snap_arrived(c)   # running a little behind the host: catch up first
				c.call(m)
		"car_prompt":
			var c = net_cars.get(str(a[0]))
			if c != null and is_instance_valid(c):
				c.card_interact.prompt = str(a[1])
				c.card_interact.enabled = true
		"gate":
			if bool(a[0]) != world.lot.gate.is_open:
				if bool(a[0]):
					world.lot.gate.open()
				else:
					world.lot.gate.close()
		"window":
			world.booth.set_side_window(bool(a[0]))
		"ring":
			_phone_ringing = bool(a[0])
			if _phone_ringing:
				_ring.play()
			else:
				_ring.stop()
		"handset":
			world.ambience.play_ui("handset", -8.0)
			var hs: Node3D = world.props.get_node_or_null("Phone/Handset")
			if hs:
				hs.visible = not bool(a[0])
		"term":
			world.props.terminal.add_log(str(a[0]))
		"knock":
			world.ambience.play_at("knock", world.booth.side_pane.global_position + Vector3(-0.05, 0, 0), -6.0)
		"chime":
			world.ambience.play_ui("chime", -6.0)
		"leaver":
			var i := int(a[0])
			if i >= 0 and i < _leavers.size() and is_instance_valid(_leavers[i]):
				_leavers[i].go()
		"ghost":
			var c = net_cars.get(str(a[0]))
			if c != null and is_instance_valid(c):
				_ghost_fx(c)
		"entries":
			entries = a[0]
			list_changed.emit()
		"log_list":
			log_list = a[0]
			list_changed.emit()
		"say_player":
			hud.say_player(_player_label(int(a[0])), str(a[1]), bool(a[2]))
		"choices":
			hud.show_choices(a[0], float(a[2]), int(a[1]) == local_player_id, _player_label(int(a[1])))
		"choice_time":
			hud.update_choice_time(float(a[0]), float(a[1]))
		"choices_hide":
			hud.hide_choices()
		"show_id":
			_guest_show_id(str(a[0]))
		"close_inspect":
			if inspect.is_open and inspect.mode == "id":
				inspect.close("ok")
		"pc_owner":
			guest_pc_owner(int(a[0]))
		"pc_taken":
			guest_pc_owner(int(a[0]))
		"chair_owner":
			chair_owner = int(a[0])
		"chair_answer":
			chair_owner = int(a[0])
			if roam:
				roam.chair_answer(chair_owner)
		"hack_state":
			if hack:
				hack.state = a[0]
				risk = int(a[1])
				if a.size() > 2 and bool(a[2]) != hack.installed:
					hack.installed = bool(a[2])
					hack.installed_changed.emit()
				hack.changed.emit()
		"hack_msg":
			if hack:
				hack.message.emit(str(a[0]))
		"download":
			if hack:
				_save_download(str(a[0]))
		"report":
			_guest_report(a[0], str(a[1]), str(a[2]), str(a[3]))
		"next_night":
			SaveGame.data.coins = int(a[0])
			SaveGame.data.night = int(a[1])
			_restart()
		"ended":
			leave_to_title(str(a[0]))
		"newsletter":
			world.props.show_newsletter()


func _guest_car(idx: int, bay: Vector3, nm: String) -> void:
	if idx < 0 or idx >= arrivals.size() or net_cars.has(nm):
		return
	var p: Dictionary = arrivals[idx]
	var car = VisitorCar.new()
	car.setup(world, p, bay)
	car.name = nm
	world.add_child(car)
	current = car
	net_cars[nm] = car
	car.tree_exiting.connect(func():
		net_cars.erase(nm)
		if current == car:
			current = null)
	car.card_interact.activated.connect(func():
		if not inspect.is_open:
			Net.request("card", [nm]))
	car.plate_interact.activated.connect(func(): _on_plate(car, p))
	car.arrived.connect(func():
		if camera.focus != world.booth.side_view:
			hud.notify_local("A car has pulled up at the side window.", 5.0))
	car.parked.connect(func():
		if current == car:
			current = null)


## Running behind the host: put the car at the window now.
func _snap_arrived(c) -> void:
	c._dist = c._stop_dist
	c._target = c._stop_dist
	c.state = "waiting"
	c._place()
	c.arrived.emit()


## Guest: the host says where the cars are. Only big differences are corrected.
func guest_cars(list: Array) -> void:
	for row in list:
		var c = net_cars.get(str(row[0]))
		if c == null or not is_instance_valid(c):
			continue
		var st := str(row[1])
		var d := float(row[2])
		if st == c.state and absf(c._dist - d) > 3.0 and st in ["approach", "entering", "leaving"]:
			c._dist = d
			c._place()
		elif st == "waiting" and c.state == "approach" and absf(c._dist - d) > 1.0:
			_snap_arrived(c)


## Guest: someone else is now using the PC (or nobody is). If it isn't us, sit back from it.
func guest_pc_owner(id: int) -> void:
	if hack == null:
		return
	hack.pc_owner = id
	if id != 0 and id != local_player_id and camera.focus == world.props.crt_interact:
		camera.unzoom()
		hud.notify_local("%s is using the PC." % Net.label(id), 4.0)


## Guest: we took the ID card; look at it, then tell the host what we decided.
func _guest_show_id(nm: String) -> void:
	var car = net_cars.get(nm)
	if car == null or not is_instance_valid(car) or inspect.is_open:
		Net.request("card_choice", [nm, "ok"])
		return
	world.ambience.play_ui("click2", -16.0)
	var choice: String = await _show_card(car.person)
	Net.request("card_choice", [nm, choice])


## Guest: the end-of-night report. Everyone sees the same one; only the host goes on.
func _guest_report(ev: Dictionary, title: String, date: String, note: String) -> void:
	ending = true
	_shift_done = true
	hud.visible = false
	var es = EndScreen.new()
	add_child(es)
	es.show_night(ev, title, date, note)
	es.set_view_only("Only %s (the host) can start the next night." % Net.label(1))


## Back to the title screen (the host left, or co-op ended). `why` is shown there.
func leave_to_title(why: String) -> void:
	Net.leave()
	Net.last_error = why
	SaveGame.guest = false
	SaveGame.slot = 0
	SaveGame.skip_title = false
	NightClock.set_time(23, 4)
	NightClock.shift_over = false
	NightClock.running = true
	Weather.set_profile("rain_mist", 0.0)   # a guest's weather was the host's
	get_tree().paused = false
	get_tree().reload_current_scene()


# ------------------------------------------------------------------ the desk chair (one guard at a time)
## This guard sits down (true) or gets up (false). Returns whether they may sit. A guest asks the host.
func chair_use(sit: bool) -> bool:
	if guest:
		Net.request("chair", [sit])
		return false
	return _set_chair(local_player_id, sit)


## Host: `id` wants to sit (or has got up). The chair is whoever got there first's.
func _set_chair(id: int, sit: bool) -> bool:
	var before := chair_owner
	if sit and (chair_owner == 0 or chair_owner == id):
		chair_owner = id
	elif not sit and chair_owner == id:
		chair_owner = 0
	if chair_owner != before:
		Net.send("chair_owner", [chair_owner])
	return chair_owner == id if sit else true


# ------------------------------------------------------------------ the staff newsletter (night three)
## Doris hands it through the side window; it lands on the desk for everyone.
func _hand_newsletter(who: String) -> void:
	if world.props.newsletter.visible:
		return
	world.ambience.play_ui("click2", -14.0)
	world.props.show_newsletter()
	Net.send("newsletter")
	hud.notify("%s hands you a newsletter through the window. It's on the desk." % who, 5.0)


func _read_newsletter() -> void:
	if inspect.is_open:
		return
	world.ambience.play_ui("click2", -16.0)
	var n: Array = Doris.newsletter()
	inspect.show_print(n[0], n[1], n[2])
	if not guest:
		flags["read_newsletter"] = true
