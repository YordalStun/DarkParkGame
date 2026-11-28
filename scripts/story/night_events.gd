extends Node
## Night three on: the set pieces outside the booth (docs/design/night-three-lore.md).
##   - The night's required tasks (top right): they stay until done, night after night.
##   - The alarm car: a random parked car goes off, lights going mad. Nothing's wrong with it, but
##     there's a note by the door that says "DEALER" and names Baxter.
##   - Baxter by the payphone (after he's been asked about the note at the window): sell to him.
##   - The police walk-round with a torch, after the second or third car. You can talk to them.
##     From night four, if they pass a car with its boot open, they come and look in the hut.
##   - The Nite Stop sells a pick lock (2 coins, it can break).
##   - Co-op only: the old second hut at the back of the lot, locked until you've got a pick lock.
## The host runs all of it; guests get what they need to see through guest_event, and ask the host
## through remote_action.

const NightThree := preload("res://scripts/story/dialogs/night_three.gd")
const PersonModel := preload("res://scripts/world/person_model.gd")
const G := -0.15                       ## the car park's ground
const PICK_LOCK_COST := 2
const PICK_BREAK_CHANCE := 0.3
const HUT_POS := Vector3(15.6, G, -39.4)
const HUT_BLOCK := Rect2(14.3, -40.6, 2.6, 2.4)
## Once it's open you can walk in: just its walls (with the doorway) and the desk are in the way.
const HUT_WALLS := [Rect2(14.3, -40.6, 2.6, 0.25), Rect2(14.3, -40.6, 0.25, 2.3), Rect2(16.65, -40.6, 0.25, 2.3),
	Rect2(14.3, -38.45, 0.85, 0.2), Rect2(16.1, -38.45, 0.8, 0.2), Rect2(14.9, -40.45, 1.4, 0.7)]
const PCStation := preload("res://scripts/world/pc_station.gd")
const BAXTER_SPOT := Vector3(11.2, G, -41.8)   ## where Baxter waits: the back of the lot, near the old hut
const POLICE_PATH := [Vector3(-4.4, G, 6.0), Vector3(-4.4, G, -16.8), Vector3(17.0, G, -16.8), Vector3(17.0, G, -34.0),
	Vector3(-6.0, G, -34.0), Vector3(-6.0, G, -16.8), Vector3(-4.4, G, -16.8), Vector3(-4.4, G, 6.0)]

var story
var world
var hud
var _tick := 0.0

# ------------------------------------------------------------------ tasks
## [id, text]. Each one is ticked off once, for good (kept in the save).
const TASKS := [
	["t_ids", "Inspect IDs and plates at the window (3 cars)"],
	["t_calls", "Take the call that adds someone to the list"],
	["t_doc", "Get the printed sheet with the web address and IP"],
	["t_lock", "Buy a pick lock at the Nite Stop (2 coins)"],
]
var _done := {}


func setup(p_story) -> void:
	story = p_story
	world = story.world
	hud = story.hud
	if SaveGame.story("dealer_note"):
		story.flags["dealer_note"] = true
	_build_shop()
	if Net.active():
		_build_hut()


func task_open(id: String) -> bool:
	return not _done.has(id) and not SaveGame.story("task_" + id)


func add_tasks() -> void:
	for t in TASKS:
		if task_open(t[0]):
			hud.add_objective(t[0], t[1])
	if Net.active() and task_open("t_hut"):
		hud.add_objective("t_hut", "Look round the old hut at the back of the lot")


func task_done(id: String) -> void:
	if not task_open(id) or story.guest:
		return
	_done[id] = true
	SaveGame.set_story("task_" + id)
	hud.complete_objective(id)


func _process(delta: float) -> void:
	_alarm_frame(delta)
	_smoke_frame(delta)
	_police_frame(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	# The hut: anyone walking up to it has had a look round.
	if hut and task_open("t_hut") and story.roam and story.roam.outside:
		var cam: Node3D = story.camera
		if Vector2(cam.global_position.x - HUT_POS.x, cam.global_position.z - HUT_POS.z).length() < 6.0:
			if story.guest:
				Net.request("hut_seen")
				_done["t_hut"] = true
			else:
				task_done("t_hut")
	if story.guest:
		return
	if task_open("t_ids"):
		var n := 0
		for r in story.results:
			if r.checked and r.get("plate_seen", false):
				n += 1
		if n >= 3:
			task_done("t_ids")
	if task_open("t_doc") and world.props.newsletter and world.props.newsletter.visible:
		task_done("t_doc")


# ------------------------------------------------------------------ the alarm car
var alarm_car: CarModel
var _alarm_t := 0.0
var _alarm_on := false
var _alarm_snd: AudioStreamPlayer3D
var _alarm_lights: Array = []    ## [OmniLight3D front, OmniLight3D rear, SpotLight3D x2]
var _alarm_glow: Array = []      ## [material, normal energy]
var _note: Node3D


## Host: a random parked car goes off. (Guests are told which one.)
func start_alarm() -> void:
	var cars: Array = world.lot.cars.filter(func(c): return c is CarModel)
	if cars.is_empty():
		return
	var i := randi() % cars.size()
	_alarm_go(i)
	Net.send("n3_alarm", [i])
	hud.add_objective("t_note", "Find out why that car alarm went off")
	await story._wait(75.0)
	if _alarm_on:   # nobody came: it gives up on its own (the note's still there)
		_alarm_stop()
		Net.send("n3_alarm_off")


func _alarm_go(i: int) -> void:
	alarm_car = world.lot.cars[i]
	_alarm_on = true
	_alarm_t = 0.0
	var ws := load("res://assets/audio/car_alarm.wav") as AudioStreamWAV
	ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ws.loop_begin = 0
	ws.loop_end = ws.data.size() / 2
	_alarm_snd = AudioStreamPlayer3D.new()
	_alarm_snd.stream = ws
	_alarm_snd.bus = "Outside"
	_alarm_snd.unit_size = 9.0
	_alarm_snd.volume_db = -4.0
	_alarm_snd.max_distance = 120.0
	alarm_car.add_child(_alarm_snd)
	_alarm_snd.play()
	# Lights: amber hazards at both ends, the headlamps strobing on the wet tarmac.
	for z in [alarm_car.S.f + 0.3, alarm_car.S.r - 0.3]:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.55, 0.12)
		o.omni_range = 6.0
		o.omni_attenuation = 1.4
		o.light_energy = 0.0
		o.position = Vector3(0, 0.7, z)
		alarm_car.add_child(o)
		_alarm_lights.append(o)
	for hp in alarm_car.head_points:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.95, 0.85)
		sp.spot_range = 20.0
		sp.spot_angle = 28.0
		sp.spot_attenuation = 0.8
		sp.light_energy = 0.0
		sp.position = hp
		sp.rotation_degrees = Vector3(-11, 180, 0)
		alarm_car.add_child(sp)
		_alarm_lights.append(sp)
	var spill := OmniLight3D.new()   # white light thrown back over the bonnet and the tarmac
	spill.light_color = Color(0.95, 0.95, 1.0)
	spill.omni_range = 5.0
	spill.light_energy = 0.0
	spill.position = Vector3(0, 0.9, alarm_car.S.f + 0.9)
	alarm_car.add_child(spill)
	_alarm_lights.append(spill)
	var rear := OmniLight3D.new()
	rear.light_color = Color(1.0, 0.1, 0.05)
	rear.omni_range = 3.5
	rear.light_energy = 0.0
	rear.position = alarm_car.rear_point + Vector3(0, 0, -0.3)
	alarm_car.add_child(rear)
	_alarm_lights.append(rear)
	_alarm_glow = [[alarm_car.amber_mat, alarm_car.amber_mat.emission_energy_multiplier],
		[alarm_car.head_mat, alarm_car.head_mat.emission_energy_multiplier],
		[alarm_car.tail_mat, alarm_car.tail_mat.emission_energy_multiplier]]
	# Something to click once you're out there.
	var it := Interactable.new()
	it.outdoor = true   # used from the car park
	it.name = "AlarmCheck"
	it.prompt = "Check the car (the alarm's going)"
	it.add_box(Vector3(alarm_car.S.w * 2.2, 1.5, (alarm_car.S.f - alarm_car.S.r) * 0.7), Vector3(0, 0.75, (alarm_car.S.f + alarm_car.S.r) * 0.5))
	alarm_car.add_child(it)
	it.activated.connect(_on_check_car)
	hud.notify("A car alarm is going off out in the lot.", 5.0)


## Flashing: hazards blink twice a second; the headlamps and tail lamps flash with the horn.
func _alarm_frame(delta: float) -> void:
	if not _alarm_on or alarm_car == null:
		return
	_alarm_t += delta
	var pos := fmod(_alarm_t, 3.92)
	var hazard := fmod(_alarm_t, 0.5) < 0.26
	var horn: bool
	var left := true
	var right := true
	if pos < 2.0:   # the wail: the headlamps wig-wag, left and right in turn
		horn = true
		left = fmod(pos, 0.3) < 0.15
		right = not left
	else:           # the honks: both lamps with every honk
		horn = fmod(pos - 2.0, 0.32) < 0.18
		left = horn
		right = horn
	(_alarm_lights[0] as Light3D).light_energy = 3.0 if hazard else 0.0
	(_alarm_lights[1] as Light3D).light_energy = 3.0 if hazard else 0.0
	var heads := _alarm_lights.size() - 4   # the headlamp spots sit between the hazards and the spill
	for k in heads:
		var on := left if k % 2 == 0 else right
		(_alarm_lights[2 + k] as Light3D).light_energy = 9.0 if on else 0.0
	(_alarm_lights[-2] as Light3D).light_energy = (1.4 if left and right else 0.8) if horn else 0.0
	(_alarm_lights[-1] as Light3D).light_energy = 1.6 if horn else 0.0
	(_alarm_glow[0][0] as StandardMaterial3D).emission_energy_multiplier = 6.0 if hazard else 0.1
	(_alarm_glow[1][0] as StandardMaterial3D).emission_energy_multiplier = 5.0 if (left or right) and horn else 0.0
	(_alarm_glow[2][0] as StandardMaterial3D).emission_energy_multiplier = 3.5 if horn else 0.4


func _alarm_stop() -> void:
	if not _alarm_on:
		return
	_alarm_on = false
	if is_instance_valid(_alarm_snd):
		_alarm_snd.queue_free()
	for l in _alarm_lights:
		if is_instance_valid(l):
			l.queue_free()
	_alarm_lights.clear()
	for g in _alarm_glow:
		(g[0] as StandardMaterial3D).emission_energy_multiplier = g[1]
	_drop_note()


func _on_check_car() -> void:
	if story.roam == null or not story.roam.outside:
		hud.notify("You'd have to go outside for that.", 3.0)
		return
	var it := alarm_car.get_node_or_null("AlarmCheck")
	if it:
		it.queue_free()
	if story.guest:
		Net.request("n3_check_car")
	else:
		_check_car()
	hud.say("", "(Nothing wrong with it. No broken glass, nobody about. Just a cheap alarm.)", 4.0)


func _check_car() -> void:
	_alarm_stop()
	Net.send("n3_alarm_off")
	hud.notify("There's a folded note on the ground by the driver's door.", 5.0)


## The note, on the wet tarmac by the driver's door (until someone picks it up).
func _drop_note() -> void:
	if _note or alarm_car == null or story.flags.get("dealer_note", false):
		return
	_note = Node3D.new()
	alarm_car.add_child(_note)
	_note.position = Vector3(-alarm_car.S.w - 0.45, 0.012, alarm_car.S.f * 0.2)
	_note.rotation_degrees.y = 23.0
	var paper := MK.emissive(Color(0.92, 0.9, 0.82), 0.25, Color(0.9, 0.88, 0.8))
	MK.box(_note, Vector3(0.15, 0.006, 0.1), Vector3.ZERO, paper)
	var it := Interactable.new()
	it.outdoor = true   # used from the car park
	it.prompt = "Pick up the note"
	it.add_box(Vector3(0.6, 0.4, 0.6), Vector3(0, 0.15, 0))
	_note.add_child(it)
	it.activated.connect(_read_note)


func _read_note() -> void:
	if story.inspect.is_open:
		return
	world.ambience.play_ui("click2", -14.0)
	story.inspect.show_print("A FOLDED NOTE", "[b]DEALER[/b]\n\nBAXTER. Medical Records.\n\nBack of the lot, by the fence, after 2.\nCash only. No names. Don't ring the ward.", "(Damp, written in biro. Somebody dropped it in a hurry.)")
	if story.guest:
		Net.request("n3_note")
	else:
		found_note()


## Host: the dealer note is found (by anyone).
func found_note() -> void:
	if story.flags.get("dealer_note", false):
		return
	story.flags["dealer_note"] = true
	SaveGame.set_story("dealer_note")
	story.notes += ("\n" if story.notes != "" else "") + "Note by the alarm car: 'DEALER - BAXTER, Medical Records. Back of the lot after 2.'"
	story.list_changed.emit()
	if is_instance_valid(_note):
		_note.queue_free()
	Net.send("n3_note_gone")
	hud.complete_objective("t_note")
	hud.tip("dealer_note", "Baxter's on tonight's list. If he turns up, you could bring the note up at the window.")


# ------------------------------------------------------------------ Baxter by the payphone
var baxter: Node3D
var _baxter_busy := false
var _baxter_sells := false


## Host: Baxter waits by the payphone. `deal` = he already knows you (later nights): straight to selling.
func baxter_outside(deal: bool, stay := 170.0) -> void:
	if is_instance_valid(baxter):
		return
	_spawn_baxter(deal)
	Net.send("n3_baxter", [deal])   # everyone sees him, and any guard can walk up and sell
	await story._wait(stay)
	while _baxter_busy:   # not while someone's mid-deal
		await story._wait(1.0)
	if is_instance_valid(baxter):
		baxter.queue_free()
		baxter = null
		Net.send("n3_baxter_gone")


## Everyone: Baxter by the payphone (just the figure; the host runs the talking).
func _spawn_baxter(deal: bool) -> void:
	if is_instance_valid(baxter):
		return
	var bd: Dictionary = NightThree.baxter(story.ARRIVALS)
	# A records clerk, not a porter: shabby mac over a cardigan, no cap, grey and unwell.
	baxter = PersonModel.build({"coat": "mid", "top": Color(0.42, 0.38, 0.3), "cardigan": Color(0.3, 0.26, 0.22),
		"trousers": Color(0.22, 0.22, 0.24), "shoes": Color(0.12, 0.09, 0.07), "skin": bd.get("skin", Color(0.86, 0.8, 0.72)),
		"hair": bd.get("hair", Color(0.45, 0.42, 0.4)), "hair_style": "short", "scarf": Color(0.35, 0.3, 0.32), "smoking": true}, "")
	baxter.name = "Baxter"
	world.add_child(baxter)
	baxter.global_position = BAXTER_SPOT   # the back of the lot, by the fence, in the dark
	baxter.rotation.y = 0.35               # facing out over the lot
	# The cigarette's in his hand (person_model's smoking arm): a glowing tip that flares when he
	# draws on it, a faint orange light so you can spot him from the booth, and smoke.
	var cig: Node3D = baxter.find_child("Cig", true, false)
	_ember_mat = MK.emissive(Color(1.0, 0.4, 0.1), 3.0)
	MK.box(cig, Vector3(0.016, 0.016, 0.014), Vector3(0, 0, 0.076), _ember_mat)
	_ember = OmniLight3D.new()
	_ember.light_color = Color(1.0, 0.45, 0.15)
	_ember.omni_range = 1.5
	_ember.light_energy = 0.3
	_ember.position = Vector3(0, 0, 0.1)
	cig.add_child(_ember)
	_wisp = _smoke(0.6, 6, 0.012)   # a thin wisp off the tip, all the time
	_wisp.position = Vector3(0, 0.01, 0.08)
	cig.add_child(_wisp)
	_puff = _smoke(1.0, 14, 0.035)   # the breath he blows out
	_puff.emitting = false
	_puff.one_shot = true
	_puff.explosiveness = 0.6
	_puff.position = Vector3(0, 1.6, 0.16)
	_puff.direction = Vector3(0.3, 0.4, 1.0)
	_puff.initial_velocity_min = 0.25
	_puff.initial_velocity_max = 0.45
	baxter.add_child(_puff)
	_smoke_t = 0.0
	_baxter_sells = deal
	var it := Interactable.new()
	it.outdoor = true   # used from the car park
	it.prompt = "Talk to Baxter"
	it.add_box(Vector3(0.8, 1.9, 0.8), Vector3(0, 0.95, 0))
	baxter.add_child(it)
	it.activated.connect(_on_baxter)
	it.key_used.connect(_baxter_id)
	it.prompt = "Talk to Baxter   (E: ask for his ID)"
	hud.notify("Someone's smoking in the dark at the back of the lot, by the fence. Baxter.", 6.0)


var _ember_mat: StandardMaterial3D
var _ember: OmniLight3D
var _wisp: CPUParticles3D
var _puff: CPUParticles3D
var _smoke_t := 0.0
const SMOKE_CYCLE := 7.0   ## seconds between drags on the cigarette


## Soft grey smoke that drifts up and fades.
func _smoke(life: float, amount: int, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life * 2.5
	var q := QuadMesh.new()
	q.size = Vector2(size, size) * 4.0
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.75, 0.75, 0.78, 0.35)
	q.material = m
	p.mesh = q
	p.direction = Vector3(0, 1, 0)
	p.spread = 18.0
	p.gravity = Vector3(0.05, 0.12, 0)
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.08
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.5))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	p.local_coords = false
	return p


## Baxter smokes: every few seconds he lifts it to his lips, the tip flares, he lowers it and
## blows the smoke out.
func _smoke_frame(delta: float) -> void:
	if not is_instance_valid(baxter) or _ember_mat == null:
		return
	_smoke_t += delta
	var c := fmod(_smoke_t, SMOKE_CYCLE)
	var t := 0.0
	if c < 0.7:
		t = c / 0.7                    # up to his mouth
	elif c < 2.0:
		t = 1.0                        # drawing on it
	elif c < 2.7:
		t = 1.0 - (c - 2.0) / 0.7      # down again
	PersonModel.pose_smoke(baxter, t)
	var draw := 1.0 if c >= 0.8 and c < 2.0 else 0.0
	var flicker := 0.85 + 0.15 * sin(_smoke_t * 23.0) * sin(_smoke_t * 7.0)
	_ember_mat.emission_energy_multiplier = lerpf(2.5, 9.0, draw) * flicker
	_ember.light_energy = lerpf(0.25, 0.8, draw) * flicker
	if c >= 2.8 and c - delta < 2.8:
		_puff.restart()                # blows it out


## E on Baxter: his ID card, the same check as at the window.
func _baxter_id() -> void:
	if story.roam == null or not story.roam.outside or not is_instance_valid(baxter) or story.inspect.is_open:
		return
	var bd: Dictionary = NightThree.baxter(story.ARRIVALS)
	hud.say("Baxter", "My ID? ...Fine. Here. Don't wave it about.", 2.5)
	story.inspect.show_id(bd, story.list_now, story.date_text, bd.reg, story.notes)
	await story.inspect.closed


func _on_baxter() -> void:
	if story.roam == null or not story.roam.outside or not is_instance_valid(baxter):
		return
	if story.guest:
		Net.request("n3_baxter_talk")
	else:
		baxter_talk(story.local_player_id)


## Host: guard `who` talks to Baxter (and maybe sells him things from the shared crate).
func baxter_talk(who: int) -> void:
	if _baxter_busy or not is_instance_valid(baxter):
		return
	_baxter_busy = true
	var me: bool = who == story.local_player_id
	if me:
		story.camera.blocked = true
	if _baxter_sells:
		await hud.say("Baxter", "You again. Go on. What've you got?", 3.0)
		await story.sell_from_crate("Baxter", who)
	else:
		var sellable := SaveGame.stash().filter(func(id): return not BootItems.is_story(id))
		await story.talk(NightThree.baxter_payphone(not sellable.is_empty()), who)
		if story.flags.get("baxter_sell", false) or story.flags.get("baxter_deal", false):
			SaveGame.set_story("baxter_deal")
		if story.flags.get("baxter_sell", false):
			await story.sell_from_crate("Baxter", who)
		_baxter_sells = SaveGame.story("baxter_deal")
	if me:
		story.camera.blocked = false
	_baxter_busy = false


# ------------------------------------------------------------------ the police walk-round
var police: Node3D
var _path: Array = []
var _police_wait := false
var _diverted := false
var _police_torch: SpotLight3D


## Everyone: an officer walks the lot with a torch, then leaves the way he came.
func police_walk() -> void:
	if is_instance_valid(police):
		return
	police = PersonModel.build({"coat": "long", "top": Color(0.06, 0.07, 0.12), "trousers": Color(0.06, 0.07, 0.1),
		"shoes": Color(0.03, 0.03, 0.03), "skin": Color(0.86, 0.7, 0.6), "hair": Color(0.2, 0.15, 0.1),
		"hair_style": "cap", "cap": Color(0.04, 0.05, 0.1), "vest": Color(0.75, 0.8, 0.2)}, "")
	police.name = "Police"
	world.add_child(police)
	_path = POLICE_PATH.duplicate()
	police.global_position = _path.pop_front()
	_police_torch = SpotLight3D.new()
	_police_torch.light_color = Color(1.0, 0.93, 0.78)
	_police_torch.spot_range = 14.0
	_police_torch.spot_angle = 18.0
	_police_torch.light_energy = 3.0
	_police_torch.shadow_enabled = false
	_police_torch.position = Vector3(0.28, 1.25, 0.25)
	_police_torch.rotation_degrees = Vector3(-18, 180, 0)
	police.add_child(_police_torch)
	# The torch itself, and reflective bands on his coat, so he shows up in the dark.
	MK.box(police, Vector3(0.06, 0.06, 0.2), Vector3(0.28, 1.22, 0.2), MK.mat(Color(0.1, 0.1, 0.1), "", 0.4))
	MK.box(police, Vector3(0.05, 0.05, 0.01), Vector3(0.28, 1.22, 0.305), MK.emissive(Color(1.0, 0.95, 0.8), 6.0))
	var band := MK.emissive(Color(0.85, 0.9, 0.85), 0.5, Color(0.7, 0.75, 0.7))
	for y in [0.95, 1.3]:
		MK.box(police, Vector3(0.5, 0.05, 0.32), Vector3(0, y, 0), band)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.95, 0.85)
	glow.omni_range = 2.2
	glow.light_energy = 0.35
	glow.position = Vector3(0.2, 1.3, 0.45)
	police.add_child(glow)
	var it := Interactable.new()
	it.outdoor = true   # used from the car park
	it.prompt = "Talk to the officer"
	it.add_box(Vector3(0.9, 1.9, 0.9), Vector3(0, 0.95, 0))
	police.add_child(it)
	it.activated.connect(_on_police)
	_diverted = false
	if not story.guest:
		Net.send("n3_police")
		hud.notify("A police officer is walking through the lot with a torch.", 5.0)
		hud.tip("police", "The police walk the lot now and then. You can go out and talk to them. Don't let them see anything they shouldn't.")


func _police_frame(delta: float) -> void:
	if not is_instance_valid(police) or _police_wait:
		return
	if _path.is_empty():
		if _diverted:
			return
		police.queue_free()
		police = null
		return
	var p := police.global_position
	var to: Vector3 = _path[0] - p
	to.y = 0.0
	if to.length() < 0.2:
		_path.pop_front()
		if _path.is_empty() and _diverted and not story.guest:
			_police_search()
		return
	var dir := to.normalized()
	police.global_position += dir * 1.2 * delta
	police.basis = police.basis.slerp(Basis.looking_at(-dir, Vector3.UP), minf(1.0, delta * 6.0))
	var phase := Time.get_ticks_msec() * 0.007
	var ll := police.get_node_or_null("LegL") as Node3D
	var lr := police.get_node_or_null("LegR") as Node3D
	if ll and lr:
		ll.rotation.x = sin(phase) * 0.45
		lr.rotation.x = -sin(phase) * 0.45
	# The torch sweeps from side to side.
	_police_torch.rotation_degrees.y = 180.0 + sin(phase * 0.23) * 25.0
	# Night four on: an open boot nearby brings him over to the hut.
	if not story.guest and not _diverted and story.night >= 4 and _open_boot_near(police.global_position, 6.0):
		_diverted = true
		Net.send("n3_police_divert")
		_divert()


func _divert() -> void:
	_diverted = true
	_path = [Vector3(police.global_position.x, G, -6.0), Vector3(0.9, G, -6.0), Vector3(3.0, G, 3.2), Vector3(0.9, G, 3.2)]
	if not story.guest:
		hud.notify("The officer's stopped by a car with its boot open. He's looking over at the hut.", 6.0)


func _open_boot_near(p: Vector3, r: float) -> bool:
	var cars: Array = world.lot.cars.duplicate()
	for c in story.net_cars.values():
		if is_instance_valid(c) and c._model:
			cars.append(c._model)
	for c in story._leavers:
		if is_instance_valid(c) and c._model:
			cars.append(c._model)
	for m in cars:
		if m is CarModel and is_instance_valid(m) and m.boot_open and m.global_position.distance_to(p) < r:
			return true
	return false


func _on_police() -> void:
	if story.roam == null or not story.roam.outside:
		return
	if story.guest:
		Net.request("n3_police_talk")
	else:
		police_talk(story.local_player_id)


## Host: someone walked up to the officer.
func police_talk(who: int) -> void:
	if _police_wait or not is_instance_valid(police):
		return
	_police_wait = true
	Net.send("n3_police_wait", [true])
	await story.talk(NightThree.police(), who)
	_police_wait = false
	Net.send("n3_police_wait", [false])


## Host: the officer looks inside the hut. A hidden crate and no download running is fine.
func _police_search() -> void:
	_police_wait = true
	world.ambience.play_at("door_open_close", world.booth.door.global_position, -6.0, "Interior", 3.0)
	await hud.say("Officer", "Somebody's had a boot open out there. Mind if I have a look in your hut?", 4.0)
	var hot := []
	for id in SaveGame.stash():   # hidden under the desk, only the big things still show
		if not BootItems.is_story(id) and (not world.booth.crate_hidden or BootItems.is_big(id)):
			hot.append(id)
	for id in story.carrying:
		if not BootItems.is_story(id):
			hot.append(id)
	var downloading: bool = story.hack != null and str(story.hack.state.downloading) != ""
	if hot.is_empty() and not downloading:
		await hud.say("Officer", "...Nothing here. Keep your eyes open. Night.", 3.0)
		_path = [Vector3(-4.4, G, 3.2), Vector3(-4.4, G, 6.0)]
		_diverted = false
		_police_wait = false
		Net.send("n3_police_leave")
		return
	if downloading:
		await hud.say("Officer", "What's that computer doing at this hour? ...Right. You're coming with me.", 4.0)
	else:
		await hud.say("Officer", "And what's all this? That's a %s off a car in this lot, isn't it? Right. You're coming with me." % story._bare(str(BootItems.info(hot[0])[0])), 4.5)
	story.lose_night("CAUGHT RED-HANDED", "The police found it in the hut. The night starts again.")


# ------------------------------------------------------------------ the Nite Stop
var _shop_it: Interactable


func _build_shop() -> void:
	_shop_it = Interactable.new()
	_shop_it.outdoor = true   # used from the car park
	_shop_it.name = "NiteStopCounter"
	_shop_it.prompt = "Nite Stop  (shop)"
	_shop_it.add_box(Vector3(1.0, 2.2, 2.0), Vector3(-0.5, 1.1, 0.0))
	world.lot.store.add_child(_shop_it)
	_shop_it.activated.connect(_on_shop)


const SCANNER_COST := 3
var _shopping := false


## The Nite Stop's counter: a pick lock, and the BootScan gadget (shows what a boot's things are worth).
func _on_shop() -> void:
	if story.roam == null or not story.roam.outside or _shopping:
		return
	var items := []
	if not SaveGame.has_upgrade("pick_lock"):
		items.append(["lock", "Pick lock  -  %d coins  (opens padlocks; it can snap)" % PICK_LOCK_COST])
	if not SaveGame.has_upgrade("boot_scanner"):
		items.append(["scanner", "BootScan  -  %d coins  (shows what things in a boot are worth)" % SCANNER_COST])
	if items.is_empty():
		hud.notify_local("\"That's all we've got, love. Come back when we've had a delivery.\"", 4.0)
		return
	_shopping = true
	story.camera.blocked = true
	var labels := []
	for it in items:
		labels.append(it[1])
	labels.append("Nothing, thanks")
	var pick: int = await hud.choose("NITE STOP", "\"Anything else?\"   (you've got %d coins)" % story.money, labels)
	story.camera.blocked = false
	_shopping = false
	if pick < 0 or pick >= items.size():
		return
	var what: String = items[pick][0]
	if story.guest:
		Net.request("n3_buy", [what])
	elif what == "lock":
		buy_lock()
	else:
		buy_scanner()


## Host: the BootScan (the team's, like everything bought).
func buy_scanner() -> void:
	if SaveGame.has_upgrade("boot_scanner"):
		return
	if story.money < SCANNER_COST:
		hud.notify("BootScan is %d coins. You haven't got enough." % SCANNER_COST, 4.0)
		return
	story.money -= SCANNER_COST
	story.spent_tonight += SCANNER_COST
	hud.set_money(story.money)
	SaveGame.add_upgrade("boot_scanner")
	story.send_upgrades()
	world.ambience.play_at("ding", world.lot.store.global_position, -8.0, "Outside", 4.0)
	hud.notify("You bought a BootScan (-%d). Boots you open from now on show what everything's worth." % SCANNER_COST, 5.5)


## Host: the pick lock (one is enough for the whole team).
func buy_lock() -> void:
	if SaveGame.has_upgrade("pick_lock"):
		return
	if story.money < PICK_LOCK_COST:
		hud.notify("A pick lock is %d coins. You haven't got enough." % PICK_LOCK_COST, 4.0)
		return
	story.money -= PICK_LOCK_COST
	story.spent_tonight += PICK_LOCK_COST
	hud.set_money(story.money)
	SaveGame.add_upgrade("pick_lock")
	SaveGame.set_story("pick_lock_night", story.night)
	world.ambience.play_at("ding", world.lot.store.global_position, -8.0, "Outside", 4.0)
	hud.notify("You bought a pick lock (-%d). Cheap thing. It might snap." % PICK_LOCK_COST, 5.0)
	_have_lock()
	Net.send("n3_lock")
	task_done("t_lock")


func _have_lock() -> void:
	_hut_prompt()


## The hut door says what you can do with it.
func _hut_prompt() -> void:
	if _hut_it == null:
		return
	_hut_it.prompt = "Pick the lock" if SaveGame.has_upgrade("pick_lock") else "Old hut door (padlocked)"


# ------------------------------------------------------------------ the second hut (co-op)
var hut: Node3D
var hut_pc: Node3D               ## pc_station.gd
var hut_pc_owner := 0            ## who's using the hut's PC (co-op: one at a time, like the booth's)
var _hut_lamp: OmniLight3D


func _hut_pc_use(on: bool) -> void:
	if story.guest:
		Net.request("n3_hutpc", [on])
	else:
		set_hut_pc_owner(story.local_player_id if on else 0, story.local_player_id)


## Host: whoever sat down at the hut's PC first has it until they sit back.
func set_hut_pc_owner(id: int, who: int) -> void:
	var before := hut_pc_owner
	if id == 0:
		if hut_pc_owner == who:
			hut_pc_owner = 0
	elif hut_pc_owner == 0:
		hut_pc_owner = id
	if hut_pc_owner != before:
		Net.send("n3_hutpc_owner", [hut_pc_owner])


## Testing (and the testing menu): the hut is unlocked straight away, with a pick lock in hand.
func debug_unlock_hut() -> void:
	if hut == null:
		_build_hut()
		Net.send("n3_hut_build")
	SaveGame.add_upgrade("pick_lock")
	_have_lock()
	if not SaveGame.story("hut_open"):
		SaveGame.set_story("hut_open")
		_open_hut(true)
		Net.send("n3_hut_open")
	hud.notify("TEST: the second hut is open (back right of the lot). Its PC works on its own.", 6.0)
var _hut_door: Node3D
var _hut_it: Interactable


func _build_hut() -> void:
	hut = Node3D.new()
	hut.name = "SecondHut"
	world.add_child(hut)
	hut.global_position = HUT_POS
	var wall := MK.mat(Color(0.24, 0.3, 0.24), "metal", 0.7, 1.5, 0.3)
	var roof := MK.mat(Color(0.2, 0.2, 0.2), "metal", 0.6, 1.5, 0.4)
	var wood := MK.mat(Color(0.32, 0.24, 0.16), "wood_desk", 0.85)
	# Shell (door in the front, +Z, facing the lot), with a gap for the door.
	MK.box_from(hut, Vector3(-1.2, 0, -1.1), Vector3(1.2, 2.3, -1.0), wall)
	MK.box_from(hut, Vector3(-1.2, 0, -1.1), Vector3(-1.1, 2.3, 1.1), wall)
	MK.box_from(hut, Vector3(1.1, 0, -1.1), Vector3(1.2, 2.3, 1.1), wall)
	MK.box_from(hut, Vector3(-1.2, 0, 1.0), Vector3(-0.4, 2.3, 1.1), wall)
	MK.box_from(hut, Vector3(0.45, 0, 1.0), Vector3(1.2, 2.3, 1.1), wall)
	MK.box_from(hut, Vector3(-0.4, 2.0, 1.0), Vector3(0.45, 2.3, 1.1), wall)
	MK.box(hut, Vector3(2.7, 0.08, 2.6), Vector3(0, 2.36, 0), roof, Vector3(-6, 0, 0))
	MK.box(hut, Vector3(2.2, 0.05, 2.0), Vector3(0, 0.02, 0), wood)
	# A dusty desk and the old PC: a second NightWin 95 machine that works on its own.
	MK.box(hut, Vector3(1.2, 0.05, 0.6), Vector3(0, 0.75, -0.65), wood)
	MK.box(hut, Vector3(0.05, 0.73, 0.55), Vector3(-0.55, 0.37, -0.65), wood)
	MK.box(hut, Vector3(0.05, 0.73, 0.55), Vector3(0.55, 0.37, -0.65), wood)
	hut_pc = PCStation.new()
	hut_pc.name = "HutPC"
	hut_pc.shared_web = world.props.desktop.web
	hut.add_child(hut_pc)
	hut_pc.position = Vector3(0, 0.775, -0.82)
	hut_pc.desktop.away_changed.connect(func(away: bool): _hut_pc_use(not away))
	hut_pc.desktop.state_changed.connect(func(on: bool):
		if not on:
			_hut_pc_use(false))
	_hut_lamp = OmniLight3D.new()
	_hut_lamp.light_color = Color(1.0, 0.85, 0.6)
	_hut_lamp.omni_range = 3.2
	_hut_lamp.light_energy = 0.0
	_hut_lamp.position = Vector3(0, 2.1, 0)
	hut.add_child(_hut_lamp)
	MK.box(hut, Vector3(0.08, 0.1, 0.08), Vector3(0, 2.22, 0), MK.emissive(Color(1.0, 0.85, 0.6), 1.5))
	story.pc_added.emit(hut_pc)
	# The door, hinged on its left, with a padlock.
	_hut_door = Node3D.new()
	hut.add_child(_hut_door)
	_hut_door.position = Vector3(-0.4, 0, 1.05)
	MK.box(_hut_door, Vector3(0.85, 2.0, 0.05), Vector3(0.425, 1.0, 0), MK.mat(Color(0.3, 0.36, 0.3), "metal", 0.7, 1.0, 0.3))
	MK.box(_hut_door, Vector3(0.07, 0.1, 0.04), Vector3(0.78, 1.05, 0.05), MK.mat(Color(0.7, 0.62, 0.3), "metal", 0.3, 1.0, 0.8))
	_hut_it = Interactable.new()
	_hut_it.outdoor = true   # used from the car park
	_hut_it.prompt = "Old hut door (locked)"
	_hut_it.add_box(Vector3(1.0, 2.1, 0.5), Vector3(0.45, 1.0, 0.1))
	hut.add_child(_hut_it)
	_hut_it.position = Vector3(-0.45, 0, 1.0)
	_hut_it.activated.connect(_on_hut_door)
	_hut_prompt()
	if story.roam:
		story.roam.extra_blockers.append(HUT_BLOCK)
	if story.share:
		story.share.add_pc(hut_pc, func(): return hut_pc_owner)
	if SaveGame.story("hut_open"):
		_open_hut(false)


func _on_hut_door() -> void:
	if story.roam == null or not story.roam.outside:
		return
	if story.guest:
		Net.request("n3_hut_door")
	else:
		hut_door(story.local_player_id)


## Host: someone tries the hut door.
func hut_door(who: int) -> void:
	if SaveGame.story("hut_open"):
		return
	if not SaveGame.has_upgrade("pick_lock"):
		story._tell(who, "Padlocked. You'd need a pick lock (the Nite Stop has them, %d coins)." % PICK_LOCK_COST, 4.5)
		return
	if int(SaveGame.story("pick_lock_night", 0)) >= story.night:
		story._tell(who, "You've got the pick lock, but not tonight: too many eyes about. Come back tomorrow night.", 5.0)
		return
	hud.say("", "(Working the pick lock...)", 2.5)
	await story._wait(2.5)
	if randf() < PICK_BREAK_CHANCE:
		SaveGame.remove_upgrade("pick_lock")
		_shop_it.enabled = true
		_hut_prompt()
		Net.send("n3_lock_broke")
		hud.notify("Snap. The pick lock broke in the padlock. Another one's %d coins at the Nite Stop." % PICK_LOCK_COST, 6.0)
		return
	SaveGame.set_story("hut_open")
	_open_hut(true)
	Net.send("n3_hut_open")
	hud.notify("You're in. One dusty desk and an old PC. No power, no phone line. Yet.", 6.0)


func _open_hut(animate: bool) -> void:
	_hut_it.enabled = false
	_hut_lamp.light_energy = 0.8
	if story.roam:   # walk in: only the walls and the desk are in the way now
		story.roam.extra_blockers.erase(HUT_BLOCK)
		for r in HUT_WALLS:
			if not story.roam.extra_blockers.has(r):
				story.roam.extra_blockers.append(r)
	if animate:
		create_tween().tween_property(_hut_door, "rotation_degrees:y", -100.0, 1.2).set_trans(Tween.TRANS_SINE)
	else:
		_hut_door.rotation_degrees.y = -100.0


# ------------------------------------------------------------------ co-op
## On a guest: what the host sent. Returns true if it was one of these.
func guest_event(what: String, a: Array) -> bool:
	match what:
		"n3_alarm":
			_alarm_go(int(a[0]))
		"n3_alarm_off":
			_alarm_stop()
		"n3_note_gone":
			story.flags["dealer_note"] = true
			if is_instance_valid(_note):
				_note.queue_free()
		"n3_police":
			police_walk()
		"n3_police_wait":
			_police_wait = bool(a[0])
		"n3_police_divert":
			if is_instance_valid(police):
				_divert()
		"n3_police_leave":
			_path = [Vector3(-4.4, G, 3.2), Vector3(-4.4, G, 6.0)]
			_diverted = false
			_police_wait = false
		"n3_lock":
			SaveGame.add_upgrade("pick_lock")
			_have_lock()
		"n3_lock_broke":
			SaveGame.remove_upgrade("pick_lock")
			_shop_it.enabled = true
			_hut_prompt()
		"n3_hut_build":
			if hut == null:
				_build_hut()
		"n3_hut_open":
			if hut:
				_open_hut(true)
		"n3_hutpc_owner":
			hut_pc_owner = int(a[0])
			if hut_pc_owner != 0 and hut_pc_owner != story.local_player_id and story.camera.focus == hut_pc.crt_interact:
				story.camera.unzoom()
				hud.notify_local("%s is using the old PC." % Net.label(hut_pc_owner), 4.0)
		"n3_baxter":
			_spawn_baxter(bool(a[0]))
		"n3_baxter_gone":
			if is_instance_valid(baxter):
				baxter.queue_free()
			baxter = null
		_:
			return false
	return true


## On the host: what a guest asked for. Returns true if it was one of these.
func remote_action(from: int, what: String, _args: Array) -> bool:
	match what:
		"n3_check_car":
			_check_car()
		"n3_note":
			found_note()
		"n3_police_talk":
			police_talk(from)
		"n3_buy_lock":
			buy_lock()
		"n3_buy":
			if str(_args[0]) == "lock":
				buy_lock()
			else:
				buy_scanner()
		"n3_hut_door":
			hut_door(from)
		"hut_seen":
			task_done("t_hut")
		"n3_baxter_talk":
			baxter_talk(from)
		"n3_hutpc":
			set_hut_pc_owner(from if bool(_args[0]) else 0, from)
		"n3_sale_picks":
			story.sale_reply.emit(_args[0] if _args.size() > 0 else [])
		_:
			return false
	return true
