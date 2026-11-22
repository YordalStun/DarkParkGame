extends Camera3D
## The player's eyes, seated at the desk. Fully mouse driven:
##  * moving the cursor toward a screen edge turns the head that way (subtle),
##  * pointing at an Interactable shows its name, left click uses it,
##  * clicking the CRT leans in to the screen; right click (or Esc) sits back.

signal hover_changed(prompt: String)
signal zoom_changed(zoomed: bool)
signal focus_changed(focus: Interactable)  ## zoomed in to something (null = sat back)

enum State { SEATED, MOVING, ZOOMED }

const SEAT_POS := Vector3(0.0, 1.2, 0.32)
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
	position = SEAT_POS
	rotation_degrees = Vector3(BASE_PITCH, 0, 0)


## Called by Main with the cursor position in -1..1 (x right, y down).
func set_pointer(p: Vector2) -> void:
	pointer = p


func _process(delta: float) -> void:
	_t += delta
	if state == State.SEATED:
		_update_seated(delta)
	elif state == State.ZOOMED:
		_update_zoomed(delta)


func _shape(v: float) -> float:
	# Dead zone in the middle; turn more as the cursor nears the edge.
	var a := absf(v)
	a = clampf((a - 0.12) / 0.88, 0.0, 1.0)
	return signf(v) * a * a * (3.0 - 2.0 * a) * 0.65 + signf(v) * a * 0.35


func _update_seated(delta: float) -> void:
	var ty := -_shape(pointer.x) * YAW_RANGE
	var py := _shape(pointer.y)
	var tp := BASE_PITCH - (py * PITCH_DOWN if py > 0.0 else py * PITCH_UP)
	var k := 1.0 - exp(-delta * 3.2)
	_yaw = lerpf(_yaw, ty, k)
	_pitch = lerpf(_pitch, tp, k)

	# Breathing and a little natural head sway.
	var breath := sin(_t * 1.15) * 0.006
	var sway := sin(_t * 0.37) * 0.004
	var head_turn := deg_to_rad(_yaw)
	position = SEAT_POS + Vector3(-sin(head_turn) * 0.06 + sway, breath, -absf(sin(head_turn)) * 0.03)
	rotation = Vector3(deg_to_rad(_pitch + sin(_t * 0.9) * 0.15), head_turn, deg_to_rad(sin(_t * 0.31) * 0.25))


func _update_zoomed(delta: float) -> void:
	if focus == null or focus.zoom_marker == null:
		return
	var target := focus.zoom_marker.global_transform
	if focus.zoom_look == Vector2.ZERO:
		# Leaned in to the screen: hold perfectly still so the picture doesn't swim.
		global_transform = target
		return
	# A view you can look around in (the side window): same edge-of-screen turning as seated.
	var ty := -_shape(pointer.x) * focus.zoom_look.x
	var py := _shape(pointer.y)
	var tp := -py * focus.zoom_look.y
	var k := 1.0 - exp(-delta * 3.2)
	_zyaw = lerpf(_zyaw, ty, k)
	_zpitch = lerpf(_zpitch, tp, k)
	var b := target.basis * Basis.from_euler(Vector3(deg_to_rad(_zpitch), deg_to_rad(_zyaw), 0))
	var breath := Vector3(0, sin(_t * 1.15) * 0.004, 0)
	global_transform = Transform3D(b, target.origin + breath)


func _physics_process(_delta: float) -> void:
	if state == State.MOVING:
		return
	var vp := get_viewport()
	var size := Vector2(vp.size)
	var screen := (pointer * 0.5 + Vector2(0.5, 0.5)) * size
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
		if c is Interactable and c.enabled and c != cur_focus and (c.requires_focus == null or c.requires_focus == cur_focus):
			it = c
			break
		skip.append(hit.rid)
	if it != hovered:
		hovered = it
		hover_changed.emit(it.prompt if it else "")


## Left click.
func click() -> void:
	if state == State.MOVING:
		return
	if hovered:
		var it := hovered
		if it.zoom_marker and state != State.MOVING and it != focus:
			zoom_to(it)
		it.activate()


## Right click / Esc. Returns true if it did something.
func back() -> bool:
	if state == State.ZOOMED:
		unzoom()
		return true
	return false


func zoom_to(it: Interactable) -> void:
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
	var rest := Transform3D(Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0)), SEAT_POS)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "global_transform", rest, 0.7)
	tw.tween_property(self, "fov", SEATED_FOV, 0.7)
	tw.chain().tween_callback(func():
		state = State.SEATED
		zoom_changed.emit(false)
		focus_changed.emit(null))
