extends RefCounted
## The four guards a player can be. From night three up to four people can share the shift, so each
## has a different look and a colour (armband, cap or beanie, name tag) to tell them apart at a
## glance, even from a distance in the dark.
##
##   var g := PlayerModel.build(0)       # player 1: blue
##   PlayerModel.set_torch(g, true)      # their torch beam
##   PlayerModel.walk(g, t, moving)      # call every frame to swing the legs
##
## Built on PersonModel: standing figure, feet at y=0, facing +Z, about 1.75 m tall.

const Person := preload("res://scripts/world/person_model.gd")

const DESIGNS := [
	{"name": "Guard 1", "colour": "Blue", "accent": Color(0.2, 0.45, 1.0),
		"spec": {"coat": "jacket", "top": Color(0.13, 0.17, 0.3), "trousers": Color(0.1, 0.11, 0.16), "shoes": Color(0.05, 0.05, 0.05),
			"skin": Color(0.88, 0.7, 0.58), "hair": Color(0.2, 0.14, 0.08), "hair_style": "cap", "cap": Color(0.1, 0.13, 0.25)}},
	{"name": "Guard 2", "colour": "Orange", "accent": Color(1.0, 0.55, 0.1),
		"spec": {"coat": "jacket", "top": Color(0.2, 0.2, 0.22), "trousers": Color(0.14, 0.14, 0.16), "shoes": Color(0.15, 0.1, 0.06),
			"skin": Color(0.36, 0.24, 0.16), "hair": Color(0.05, 0.04, 0.03), "hair_style": "beanie", "beanie": Color(0.9, 0.45, 0.08),
			"vest": Color(1.0, 0.5, 0.08), "glasses": true}},
	{"name": "Guard 3", "colour": "Green", "accent": Color(0.2, 0.8, 0.35),
		"spec": {"coat": "mid", "top": Color(0.2, 0.3, 0.2), "trousers": Color(0.16, 0.17, 0.15), "shoes": Color(0.1, 0.08, 0.06),
			"skin": Color(0.95, 0.8, 0.7), "hair": Color(0.55, 0.3, 0.12), "hair_style": "ponytail", "hood": true}},
	{"name": "Guard 4", "colour": "Red", "accent": Color(0.9, 0.15, 0.12),
		"spec": {"coat": "long", "top": Color(0.18, 0.17, 0.17), "trousers": Color(0.09, 0.09, 0.1), "shoes": Color(0.04, 0.04, 0.04),
			"skin": Color(0.78, 0.6, 0.46), "hair": Color(0.12, 0.1, 0.08), "hair_style": "bald", "beard": true, "scarf": Color(0.85, 0.15, 0.12)}},
]


static func build(index: int, with_torch := true) -> Node3D:
	var d: Dictionary = DESIGNS[index % DESIGNS.size()]
	var accent: Color = d.accent
	var g := Person.build(d.spec, "")
	g.name = "Player%d" % (index + 1)
	var acc := MK.mat(accent, "", 0.5)
	var glow := MK.emissive(accent, 2.0, accent.darkened(0.5))
	var dark := MK.mat(Color(0.06, 0.06, 0.07), "", 0.5, 1.0, 0.2)
	var metal := MK.mat(Color(0.6, 0.6, 0.62), "", 0.3, 1.0, 0.7)

	# Utility belt with a buckle, and a pouch.
	MK.box(g, Vector3(0.45, 0.06, 0.27), Vector3(0, 0.97, 0), dark)
	MK.box(g, Vector3(0.06, 0.05, 0.02), Vector3(0, 0.97, 0.14), metal)
	MK.box(g, Vector3(0.09, 0.1, 0.07), Vector3(0.2, 0.93, 0.02), dark)
	# Shoulder radio with a short aerial and a little LED, and a badge on the chest.
	MK.box(g, Vector3(0.06, 0.1, 0.04), Vector3(-0.15, 1.38, 0.13), dark)
	MK.box(g, Vector3(0.012, 0.1, 0.012), Vector3(-0.17, 1.48, 0.13), dark)
	MK.box(g, Vector3(0.015, 0.015, 0.01), Vector3(-0.13, 1.42, 0.155), glow)
	MK.box(g, Vector3(0.05, 0.06, 0.012), Vector3(0.13, 1.35, 0.135), MK.mat(Color(0.85, 0.7, 0.2), "", 0.3, 1.0, 0.6))
	# Armbands (both upper arms) and an accent stripe down the trouser leg: the colour code.
	MK.box(g, Vector3(0.115, 0.07, 0.125), Vector3(-0.3, 1.3, 0.0), acc, Vector3(0, 0, -4))
	MK.box(g, Vector3(0.115, 0.07, 0.125), Vector3(0.3, 1.3, 0.0), acc, Vector3(0, 0, 4))
	for leg in ["LegL", "LegR"]:
		var lg := g.get_node(leg) as Node3D
		MK.box(lg, Vector3(0.012, 0.5, 0.04), Vector3(0.056 * (-1.0 if leg == "LegL" else 1.0), -0.45, 0.0), acc)
	# A band round the cap or beanie so the colour reads from above and from behind.
	MK.box(g, Vector3(0.235, 0.025, 0.235), Vector3(0, 1.735, 0.0), acc)
	# Player number on the back of the coat.
	var l := Label3D.new()
	l.text = str(index + 1)
	l.font_size = 64
	l.pixel_size = 0.0022
	l.modulate = accent.lightened(0.3)
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0)
	l.shaded = false
	l.double_sided = false
	l.position = Vector3(0, 1.22, -0.131)
	l.rotation_degrees.y = 180.0
	g.add_child(l)

	if with_torch:
		# A torch in the hanging left hand, pointing forward, with a beam that starts off.
		var torch := Node3D.new()
		torch.name = "Torch"
		torch.position = Vector3(-0.33, 0.8, 0.08)
		g.add_child(torch)
		MK.cyl(torch, 0.028, 0.028, 0.2, Vector3(0, 0, 0.06), dark, 8, Vector3(90, 0, 0))
		MK.cyl(torch, 0.04, 0.03, 0.05, Vector3(0, 0, 0.17), metal, 8, Vector3(90, 0, 0))
		MK.sphere(torch, 0.028, Vector3(0, 0, 0.19), MK.emissive(Color(1.0, 0.95, 0.8), 5.0, Color(0.6, 0.6, 0.5)), 6, 4)
		var beam := SpotLight3D.new()
		beam.name = "TorchBeam"
		beam.position = Vector3(0, 0, 0.2)
		beam.rotation_degrees = Vector3(0, 180, 0)   # spots shine along -Z; turn it to face the front
		beam.light_color = Color(1.0, 0.95, 0.8)
		beam.light_energy = 4.0
		beam.spot_range = 18.0
		beam.spot_angle = 22.0
		beam.shadow_enabled = false
		beam.visible = false
		torch.add_child(beam)
	g.set_meta("accent", accent)
	return g


static func set_torch(g: Node3D, on: bool) -> void:
	var beam := g.get_node_or_null("Torch/TorchBeam") as Node3D
	if beam:
		beam.visible = on


## Swings the legs. Call every frame with a steadily increasing time; moving=false stands still.
static func walk(g: Node3D, t: float, moving: bool) -> void:
	var swing := sin(t * 8.0) * 0.5 if moving else 0.0
	(g.get_node("LegL") as Node3D).rotation.x = swing
	(g.get_node("LegR") as Node3D).rotation.x = -swing
	g.position.y = absf(swing) * 0.06


## A floating label for other players to see, e.g. "P2" in their colour. Add it as a child.
static func name_tag(index: int, text := "") -> Label3D:
	var d: Dictionary = DESIGNS[index % DESIGNS.size()]
	var l := Label3D.new()
	l.text = text if text != "" else "P%d" % (index + 1)
	l.font_size = 48
	l.pixel_size = 0.004
	l.modulate = d.accent
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, 2.0, 0)
	return l
