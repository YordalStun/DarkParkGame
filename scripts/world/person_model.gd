extends RefCounted
## A standing person for the car park, built from simple solids: feet at y=0, facing +Z, about
## 1.75 m tall. Describe them with a spec dictionary (see DESIGNS for examples) and optionally an
## umbrella style, held in the right hand.

const Umbrella := preload("res://scripts/world/umbrella.gd")

## Looks to choose from. coat: jacket (hip), mid (thigh), long (knee), scrubs (tunic over trousers).
const DESIGNS := {
	"nurse": {"label": "Nurse", "coat": "scrubs", "top": Color(0.16, 0.32, 0.5), "cardigan": Color(0.12, 0.17, 0.3), "trousers": Color(0.16, 0.32, 0.5),
		"shoes": Color(0.9, 0.9, 0.9), "skin": Color(0.9, 0.72, 0.6), "hair": Color(0.55, 0.32, 0.12), "hair_style": "bun", "lanyard": true, "umbrella": "clear"},
	"porter": {"label": "Porter", "coat": "jacket", "top": Color(0.42, 0.44, 0.46), "trousers": Color(0.2, 0.22, 0.26), "shoes": Color(0.1, 0.08, 0.06),
		"skin": Color(0.36, 0.24, 0.16), "hair": Color(0.05, 0.04, 0.03), "hair_style": "cap", "cap": Color(0.15, 0.17, 0.2), "vest": Color(0.9, 0.78, 0.1), "umbrella": "classic"},
	"registrar": {"label": "Registrar", "coat": "long", "top": Color(0.62, 0.5, 0.33), "trousers": Color(0.15, 0.15, 0.17), "shoes": Color(0.08, 0.06, 0.05),
		"skin": Color(0.92, 0.76, 0.66), "hair": Color(0.12, 0.1, 0.08), "hair_style": "long", "glasses": true, "bag": "briefcase", "umbrella": "striped"},
	"technician": {"label": "Technician", "coat": "mid", "top": Color(0.2, 0.34, 0.26), "trousers": Color(0.2, 0.2, 0.22), "shoes": Color(0.12, 0.1, 0.08),
		"skin": Color(0.85, 0.65, 0.52), "hair": Color(0.45, 0.42, 0.4), "hair_style": "beanie", "beanie": Color(0.55, 0.12, 0.1), "hood": true, "scarf": Color(0.5, 0.5, 0.48), "umbrella": "golf"},
	"pharmacist": {"label": "Pharmacist", "coat": "long", "top": Color(0.45, 0.22, 0.42), "trousers": Color(0.18, 0.16, 0.2), "shoes": Color(0.14, 0.1, 0.1),
		"skin": Color(0.95, 0.8, 0.7), "hair": Color(0.75, 0.72, 0.68), "hair_style": "long", "glasses": true, "scarf": Color(0.85, 0.8, 0.6), "bag": "tote", "umbrella": "yellow"},
	"guard": {"label": "Night guard (the odd one)", "coat": "long", "top": Color(0.12, 0.14, 0.2), "trousers": Color(0.1, 0.1, 0.12), "shoes": Color(0.05, 0.05, 0.05),
		"skin": Color(0.78, 0.78, 0.74), "hair": Color(0.3, 0.3, 0.3), "hair_style": "cap", "cap": Color(0.1, 0.11, 0.15), "umbrella": "tattered", "pale": true},
}


## Which design suits a person, from their role (falls back to the porter look).
## Open the umbrella this person carries (if any) after `delay` seconds, with the opening animation.
static func open_umbrella(person: Node3D, delay := 0.0) -> void:
	var um = person.get_meta("umbrella", null)
	if um != null:
		Umbrella.open_up(um as Node3D, delay)


static func design_for(person: Dictionary) -> String:
	var role: String = str(person.get("role", "")).to_lower()
	if role.contains("nurse"):
		return "nurse"
	if role.contains("registrar") or role.contains("doctor"):
		return "registrar"
	if role.contains("technician"):
		return "technician"
	if role.contains("pharmac"):
		return "pharmacist"
	if role.contains("security"):
		return "guard"
	return "porter"


## A walker for one of the night's arrivals: the matching design, wearing their own skin, hair
## and glasses so each person is still recognisably themselves.
static func from_arrival(person: Dictionary, with_umbrella: bool) -> Node3D:
	var key := design_for(person)
	var spec: Dictionary = (DESIGNS[key] as Dictionary).duplicate()
	for k in ["skin", "hair", "hair_style", "glasses", "moustache"]:
		if person.has(k):
			spec[k] = person[k]
	if person.has("shirt") and key not in ["nurse", "guard"]:
		spec["top"] = (person.shirt as Color).lerp(spec.top, 0.5)
	return build(spec, spec.umbrella if with_umbrella else "")


static func build(spec: Dictionary, umbrella := "") -> Node3D:
	var p := Node3D.new()
	p.name = "Person"
	var skin := MK.mat(spec.get("skin", Color(0.85, 0.66, 0.52)), "", 0.8)
	var hair := MK.mat(spec.get("hair", Color(0.2, 0.14, 0.08)), "", 0.95)
	var top_c: Color = spec.get("top", Color(0.25, 0.3, 0.45))
	var coat := MK.mat(top_c, "", 0.9)
	var coat_dark := MK.mat(top_c.darkened(0.25), "", 0.9)
	var trousers := MK.mat(spec.get("trousers", Color(0.15, 0.15, 0.18)), "", 0.85)
	var shoes := MK.mat(spec.get("shoes", Color(0.08, 0.06, 0.05)), "", 0.4)
	var kind: String = spec.get("coat", "jacket")

	# Legs and shoes, each hanging from a hip pivot so a walker can swing them.
	for side in [["LegL", -0.085], ["LegR", 0.085]]:
		var leg := Node3D.new()
		leg.name = side[0]
		leg.position = Vector3(side[1], 0.9, 0)
		p.add_child(leg)
		MK.cyl(leg, 0.052, 0.062, 0.8, Vector3(0, -0.43, 0), trousers, 7)
		MK.box(leg, Vector3(0.1, 0.07, 0.25), Vector3(0, -0.865, 0.05), shoes)
		MK.box(leg, Vector3(0.1, 0.035, 0.1), Vector3(0, -0.825, 0.12), shoes)

	# Body: hips, then the coat or tunic, then the shoulders.
	var hem: float = {"jacket": 0.72, "mid": 0.52, "long": 0.32, "scrubs": 0.62}[kind]
	var top_y := 1.47
	var hip_y := 0.95
	MK.taper(p, Vector3(0.42, top_y - hip_y, 0.24), 0.5, 0.0, Vector3(0, (top_y + hip_y) * 0.5, 0), coat)
	if hem < hip_y:
		var h: float = hip_y - hem
		MK.taper(p, Vector3(0.5, h, 0.3), 0.42, 0.0, Vector3(0, hip_y - h * 0.5, 0), coat_dark, Vector3.ZERO, 0.24)
		MK.box(p, Vector3(0.015, h * 0.96, 0.31), Vector3(0, hip_y - h * 0.5, 0), MK.mat(Color(0.05, 0.05, 0.05), "", 0.8))   # front opening / buttons line
	if spec.has("cardigan"):
		var card := MK.mat(spec.cardigan, "", 0.95)
		MK.taper(p, Vector3(0.45, 0.5, 0.26), 0.52, 0.0, Vector3(0, 1.22, 0), card)
		MK.box(p, Vector3(0.14, 0.4, 0.02), Vector3(0, 1.24, 0.135), coat)   # tunic showing between the cardigan fronts
	if spec.has("vest"):
		var vest := MK.mat(spec.vest, "", 0.7)
		MK.taper(p, Vector3(0.45, 0.5, 0.26), 0.5, 0.0, Vector3(0, 1.22, 0), vest)
		MK.box(p, Vector3(0.46, 0.04, 0.27), Vector3(0, 1.1, 0), MK.mat(Color(0.75, 0.75, 0.78), "", 0.4, 1.0, 0.3))
		MK.box(p, Vector3(0.46, 0.04, 0.27), Vector3(0, 1.32, 0), MK.mat(Color(0.75, 0.75, 0.78), "", 0.4, 1.0, 0.3))
	MK.box(p, Vector3(0.52, 0.1, 0.25), Vector3(0, top_y - 0.03, 0), coat)   # shoulders
	if spec.get("lanyard", false):
		MK.box(p, Vector3(0.025, 0.36, 0.01), Vector3(0, 1.3, 0.14), MK.mat(Color(0.6, 0.1, 0.1), "", 0.6))
		MK.box(p, Vector3(0.07, 0.09, 0.012), Vector3(0, 1.1, 0.14), MK.mat(Color(0.92, 0.92, 0.9), "", 0.5))

	# Head, neck, face.
	var pale: bool = spec.get("pale", false)
	MK.cyl(p, 0.05, 0.055, 0.1, Vector3(0, 1.53, 0), skin, 8)
	var head := MK.sphere(p, 0.11, Vector3(0, 1.66, 0.01), skin, 10, 8)
	head.scale = Vector3(0.88, 1.12, 0.98)
	MK.box(p, Vector3(0.03, 0.045, 0.035), Vector3(0, 1.645, 0.115), skin)                      # nose
	var eye := MK.mat(Color(0.03, 0.03, 0.03) if not pale else Color(0.0, 0.0, 0.0), "", 0.3)
	for sx in [-0.04, 0.04]:
		MK.box(p, Vector3(0.022, 0.014 if not pale else 0.03, 0.01), Vector3(sx, 1.69, 0.1), eye)
		MK.box(p, Vector3(0.04, 0.008, 0.01), Vector3(sx, 1.715, 0.1), hair)                    # brow
	MK.box(p, Vector3(0.05, 0.008, 0.01), Vector3(0, 1.6, 0.1), MK.mat(Color(0.5, 0.25, 0.25), "", 0.6))   # mouth
	if spec.get("glasses", false):
		var gl := MK.mat(Color(0.55, 0.58, 0.62), "", 0.2, 1.0, 0.7)
		for sx in [-0.042, 0.042]:
			MK.box(p, Vector3(0.062, 0.045, 0.01), Vector3(sx, 1.69, 0.108), gl)
		MK.box(p, Vector3(0.03, 0.01, 0.01), Vector3(0, 1.695, 0.108), gl)
	if spec.get("moustache", false):
		MK.box(p, Vector3(0.07, 0.014, 0.02), Vector3(0, 1.625, 0.112), hair)

	# Hair and headwear.
	var style: String = spec.get("hair_style", "short")
	match style:
		"long":
			var back := MK.sphere(p, 0.118, Vector3(0, 1.69, -0.015), hair, 10, 8)
			back.scale = Vector3(0.95, 1.1, 0.95)
			MK.box(p, Vector3(0.22, 0.3, 0.09), Vector3(0, 1.52, -0.085), hair)
		"bun":
			var cap := MK.sphere(p, 0.116, Vector3(0, 1.7, -0.01), hair, 10, 8)
			cap.scale = Vector3(0.92, 0.85, 1.0)
			MK.sphere(p, 0.05, Vector3(0, 1.78, -0.08), hair, 8, 6)
		"bald":
			pass
		"cap":
			var cap2 := MK.sphere(p, 0.115, Vector3(0, 1.69, -0.01), hair, 10, 8)
			cap2.scale = Vector3(0.92, 0.7, 1.0)
			var cc := MK.mat(spec.get("cap", Color(0.15, 0.15, 0.18)), "", 0.7)
			MK.cyl(p, 0.118, 0.122, 0.05, Vector3(0, 1.755, 0.0), cc, 10)
			MK.box(p, Vector3(0.18, 0.012, 0.1), Vector3(0, 1.74, 0.13), cc, Vector3(8, 0, 0))   # peak
		"beanie":
			var bc := MK.mat(spec.get("beanie", Color(0.5, 0.1, 0.1)), "", 0.95)
			var bn := MK.sphere(p, 0.122, Vector3(0, 1.71, -0.005), bc, 10, 8)
			bn.scale = Vector3(0.95, 0.85, 1.0)
			MK.sphere(p, 0.03, Vector3(0, 1.82, 0.0), bc, 6, 4)
		_:
			var cap3 := MK.sphere(p, 0.114, Vector3(0, 1.7, -0.012), hair, 10, 8)
			cap3.scale = Vector3(0.92, 0.8, 1.0)
	if spec.get("hood", false):
		# Hood down around the back of the neck.
		var hood := MK.sphere(p, 0.13, Vector3(0, 1.58, -0.1), coat, 8, 6)
		hood.scale = Vector3(1.15, 0.7, 0.8)
	if spec.has("scarf"):
		var sc := MK.mat(spec.scarf, "", 0.95)
		MK.cyl(p, 0.085, 0.095, 0.09, Vector3(0, 1.49, 0.005), sc, 8)
		MK.box(p, Vector3(0.07, 0.24, 0.025), Vector3(0.04, 1.36, 0.125), sc)

	# Arms. Left hangs (or carries a bag); right is raised to the umbrella if there is one.
	var sleeve := coat if kind != "scrubs" else MK.mat(spec.get("cardigan", top_c), "", 0.9)
	MK.box(p, Vector3(0.1, 0.34, 0.11), Vector3(-0.3, 1.27, 0.0), sleeve, Vector3(0, 0, -4))
	MK.box(p, Vector3(0.09, 0.3, 0.1), Vector3(-0.32, 0.98, 0.03), sleeve, Vector3(-6, 0, -2))
	MK.sphere(p, 0.05, Vector3(-0.33, 0.8, 0.05), skin, 6, 4)
	var bag: String = spec.get("bag", "")
	if bag == "briefcase":
		MK.box(p, Vector3(0.07, 0.3, 0.42), Vector3(-0.34, 0.62, 0.05), MK.mat(Color(0.25, 0.14, 0.07), "", 0.5))
	elif bag == "tote":
		MK.box(p, Vector3(0.1, 0.32, 0.34), Vector3(-0.35, 0.62, 0.05), MK.mat(Color(0.8, 0.75, 0.6), "", 0.9))
	if umbrella != "":
		MK.box(p, Vector3(0.1, 0.3, 0.1), Vector3(0.29, 1.3, 0.05), sleeve, Vector3(-20, 0, 8))       # upper arm out
		MK.box(p, Vector3(0.09, 0.3, 0.09), Vector3(0.3, 1.2, 0.17), sleeve, Vector3(-60, 0, 0))       # forearm up
		var hand_pos := Vector3(0.3, 1.27, 0.27)
		MK.sphere(p, 0.05, hand_pos, skin, 6, 4)
		var um := Umbrella.build(umbrella)
		um.position = hand_pos - Vector3(0.0, 0.3, 0.0)
		um.rotation_degrees = Vector3(0, 0, 0)
		# Move the canopy over the head: the pole leans in a little.
		um.position.x = 0.3
		p.add_child(um)
		um.rotation_degrees = Vector3(0, 0, 17.0)
		p.set_meta("umbrella", um)
	else:
		MK.box(p, Vector3(0.1, 0.34, 0.11), Vector3(0.3, 1.27, 0.0), sleeve, Vector3(0, 0, 4))
		MK.box(p, Vector3(0.09, 0.3, 0.1), Vector3(0.32, 0.98, 0.03), sleeve, Vector3(-6, 0, 2))
		MK.sphere(p, 0.05, Vector3(0.33, 0.8, 0.05), skin, 6, 4)
	return p
