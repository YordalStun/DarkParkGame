extends Node3D
## The A&E block at the west end of the walking aisle: a low concrete building with a red
## ACCIDENT & EMERGENCY sign, an ambulance-bay canopy and a handrailed ramp. Staff walk along
## the path and in through the lit double doors.
##
## Local frame: origin on the ground at the middle of the doors; the front faces +X (towards the
## car park) and the building stands back towards -X. The path runs along +X from the door.

const DOOR_REACH := 1.2   ## how far in front of the doors walkers stop (and vanish)

var _concrete: StandardMaterial3D
var _dark: StandardMaterial3D
var _hazard: StandardMaterial3D


func _ready() -> void:
	_concrete = MK.mat(Color(0.5, 0.5, 0.48), "concrete", 0.9, 3.0)
	_dark = MK.mat(Color(0.14, 0.15, 0.17), "", 0.6)
	_hazard = MK.mat(Color(0.85, 0.7, 0.05), "", 0.5)
	var cool := Color(0.85, 1.0, 0.98)
	var cool_glow := MK.emissive(cool, 3.0, Color(0.55, 0.62, 0.62))

	# The block, with a flat roof edge.
	MK.box_from(self, Vector3(-32.0, 0.0, -9.0), Vector3(0.0, 7.0, 9.0), _concrete, "Block")
	MK.box_from(self, Vector3(-32.3, 7.0, -9.3), Vector3(0.3, 7.3, 9.3), MK.mat(Color(0.35, 0.36, 0.36), "", 0.8), "RoofEdge")
	# Windows: two bands across the front, most lit, a few dark.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var dim := MK.mat(Color(0.03, 0.035, 0.05), "", 0.2, 1.0, 0.3)
	for row in [[3.8, 1.6], [0.7, 1.6]]:
		for i in 8:
			var z := -8.0 + i * 2.1
			if absf(z + 0.9) < 2.6 and row[0] < 3.0:
				continue   # the doors
			MK.box(self, Vector3(0.06, row[1], 1.5), Vector3(0.02, row[0] + row[1] * 0.5, z), cool_glow if rng.randf() < 0.7 else dim)
	# Double doors, bright inside, with a dark mullion.
	MK.box(self, Vector3(0.08, 2.6, 4.0), Vector3(0.03, 1.4, 0.0), cool_glow, Vector3.ZERO, "Doors")
	MK.box(self, Vector3(0.1, 2.6, 0.1), Vector3(0.05, 1.4, 0.0), _dark)
	# The big red sign.
	# (On the front edge of the canopy, so it can be read from the car park and the canopy doesn't hide it.)
	MK.box(self, Vector3(0.3, 1.0, 10.0), Vector3(12.1, 5.45, 0.0), MK.emissive(Color(1.0, 0.15, 0.1), 3.0, Color(0.3, 0.02, 0.02)), Vector3.ZERO, "Sign")
	var l := Label3D.new()
	l.text = "ACCIDENT & EMERGENCY"
	l.font_size = 64
	l.pixel_size = 0.0085
	l.modulate = Color(1, 1, 1)
	l.outline_size = 8
	l.outline_modulate = Color(0.3, 0.02, 0.02)
	l.shaded = false
	l.position = Vector3(12.3, 5.45, 0.0)
	l.rotation_degrees.y = 90.0
	add_child(l)
	MK.omni(self, Vector3(14.0, 5.0, 0.0), Color(1.0, 0.25, 0.15), 2.0, 14.0, false, "SignGlow")

	# Ambulance-bay canopy over the entrance, with a bright underlight.
	MK.box_from(self, Vector3(0.0, 4.6, -6.0), Vector3(12.0, 4.9, 6.0), _concrete, "Canopy")
	for cz in [-5.4, 5.4]:
		MK.cyl(self, 0.25, 0.25, 4.6, Vector3(11.3, 2.3, cz), _concrete, 6)
	MK.box(self, Vector3(9.0, 0.06, 1.6), Vector3(5.5, 4.57, 0.0), MK.emissive(cool, 4.0, Color(0.6, 0.65, 0.65)))
	MK.omni(self, Vector3(5.5, 4.0, 0.0), cool, 3.2, 17.0, false, "CanopyLight")

	# The ramp path: a wide slab with yellow edges and low handrails both sides.
	var slab := MK.mat(Color(0.2, 0.21, 0.22), "", 0.35, 1.0, 0.1)
	MK.box_from(self, Vector3(0.0, 0.0, -1.5), Vector3(22.0, 0.04, 1.5), slab, "RampPath")
	for sz in [-1.5, 1.5]:
		MK.box_from(self, Vector3(0.0, 0.045, sz - 0.05), Vector3(22.0, 0.05, sz + 0.05), _hazard)
		MK.box_from(self, Vector3(0.0, 0.88, sz - 0.03), Vector3(22.0, 0.93, sz + 0.03), MK.mat(Color(0.8, 0.8, 0.78), "", 0.4, 1.0, 0.5))
		var px := 0.0
		while px <= 22.0:
			MK.box(self, Vector3(0.05, 0.9, 0.05), Vector3(px, 0.45, sz), MK.mat(Color(0.8, 0.8, 0.78), "", 0.4, 1.0, 0.5))
			px += 3.0
	# Hazard stripes along the bay kerb.
	for i in 12:
		MK.box(self, Vector3(0.35, 0.01, 0.8), Vector3(12.2, 0.045, -4.5 + i * 0.8), _hazard if i % 2 == 0 else _dark)
	_ambulance(Vector3(6.0, 0.0, 8.5))
	for lx in [8.0, 18.0]:
		_lamp(Vector3(lx, 0.0, -3.4))


func _ambulance(pos: Vector3) -> void:
	var amb := Node3D.new()
	amb.name = "Ambulance"
	amb.position = pos
	amb.rotation_degrees.y = 90.0 + 180.0
	add_child(amb)
	var white := MK.mat(Color(0.92, 0.92, 0.88), "", 0.5)
	MK.box(amb, Vector3(5.0, 2.2, 2.0), Vector3(0, 1.4, 0), white)
	MK.box(amb, Vector3(1.6, 1.4, 1.9), Vector3(3.0, 1.0, 0), white)
	MK.box(amb, Vector3(5.0, 0.3, 2.02), Vector3(0, 1.1, 0), MK.mat(Color(0.85, 0.8, 0.1), "", 0.5))
	MK.box(amb, Vector3(0.4, 0.15, 1.5), Vector3(0.5, 2.6, 0), MK.emissive(Color(0.2, 0.4, 1.0), 4.0, Color(0.05, 0.1, 0.3)))
	for wx in [-1.5, 2.5]:
		for wz in [-1.0, 1.0]:
			MK.cyl(amb, 0.4, 0.4, 0.25, Vector3(wx, 0.4, wz), _dark, 10, Vector3(90, 0, 0))
	MK.omni(amb, Vector3(0.5, 2.8, 0), Color(0.3, 0.45, 1.0), 1.2, 8.0, false)


func _lamp(pos: Vector3) -> void:
	var metal := MK.mat(Color(0.12, 0.12, 0.13), "", 0.5, 1.0, 0.4)
	MK.cyl(self, 0.05, 0.07, 5.0, pos + Vector3(0, 2.5, 0), metal, 6)
	MK.box(self, Vector3(0.18, 0.06, 0.7), pos + Vector3(0, 5.02, 0.3), metal)
	MK.box(self, Vector3(0.14, 0.05, 0.4), pos + Vector3(0, 4.97, 0.4), MK.emissive(Color(0.85, 0.95, 1.0), 7.0, Color(0.4, 0.45, 0.5)))
	MK.omni(self, pos + Vector3(0, 4.8, 0.4), Color(0.85, 0.95, 1.0), 2.0, 10.0, false)
