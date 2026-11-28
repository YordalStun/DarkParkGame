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
	if args.has("boot"):   # --boot[=style]: a car with its boot broken into and five things inside
		var c := CarModel.new()
		c.paint = Color(0.55, 0.06, 0.05)
		c.style = str(args.boot) if str(args.boot) != "true" else "saloon"
		c.build()
		root.add_child(c)
		c.open_boot_lid()
		var ids := ["guitar", "camera", "radio", "shopping", "cigs"]
		var ms := []
		for id in ids:
			ms.append(BootItems.make(id))
		c.place_in_boot(ms)
		var cam2 := Camera3D.new()
		cam2.fov = 45
		root.add_child(cam2)
		for v in [["boot_a", Vector3(1.6, 2.4, -4.6)], ["boot_b", Vector3(0.2, 1.5, c.S.r - 0.85)]]:
			cam2.look_at_from_position(v[1], Vector3(0, c.boot_floor, (c.boot_zone.x + c.boot_zone.y) * 0.5))
			for k in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("%s/%s.png" % [out, v[0]])
		quit()
		return
	if args.has("anim"):   # --anim=style: frames of the boot opening, a look inside, then closing (for clips)
		var c3 := CarModel.new()
		c3.paint = Color(0.1, 0.2, 0.45) if str(args.anim) != "saloon" else Color(0.55, 0.06, 0.05)
		c3.style = str(args.anim)
		c3.build()
		root.add_child(c3)
		var ms3 := []
		for id in ["guitar", "camera", "radio", "shopping"]:
			ms3.append(BootItems.make(id))
		c3.place_in_boot(ms3)
		var cam3 := Camera3D.new()
		cam3.fov = 50
		root.add_child(cam3)
		cam3.look_at_from_position(Vector3(2.6, 2.0, c3.S.r - 3.6), Vector3(0, 0.9, c3.S.r + 0.6))
		var f := [0]   # (a lambda can't change a local)
		var shoot := func(n: int) -> void:
			for k in n:
				await process_frame
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png("%s/f_%04d.png" % [out, f[0]])
				f[0] += 1
		await shoot.call(10)
		c3.open_boot_lid()
		await shoot.call(40)
		cam3.global_transform = c3.boot_view.global_transform   # the player's look into it
		cam3.fov = 55
		await shoot.call(25)
		cam3.look_at_from_position(Vector3(2.6, 2.0, c3.S.r - 3.6), Vector3(0, 0.9, c3.S.r + 0.6))
		cam3.fov = 50
		c3.close_boot_lid()
		await shoot.call(40)
		quit()
		return
	if args.has("all"):
		await _all_styles(root, out)
		quit()
		return
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


## --all: every design side by side, one picture each at a 3/4 front view.
func _all_styles(root: Node3D, out: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	var paints := [Color(0.55, 0.06, 0.05), Color(0.1, 0.2, 0.45), Color(0.75, 0.72, 0.6), Color(0.1, 0.25, 0.15), Color(0.6, 0.6, 0.62)]
	var i := 0
	for st in CarModel.STYLES:
		var car := CarModel.new()
		car.paint = paints[i % paints.size()]
		car.style = st
		car.build()
		root.add_child(car)
		for view in [["a", Vector3(4.6, 1.9, 6.0)], ["b", Vector3(-5.0, 1.8, -5.8)]]:
			cam.look_at_from_position(view[1], Vector3(0, 0.75, 0))
			for k in 6:
				await process_frame
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("%s/style_%02d_%s_%s.png" % [out, i, st, view[0]])
		car.queue_free()
		i += 1
