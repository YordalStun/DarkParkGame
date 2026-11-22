extends SceneTree
## Renders the title screen (with whatever save slots exist) to a PNG.
##   godot --path . -s tools/title_test.gd -- --out=x.png [--slots] [--load]

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else true
	await process_frame
	var sg = root.get_node("/root/SaveGame")
	if args.has("slots"):
		sg.new_game(1)
		sg.finish_night(11, 5, ["Heating"])
		sg.finish_night(6, 1, [])
		sg.new_game(3)
	var t = load("res://scripts/ui/title_screen.gd").new()
	root.add_child(t)
	for i in 80:
		await process_frame
	if args.has("load"):
		t._show_slots("load")
		for i in 10:
			await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(args.get("out", "/tmp/title.png"))
	print("saved")
	quit()
