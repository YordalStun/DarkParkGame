class_name BootItems
## Things you find in car boots (night three on): low-poly models, plus what each is worth.
## make(id) builds one with its origin on the floor under its middle, longest side along X.

## id -> [name, sells for (coins), risk added when you take it, inventory slots it takes]
const ITEMS := {
	"guitar": ["a guitar in a hard case", 6, 25, 2],
	"radio": ["a car radio", 4, 15, 1],
	"camera": ["a camera bag", 5, 20, 1],
	"briefcase": ["a briefcase", 5, 20, 1],
	"toolbox": ["a toolbox", 3, 15, 1],
	"shopping": ["a bag of shopping", 1, 5, 1],
	"camcorder": ["a camcorder", 7, 25, 1],
	"boombox": ["a ghetto blaster", 4, 15, 1],
	"records": ["a crate of records", 3, 10, 1],
	"golf": ["a bag of golf clubs", 6, 20, 2],
	"fishing": ["a fishing rod and tackle box", 3, 10, 2],
	"beer": ["a crate of beer", 2, 10, 1],
	"petrol": ["a can of petrol", 1, 10, 1],
	"battery": ["a car battery", 2, 10, 1],
	"holdall": ["a sports holdall", 2, 10, 1],
	"suitcase": ["a suitcase", 3, 15, 2],
	"typewriter": ["a typewriter", 3, 10, 1],
	"vcr": ["a video recorder", 5, 20, 1],
	"tv": ["a portable TV", 5, 20, 2],
	"cigs": ["a carton of cigarettes", 3, 15, 1],
}


## Big things (2 slots): fill your hands, take 2 spaces in the crate, and won't fit under the desk
## when you hide the crate (so the police or the supervisor can still see them).
static func is_big(id: String) -> bool:
	return int(info(id)[3]) >= 2


## What vans carry: tradesmen's and delivery gear. Worth more, and a lot riskier to take.
const VAN_LOOT := ["tv", "vcr", "camcorder", "toolbox", "boombox", "typewriter", "golf", "cigs", "briefcase", "camera"]


## Story things that can live in the crate too: never sold, never confiscated.
const STORY := {
	"newsletter": ["Doris's newsletter", 0, 0, 1],
}


## [name, value, risk, slots] for a boot item or a story item.
static func info(id: String) -> Array:
	if ITEMS.has(id):
		return ITEMS[id]
	return STORY.get(id, [id, 0, 0, 1])


static func is_story(id: String) -> bool:
	return STORY.has(id)


static func make(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Item_" + id
	match id:
		"guitar": _guitar(n)
		"radio": _radio(n)
		"camera": _camera(n)
		"briefcase": _briefcase(n)
		"toolbox": _toolbox(n)
		"camcorder": _camcorder(n)
		"boombox": _boombox(n)
		"records": _records(n)
		"golf": _golf(n)
		"fishing": _fishing(n)
		"beer": _beer(n)
		"petrol": _petrol(n)
		"battery": _battery(n)
		"holdall": _holdall(n)
		"suitcase": _suitcase(n)
		"typewriter": _typewriter(n)
		"vcr": _vcr(n)
		"tv": _tv(n)
		"cigs": _cigs(n)
		_: _shopping(n)
	return n


static func _guitar(n: Node3D) -> void:
	var tolex := MK.mat(Color(0.06, 0.06, 0.07), "", 0.75)
	var plush := MK.mat(Color(0.45, 0.06, 0.1), "", 1.0)
	var chrome := MK.mat(Color(0.75, 0.75, 0.72), "", 0.2, 1.0, 0.9)
	# A hard case: a big round lower bout, a smaller upper bout, a long neck. Lying flat.
	var b1 := MK.cyl(n, 0.2, 0.2, 0.11, Vector3(-0.3, 0.055, 0), tolex, 16)
	b1.scale = Vector3(1.0, 1.0, 0.92)
	MK.cyl(n, 0.16, 0.16, 0.11, Vector3(-0.02, 0.055, 0), tolex, 16)
	MK.box(n, Vector3(0.6, 0.09, 0.11), Vector3(0.42, 0.045, 0), tolex)
	MK.box(n, Vector3(0.14, 0.09, 0.17), Vector3(0.76, 0.045, 0), tolex)   # headstock end
	# Seam, latches, handle.
	MK.box(n, Vector3(1.3, 0.012, 0.005), Vector3(0.18, 0.06, 0.205), chrome)
	for x in [-0.36, 0.1, 0.5]:
		MK.box(n, Vector3(0.05, 0.03, 0.02), Vector3(x, 0.06, 0.2 if x < 0.3 else 0.06), chrome)
	MK.box(n, Vector3(0.14, 0.03, 0.03), Vector3(-0.1, 0.115, 0.1), MK.mat(Color(0.1, 0.1, 0.1), "", 0.5))
	MK.box(n, Vector3(0.1, 0.004, 0.06), Vector3(-0.32, 0.111, -0.05), plush)   # a bit of lining showing


static func _radio(n: Node3D) -> void:
	var case := MK.mat(Color(0.12, 0.12, 0.13), "metal", 0.4, 1.0, 0.6)
	var face := MK.mat(Color(0.05, 0.05, 0.05), "", 0.4)
	var chrome := MK.mat(Color(0.7, 0.7, 0.7), "", 0.2, 1.0, 0.9)
	MK.box(n, Vector3(0.18, 0.05, 0.16), Vector3(0, 0.025, 0), case)            # the DIN box
	MK.box(n, Vector3(0.19, 0.055, 0.012), Vector3(0, 0.0275, 0.085), face)    # front
	MK.box(n, Vector3(0.08, 0.016, 0.004), Vector3(0.02, 0.036, 0.092), MK.emissive(Color(0.2, 0.9, 0.5), 0.6, Color(0.05, 0.2, 0.1)))
	MK.box(n, Vector3(0.09, 0.008, 0.004), Vector3(0.02, 0.016, 0.092), MK.mat(Color(0.02, 0.02, 0.02), "", 0.5))  # tape slot
	for x in [-0.075, 0.075]:
		MK.cyl(n, 0.012, 0.012, 0.014, Vector3(x, 0.028, 0.095), chrome, 10, Vector3(90, 0, 0))
	for i in 4:
		MK.box(n, Vector3(0.012, 0.006, 0.004), Vector3(-0.03 + i * 0.02, 0.008, 0.092), chrome)
	# Wires hanging out the back where it was pulled from a dash.
	for c in [Color(0.8, 0.1, 0.1), Color(0.9, 0.8, 0.1), Color(0.1, 0.1, 0.1)]:
		MK.box(n, Vector3(0.005, 0.005, 0.08), Vector3(randf_range(-0.04, 0.04), 0.01, -0.11), MK.mat(c, "", 0.6))


static func _camera(n: Node3D) -> void:
	var nylon := MK.mat(Color(0.12, 0.14, 0.2), "", 0.9)
	var trim := MK.mat(Color(0.05, 0.05, 0.05), "", 0.7)
	MK.box(n, Vector3(0.3, 0.2, 0.17), Vector3(0, 0.1, 0), nylon)
	MK.box(n, Vector3(0.31, 0.03, 0.18), Vector3(0, 0.2, 0), trim)                     # lid edge
	MK.box(n, Vector3(0.31, 0.12, 0.01), Vector3(0, 0.16, 0.09), nylon, Vector3(-6, 0, 0))  # flap
	MK.box(n, Vector3(0.08, 0.03, 0.004), Vector3(0, 0.14, 0.097), MK.mat(Color(0.9, 0.75, 0.2), "", 0.4))  # badge
	for x in [-0.15, 0.15]:
		MK.box(n, Vector3(0.02, 0.12, 0.03), Vector3(x, 0.17, 0), trim)
	MK.box(n, Vector3(0.32, 0.015, 0.03), Vector3(0, 0.235, 0), trim, Vector3(0, 0, 4))      # strap


static func _briefcase(n: Node3D) -> void:
	var hide := MK.mat(Color(0.32, 0.17, 0.08), "", 0.45)
	var brass := MK.mat(Color(0.8, 0.65, 0.3), "", 0.25, 1.0, 0.9)
	MK.box(n, Vector3(0.44, 0.09, 0.32), Vector3(0, 0.045, 0), hide)
	MK.box(n, Vector3(0.445, 0.006, 0.325), Vector3(0, 0.06, 0), MK.mat(Color(0.2, 0.1, 0.05), "", 0.5))  # lid line
	for x in [-0.14, 0.14]:
		MK.box(n, Vector3(0.035, 0.03, 0.01), Vector3(x, 0.065, 0.163), brass)
	MK.box(n, Vector3(0.12, 0.02, 0.025), Vector3(0, 0.095, 0.15), MK.mat(Color(0.15, 0.08, 0.04), "", 0.5))   # handle


static func _toolbox(n: Node3D) -> void:
	var red := MK.mat(Color(0.7, 0.08, 0.05), "metal", 0.4, 1.0, 0.5)
	var steel := MK.mat(Color(0.6, 0.6, 0.6), "metal", 0.3, 1.0, 0.8)
	MK.box(n, Vector3(0.42, 0.16, 0.2), Vector3(0, 0.08, 0), red)
	MK.taper(n, Vector3(0.42, 0.05, 0.2), 0.3, 0.0, Vector3(0, 0.185, 0), red)   # sloped lid
	MK.box(n, Vector3(0.24, 0.02, 0.02), Vector3(0, 0.23, 0), steel)                  # handle
	for x in [-0.1, 0.1]:
		MK.box(n, Vector3(0.02, 0.04, 0.02), Vector3(x, 0.215, 0), steel)
	MK.box(n, Vector3(0.05, 0.03, 0.01), Vector3(0, 0.14, 0.104), steel)               # catch
	MK.box(n, Vector3(0.12, 0.012, 0.012), Vector3(0.12, 0.165, 0.09), MK.mat(Color(0.75, 0.6, 0.2), "", 0.4), Vector3(0, 0, 20))  # screwdriver poking out


static func _shopping(n: Node3D) -> void:
	var bag := MK.mat(Color(0.88, 0.88, 0.84), "", 0.9)
	MK.taper(n, Vector3(0.26, 0.24, 0.16), 0.3, 0.0, Vector3(0, 0.12, 0), bag)
	MK.box(n, Vector3(0.12, 0.06, 0.004), Vector3(0, 0.13, 0.081), MK.mat(Color(0.1, 0.35, 0.7), "", 0.6))   # shop logo
	MK.box(n, Vector3(0.16, 0.08, 0.1), Vector3(-0.04, 0.28, 0), MK.mat(Color(0.82, 0.62, 0.35), "", 0.9))     # a loaf
	MK.cyl(n, 0.03, 0.03, 0.16, Vector3(0.07, 0.3, 0.02), MK.mat(Color(0.2, 0.45, 0.2), "", 0.2), 8)          # a bottle
	MK.cyl(n, 0.012, 0.016, 0.04, Vector3(0.07, 0.4, 0.02), MK.mat(Color(0.7, 0.6, 0.2), "", 0.3), 6)
	for x in [-0.08, 0.08]:
		MK.box(n, Vector3(0.015, 0.07, 0.01), Vector3(x, 0.27, 0.06), bag, Vector3(0, 0, 25 if x < 0 else -25))


static func _black() -> StandardMaterial3D:
	return MK.mat(Color(0.06, 0.06, 0.06), "", 0.5)


static func _chrome() -> StandardMaterial3D:
	return MK.mat(Color(0.72, 0.72, 0.7), "", 0.2, 1.0, 0.9)


static func _camcorder(n: Node3D) -> void:
	var body := MK.mat(Color(0.15, 0.15, 0.16), "", 0.45)
	MK.box(n, Vector3(0.32, 0.13, 0.11), Vector3(0, 0.065, 0), body)
	MK.cyl(n, 0.045, 0.05, 0.1, Vector3(0.2, 0.08, 0), _black(), 12, Vector3(0, 0, 90))      # lens
	MK.cyl(n, 0.04, 0.04, 0.005, Vector3(0.252, 0.08, 0), MK.mat(Color(0.1, 0.2, 0.35), "", 0.05, 1.0, 0.5), 12, Vector3(0, 0, 90))
	MK.box(n, Vector3(0.1, 0.04, 0.04), Vector3(-0.17, 0.12, 0.03), _black())              # viewfinder
	MK.box(n, Vector3(0.22, 0.025, 0.03), Vector3(0.02, 0.145, 0), _black())                # handle
	MK.box(n, Vector3(0.008, 0.008, 0.008), Vector3(0.12, 0.1, 0.056), MK.emissive(Color(1, 0.1, 0.05), 2.0))
	MK.box(n, Vector3(0.12, 0.02, 0.003), Vector3(-0.04, 0.05, 0.056), MK.mat(Color(0.8, 0.8, 0.78), "", 0.4))   # "VHS-C" label


static func _boombox(n: Node3D) -> void:
	var grey := MK.mat(Color(0.55, 0.56, 0.58), "metal", 0.35, 1.0, 0.6)
	MK.box(n, Vector3(0.5, 0.24, 0.12), Vector3(0, 0.12, 0), grey)
	for x in [-0.16, 0.16]:
		MK.cyl(n, 0.08, 0.08, 0.01, Vector3(x, 0.11, 0.062), _black(), 14, Vector3(90, 0, 0))
		MK.cyl(n, 0.025, 0.025, 0.012, Vector3(x, 0.11, 0.064), _chrome(), 10, Vector3(90, 0, 0))
	MK.box(n, Vector3(0.14, 0.08, 0.008), Vector3(0, 0.12, 0.062), _black())                 # tape deck
	MK.box(n, Vector3(0.44, 0.03, 0.03), Vector3(0, 0.27, 0), _chrome())                       # handle
	MK.box(n, Vector3(0.12, 0.02, 0.006), Vector3(0, 0.205, 0.062), MK.emissive(Color(1, 0.55, 0.15), 0.4, Color(0.4, 0.2, 0.05)))   # dial


static func _records(n: Node3D) -> void:
	var wood := MK.mat(Color(0.55, 0.42, 0.25), "", 0.8)
	MK.box(n, Vector3(0.34, 0.03, 0.34), Vector3(0, 0.015, 0), wood)
	for x in [-0.165, 0.165]:
		MK.box(n, Vector3(0.015, 0.24, 0.34), Vector3(x, 0.12, 0), wood)
	MK.box(n, Vector3(0.34, 0.12, 0.015), Vector3(0, 0.06, 0.165), wood)
	var cols := [Color(0.8, 0.2, 0.15), Color(0.15, 0.3, 0.7), Color(0.9, 0.8, 0.2), Color(0.1, 0.1, 0.1), Color(0.85, 0.85, 0.8), Color(0.3, 0.6, 0.3)]
	for i in 9:
		MK.box(n, Vector3(0.31, 0.31, 0.008), Vector3(0, 0.17, -0.14 + i * 0.033), MK.mat(cols[i % cols.size()], "", 0.6), Vector3(randf_range(-4, 4), 0, 0))


static func _golf(n: Node3D) -> void:
	var bag := MK.mat(Color(0.12, 0.3, 0.18), "", 0.6)
	var cream := MK.mat(Color(0.88, 0.85, 0.75), "", 0.5)
	MK.cyl(n, 0.11, 0.12, 0.85, Vector3(0, 0.12, 0), bag, 12, Vector3(0, 0, 90))
	MK.cyl(n, 0.122, 0.122, 0.04, Vector3(0.38, 0.12, 0), cream, 12, Vector3(0, 0, 90))
	for i in 5:
		var a := i * TAU / 5.0
		MK.box(n, Vector3(0.14, 0.04, 0.05), Vector3(0.5, 0.12 + sin(a) * 0.06, cos(a) * 0.06), _chrome() if i % 2 == 0 else MK.mat(Color(0.5, 0.35, 0.2), "", 0.4))
	MK.box(n, Vector3(0.5, 0.02, 0.03), Vector3(0, 0.24, 0), cream)   # strap


static func _fishing(n: Node3D) -> void:
	var green := MK.mat(Color(0.3, 0.45, 0.3), "", 0.5)
	MK.box(n, Vector3(0.3, 0.14, 0.17), Vector3(-0.15, 0.07, 0), green)                 # tackle box
	MK.box(n, Vector3(0.1, 0.02, 0.02), Vector3(-0.15, 0.15, 0), _black())
	MK.cyl(n, 0.012, 0.006, 1.1, Vector3(0.3, 0.03, 0.12), MK.mat(Color(0.2, 0.2, 0.25), "", 0.3), 6, Vector3(0, 0, 90))   # rod
	MK.cyl(n, 0.035, 0.035, 0.03, Vector3(-0.15, 0.05, 0.12), _chrome(), 10, Vector3(90, 0, 0))   # reel
	MK.cyl(n, 0.02, 0.02, 0.18, Vector3(-0.24, 0.03, 0.12), MK.mat(Color(0.5, 0.35, 0.2), "", 0.6), 8, Vector3(0, 0, 90))    # handle


static func _beer(n: Node3D) -> void:
	var crate := MK.mat(Color(0.75, 0.55, 0.1), "", 0.6)
	MK.box(n, Vector3(0.34, 0.14, 0.24), Vector3(0, 0.07, 0), crate)
	var brown := MK.mat(Color(0.35, 0.2, 0.05), "", 0.1)
	for ix in 4:
		for iz in 3:
			MK.cyl(n, 0.025, 0.025, 0.14, Vector3(-0.12 + ix * 0.08, 0.2, -0.075 + iz * 0.075), brown, 8)
			MK.cyl(n, 0.014, 0.014, 0.01, Vector3(-0.12 + ix * 0.08, 0.275, -0.075 + iz * 0.075), _chrome(), 6)


static func _petrol(n: Node3D) -> void:
	var red := MK.mat(Color(0.72, 0.1, 0.06), "metal", 0.4, 1.0, 0.5)
	MK.box(n, Vector3(0.3, 0.34, 0.14), Vector3(0, 0.17, 0), red)
	MK.box(n, Vector3(0.14, 0.03, 0.04), Vector3(-0.05, 0.36, 0), red)                   # handles
	MK.cyl(n, 0.025, 0.025, 0.06, Vector3(0.1, 0.36, 0), _black(), 8, Vector3(0, 0, -30))   # spout cap
	MK.box(n, Vector3(0.24, 0.24, 0.005), Vector3(0, 0.17, 0.072), MK.mat(Color(0.6, 0.08, 0.05), "metal", 0.4, 1.0, 0.5))


static func _battery(n: Node3D) -> void:
	MK.box(n, Vector3(0.26, 0.18, 0.17), Vector3(0, 0.09, 0), _black())
	MK.box(n, Vector3(0.26, 0.02, 0.17), Vector3(0, 0.19, 0), MK.mat(Color(0.9, 0.85, 0.75), "", 0.5))
	MK.cyl(n, 0.015, 0.015, 0.03, Vector3(-0.09, 0.21, 0.05), MK.mat(Color(0.8, 0.1, 0.1), "", 0.4), 8)
	MK.cyl(n, 0.015, 0.015, 0.03, Vector3(0.09, 0.21, 0.05), _black(), 8)
	MK.box(n, Vector3(0.1, 0.05, 0.003), Vector3(0, 0.1, 0.086), MK.mat(Color(0.95, 0.75, 0.1), "", 0.5))


static func _holdall(n: Node3D) -> void:
	var blue := MK.mat(Color(0.15, 0.25, 0.55), "", 0.8)
	var b := MK.cyl(n, 0.13, 0.13, 0.5, Vector3(0, 0.12, 0), blue, 10, Vector3(0, 0, 90))
	b.scale = Vector3(1, 1, 0.85)
	MK.box(n, Vector3(0.46, 0.01, 0.02), Vector3(0, 0.25, 0), MK.mat(Color(0.8, 0.8, 0.8), "", 0.4))   # zip
	for x in [-0.08, 0.08]:
		MK.box(n, Vector3(0.03, 0.08, 0.02), Vector3(x, 0.28, 0.0), _black(), Vector3(0, 0, 20 if x < 0 else -20))
	MK.box(n, Vector3(0.16, 0.06, 0.003), Vector3(0.12, 0.12, 0.111), MK.mat(Color(0.95, 0.95, 0.9), "", 0.5))   # logo


static func _suitcase(n: Node3D) -> void:
	var tan := MK.mat(Color(0.62, 0.48, 0.3), "", 0.6)
	MK.box(n, Vector3(0.62, 0.2, 0.42), Vector3(0, 0.1, 0), tan)
	for z in [-0.12, 0.12]:
		MK.box(n, Vector3(0.63, 0.205, 0.04), Vector3(0, 0.1, z), MK.mat(Color(0.35, 0.22, 0.12), "", 0.6))   # straps
	MK.box(n, Vector3(0.15, 0.03, 0.03), Vector3(0, 0.215, 0.18), _black())
	MK.box(n, Vector3(0.08, 0.05, 0.003), Vector3(-0.2, 0.15, 0.212), MK.mat(Color(0.9, 0.85, 0.6), "", 0.6))   # luggage tag


static func _typewriter(n: Node3D) -> void:
	var case := MK.mat(Color(0.45, 0.6, 0.62), "", 0.4)
	MK.taper(n, Vector3(0.38, 0.1, 0.32), 0.38, 0.0, Vector3(0, 0.05, 0), case)
	MK.cyl(n, 0.03, 0.03, 0.42, Vector3(0, 0.12, -0.1), _black(), 10, Vector3(0, 0, 90))   # platen
	for i in 4:
		for j in 9:
			MK.box(n, Vector3(0.022, 0.01, 0.022), Vector3(-0.12 + j * 0.03, 0.105 + i * 0.008, 0.11 - i * 0.03), MK.mat(Color(0.9, 0.9, 0.85), "", 0.4))
	MK.box(n, Vector3(0.2, 0.12, 0.003), Vector3(0, 0.19, -0.1), MK.mat(Color(0.97, 0.97, 0.94), "", 0.8), Vector3(-10, 0, 0))   # paper


static func _vcr(n: Node3D) -> void:
	var silver := MK.mat(Color(0.6, 0.6, 0.62), "metal", 0.35, 1.0, 0.6)
	MK.box(n, Vector3(0.42, 0.09, 0.3), Vector3(0, 0.045, 0), silver)
	MK.box(n, Vector3(0.42, 0.09, 0.01), Vector3(0, 0.045, 0.152), _black())
	MK.box(n, Vector3(0.18, 0.02, 0.004), Vector3(-0.08, 0.06, 0.158), MK.mat(Color(0.15, 0.15, 0.15), "", 0.5))   # tape door
	MK.box(n, Vector3(0.08, 0.02, 0.004), Vector3(0.12, 0.06, 0.158), MK.emissive(Color(0.2, 0.9, 0.9), 0.5, Color(0.05, 0.25, 0.25)))  # clock
	for i in 5:
		MK.box(n, Vector3(0.018, 0.01, 0.004), Vector3(0.06 + i * 0.025, 0.025, 0.158), silver)


static func _tv(n: Node3D) -> void:
	var case := MK.mat(Color(0.82, 0.8, 0.74), "beige_plastic", 0.5, 0.4)
	MK.box(n, Vector3(0.3, 0.26, 0.26), Vector3(0, 0.13, 0), case)
	MK.box(n, Vector3(0.2, 0.16, 0.01), Vector3(-0.03, 0.14, 0.131), MK.mat(Color(0.08, 0.1, 0.1), "", 0.1, 1.0, 0.3))   # screen
	for i in 3:
		MK.cyl(n, 0.012, 0.012, 0.012, Vector3(0.11, 0.2 - i * 0.04, 0.132), _black(), 8, Vector3(90, 0, 0))
	MK.cyl(n, 0.003, 0.003, 0.3, Vector3(0.08, 0.38, -0.05), _chrome(), 4, Vector3(0, 0, -25))   # aerial
	MK.box(n, Vector3(0.12, 0.02, 0.02), Vector3(0, 0.27, 0), _black())   # handle


static func _cigs(n: Node3D) -> void:
	var white := MK.mat(Color(0.95, 0.95, 0.92), "", 0.6)
	var red := MK.mat(Color(0.75, 0.08, 0.06), "", 0.5)
	MK.box(n, Vector3(0.27, 0.05, 0.1), Vector3(0, 0.025, 0), white)
	MK.box(n, Vector3(0.27, 0.051, 0.04), Vector3(0, 0.025, 0.02), red)
	MK.box(n, Vector3(0.1, 0.003, 0.03), Vector3(-0.06, 0.051, -0.02), MK.mat(Color(0.8, 0.7, 0.3), "", 0.4))
