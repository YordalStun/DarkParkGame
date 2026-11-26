extends SceneTree
## Renders the boot items (scripts/world/boot_items.gd) under plain light.
##   godot --path . -s tools/item_studio.gd -- --out=dir

func _init() -> void:
	var out := "/tmp"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.23, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.35, 0.35, 0.35)
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	var fl := MeshInstance3D.new()
	fl.mesh = pm
	fl.material_override = fm
	root.add_child(fl)
	var ids: Array = BootItems.ITEMS.keys()
	for i in ids.size():
		var it := BootItems.make(ids[i])
		it.position = Vector3(-1.9 + (i % 5) * 0.95, 0, -1.3 + (i / 5) * 0.85)
		it.rotation_degrees.y = [8, -15, 20, -10, 15][i % 5]
		root.add_child(it)
	var cam := Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 3.4, 2.9), Vector3(0.0, 0.0, -0.05))
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/boot_items.png")
	cam.look_at_from_position(Vector3(0.8, 1.0, 1.6), Vector3(0.6, 0.1, 0.4))
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/boot_items_close.png")
	print("done")
	quit()
