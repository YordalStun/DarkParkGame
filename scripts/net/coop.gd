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
## Everyone: there is ONE desk chair (P1 starts in it); the others start on their feet at a spot in the
## booth and can use everything standing. From night three anyone can walk out into the car park
## (scripts/player/roam.gd). Each guard is drawn where they are for the others, in their colour.

const PlayerModel := preload("res://scripts/world/player_model.gd")
const POSE_RATE := 15.0      ## head positions sent per second
const SYNC_RATE := 1.0       ## clock / weather / car corrections per second (host)
const READY_TIMEOUT := 60.0  ## host: how long to wait for everyone to finish loading

## Where each guard starts the night (x, z on the booth floor). P1 is in the desk chair.
const SPOTS := [
	Vector2(0.0, 0.32),    # P1: the desk chair (DeskCamera.SEAT_POS)
	Vector2(-0.55, 0.55),  # P2: behind-left of the chair, by the side window
	Vector2(0.55, 0.8),    # P3: behind-right
	Vector2(-0.1, 1.15),   # P4: by the door
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
	# Only one chair: the host sits in it, everyone else starts on their feet at their spot.
	if not Net.is_host():
		var g := Net.guard_of(Net.my_id())
		camera.start_standing(SPOTS[g % SPOTS.size()], 0.0)
		if story.roam:
			story.roam.in_chair = false
			story.roam._refresh()
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
		Net.send_pose(camera.global_transform, _my_state())
	if Net.is_host():
		_sync_t += delta
		if _sync_t >= 1.0 / SYNC_RATE:
			_sync_t = 0.0
			_send_sync()
	_update_guards(delta)


## 0 = in the chair, 1 = on their feet in the booth, 2 = out in the car park.
func _my_state() -> int:
	var r = story.roam
	if r == null:
		return 0
	if r.outside:
		return 2
	return 0 if r.in_chair else 1


# ------------------------------------------------------------------ the other guards
func _add_guard(id: int) -> void:
	if _guards.has(id):
		return
	var g := Net.guard_of(id)
	var model := PlayerModel.build(g, true)
	model.name = "Guard_%d" % id
	var tag := PlayerModel.name_tag(g)
	tag.name = "Tag"
	model.add_child(tag)
	world.add_child(model)
	var spot: Vector2 = SPOTS[g % SPOTS.size()]
	var seated := g == 0
	var xf := Transform3D(Basis(), Vector3(spot.x, 1.2 if seated else 1.5, spot.y))
	_guards[id] = {"node": model, "xf": xf, "state": 0 if seated else 1, "t": 0.0, "last": Vector3.ZERO}
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
	var was: int = _guards[from].state
	_guards[from].xf = xf
	_guards[from].state = state
	# Going in or out of the booth: the door swings for everyone.
	if (was == 2) != (state == 2) and story.roam:
		story.roam.swing_door()
		world.ambience.play_at("door_open_close", world.booth.door.global_position + Vector3(-0.4, 1.0, 0), -6.0, "Interior", 3.0)


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
	var feet := Vector3(eye.x, -0.42 if seated else (-0.15 if g.state == 2 else 0.0), eye.z)
	# Behind the eyes a little (the eyes are at the front of the head).
	var fwd := -xf.basis.z
	fwd.y = 0.0
	if fwd.length() > 0.01:
		fwd = fwd.normalized()
		feet -= fwd * 0.08
		var yaw := atan2(fwd.x, fwd.z)
		n.rotation.y = lerp_angle(n.rotation.y, yaw, k)
	n.position = n.position.lerp(feet, k) if n.position != Vector3.ZERO else feet
	PlayerModel.set_torch(n, g.state == 2)
	if seated:
		for leg in ["LegL", "LegR"]:
			var lg := n.get_node_or_null(leg) as Node3D
			if lg:
				lg.rotation.x = -1.4
	else:
		# Walking: swing the legs while they're moving.
		var moved: float = Vector2(feet.x - g.last.x, feet.z - g.last.z).length()
		g.last = feet
		g.t += get_process_delta_time()
		var model_y := n.position.y
		PlayerModel.walk(n, g.t, moved > 0.004)
		n.position.y = model_y
	# Never draw a guard inside your own head.
	var me: Vector3 = camera.global_position
	var dist := Vector2(n.global_position.x - me.x, n.global_position.z - me.z).length()
	n.visible = dist > 0.35
	# The floating "P2" tag is for spotting someone across the car park; up close it's in the way.
	var tag := n.get_node_or_null("Tag") as Node3D
	if tag:
		tag.visible = dist > 4.0


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
