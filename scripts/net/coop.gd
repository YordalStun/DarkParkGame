extends Node
## Co-op during a night (see docs/design/coop-notes.md). Main adds this when a co-op game is running.
##
## HOST: the story runs as normal. This node passes on what happens (HUD lines, objectives, the clock,
## the weather, cars, the gate, the window, the phone...) to everyone else, and hands what the other
## players DO (Net.request_in) to the story's entry points with that player's id.
##
## CLIENT (a guest): the story does not run its own night. This node shows what the host sends and
## turns the player's clicks into requests to the host.
##
## Everyone: each guard has a spot in the booth (P1 in the desk chair, the others standing around it)
## and is drawn where they are for the others, in their colour (PlayerModel).

const PlayerModel := preload("res://scripts/world/player_model.gd")
const POSE_RATE := 15.0      ## head positions sent per second
const SYNC_RATE := 1.0       ## clock / weather / car corrections per second (host)
const READY_TIMEOUT := 60.0  ## host: how long to wait for everyone to finish loading

## Where each guard stands in the booth (camera position, eyes). P1 is in the desk chair.
const SPOTS := [
	Vector3(0.0, 1.2, 0.32),     # P1: the desk chair (DeskCamera.SEAT_POS)
	Vector3(-0.78, 1.55, 0.62),  # P2: standing behind-left of the chair, by the side window
	Vector3(0.72, 1.55, 0.58),   # P3: standing behind-right
	Vector3(0.3, 1.55, 1.12),    # P4: by the door
]

var world
var hud
var story
var inspect
var camera
var _guards := {}            ## id -> {"node", "xf", "state", "t"}
var _pose_t := 0.0
var _sync_t := 0.0
var _tick_t := 0.0


func setup(p_world, p_hud, p_story, p_inspect) -> void:
	world = p_world
	hud = p_hud
	story = p_story
	inspect = p_inspect
	camera = world.camera
	Net.pose_in.connect(_on_pose)
	Net.player_left.connect(_on_player_left)
	Net.disconnected.connect(_on_disconnected)
	if Net.is_host():
		Net.request_in.connect(_on_request)
		hud.relay = _relay_hud
		Weather.lightning_struck.connect(_on_lightning)
	else:
		Net.event.connect(_on_event)
	# My spot in the booth.
	var g := Net.guard_of(Net.my_id())
	camera.seat_pos = SPOTS[g % SPOTS.size()]
	camera.position = camera.seat_pos
	for id in Net.ids():
		if id != Net.my_id():
			_add_guard(id)


## Host: wait until every guard has loaded the night (or give up after a minute).
func wait_for_everyone() -> void:
	var left := READY_TIMEOUT
	while left > 0.0:
		var all := true
		for id in Net.ids():
			if not Net.ready_ids.has(id):
				all = false
		if all:
			return
		await get_tree().process_frame
		left -= get_process_delta_time()


func _process(delta: float) -> void:
	if not Net.active():
		return
	_pose_t += delta
	if _pose_t >= 1.0 / POSE_RATE:
		_pose_t = 0.0
		Net.send_pose(camera.global_transform, 1 if camera.state == camera.State.WALK or camera.seat_pos.y > 1.4 else 0)
	if Net.is_host():
		_sync_t += delta
		if _sync_t >= 1.0 / SYNC_RATE:
			_sync_t = 0.0
			_send_sync()
	_update_guards(delta)


# ------------------------------------------------------------------ the other guards
func _add_guard(id: int) -> void:
	if _guards.has(id):
		return
	var g := Net.guard_of(id)
	var model := PlayerModel.build(g, false)
	model.name = "Guard_%d" % id
	model.add_child(PlayerModel.name_tag(g))
	world.add_child(model)
	var spot: Vector3 = SPOTS[g % SPOTS.size()]
	var xf := Transform3D(Basis(), spot)
	_guards[id] = {"node": model, "xf": xf, "state": 1 if spot.y > 1.4 else 0, "t": 0.0}
	_place_guard(_guards[id], 1.0)


func _remove_guard(id: int) -> void:
	if _guards.has(id):
		var n: Node3D = _guards[id].node
		if is_instance_valid(n):
			n.queue_free()
		_guards.erase(id)


func _on_pose(from: int, xf: Transform3D, state: int) -> void:
	if not _guards.has(from):
		if not Net.players.has(from):
			return
		_add_guard(from)
	_guards[from].xf = xf
	_guards[from].state = state


func _update_guards(delta: float) -> void:
	var k := 1.0 - exp(-delta * 12.0)
	for id in _guards:
		_place_guard(_guards[id], k)


## Feet under the eyes, facing where they look. Seated guards fold their legs.
func _place_guard(g: Dictionary, k: float) -> void:
	var n: Node3D = g.node
	if not is_instance_valid(n):
		return
	var xf: Transform3D = g.xf
	var eye := xf.origin
	var seated: bool = g.state == 0
	var feet := Vector3(eye.x, 0.0 if not seated else -0.42, eye.z)
	# Behind the eyes a little (the eyes are at the front of the head).
	var fwd := -xf.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.01:
		fwd = fwd.normalized()
		feet -= fwd * 0.08
		var yaw := atan2(fwd.x, fwd.z)
		n.rotation.y = lerp_angle(n.rotation.y, yaw, k)
	n.position = n.position.lerp(feet, k) if n.position != Vector3.ZERO else feet
	var legs := -1.4 if seated else 0.0
	for leg in ["LegL", "LegR"]:
		var lg := n.get_node_or_null(leg) as Node3D
		if lg:
			lg.rotation.x = legs
	# Never draw a guard inside your own head.
	var me: Vector3 = camera.global_position
	n.visible = Vector2(n.global_position.x - me.x, n.global_position.z - me.z).length() > 0.35


func _on_player_left(id: int) -> void:
	_remove_guard(id)
	if Net.is_host():
		story.player_gone(id)
	hud.notify("%s has left the shift." % _name_of(id), 4.0)


func _name_of(id: int) -> String:
	return "Guard %d" % (Net.guard_of(id) + 1) if Net.players.has(id) else "A guard"


func _on_disconnected(why: String) -> void:
	# Back to the title screen (it shows `why`).
	story.leave_to_title(why)


# ------------------------------------------------------------------ host -> clients
func _relay_hud(fn: String, args: Array) -> void:
	Net.send("hud", [fn, args])


func _on_lightning(strength: float, distance: float) -> void:
	Net.send("lightning", [strength, distance])


func _send_sync() -> void:
	var cars: Array = []
	for nm in story.net_cars:
		var c = story.net_cars[nm]
		if is_instance_valid(c):
			cars.append([nm, c.state, c._dist])
	Net.send("sync", [NightClock._minutes, Weather.profile, Weather._rain_target, Weather._wind_target, Weather._fog_target,
		Weather.heavy, story.risk, story.money, cars, story.pc_owner()])


func _on_request(from: int, name: String, args: Array) -> void:
	match name:
		"ready":
			story.send_state_to(from)
		_:
			story.remote_action(from, name, args)


# ------------------------------------------------------------------ clients: what the host sends
func _on_event(name: String, args: Array) -> void:
	match name:
		"hud":
			hud.relay_in(str(args[0]), args[1])
		"lightning":
			Weather.strike_lightning(float(args[0]), float(args[1]))
		"sync":
			_apply_sync(args)
		_:
			story.guest_event(name, args)


func _apply_sync(a: Array) -> void:
	var minutes := float(a[0])
	if absf(NightClock._minutes - minutes) > 0.4:
		NightClock._minutes = minutes
	if not NightClock.shift_over and minutes >= NightClock.SHIFT_END and minutes < 12.0 * 60.0:
		NightClock._minutes = NightClock.SHIFT_END - 0.01   # let the local clock reach 07:00 itself
	Weather.profile = str(a[1])
	Weather.force(float(a[2]), float(a[3]), float(a[4]), 6.0)
	Weather.heavy = bool(a[5])
	story.risk = int(a[6])
	if int(a[7]) != story.money:
		story.money = int(a[7])
	story.guest_cars(a[8])
	story.guest_pc_owner(int(a[9]))
