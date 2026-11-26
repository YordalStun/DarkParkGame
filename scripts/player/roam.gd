extends Node
## Leaving the hut (night three on): get up from your spot, walk round the booth, go out of the door into
## the car park and come back. Works the same solo and in co-op (each guard roams on their own machine,
## and the others see them walk: scripts/net/coop.gd).
##
##   G (or the GET UP button)  get up / sit back down (inside the booth)
##   WASD + mouse              walk and look
##   E (or click) on the door  go outside / come back in
##   right click               sit back down (inside)
##
## Outside, the car park's edges are the fence at the far end, the tree line on the left, the shop on the
## right and the end of the access road behind the booth: you can't walk out of the lot. Parked and moving
## cars, the booth, the lamp island, the payphone and the bin are in the way.
##
## ONE CHAIR: only one guard sits at the desk at a time (story.chair_owner; the host decides who). The
## others stand, and standing you can still use everything: the phone, the side window (click it),
## the barrier buttons, the logbook, and the PC (one at a time). Leaning out of the PC or the window puts
## you back on your feet where you were.
##
## At 07:00 clocking out works as before: come back in, shut the PC down, sign the logbook, then the
## story takes over the door (`enabled = false`) for the light-off-and-leave ending.

signal outside_changed(outside: bool)

const FROM_NIGHT := 3              ## the first night you can leave the hut
const OUT_SPEED := 2.4             ## walking speed in the car park (m/s); inside it's the booth's 1.35
## The lot you can walk in (x, z): fence at the back (z -44.6), trees on the left, the shop on the right.
const LOT := Rect2(-14.5, -43.6, 33.3, 49.1)
const BODY_R := 0.3
## Things in the way outside (x, z rectangles).
const LOT_BLOCKERS := [
	Rect2(-1.95, -1.2, 3.9, 2.95),     # the booth
	Rect2(-12.6, -18.2, 2.8, 5.2),     # the lamp island (and its oak)
	Rect2(3.5, -2.75, 0.8, 0.7),       # payphone
	Rect2(2.45, -2.2, 0.6, 0.6),       # bin
	Rect2(-10.4, -4.0, 0.4, 0.4),      # LOT C sign
	Rect2(-2.95, -2.9, 0.6, 0.6),      # entry barrier post
	Rect2(-8.8, -3.05, 0.6, 0.6),      # exit barrier post
	Rect2(11.3, -1.7, 1.4, 1.4),       # bush
]
const CAR_HALF := Vector2(1.0, 2.45)   ## a car's footprint (half width, half length)
## Either side of the back door: where you stand after coming in, and after going out.
const DOOR_IN := Vector3(0.9, 1.5, 1.12)
const DOOR_OUT := Vector3(0.9, 1.35, 2.35)   ## the car park is 15 cm below the booth floor
const LOT_FLOOR := -0.15

var story
var world
var hud
var camera
var outside := false
var enabled := true       ## false once the story's clock-out ending owns the door
var _busy := false        ## going through the door / getting up / sitting down
var in_chair := false     ## this guard is sitting in the desk chair
var _want_chair := false  ## co-op guest: asked the host for the chair, waiting for the answer
var _torch: SpotLight3D
var _in_bounds: Rect2
var _in_blockers: Array


func setup(p_story) -> void:
	story = p_story
	world = story.world
	hud = story.hud
	camera = world.camera
	_in_bounds = camera.walk_bounds
	_in_blockers = camera.walk_blockers
	camera.back_fn = func() -> bool:
		if enabled and not outside and not _busy:
			sit_down()
			return true
		return false
	var door: Interactable = world.booth.door_interact
	door.outdoor = true
	door.activated.connect(_on_door)
	door.key_used.connect(_on_door)
	camera.zoom_changed.connect(func(_z): _refresh())
	# A torch for the dark: on whenever you're outside.
	_torch = SpotLight3D.new()
	_torch.name = "Torch"
	_torch.light_color = Color(1.0, 0.95, 0.82)
	_torch.light_energy = 3.0
	_torch.spot_range = 16.0
	_torch.spot_angle = 24.0
	_torch.spot_attenuation = 0.8
	_torch.shadow_enabled = false
	_torch.position = Vector3(0.18, -0.25, 0)
	_torch.visible = false
	camera.add_child(_torch)
	hud.roam_pressed.connect(toggle)
	in_chair = camera.state == camera.State.SEATED
	_refresh()


func standing() -> bool:
	return camera.state == camera.State.WALK


## G / the button: get up, or sit back down.
func toggle() -> void:
	if not enabled or _busy or camera.blocked:
		return
	if camera.state == camera.State.SEATED:
		get_up()
	elif standing() and not outside:
		sit_down()
	elif camera.state == camera.State.ZOOMED and not in_chair:
		hud.notify_local("Lean back out first (right click).", 2.5)
	elif outside:
		hud.notify_local("Go back inside to sit down (the door at the back of the booth).", 3.5)


func get_up() -> void:
	if not enabled or _busy or camera.state != camera.State.SEATED:
		return
	_busy = true
	hud.set_look_left(false)
	hud.set_look_back(false)
	var spot: Vector3 = camera.seat_pos
	var at := Vector2(0.42, 0.42) if spot.y < 1.4 else Vector2(spot.x, spot.z)   # P1 gets up beside the chair
	world.ambience.play_at("window_slide", world.booth.chair.global_position + Vector3(0, 0.3, 0), -18.0)
	world.booth.push_chair_back()
	in_chair = false
	story.chair_use(false)
	await camera.stand_up(at)
	_busy = false
	_refresh()
	if not SaveGame.tip_seen("roam"):
		hud.tip("roam", "You're up. WASD to walk, mouse to look. The door at the back takes you outside (E). G or right click sits you back down.")
	else:
		hud.notify_local("WASD to walk. E on the door to go out. G to sit back down.", 4.0)


func sit_down() -> void:
	if _busy or not standing() or outside or _want_chair:
		return
	if Net.is_guest():
		_want_chair = true   # the host says whether the chair is free (chair_answer)
		story.chair_use(true)
		return
	if not story.chair_use(true):
		hud.notify_local("%s is in the chair." % Net.label(story.chair_owner), 3.0)
		return
	await _sit()


## Co-op guest: the host answered (the chair's owner is now `owner_id`).
func chair_answer(owner_id: int) -> void:
	if not _want_chair:
		return
	_want_chair = false
	if owner_id == story.local_player_id:
		await _sit()
	else:
		hud.notify_local("%s is in the chair." % Net.label(owner_id), 3.0)


func _sit() -> void:
	_busy = true
	in_chair = true
	world.booth.pull_chair_in()
	await camera.sit_down()
	_busy = false
	hud.set_look_left(true)
	_refresh()


func _on_door() -> void:
	if not enabled or _busy or not standing():
		return
	_busy = true
	var booth = world.booth
	world.ambience.play_at("door_open_close", booth.door.global_position + Vector3(-0.4, 1.0, 0), -2.0, "Interior", 3.0)
	swing_door()
	await get_tree().create_timer(0.35).timeout
	if not outside:
		await camera.walk_to(DOOR_OUT, PI, 0.9)
		_set_outside(true)
	else:
		await camera.walk_to(DOOR_IN, 0.0, 0.9)
		_set_outside(false)
	_busy = false
	_refresh()


## The door swings open and shut (also when another guard goes through it).
func swing_door() -> void:
	var door: Node3D = world.booth.door
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(door, "rotation:y", deg_to_rad(80.0), 0.5)
	tw.tween_interval(0.9)
	tw.tween_property(door, "rotation:y", 0.0, 0.45).set_ease(Tween.EASE_IN)


func _set_outside(o: bool) -> void:
	outside = o
	camera.outside = o
	camera.walk_speed = OUT_SPEED if o else camera.WALK_SPEED
	camera.floor_y = LOT_FLOOR if o else 0.0
	camera.free_fn = _lot_free if o else Callable()
	_torch.visible = o
	world.ambience.outdoors = 1.0 if o else 0.0
	world.weather_fx.follow = camera if o else null
	outside_changed.emit(o)


## Clock-out ending: the story needs you inside and owns the door from here.
func finish() -> void:
	enabled = false
	_refresh()


func _refresh() -> void:
	hud.set_crosshair(standing())
	if not enabled:
		hud.set_roam_button("")
	elif camera.state == camera.State.SEATED:
		hud.set_roam_button("GET UP  [G]")
	elif standing() and not outside:
		hud.set_roam_button("SIT DOWN  [G]")
	else:
		hud.set_roam_button("")
	var door: Interactable = world.booth.door_interact
	if enabled:
		door.enabled = standing()
		door.prompt = "Go back inside  [E]" if outside else "Go outside  [E]"


func _process(_delta: float) -> void:
	if outside and standing():
		_push_out_of_cars()


# ------------------------------------------------------------------ outside
func _lot_free(p: Vector2) -> bool:
	if not LOT.grow(-BODY_R).has_point(p):
		return false
	for r in LOT_BLOCKERS:
		if (r as Rect2).grow(BODY_R).has_point(p):
			return false
	for c in _cars():
		if _in_car(c, p, BODY_R):
			return false
	return true


func _cars() -> Array:
	var out: Array = world.lot.cars.duplicate()
	for c in story._leavers:
		if is_instance_valid(c):
			out.append(c)
	for nm in story.net_cars:
		var c = story.net_cars[nm]
		if is_instance_valid(c) and c.state != "gone":
			out.append(c)
	if story.current != null and is_instance_valid(story.current) and not out.has(story.current):
		out.append(story.current)
	return out


func _in_car(c: Node3D, p: Vector2, grow: float) -> bool:
	var local: Vector3 = c.global_transform.affine_inverse() * Vector3(p.x, c.global_position.y, p.y)
	return absf(local.x) < CAR_HALF.x + grow and absf(local.z) < CAR_HALF.y + grow


## A car drove into you: step out of its way (to the nearer side).
func _push_out_of_cars() -> void:
	var p := Vector2(camera.position.x, camera.position.z)
	for c in _cars():
		if not _in_car(c, p, BODY_R * 0.5):
			continue
		var local: Vector3 = c.global_transform.affine_inverse() * Vector3(p.x, c.global_position.y, p.y)
		var side := signf(local.x) if local.x != 0.0 else 1.0
		local.x = side * (CAR_HALF.x + BODY_R + 0.05)
		var w: Vector3 = c.global_transform * local
		camera.position.x = w.x
		camera.position.z = w.z
