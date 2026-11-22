extends SceneTree
## Renders the car model from a few angles under plain light, to judge its shape.
## godot --path . -s tools/car_studio.gd -- --out=dir [--style=hatch] [--night]

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else true
	var out: String = args.get("out", "/tmp")
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.27, 0.3) if not args.has("night") else Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.55) if not args.has("night") else Color(0.03, 0.03, 0.04)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.2 if not args.has("night") else 0.0
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color(0.3, 0.3, 0.3)
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	var fl := MeshInstance3D.new()
	fl.mesh = pm
	fl.material_override = floor_m
	root.add_child(fl)
	var car := CarModel.new()
	car.paint = Color(0.55, 0.06, 0.05)
	car.style = args.get("style", "saloon")
	car.driver_window_open = true
	car.build()
	root.add_child(car)
	if args.has("night"):
		var sp := SpotLight3D.new()
		sp.position = Vector3(-2.5, 2.6, -0.2)
		sp.rotation_degrees = Vector3(-48, -90, 0)
		sp.light_energy = 5.0
		sp.spot_range = 14.0
		sp.spot_angle = 52.0
		sp.shadow_enabled = true
		root.add_child(sp)
	var cam := Camera3D.new()
	cam.fov = 45
	root.add_child(cam)
	var views := [["front34", Vector3(4.5, 1.8, 5.5)], ["side", Vector3(-7.0, 1.2, 0.0)], ["rear34", Vector3(-4.5, 1.9, -5.5)], ["booth", Vector3(-2.3, 1.1, -0.2)]]
	for v in views:
		cam.look_at_from_position(v[1], Vector3(0, 0.7, 0) if v[0] != "booth" else Vector3(0, 0.9, -0.1))
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s/studio_%s.png" % [out, v[0]])
	print("studio done")
	quit()
