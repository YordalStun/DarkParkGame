extends CanvasLayer
## Start-up loading screen in the style of the booth's green-phosphor terminal:
## title, what is being built right now, a segmented progress bar and a percentage.

const GREEN := Color(0.33, 1.0, 0.45)
const DIM := Color(0.1, 0.32, 0.14)
const SEGMENTS := 32

var _status: Label
var _percent: Label
var _cursor: Label
var _blocks: Array[ColorRect] = []
var _root: Control
var _shown := 0.0     # displayed progress (eases toward the target)
var _target := 0.0
var _blink := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font := load("res://assets/fonts/VT323-Regular.ttf") as FontFile

	_root = ColorRect.new()
	(_root as ColorRect).color = Color.BLACK
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(640, 0)
	box.position = -Vector2(320, 110)
	box.add_theme_constant_override("separation", 10)
	_root.add_child(box)

	var title := _label(font, 64, GREEN)
	title.text = "DARK PARK"
	box.add_child(title)
	var sub := _label(font, 24, GREEN.darkened(0.45))
	sub.text = "LOT C  -  BOOTH 2  -  FRI 13 OCT 1989"
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	box.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_status = _label(font, 26, GREEN)
	_status.text = "STARTING UP"
	row.add_child(_status)
	_cursor = _label(font, 26, GREEN)
	_cursor.text = "_"
	row.add_child(_cursor)

	# Segmented bar inside a thin frame.
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.BLACK
	sb.border_color = DIM
	sb.set_border_width_all(2)
	sb.set_content_margin_all(5)
	frame.add_theme_stylebox_override("panel", sb)
	box.add_child(frame)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 3)
	frame.add_child(bar)
	for i in SEGMENTS:
		var b := ColorRect.new()
		b.custom_minimum_size = Vector2(16, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.color = DIM.darkened(0.6)
		bar.add_child(b)
		_blocks.append(b)

	_percent = _label(font, 24, GREEN.darkened(0.3))
	_percent.text = "0%"
	box.add_child(_percent)


func _label(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## fraction 0..1 and a short description of the current step.
func set_progress(fraction: float, text: String) -> void:
	_target = maxf(_target, clampf(fraction, 0.0, 1.0))
	if text != "":
		_status.text = text.to_upper()


func _process(delta: float) -> void:
	_shown = move_toward(_shown, _target, delta * 1.5)
	var lit := int(round(_shown * SEGMENTS))
	for i in SEGMENTS:
		_blocks[i].color = GREEN if i < lit else DIM.darkened(0.6)
	_percent.text = "%d%%" % int(round(_shown * 100.0))
	_blink += delta
	_cursor.modulate.a = 1.0 if fmod(_blink, 1.0) < 0.5 else 0.0


## Wait for the bar to visibly reach 100%, then fade the screen away.
func finish(fade_time := 0.8) -> void:
	_target = 1.0
	while _shown < 1.0:
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, fade_time)
	await tw.finished
	queue_free()
