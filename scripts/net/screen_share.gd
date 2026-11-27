extends Node
## Co-op: every guard sees what's on a PC's screen, whoever is using it.
## Each machine runs its own copy of the desktop, so the guard using a PC sends a small JPEG of
## its screen a few times a second (Net.send_screen) and everyone else shows that on their monitor.
## When nobody else's pictures are arriving, a monitor goes back to this machine's own desktop.

const FPS := 4.0
const SIZE := Vector2i(320, 240)
const QUALITY := 0.55
const STALE := 2.5          ## seconds without a picture before a monitor goes back to its own desktop

var story
## One entry per PC: {station, owner: Callable -> int, mine (was last used here), remote_t, tex}
var pcs: Array = []
var _t := 0.0


func setup(p_story) -> void:
	story = p_story
	Net.screen_in.connect(_on_screen)


func add_pc(station: Node, owner_fn: Callable) -> void:
	pcs.append({"station": station, "owner": owner_fn, "mine": false, "remote_t": -100.0, "tex": null, "showing": false})


func _process(delta: float) -> void:
	if not Net.active():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for pc in pcs:
		var o: int = pc.owner.call()
		if o == story.local_player_id:
			pc.mine = true
		elif o != 0:
			pc.mine = false
		if pc.showing and (o == story.local_player_id or now - float(pc.remote_t) > STALE):
			pc.showing = false
			var st: Node = pc.station
			st._on_desktop_state(st.desktop.is_on())
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0 / FPS
	for i in pcs.size():
		var pc: Dictionary = pcs[i]
		var desk: SubViewport = pc.station.desktop
		if not pc.mine or not desk.is_on():
			continue
		var img := desk.get_texture().get_image()
		if img == null or img.is_empty():
			continue
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
		Net.send_screen(i, img.save_jpg_to_buffer(QUALITY))


func _on_screen(_from: int, which: int, data: PackedByteArray) -> void:
	if which < 0 or which >= pcs.size():
		return
	var pc: Dictionary = pcs[which]
	if pc.owner.call() == story.local_player_id:
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(data) != OK:
		return
	if pc.tex == null or (pc.tex as ImageTexture).get_size() != Vector2(img.get_size()):
		pc.tex = ImageTexture.create_from_image(img)
	else:
		(pc.tex as ImageTexture).update(img)
	pc.remote_t = Time.get_ticks_msec() / 1000.0
	var st: Node = pc.station
	if not pc.showing:
		pc.showing = true
		st._on_desktop_state(true)   # the desktop's look on the tube...
	st.crt_screen_mat.set_shader_parameter("screen", pc.tex)   # ...with their picture on it
	st.crt_screen_mat.set_shader_parameter("texel", Vector2(1.0 / SIZE.x, 1.0 / SIZE.y))
