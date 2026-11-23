extends Camera3D
## The player's eyes, seated at the desk. Fully mouse driven:
##  * moving the cursor toward a screen edge turns the head that way (subtle),
##  * pointing at an Interactable shows its name, left click uses it,
##  * clicking the CRT leans in to the screen; right click (or Esc) sits back.

signal hover_changed(prompt: String)
signal zoom_changed(zoomed: bool)
signal focus_changed(focus: Interactable)  ## zoomed in to something (null = sat back)

enum State { SEATED, MOVING, ZOOMED, WALK }

## Standing up and walking (end of the shift only): first-person mouse look and WASD inside the booth.
const EYE := 1.5
const WALK_SPEED := 1.35
var walk_speed := WALK_SPEED   ## faster out in the car park
const BODY_R := 0.24
var walk_blockers: Array = []    ## Rect2 in x/z the player can't walk into (furniture)
var walk_bounds := Rect2(-1.6, -0.25, 3.2, 1.62)   ## x, z of the walkable floor
var _wyaw := PI
var _wpitch := 0.0
var _bob := 0.0
var _step_acc := 0.0
signal footstep
## Out in the car park (night three on): only `outdoor` things can be used, and `free_fn` (if set)
## decides where you can walk instead of walk_bounds / walk_blockers.
var outside := false
var free_fn := Callable()
var back_fn := Callable()        ## standing: right click / Esc asks this first (e.g. sit back down)
var auto_walk := Vector2.ZERO    ## testing: walk as if these keys were held (x right, y back)
var floor_y := 0.0               ## the ground under you (the booth floor is 0, the car park -0.15)

const SEAT_POS := Vector3(0.0, 1.2, 0.32)
var seat_pos := SEAT_POS      ## where this player's eyes rest (co-op: P2-P4 stand at other spots in the booth)
## Co-op: asked before leaning in to something (the PC is one player's at a time). Returns true to allow.
var zoom_guard := Callable()
const BASE_PITCH := -5.0      # degrees, looking slightly down at the desk
const YAW_RANGE := 34.0       # degrees each side
const PITCH_UP := 18.0
const PITCH_DOWN := 20.0
const SEATED_FOV := 64.0

var state := State.SEATED
var pointer := Vector2.ZERO   ## -1..1 cursor position across the window
var hovered: Interactable
var focus: Interactable       ## what we are zoomed into

var _yaw := 0.0
var _pitch := BASE_PITCH
var _zyaw := 0.0
var _zpitch := 0.0
var _t := 0.0


func _ready() -> void:
	fov = SEATED_FOV
	near = 0.03
	far = 400.0
	current = true
	position = seat_pos
	rotation_degrees = Vector3(BASE_PITCH, 0, 0)


## Called by Main with the cursor position in -1..1 (x right, y down).
func set_pointer(p: Vector2) -> void:
	pointer = p


func _process(delta: float) -> void:
	_t += delta
	if blocked:
		return   # an overlay is up (ID card, plate, report): hold the view still
	if state == State.SEATED:
		_update_seated(delta)
	elif state == State.ZOOMED:
		_update_zoomed(delta)
	elif state == State.WALK:
		_update_walk(delta)


func _shape(v: float) -> float:
	# Dead zone in the middle; turn more as the cursor nears the edge.
	var a := absf(v)
	a = clampf((a - 0.12) / 0.88, 0.0, 1.0)
	return signf(v) * a * a * (3.0 - 2.0 * a) * 0.65 + signf(v) * a * 0.35


## Comfort setting (GRAPHICS > Camera motion): how far the view turns, and how much it sways.
const MOTION_RANGE := [1.0, 0.75, 0.55]
const MOTION_SWAY := [1.0, 0.4, 0.0]


func _range_k() -> float:
	return MOTION_RANGE[clampi(int(Settings.graphics.get("motion", 0)), 0, 2)]


func _sway_k() -> float:
	return MOTION_SWAY[clampi(int(Settings.graphics.get("motion", 0)), 0, 2)]


## Like _shape, but with a wider still zone in the middle (only the outer part of the screen turns).
func _shape_soft(v: float) -> float:
	var a := clampf((absf(v) - 0.3) / 0.7, 0.0, 1.0)
	return signf(v) * a * a * (3.0 - 2.0 * a)


func _update_seated(delta: float) -> void:
	var rk := _range_k()
	var ty := -_shape(pointer.x) * YAW_RANGE * rk
	var py := _shape(pointer.y)
	var tp := BASE_PITCH - (py * PITCH_DOWN if py > 0.0 else py * PITCH_UP) * rk
	var k := 1.0 - exp(-delta * 3.2)
	_yaw = lerpf(_yaw, ty, k)
	_pitch = lerpf(_pitch, tp, k)

	# Breathing and a little natural head sway.
	var sk := _sway_k()
	var breath := sin(_t * 1.15) * 0.006 * sk
	var sway := sin(_t * 0.37) * 0.004 * sk
	var head_turn := deg_to_rad(_yaw)
	position = seat_pos + Vector3(-sin(head_turn) * 0.06 + sway, breath, -absf(sin(head_turn)) * 0.03)
	rotation = Vector3(deg_to_rad(_pitch + sin(_t * 0.9) * 0.15 * sk), head_turn, deg_to_rad(sin(_t * 0.31) * 0.25 * sk))


func _update_zoomed(delta: float) -> void:
	if focus == null or focus.zoom_marker == null:
		return
	var target := focus.zoom_marker.global_transform
	if focus.zoom_look == Vector2.ZERO:
		# Leaned in to the screen: hold perfectly still so the picture doesn't swim.
		global_transform = target
		return
	# A view you can look around in (the side window): same edge-of-screen turning as seated.
	# Gentler than at the desk: a wide dead zone in the middle and a slow, soft follow,
	# so reaching for the card or the buttons doesn't swing the whole view.
	var rk := _range_k()
	var ty := -_shape_soft(pointer.x) * focus.zoom_look.x * rk
	var py := _shape_soft(pointer.y)
	var tp := -py * focus.zoom_look.y * rk
	var k := 1.0 - exp(-delta * 2.0)
	_zyaw = lerpf(_zyaw, ty, k)
	_zpitch = lerpf(_zpitch, tp, k)
	var b := target.basis * Basis.from_euler(Vector3(deg_to_rad(_zpitch), deg_to_rad(_zyaw), 0))
	var breath := Vector3(0, sin(_t * 1.15) * 0.004 * _sway_k(), 0)
	global_transform = Transform3D(b, target.origin + breath)


var blocked := false   ## an overlay (ID card, plate) is up: point at nothing


func _physics_process(_delta: float) -> void:
	if state == State.MOVING:
		return
	if blocked:
		if hovered:
			hovered = null
			hover_changed.emit("")
		return
	var vp := get_viewport()
	var size := Vector2(vp.size)
	var screen := (pointer * 0.5 + Vector2(0.5, 0.5)) * size if state != State.WALK else size * 0.5
	var from := project_ray_origin(screen)
	var to := from + project_ray_normal(screen) * 4.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 << (Interactable.LAYER - 1))
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var it: Interactable = null
	var skip: Array[RID] = []
	var cur_focus := focus if state == State.ZOOMED else null
	# Look past things that can't be used right now (the zone we're zoomed into, switched-off items).
	for i in 6:
		q.exclude = skip
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit:
			break
		var c = hit.collider
		if c is Interactable and c.enabled and c != cur_focus and (c.requires_focus == null or c.requires_focus == cur_focus) \
				and (c.outdoor or not outside):
			it = c
			break
		skip.append(hit.rid)
	if it != hovered:
		hovered = it
		hover_changed.emit(it.prompt if it else "")


# ------------------------------------------------------------------ standing up
## Get up from the desk: rise and turn round to face the back of the booth, then walk.
## `at` is where to stand (x, z); the default is beside the desk chair.
func stand_up(at := Vector2(0.42, 0.42)) -> void:
	if state == State.WALK:
		return
	if state == State.ZOOMED:
		unzoom()
		await zoom_changed
	state = State.MOVING
	hovered = null
	hover_changed.emit("")
	_wyaw = PI
	_wpitch = deg_to_rad(-6.0)
	var target := Transform3D(Basis.from_euler(Vector3(_wpitch, _wyaw, 0)), Vector3(at.x, EYE, at.y))
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_transform", target, 1.8)
	tw.tween_property(self, "fov", 70.0, 1.8)
	await tw.finished
	state = State.WALK


## Co-op: start the night on your feet at a spot in the booth (the chair is someone else's).
func start_standing(at: Vector2, yaw := 0.0) -> void:
	state = State.WALK
	_wyaw = yaw
	_wpitch = deg_to_rad(-8.0)
	fov = 70.0
	position = Vector3(at.x, EYE, at.y)
	rotation = Vector3(_wpitch, _wyaw, 0)


## Back into the desk chair and the seated view.
func sit_down() -> void:
	if state != State.WALK:
		return
	state = State.MOVING
	hovered = null
	hover_changed.emit("")
	_yaw = 0.0
	_pitch = BASE_PITCH
	var rest := Transform3D(Basis.from_euler(Vector3(deg_to_rad(_pitch), 0, 0)), seat_pos)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_transform", rest, 1.2)
	tw.tween_property(self, "fov", SEATED_FOV, 1.2)
	await tw.finished
	state = State.SEATED


## Move to a spot while standing (going through the door), facing `yaw`. Returns when there.
func walk_to(p: Vector3, yaw: float, seconds: float) -> void:
	state = State.MOVING
	hovered = null
	hover_changed.emit("")
	_wyaw = yaw
	_wpitch = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_transform", Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), p), seconds)
	await tw.finished
	state = State.WALK


## Mouse movement while standing (relative pixels).
func look(rel: Vector2) -> void:
	if state != State.WALK or blocked:
		return
	_wyaw -= rel.x * 0.0035
	_wpitch = clampf(_wpitch - rel.y * 0.0035, deg_to_rad(-70), deg_to_rad(70))


func _update_walk(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	dir += auto_walk
	var p := Vector2(position.x, position.z)
	var moving := dir != Vector2.ZERO and not blocked
	if moving:
		dir = dir.normalized().rotated(-_wyaw)
		var step := dir * walk_speed * delta
		# Slide along walls and furniture: try each axis on its own.
		var nx := p + Vector2(step.x, 0)
		if _free(nx):
			p = nx
		var nz := p + Vector2(0, step.y)
		if _free(nz):
			p = nz
		_bob += delta * 9.0
		_step_acc += delta
		if _step_acc > 0.48:
			_step_acc = 0.0
			footstep.emit()
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, 1.0 - exp(-delta * 6.0))
	var sk := _sway_k()
	var bob_y := (sin(_bob) * 0.022 if moving else sin(_bob) * 0.01) * sk
	position = Vector3(p.x, floor_y + EYE + bob_y + sin(_t * 1.1) * 0.003 * sk, p.y)
	rotation = Vector3(_wpitch, _wyaw, sin(_bob * 0.5) * 0.004 * sk)


func _free(p: Vector2) -> bool:
	if free_fn.is_valid():
		return bool(free_fn.call(p))
	var b := walk_bounds.grow(-BODY_R)
	if not b.has_point(p):
		return false
	for r in walk_blockers:
		if (r as Rect2).grow(BODY_R).has_point(p):
			return false
	return true


## Left click.
func click() -> void:
	if state == State.MOVING:
		return
	if hovered:
		var it := hovered
		if it.zoom_marker and state != State.MOVING and it != focus:
			if zoom_guard.is_valid() and not zoom_guard.call(it):
				return
			zoom_to(it)
		it.activate()


## Right click / Esc. Returns true if it did something.
func back() -> bool:
	if state == State.WALK and back_fn.is_valid():
		return bool(back_fn.call())
	if state == State.ZOOMED:
		unzoom()
		return true
	return false


var _zoom_from_walk := false      ## leaned in while standing: lean back out to where you stood
var _walk_return := Transform3D()


func zoom_to(it: Interactable) -> void:
	if state == State.WALK:
		_zoom_from_walk = true
		_walk_return = global_transform
	elif state != State.ZOOMED:
		_zoom_from_walk = false
	focus = it
	_zyaw = 0.0
	_zpitch = 0.0
	state = State.MOVING
	hovered = null
	hover_changed.emit("")
	# The marker sits in front of the screen with its -Z axis pointing into it.
	var target := it.zoom_marker.global_transform
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_transform", target, 0.9)
	tw.tween_property(self, "fov", it.zoom_fov, 0.9)
	tw.chain().tween_callback(func():
		state = State.ZOOMED
		zoom_changed.emit(true)
		focus_changed.emit(it))


func unzoom() -> void:
	state = State.MOVING
	focus = null
	if _zoom_from_walk:
		_zoom_from_walk = false
		var tw0 := create_tween().set_parallel(true)
		tw0.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw0.tween_property(self, "global_transform", _walk_return, 0.7)
		tw0.tween_property(self, "fov", 70.0, 0.7)
		tw0.chain().tween_callback(func():
			state = State.WALK
			zoom_changed.emit(false)
			focus_changed.emit(null))
		return
	var rest := Transform3D(Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0)), seat_pos)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_transform", rest, 0.7)
	tw.tween_property(self, "fov", SEATED_FOV, 0.7)
	tw.chain().tween_callback(func():
		state = State.SEATED
		zoom_changed.emit(false)
		focus_changed.emit(null))
