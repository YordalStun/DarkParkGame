extends SceneTree
## Dev harness: drives the desktop with synthetic input and prints PASS/FAIL checks.
##   godot --path . --script tools/desktop_interact_test.gd -- --out=/tmp/x.png

var os: SubViewport
var fails := 0


func ok(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func mouse(pos: Vector2, pressed := false, release := false, btn := MOUSE_BUTTON_LEFT, dbl := false) -> void:
	var ev: InputEvent
	if pressed or release:
		var b := InputEventMouseButton.new()
		b.button_index = btn
		b.pressed = pressed
		b.double_click = dbl
		b.position = pos
		b.global_position = pos
		ev = b
	else:
		var m := InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		ev = m
	os.push_input(ev, true)


func click(pos: Vector2, btn := MOUSE_BUTTON_LEFT, dbl := false) -> void:
	mouse(pos)
	await process_frame
	mouse(pos, true, false, btn, dbl)
	await process_frame
	mouse(pos, false, true, btn)
	await process_frame


func key(code: int, uni := 0) -> void:
	for p in [true, false]:
		var k := InputEventKey.new()
		k.keycode = code
		k.physical_keycode = code
		k.unicode = uni
		k.pressed = p
		os.push_input(k, true)
	await process_frame


func type(s: String) -> void:
	for ch in s:
		await key(ch.to_upper().unicode_at(0) if ch != " " else KEY_SPACE, ch.unicode_at(0))


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	var out := "/tmp/interact.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	root.size = Vector2i(640, 480)
	os = load("res://scripts/desktop/os.gd").new()
	root.add_child(os)
	await frames(2)
	os.power_on(true)
	os.net_connected = true
	await frames(4)

	# --- Start menu via real clicks
	await click(Vector2(28, 466))
	await frames(2)
	ok(os.has_open_menu(), "Start button opens the menu")
	await click(Vector2(60, 400))   # Run... row region
	await frames(2)
	ok(os.dialog_layer.get_child_count() > 0, "Start > Run... opens the Run dialog")
	ok(os.escape(), "Esc closes the dialog before anything else")
	await frames(2)

	# --- Notepad: type, then drag window by title bar
	var w: Control = os.open_app("notepad")
	await frames(3)
	var start_pos := w.position
	var title_pt := w.position + Vector2(100, 12)
	await click(w.position + Vector2(100, 100))
	await type("hello night")
	ok(w.app.edit.text == "hello night", "Notepad receives typing (got '%s')" % w.app.edit.text)
	mouse(title_pt)
	await frames(1)
	mouse(title_pt, true)
	await frames(1)
	mouse(title_pt + Vector2(60, 40))
	await frames(1)
	mouse(title_pt + Vector2(60, 40), false, true)
	await frames(2)
	ok(w.position.distance_to(start_pos + Vector2(60, 40)) < 3.0, "Window drags by its title bar (%s -> %s)" % [start_pos, w.position])
	# maximise via double click on title
	await click(w.position + Vector2(100, 12), MOUSE_BUTTON_LEFT, true)
	await frames(2)
	ok(w.maximized, "Double-clicking the title bar maximises")
	w.request_close()   # modified -> asks to save
	await frames(3)
	ok(os.dialog_layer.get_child_count() > 0, "Closing a modified Notepad asks to save")
	await key(KEY_ESCAPE)
	os.escape()
	await frames(2)

	# --- Calculator logic
	var cw: Control = os.open_app("calc")
	await frames(2)
	for k in ["7", "*", "6", "="]:
		cw.app._press(k)
	ok(cw.app.display.text == "42", "Calculator 7*6 = 42 (got %s)" % cw.app.display.text)
	for k in ["c", "8", "/", "0", "="]:
		cw.app._press(k)
	ok(cw.app.display.text.begins_with("Cannot"), "Calculator divide by zero message")

	# --- DOS prompt
	var dw: Control = os.open_app("dos")
	await frames(3)
	await click(dw.position + Vector2(100, 100))
	await type("dir")
	await key(KEY_ENTER)
	await type("type readme.txt")
	await key(KEY_ENTER)
	var joined := "\n".join(dw.app.lines)
	ok(joined.contains("Directory of C:\\WINDOWS"), "DOS 'dir' lists the directory")
	await type("cd ..")
	await key(KEY_ENTER)
	ok(dw.app.cwd == "C:\\", "DOS 'cd ..' goes up (cwd %s)" % dw.app.cwd)
	await type("type readme.txt")
	await key(KEY_ENTER)
	ok("\n".join(dw.app.lines).contains("NIGHTWIN 95"), "DOS 'type' prints a file")

	# --- Minesweeper
	var mw: Control = os.open_app("mines")
	await frames(3)
	await click(mw.position + Vector2(4, 19 + 22) + Vector2(8 + 40, 25 + 42 + 40))
	ok(mw.app.state == "play" or mw.app.state == "lost", "Minesweeper first click starts the game (%s)" % mw.app.state)

	# --- Paint
	var pw: Control = os.open_app("paint")
	await frames(3)
	var cv: Control = pw.app.view
	var origin: Vector2 = cv.get_global_rect().position
	mouse(origin + Vector2(30, 30))
	mouse(origin + Vector2(30, 30), true)
	await frames(1)
	mouse(origin + Vector2(80, 60))
	await frames(1)
	mouse(origin + Vector2(80, 60), false, true)
	await frames(2)
	ok(pw.app.img.get_pixel(80, 60) == Color.BLACK or pw.app.img.get_pixel(79, 59) == Color.BLACK or pw.app.img.get_pixel(30, 30) == Color.BLACK, "Paint pencil draws on the canvas")

	# --- Browser navigation (fake web)
	var bw: Control = os.open_app("browser")
	await frames(120)
	bw.app.navigate("lot c")
	await frames(120)
	ok(bw.app.addr.text.contains("findit.com/search"), "Typing words in the address bar searches (%s)" % bw.app.addr.text)
	bw.app.navigate("http://www.ashfordgazette.com/")
	await frames(120)
	ok(bw.app.win.title.begins_with("The Ashford Gazette"), "Fake site loads (%s)" % bw.app.win.title)
	bw.app.go_back()
	await frames(120)
	ok(bw.app.addr.text.contains("findit.com/search"), "Back button works")

	# --- Run dialog
	var D := load("res://scripts/desktop/dialogs.gd")
	D.run_dialog(os)
	await frames(3)
	var count_before: int = os.windows.size()
	D.run_command(os, "winmine")
	await frames(3)
	ok(os.windows.size() == count_before + 1, "Run: 'winmine' opens Minesweeper")
	D.run_command(os, "nonsense.exe")
	await frames(3)
	ok(os.dialog_layer.get_child_count() > 0, "Run: unknown command shows an error")

	await frames(10)
	await RenderingServer.frame_post_draw
	os.get_texture().get_image().save_png(out)
	print("FAILS: ", fails)
	quit(fails)
