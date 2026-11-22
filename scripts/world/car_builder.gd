class_name CarBuilder
## Boxy late-80s cars and a van. Nose points toward local +Z. Origin on the ground.


## see_through: tinted but transparent glass, so the driver can be seen (story cars).
static func make(paint: Color, kind := "sedan", see_through := false) -> Node3D:
	var car := Node3D.new()
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = paint
	body_m.metallic = 0.35
	body_m.roughness = 0.3
	body_m.clearcoat_enabled = true
	body_m.clearcoat = 0.8
	body_m.clearcoat_roughness = 0.1
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.02, 0.025, 0.03)
	glass.roughness = 0.05
	glass.metallic = 0.2
	if see_through:
		glass.albedo_color = Color(0.05, 0.07, 0.08, 0.45)
		glass.metallic = 0.6
		glass.roughness = 0.02
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var black := MK.mat(Color(0.03, 0.03, 0.03), "", 0.7)
	var tyre := MK.mat(Color(0.02, 0.02, 0.02), "", 0.95)
	var hub := MK.mat(Color(0.5, 0.5, 0.48), "", 0.35, 1.0, 0.8)
	var chrome := MK.mat(Color(0.6, 0.6, 0.6), "", 0.2, 1.0, 0.9)
	var lens := MK.mat(Color(0.75, 0.75, 0.7), "", 0.1)
	var red := MK.mat(Color(0.45, 0.02, 0.02), "", 0.15)
	var plate := MK.mat(Color(0.85, 0.82, 0.6), "", 0.5)

	if kind == "van":
		MK.box(car, Vector3(1.85, 1.55, 4.7), Vector3(0, 1.08, -0.1), body_m)
		MK.taper(car, Vector3(0.6, 1.0, 1.84), 0.25, 0.18, Vector3(0, 1.0, 2.43), body_m, Vector3(0, -90, 0), 1.8)
		MK.box(car, Vector3(1.7, 0.5, 0.02), Vector3(0, 1.55, 2.38), glass, Vector3(-20, 0, 0))
		for sx in [-0.93, 0.93]:
			MK.box(car, Vector3(0.02, 0.45, 0.9), Vector3(sx, 1.5, 1.6), glass)
	else:
		MK.box(car, Vector3(1.72, 0.55, 4.55), Vector3(0, 0.6, 0), body_m)
		var cabin := MK.taper(car, Vector3(2.6, 0.5, 1.64), 1.45, -0.25, Vector3(0, 1.12, -0.25), glass, Vector3(0, -90, 0), 1.42)
		cabin.name = "Cabin"
		MK.box(car, Vector3(1.44, 0.04, 1.5), Vector3(0, 1.385, -0.5), body_m)  # roof
		for sx in [-0.79, 0.79]:
			MK.box(car, Vector3(0.05, 0.48, 0.1), Vector3(sx * 0.95, 1.12, -0.3), body_m)  # B pillar
		MK.box(car, Vector3(1.74, 0.06, 4.57), Vector3(0, 0.66, 0), chrome)  # side trim line

	# Wheels.
	var wz := 1.45 if kind != "van" else 1.6
	for sx in [-0.8, 0.8]:
		for sz in [-wz, wz]:
			MK.cyl(car, 0.31, 0.31, 0.2, Vector3(sx, 0.31, sz), tyre, 10, Vector3(0, 0, 90))
			MK.cyl(car, 0.17, 0.17, 0.205, Vector3(sx, 0.31, sz), hub, 8, Vector3(0, 0, 90))
	# Bumpers, lights, plates.
	var len_half := 2.29 if kind != "van" else 2.38
	MK.box(car, Vector3(1.78, 0.16, 0.12), Vector3(0, 0.42, len_half), black)
	MK.box(car, Vector3(1.78, 0.16, 0.12), Vector3(0, 0.42, -len_half + (0.18 if kind == "van" else 0.0)), black)
	for sx in [-0.62, 0.62]:
		MK.box(car, Vector3(0.38, 0.14, 0.03), Vector3(sx, 0.72, len_half - 0.02), lens)
		MK.box(car, Vector3(0.36, 0.13, 0.03), Vector3(sx, 0.72, -len_half + 0.02 + (0.18 if kind == "van" else 0.0)), red)
	MK.box(car, Vector3(0.5, 0.06, 0.03), Vector3(0, 0.6, len_half + 0.01), black)  # grille
	MK.box(car, Vector3(0.36, 0.12, 0.01), Vector3(0, 0.42, len_half + 0.065), plate)
	MK.box(car, Vector3(0.36, 0.12, 0.01), Vector3(0, 0.42, -len_half - 0.065 + (0.18 if kind == "van" else 0.0)), plate)
	# Dark underside so the car sits on the ground.
	MK.box(car, Vector3(1.6, 0.05, 4.2), Vector3(0, 0.28, 0), black)
	return car
