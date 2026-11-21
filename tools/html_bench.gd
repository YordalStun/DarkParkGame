extends SceneTree
## Times the browser's HTML renderer on saved pages:
##   godot --headless --path . -s tools/html_bench.gd -- page1.html page2.html ...

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var HtmlView = load("res://scripts/desktop/html_view.gd")
	for path in OS.get_cmdline_user_args():
		var html := FileAccess.get_file_as_string(path)
		var rtl := RichTextLabel.new()
		rtl.size = Vector2(600, 400)
		root.add_child(rtl)
		var t0 := Time.get_ticks_msec()
		HtmlView.new().render(rtl, html, "https://example.com/")
		print("BENCH %-45s %8d chars  %6d ms" % [path.get_file(), html.length(), Time.get_ticks_msec() - t0])
		rtl.queue_free()
	quit()
