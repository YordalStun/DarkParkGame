extends SceneTree
## Dev harness: boots the desktop on its own (no 3D world), optionally opens apps,
## and saves a screenshot.
##   godot --path . --script tools/desktop_test.gd -- --out=/tmp/x.png --apps=notepad,calc --frames=20 [--url=...] [--click=x,y ...]

var os: SubViewport


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var out: String = args.get("out", "/tmp/desktop.png")
	root.size = Vector2i(640, 480)
	os = load("res://scripts/desktop/os.gd").new()
	root.add_child(os)
	await process_frame
	os.power_on(true)
	if args.has("online"):
		os.net_connected = true
	for i in 4:
		await process_frame
	for id in str(args.get("apps", "")).split(",", false):
		var a: Dictionary = {}
		if args.has("url") and id == "browser":
			a["url"] = args.url
		if args.has("path"):
			a["path"] = args.path
		os.open_app(id, a)
		for i in 3:
			await process_frame
	if args.has("menu"):
		os.toggle_start()
	if args.has("dialog"):
		var D := load("res://scripts/desktop/dialogs.gd")
		match args.dialog:
			"welcome": D.welcome(os)
			"shutdown": D.shutdown_dialog(os)
			"run": D.run_dialog(os)
			"msg": D.msgbox(os, "Error", "Cannot find the file 'x'.", "error")
			"dial": D.dialup(os, func(_o): pass)
			"display": D.display_props(os)
	var wait := int(args.get("frames", "20"))
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	os.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
