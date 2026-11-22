extends SceneTree
## Renders design sheets to pick from: umbrellas, people (with umbrellas), hospital and path options.
##   godot --path . -s tools/design_studio.gd -- --out=dir [--what=umbrellas|people|hospital]
const Umbrella := preload("res://scripts/world/umbrella.gd")
const Person := preload("res://scripts/world/person_model.gd")
const Hospital := preload("res://tools/hospital_concepts.gd")


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else true
	var out: String = args.get("out", "/tmp")
	var what: String = args.get("what", "all")
	get_root().size = Vector2i(1280, 720)
	if what in ["all", "umbrellas"]:
		await _sheet(out + "/umbrellas.png", _umbrellas(), Vector3(0, 1.45, 5.6), Vector3(0, 1.2, 0), 50.0, false)
	if what in ["all", "people"]:
		await _sheet(out + "/people.png", _people(), Vector3(0.4, 1.4, 6.2), Vector3(0.1, 1.0, 0), 50.0, false)
	if what in ["all", "hospital"]:
		var i := 0
		for h in Hospital.CONCEPTS:
			await _sheet(out + "/hospital_%d.png" % (i + 1), Hospital.build(h), Vector3(-16.0, 2.2, 21.0), Vector3(-40.0, 4.0, 3.0), 54.0, true)
			i += 1
	quit()


func _umbrellas() -> Node3D:
	var root := Node3D.new()
	var i := 0
	for st in Umbrella.STYLES:
		var u := Umbrella.build(st)
		u.position = Vector3(-3.1 + i * 1.25, 0.5, 0)
		root.add_child(u)
		var lbl := Label3D.new()
		lbl.text = Umbrella.STYLES[st].label
		lbl.font_size = 40
		lbl.pixel_size = 0.0035
		lbl.position = Vector3(-3.1 + i * 1.25, 0.25, 0.3)
		lbl.modulate = Color(1, 1, 1)
		root.add_child(lbl)
		i += 1
	return root


func _people() -> Node3D:
	var root := Node3D.new()
	var i := 0
	for d in Person.DESIGNS:
		var spec: Dictionary = Person.DESIGNS[d]
		var p := Person.build(spec, spec.umbrella)
		p.position = Vector3(-3.4 + i * 1.4, 0, 0)
		p.rotation_degrees.y = 18 if i % 2 == 0 else -14
		root.add_child(p)
		var lbl := Label3D.new()
		lbl.text = "%d. %s" % [i + 1, spec.label]
		lbl.font_size = 40
		lbl.pixel_size = 0.0035
		lbl.position = Vector3(-3.4 + i * 1.4, -0.12, 0.4)
		root.add_child(lbl)
		i += 1
	return root


func _sheet(path: String, content: Node3D, cam_pos: Vector3, look: Vector3, fov: float, dusk: bool) -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.12) if dusk else Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.45) if dusk else Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 0.7 if not dusk else 1.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 0.8 if dusk else 1.1
	sun.shadow_enabled = not dusk
	root.add_child(sun)
	if not dusk:
		var fl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(40, 40)
		fl.mesh = pm
		fl.material_override = MK.mat(Color(0.28, 0.29, 0.3))
		root.add_child(fl)
	root.add_child(content)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.far = 200.0
	root.add_child(cam)
	cam.look_at_from_position(cam_pos, look)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(path)
	print("saved ", path)
	root.queue_free()
