extends SceneTree
## Smoke test for the embedded browser engine:
##   godot --path . -s tools/cef_smoke.gd -- <out_dir> <url> [<url>...]
## Loads each URL, waits, and saves what the browser rendered as PNG.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var cef = ClassDB.instantiate("GDCEF")
	if cef == null:
		print("SMOKE: GDCEF class not found (extension failed to load)")
		quit(1)
		return
	root.add_child(cef)
	var ok: bool = cef.initialize({"incognito": true, "locale": "en-US", "use_gpu": false, "log_severity": "warning"})
	print("SMOKE: initialize -> ", ok, " ", cef.get_error())
	var tr := TextureRect.new()
	tr.size = Vector2(800, 600)
	root.add_child(tr)
	var i := 0
	for url in args.slice(1):
		var b = cef.create_browser(url, tr, {"frame_rate": 30, "user_gesture_required": false})
		b.resize(Vector2(800, 600))
		var loaded := [false]
		b.on_page_loaded.connect(func(_b): loaded[0] = true)
		b.on_page_failed_loading.connect(func(c, m, _b): print("SMOKE: failed ", url, " ", c, " ", m))
		for f in 600:
			await process_frame
			if loaded[0] and f > 240:
				break
		var tex = b.get_texture()
		if tex:
			tex.get_image().save_png("%s/cef_%d.png" % [out, i])
		print("SMOKE: ", url, " loaded=", loaded[0], " title=", b.get_title())
		b.close()
		i += 1
	cef.shutdown()
	quit(0)
