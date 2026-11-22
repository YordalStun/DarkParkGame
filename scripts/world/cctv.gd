extends Node3D
## The lot's CCTV system: four real cameras placed in the 3D world. Each renders
## into its own small viewport, so anything that moves in the world (cars later,
## people, weather) shows up on the CamLink monitor exactly where it should.
##
## To keep it cheap the feeds only render while something is watching them
## (acquire()/release()), at a choppy CCTV frame rate, with a lighter environment
## (no volumetric mist or screen-space effects, but higher gain like a low-light camera).

const RES := Vector2i(320, 240)
const FPS := 10.0           ## frames per second per camera

var world  ## the World node (untyped: reads its builder fields)
var cams: Array = []        ## [{name, viewport, camera, rig}]

var _users := 0
var _acc := 0.0
var _next := 0
var _env: Environment


func _ready() -> void:
	_env = (world.environment as Environment).duplicate()
	_env.volumetric_fog_enabled = false
	_env.ssr_enabled = false
	_env.ssao_enabled = false
	_env.glow_enabled = false
	# A low-light camera: lots of gain, and a lifted floor so the dark lot is still readable.
	# (This environment is only used by the camera viewports, so the booth view is unaffected.)
	_env.tonemap_exposure = 3.0
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.13, 0.14, 0.16)
	_env.ambient_light_energy = 1.0
	_env.fog_light_color = Color(0.05, 0.055, 0.065)
	_env.fog_density = 0.02

	var G := -0.15
	var store: Node3D = world.lot.store
	var door: Vector3 = store.position + store.door_pos
	# name, camera position, look-at target, mount: "roof" | "pole" | "wall"
	_add("CAM 1  LOT EAST", Vector3(2.35, 2.95, -1.75), Vector3(9.0, G, -20.0), "roof")
	_add("CAM 2  LOT WEST", Vector3(-37.6, 5.6, -41.6), Vector3(-6.0, G, -6.0), "pole")
	_add("CAM 3  STORE DOOR", Vector3(store.position.x - 5.0, 4.4, door.z - 2.6), Vector3(store.position.x + 0.2, 0.7, door.z), "pole")
	_add("CAM 4  ENTRANCE GATE", Vector3(-7.4, 4.3, 4.4), Vector3(-4.0, -0.15, -1.0), "pole")


func _add(cam_name: String, pos: Vector3, target: Vector3, mount: String) -> void:
	var vp := SubViewport.new()
	vp.name = cam_name.replace(" ", "")
	vp.size = RES
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.positional_shadow_atlas_size = 1024
	vp.audio_listener_enable_3d = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)

	var cam := Camera3D.new()
	cam.fov = 68.0
	cam.near = 0.1
	cam.far = 140.0
	cam.environment = _env
	cam.current = true
	vp.add_child(cam)
	# The lens sits just in front of the housing (otherwise it films the inside of its own box).
	cam.look_at_from_position(pos + (target - pos).normalized() * 0.3, target, Vector3.UP)

	cams.append({"name": cam_name, "viewport": vp, "camera": cam, "rig": _build_rig(pos, target, mount)})


## The physical camera: housing, sun hood, bracket and a red tally LED.
func _build_rig(pos: Vector3, target: Vector3, mount: String) -> Node3D:
	var body := MK.mat(Color(0.78, 0.78, 0.74), "metal", 0.45, 1.0, 0.3)
	var dark := MK.mat(Color(0.1, 0.1, 0.1), "", 0.5)
	var rig := Node3D.new()
	add_child(rig)
	rig.look_at_from_position(pos, target, Vector3.UP)
	MK.box(rig, Vector3(0.16, 0.14, 0.38), Vector3(0, 0, 0.04), body)        # housing (looks along -Z)
	MK.box(rig, Vector3(0.2, 0.02, 0.46), Vector3(0, 0.085, 0.0), body)      # sun hood
	MK.box(rig, Vector3(0.11, 0.11, 0.02), Vector3(0, 0, -0.155), dark)      # lens face
	MK.box(rig, Vector3(0.025, 0.025, 0.01), Vector3(0.05, -0.04, -0.16), MK.emissive(Color(1, 0.1, 0.05), 6.0))
	# Bracket back to the mount.
	MK.box(rig, Vector3(0.05, 0.05, 0.35), Vector3(0, -0.05, 0.38), dark)
	if mount == "pole":
		var pole := MK.mat(Color(0.4, 0.41, 0.42), "metal", 0.5, 1.0, 0.5)
		var base := pos + (pos - target).normalized() * Vector3(1, 0, 1) * 0.5
		MK.cyl(self, 0.06, 0.08, base.y + 0.15, Vector3(base.x, (base.y - 0.15) * 0.5, base.z), pole, 6)
	return rig


func acquire() -> void:
	_users += 1


func release() -> void:
	_users = maxi(0, _users - 1)


func is_live() -> bool:
	return _users > 0


func texture(i: int) -> Texture2D:
	return cams[i].viewport.get_texture()


func _process(delta: float) -> void:
	if _users <= 0 or cams.is_empty():
		return
	# Round-robin: one camera renders per tick, each reaching FPS frames a second.
	_acc += delta
	var step := 1.0 / (FPS * cams.size())
	var n := 0
	while _acc >= step and n < cams.size():
		_acc -= step
		n += 1
		cams[_next].viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_next = (_next + 1) % cams.size()
	_acc = minf(_acc, step)
