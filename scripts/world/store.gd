extends Node3D
## "Nite Stop" 24-hour convenience store on the east edge of the lot.
## Its front faces the lot (local -X). Bright aisles glow through the windows,
## a backlit sign hangs over them and a single lamp lights the door.
## Origin = ground level at the middle of the shop front.

const DEPTH := 9.0     # front to back (local +X)
const WIDTH := 12.0    # along the front (local Z)
const HEIGHT := 4.2
const DOOR_Z := 0.0    # door is in the middle of the front

var door_light: SpotLight3D
var door_pos: Vector3  ## local position of the front door (for the CCTV camera)


func _ready() -> void:
	var brick := MK.mat(Color(0.75, 0.7, 0.66), "brick", 0.85, 2.0)
	var trim := MK.mat(Color(0.18, 0.2, 0.24), "metal", 0.5, 1.0, 0.4)
	var concrete := MK.mat(Color(0.65, 0.63, 0.6), "concrete", 0.9, 1.5)
	var hw := WIDTH * 0.5

	# Shell: back block, plus a front wall made of piers around windows and the door.
	MK.box_from(self, Vector3(0.3, 0, -hw), Vector3(DEPTH, HEIGHT, hw), brick, "Body")
	MK.box_from(self, Vector3(-0.2, HEIGHT, -hw - 0.2), Vector3(DEPTH + 0.2, HEIGHT + 0.5, hw + 0.2), trim, "Parapet")
	MK.box_from(self, Vector3(0, 0, -hw), Vector3(0.3, 0.6, hw), brick, "Kneewall")
	MK.box_from(self, Vector3(0, 2.6, -hw), Vector3(0.3, HEIGHT, hw), brick, "Header")
	for pier in [[-hw, -hw + 0.4], [-1.1, -0.9], [0.9, 1.1], [hw - 0.4, hw]]:
		MK.box_from(self, Vector3(0, 0, pier[0]), Vector3(0.32, 2.6, pier[1]), brick)

	# Lit interior seen through the glass (emissive picture just behind the windows).
	var inside := MK.picture("store_interior", 0.9, 0.9)
	inside.albedo_color = Color(0.85, 0.9, 0.82)
	for span in [[-hw + 0.4, -1.1], [1.1, hw - 0.4]]:
		var w: float = span[1] - span[0]
		var q := MK.quad(self, Vector2(w, 2.0), Vector3(0.28, 1.6, (span[0] + span[1]) * 0.5), inside, Vector3(0, -90, 0))
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Window frames.
		MK.box(self, Vector3(0.06, 0.06, w), Vector3(0.02, 2.6, (span[0] + span[1]) * 0.5), trim)
		MK.box(self, Vector3(0.06, 0.06, w), Vector3(0.02, 0.6, (span[0] + span[1]) * 0.5), trim)

	# Door: glass with a push bar, a frame and the light above it.
	var door_m := MK.picture("store_interior", 0.9, 0.7)
	var d := MK.quad(self, Vector2(1.8, 2.3), Vector3(0.25, 1.15, DOOR_Z), door_m, Vector3(0, -90, 0), "Door")
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MK.box(self, Vector3(0.08, 2.4, 0.08), Vector3(0.1, 1.2, DOOR_Z - 0.95), trim)
	MK.box(self, Vector3(0.08, 2.4, 0.08), Vector3(0.1, 1.2, DOOR_Z + 0.95), trim)
	MK.box(self, Vector3(0.08, 0.08, 1.9), Vector3(0.1, 2.38, DOOR_Z), trim)
	MK.box(self, Vector3(0.05, 0.05, 1.2), Vector3(0.18, 1.05, DOOR_Z), MK.mat(Color(0.7, 0.7, 0.68), "", 0.25, 1.0, 0.9))
	door_pos = Vector3(-0.6, 0.0, DOOR_Z)

	# Backlit sign over the windows.
	var sign := MK.picture("store_sign", 0.6, 2.2)
	var sq := MK.quad(self, Vector2(6.0, 1.4), Vector3(-0.05, 3.35, 0), sign, Vector3(0, -90, 0), "Sign")
	sq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MK.box(self, Vector3(0.12, 1.55, 6.15), Vector3(0.02, 3.35, 0), trim)

	# Sidewalk in front.
	MK.box_from(self, Vector3(-2.2, 0, -hw - 0.5), Vector3(0, 0.14, hw + 0.5), concrete, "Sidewalk")

	# Light from the windows spilling onto the sidewalk (no shadows: cheap).
	var spill := MK.omni(self, Vector3(-1.2, 1.6, 0), Color(0.92, 0.97, 0.88), 1.1, 9.0, false, "WindowSpill")
	spill.light_volumetric_fog_energy = 0.6
	spill.light_specular = 0.4

	# Lamp over the door.
	MK.box(self, Vector3(0.3, 0.12, 0.4), Vector3(-0.15, 2.85, DOOR_Z), trim)
	MK.box(self, Vector3(0.22, 0.03, 0.32), Vector3(-0.15, 2.78, DOOR_Z), MK.emissive(Color(1.0, 0.85, 0.6), 5.0))
	door_light = SpotLight3D.new()
	door_light.position = Vector3(-0.2, 2.75, DOOR_Z)
	door_light.rotation_degrees = Vector3(-90, 0, 0)
	door_light.light_color = Color(1.0, 0.82, 0.58)
	door_light.light_energy = 3.0
	door_light.spot_range = 6.0
	door_light.spot_angle = 55.0
	door_light.light_volumetric_fog_energy = 1.0
	door_light.shadow_enabled = false
	add_child(door_light)

	# Odds and ends out front: ice chest, newspaper box, bin.
	MK.box(self, Vector3(0.7, 1.1, 1.6), Vector3(-0.45, 0.69, -4.2), MK.mat(Color(0.85, 0.87, 0.9), "metal", 0.4, 1.0, 0.3))
	MK.box(self, Vector3(0.72, 0.18, 1.62), Vector3(-0.45, 1.25, -4.2), MK.mat(Color(0.15, 0.3, 0.6), "", 0.5))
	MK.box(self, Vector3(0.45, 1.0, 0.45), Vector3(-0.6, 0.64, 2.2), MK.mat(Color(0.65, 0.12, 0.1), "metal", 0.5, 1.0, 0.3))
	MK.cyl(self, 0.25, 0.22, 0.85, Vector3(-0.7, 0.56, 3.4), MK.mat(Color(0.18, 0.22, 0.16), "metal", 0.6, 1.0, 0.3), 10)
