extends RefCounted
## Three looks for the hospital the staff walk to, and the path that gets them there.
## Scene: the car park's walking aisle runs along -X from x=0; each hospital stands at the far end.

const CONCEPTS := ["ward_block", "old_wing", "ae_block"]
const G := 0.0


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
	var ground := MK.box(root, Vector3(140, 0.2, 80), Vector3(-30, -0.1, 0), MK.mat(Color(0.07, 0.07, 0.08), "", 0.25, 1.0, 0.2))
	ground.name = "Ground"
	# The end of the car park: a strip of bays and the aisle the people walk along.
	MK.box(root, Vector3(10, 0.02, 6), Vector3(2, 0.01, -2.5), MK.mat(Color(0.1, 0.1, 0.11), "", 0.3))
	for i in 3:
		MK.box(root, Vector3(0.1, 0.01, 4.5), Vector3(-1.5 + i * 2.7, 0.025, -4.5), MK.mat(Color(0.7, 0.7, 0.65), "", 0.6))
	match kind:
		"ward_block": _ward_block(root)
		"old_wing": _old_wing(root)
		"ae_block": _ae_block(root)
	return root


# ------------------------------------------------------------------ helpers
static func _window_grid(root: Node3D, origin: Vector3, cols: int, rows: int, size: Vector2, gap: Vector2, lit_chance: float, warm: Color, facing_z := true, seed_v := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var lit := MK.emissive(warm, 2.2, Color(0.05, 0.05, 0.06))
	var dim := MK.mat(Color(0.03, 0.035, 0.05), "", 0.2, 1.0, 0.3)
	for r in rows:
		for c in cols:
			var pos := origin + Vector3(c * (size.x + gap.x), r * (size.y + gap.y), 0)
			MK.box(root, Vector3(size.x, size.y, 0.06), pos, lit if rng.randf() < lit_chance else dim)


static func _lamp(root: Node3D, pos: Vector3, height := 4.5, color := Color(1.0, 0.62, 0.3), energy := 2.0) -> void:
	var metal := MK.mat(Color(0.12, 0.12, 0.13), "", 0.5, 1.0, 0.4)
	MK.cyl(root, 0.05, 0.07, height, pos + Vector3(0, height * 0.5, 0), metal, 6)
	MK.box(root, Vector3(0.7, 0.06, 0.18), pos + Vector3(0.3, height + 0.02, 0), metal)
	MK.box(root, Vector3(0.4, 0.05, 0.14), pos + Vector3(0.4, height - 0.03, 0), MK.emissive(color, 7.0, Color(0.2, 0.15, 0.1)))
	MK.omni(root, pos + Vector3(0.4, height - 0.2, 0), color, energy, 9.0, false)


static func _slab_path(root: Node3D, x0: float, x1: float, z: float, width: float, color: Color) -> void:
	MK.box_from(root, Vector3(x0, 0.0, z - width * 0.5), Vector3(x1, 0.03, z + width * 0.5), MK.mat(color, "", 0.35, 1.0, 0.1))
	var x := minf(x0, x1)
	while x < maxf(x0, x1):
		MK.box(root, Vector3(0.03, 0.005, width), Vector3(x, 0.033, z), MK.mat(color.darkened(0.3), "", 0.5))
		x += 1.8


static func _sign(root: Node3D, text: String, pos: Vector3, color: Color, size := 0.1, emit := true) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = size * 0.05
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0)
	l.position = pos
	l.shaded = false
	l.double_sided = true
	root.add_child(l)


# ------------------------------------------------------------------ 1. Ward block + covered walkway
static func _ward_block(root: Node3D) -> void:
	var brick := MK.mat(Color(0.36, 0.2, 0.15), "", 0.9)
	var concrete := MK.mat(Color(0.45, 0.46, 0.46), "", 0.85)
	# A long covered walkway: flat roof on posts, strip lights underneath, wet slabs.
	_slab_path(root, -2.0, -33.0, -1.0, 2.6, Color(0.2, 0.21, 0.22))
	var x := -3.0
	while x > -33.0:
		MK.box(root, Vector3(0.14, 3.0, 0.14), Vector3(x, 1.5, -2.2), concrete)
		MK.box(root, Vector3(0.14, 3.0, 0.14), Vector3(x, 1.5, 0.2), concrete)
		MK.box(root, Vector3(0.9, 0.04, 0.2), Vector3(x - 1.5, 2.9, -1.0), MK.emissive(Color(0.8, 1.0, 0.9), 3.5, Color(0.5, 0.6, 0.55)))
		x -= 3.0
	MK.box_from(root, Vector3(-2.0, 3.0, -2.5), Vector3(-33.0, 3.15, 0.5), MK.mat(Color(0.25, 0.3, 0.28), "", 0.6))
	for sz in [-2.2, 0.2]:
		MK.box_from(root, Vector3(-2.0, 0.0, sz - 0.02), Vector3(-33.0, 0.9, sz + 0.02), MK.mat(Color(0.28, 0.3, 0.3), "", 0.5, 1.0, 0.6))  # handrails run low: a rail on posts
	MK.omni(root, Vector3(-18, 2.6, -1.0), Color(0.8, 1.0, 0.9), 1.6, 22.0, false)
	# Ward block: three storeys of brick, lit windows, a bright glass entrance.
	MK.box_from(root, Vector3(-60.0, 0.0, -8.0), Vector3(-34.0, 11.0, 6.0), brick)
	MK.box_from(root, Vector3(-60.5, 11.0, -8.5), Vector3(-33.5, 11.4, 6.5), concrete)
	_window_grid(root, Vector3(-58.0, 3.0, 6.05), 8, 3, Vector2(1.6, 1.5), Vector2(1.0, 1.0), 0.55, Color(1.0, 0.85, 0.55), true, 3)
	_window_grid(root, Vector3(-37.0, 3.0, 6.05), 1, 3, Vector2(1.6, 1.5), Vector2(1.0, 1.0), 0.8, Color(1.0, 0.85, 0.55), true, 7)
	MK.box_from(root, Vector3(-37.5, 0.0, 6.0), Vector3(-33.0, 3.4, 8.8), MK.mat(Color(0.12, 0.14, 0.16), "", 0.3, 1.0, 0.4))   # entrance lobby
	MK.box(root, Vector3(4.0, 2.4, 0.06), Vector3(-35.2, 1.3, 8.82), MK.emissive(Color(0.85, 1.0, 0.95), 3.0, Color(0.5, 0.6, 0.6)))   # glass doors, lit
	MK.box_from(root, Vector3(-38.5, 3.4, 5.8), Vector3(-32.0, 3.6, 9.8), concrete)   # canopy
	MK.omni(root, Vector3(-35.2, 2.6, 9.5), Color(0.85, 1.0, 0.95), 3.0, 14.0, false)
	_sign(root, "WARD BLOCK", Vector3(-35.2, 4.3, 9.9), Color(0.9, 0.95, 1.0), 0.22)
	_sign(root, "MAIN ENTRANCE  >", Vector3(-12.0, 3.5, -2.6), Color(0.9, 1.0, 0.9), 0.15)
	for lx in [-8.0, -24.0, -40.0]:
		_lamp(root, Vector3(lx, 0, 3.4))


# ------------------------------------------------------------------ 2. Old Victorian wing
static func _old_wing(root: Node3D) -> void:
	var brick := MK.mat(Color(0.42, 0.18, 0.12), "", 0.95)
	var stone := MK.mat(Color(0.55, 0.52, 0.46), "", 0.9)
	var slate := MK.mat(Color(0.12, 0.13, 0.16), "", 0.6)
	# A gravel path between hedges, with low bollard lights.
	MK.box_from(root, Vector3(-2.0, 0.0, -2.0), Vector3(-34.0, 0.03, 0.4), MK.mat(Color(0.35, 0.32, 0.26), "", 0.95))
	for hz in [-2.9, 1.3]:
		MK.box_from(root, Vector3(-4.0, 0.0, hz), Vector3(-33.0, 0.9, hz + 0.7), MK.mat(Color(0.06, 0.16, 0.08), "", 0.95))
	var x := -5.0
	while x > -33.0:
		MK.cyl(root, 0.1, 0.12, 0.6, Vector3(x, 0.3, -1.3), MK.mat(Color(0.1, 0.1, 0.1), "", 0.5), 6)
		MK.sphere(root, 0.1, Vector3(x, 0.66, -1.3), MK.emissive(Color(1.0, 0.75, 0.4), 6.0, Color(0.3, 0.2, 0.1)), 6, 4)
		MK.omni(root, Vector3(x, 0.8, -1.3), Color(1.0, 0.72, 0.38), 0.55, 4.5, false)
		x -= 5.6
	# The wing: two long brick blocks either side of a central bay with a clock tower.
	MK.box_from(root, Vector3(-72.0, 0.0, -9.0), Vector3(-48.0, 9.0, 5.0), brick)
	MK.box_from(root, Vector3(-48.0, 0.0, -9.0), Vector3(-36.0, 9.0, 8.0), stone)           # the central bay, standing proud
	# Pitched slate roofs: two sloped slabs each.
	_roof(root, -72.0, -49.0, 9.0, -9.0, 5.0, slate)
	_roof(root, -47.0, -36.0, 9.0, -9.0, 8.0, slate)
	# Clock tower.
	MK.box_from(root, Vector3(-45.0, 9.0, -2.0), Vector3(-39.0, 16.0, 4.0), stone)
	MK.cyl(root, 1.1, 1.1, 0.2, Vector3(-42.0, 13.5, 4.1), MK.emissive(Color(1.0, 0.95, 0.75), 2.5, Color(0.6, 0.58, 0.5)), 16, Vector3(90, 0, 0))
	MK.box(root, Vector3(0.1, 0.8, 0.05), Vector3(-42.0, 13.7, 4.25), MK.mat(Color(0.05, 0.05, 0.05)))
	MK.box(root, Vector3(0.7, 0.1, 0.05), Vector3(-41.7, 13.5, 4.25), MK.mat(Color(0.05, 0.05, 0.05)))
	_roof_pyramid(root, Vector3(-42.0, 16.0, 1.0), 3.8, 3.2, slate)
	# Tall windows glowing warm, an arched door under a portico with pillars.
	_window_grid(root, Vector3(-70.0, 2.0, 5.05), 8, 2, Vector2(1.0, 2.0), Vector2(1.3, 1.6), 0.5, Color(1.0, 0.78, 0.42), true, 11)
	_window_grid(root, Vector3(-47.0, 2.0, 8.05), 1, 2, Vector2(1.0, 2.0), Vector2(1.3, 1.6), 0.6, Color(1.0, 0.78, 0.42), true, 5)
	MK.box(root, Vector3(2.0, 3.0, 0.1), Vector3(-42.0, 1.5, 8.05), MK.emissive(Color(1.0, 0.8, 0.5), 2.8, Color(0.2, 0.15, 0.1)))   # door, lit from within
	MK.cyl(root, 1.0, 1.0, 0.1, Vector3(-42.0, 3.0, 8.05), MK.emissive(Color(1.0, 0.8, 0.5), 2.8, Color(0.2, 0.15, 0.1)), 12, Vector3(90, 0, 0))
	for px in [-44.5, -39.5]:
		MK.cyl(root, 0.22, 0.26, 4.2, Vector3(px, 2.1, 9.6), stone, 8)
	MK.box_from(root, Vector3(-45.2, 4.2, 7.8), Vector3(-38.8, 4.6, 10.0), stone)
	MK.omni(root, Vector3(-42.0, 2.5, 9.0), Color(1.0, 0.78, 0.45), 3.0, 12.0, false)
	_sign(root, "ST. ANNE'S HOSPITAL  -  OLD WING", Vector3(-42.0, 5.3, 10.1), Color(1.0, 0.92, 0.7), 0.13)
	for lx in [-10.0, -26.0]:
		_lamp(root, Vector3(lx, 0, 2.2), 4.2, Color(1.0, 0.68, 0.32), 2.0)


static func _roof(root: Node3D, x0: float, x1: float, y: float, z0: float, z1: float, m: Material) -> void:
	var mid := (z0 + z1) * 0.5
	var half := (z1 - z0) * 0.5
	var slope := 3.0
	var len := sqrt(half * half + slope * slope)
	var ang := rad_to_deg(atan2(slope, half))
	for s in [-1.0, 1.0]:
		var b := MK.box(root, Vector3(absf(x1 - x0), 0.2, len), Vector3((x0 + x1) * 0.5, y + slope * 0.5, mid + s * half * 0.5), m)
		b.rotation_degrees.x = ang * s
	MK.box_from(root, Vector3(x0, y, z0), Vector3(x1, y + 0.2, z1), m)


static func _roof_pyramid(root: Node3D, pos: Vector3, w: float, h: float, m: Material) -> void:
	MK.taper(root, Vector3(w * 2.0, h, w * 2.0), 0.3, 0.0, pos + Vector3(0, h * 0.5, 0), m, Vector3.ZERO, 0.3)


# ------------------------------------------------------------------ 3. Eighties A&E block
static func _ae_block(root: Node3D) -> void:
	var concrete := MK.mat(Color(0.5, 0.5, 0.48), "", 0.9)
	var dark := MK.mat(Color(0.14, 0.15, 0.17), "", 0.6)
	var hazard := MK.mat(Color(0.85, 0.7, 0.05), "", 0.5)
	# A sloping ramp path with handrails and yellow edge markings, down to the bay.
	_slab_path(root, -2.0, -30.0, -1.0, 3.0, Color(0.22, 0.23, 0.24))
	for sz in [-2.4, 0.4]:
		MK.box_from(root, Vector3(-3.0, 0.8, sz), Vector3(-30.0, 0.86, sz + 0.05), MK.mat(Color(0.8, 0.8, 0.78), "", 0.4, 1.0, 0.5))
		var px := -3.0
		while px > -30.0:
			MK.box(root, Vector3(0.05, 0.8, 0.05), Vector3(px, 0.4, sz + 0.025), MK.mat(Color(0.8, 0.8, 0.78), "", 0.4, 1.0, 0.5))
			px -= 3.0
	for sz in [-2.45, 0.45]:
		MK.box_from(root, Vector3(-2.0, 0.04, sz), Vector3(-30.0, 0.045, sz + 0.1), hazard)
	# Low block with a big flat canopy over the ambulance bay.
	MK.box_from(root, Vector3(-64.0, 0.0, -10.0), Vector3(-32.0, 7.0, 4.0), concrete)
	_window_grid(root, Vector3(-62.0, 3.8, 4.05), 12, 1, Vector2(1.6, 1.6), Vector2(0.8, 0.0), 0.65, Color(0.85, 1.0, 0.95), true, 9)
	_window_grid(root, Vector3(-62.0, 0.6, 4.05), 6, 1, Vector2(1.6, 1.6), Vector2(0.8, 0.0), 0.5, Color(0.85, 1.0, 0.95), true, 2)
	MK.box_from(root, Vector3(-52.0, 4.6, 3.0), Vector3(-32.0, 4.9, 14.0), concrete)             # canopy
	for cx in [-51.0, -33.0]:
		MK.cyl(root, 0.25, 0.25, 4.6, Vector3(cx, 2.3, 13.4), concrete, 6)
	MK.box(root, Vector3(10.0, 0.06, 2.0), Vector3(-42.0, 4.5, 9.0), MK.emissive(Color(0.85, 1.0, 1.0), 3.8, Color(0.6, 0.65, 0.65)))   # canopy underlight
	MK.omni(root, Vector3(-42.0, 4.0, 9.0), Color(0.85, 1.0, 1.0), 3.5, 16.0, false)
	# Double doors, bright inside.
	MK.box(root, Vector3(4.0, 2.6, 0.08), Vector3(-42.0, 1.5, 4.1), MK.emissive(Color(0.9, 1.0, 1.0), 3.0, Color(0.6, 0.65, 0.65)))
	MK.box(root, Vector3(0.1, 2.6, 0.1), Vector3(-42.0, 1.5, 4.12), dark)
	# The big red sign.
	MK.box(root, Vector3(10.0, 1.3, 0.3), Vector3(-42.0, 5.6, 4.2), MK.emissive(Color(1.0, 0.15, 0.1), 3.0, Color(0.3, 0.02, 0.02)))
	_sign(root, "ACCIDENT & EMERGENCY", Vector3(-42.0, 5.6, 4.4), Color(1, 1, 1), 0.2)
	# Hazard stripes on the kerb and an ambulance parked in the bay.
	for i in 14:
		MK.box(root, Vector3(0.8, 0.01, 0.35), Vector3(-36.0 - i * 0.9, 0.035, 8.5), hazard if i % 2 == 0 else dark)
	var amb := Node3D.new()
	amb.position = Vector3(-48.0, 0, 9.0)
	root.add_child(amb)
	MK.box(amb, Vector3(5.0, 2.2, 2.0), Vector3(0, 1.4, 0), MK.mat(Color(0.92, 0.92, 0.88), "", 0.5))
	MK.box(amb, Vector3(1.6, 1.4, 1.9), Vector3(3.0, 1.0, 0), MK.mat(Color(0.9, 0.9, 0.86), "", 0.5))
	MK.box(amb, Vector3(5.0, 0.3, 2.02), Vector3(0, 1.1, 0), MK.mat(Color(0.85, 0.8, 0.1), "", 0.5))
	MK.box(amb, Vector3(0.4, 0.15, 1.5), Vector3(0.5, 2.6, 0), MK.emissive(Color(0.2, 0.4, 1.0), 6.0, Color(0.05, 0.1, 0.3)))
	MK.omni(amb, Vector3(0.5, 2.8, 0), Color(0.3, 0.45, 1.0), 2.0, 9.0, false)
	for lx in [-10.0, -22.0]:
		_lamp(root, Vector3(lx, 0, 3.0), 5.0, Color(0.85, 0.95, 1.0), 2.4)
