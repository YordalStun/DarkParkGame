extends SubViewport
## The green-phosphor security terminal shown on the CRT.
## Renders to a texture that the CRT screen shader samples.

const W := 512
const H := 384
const GREEN := Color(0.33, 1.0, 0.45)
const DIM := Color(0.16, 0.5, 0.22)

var _body: Label
var _status: Label
var _hint: Label
var _cursor_on := true
var _blink := 0.0
var log_lines: Array[String] = [
	"23:00  SHIFT CHANGE - OPERATOR LOGGED IN",
	"23:02  GATE ARM TEST ............ OK",
	"23:03  CAMERA LINK 1-4 ........ NO SIGNAL",
]


func _ready() -> void:
	size = Vector2i(W, H)
	transparent_bg = false
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	gui_disable_input = true

	var font := load("res://assets/fonts/VT323-Regular.ttf") as FontFile
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.012, 0.004)
	bg.size = Vector2(W, H)
	add_child(bg)

	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = 21
	settings.font_color = GREEN
	settings.line_spacing = -2

	var header := Label.new()
	header.label_settings = settings
	header.position = Vector2(22, 16)
	header.text = "NIGHTWATCH SECURITY SYSTEMS  v1.3\nLOT C  -  BOOTH 2           (C)1988 NWS"
	add_child(header)

	var rule := ColorRect.new()
	rule.color = DIM
	rule.position = Vector2(22, 64)
	rule.size = Vector2(W - 44, 2)
	add_child(rule)

	_status = Label.new()
	_status.label_settings = settings
	_status.position = Vector2(22, 72)
	add_child(_status)

	var rule2 := rule.duplicate()
	rule2.position = Vector2(22, 176)
	add_child(rule2)

	_body = Label.new()
	_body.label_settings = settings
	_body.position = Vector2(22, 184)
	add_child(_body)

	_hint = Label.new()
	_hint.label_settings = settings.duplicate()
	_hint.label_settings.font_color = DIM
	_hint.position = Vector2(22, 344)
	add_child(_hint)

	_refresh()


func add_log(text: String) -> void:
	log_lines.append("%s  %s" % [NightClock.time_text(), text])
	while log_lines.size() > 6:
		log_lines.pop_front()
	_refresh()


func _process(delta: float) -> void:
	_blink += delta
	if _blink >= 0.53:
		_blink = 0.0
		_cursor_on = not _cursor_on
		_refresh()


func _refresh() -> void:
	if _status == null:
		return
	_status.text = "DATE  %s      TIME  %s\nWEATHER  %-12s  GATE  CLOSED\nVEHICLES ON LOT  4      PATROL DUE  00:00" % [
		NightClock.DATE_TEXT, NightClock.time_text(), Weather.describe()]
	var t := "EVENT LOG\n"
	for l in log_lines:
		t += l + "\n"
	t += "> " + ("_" if _cursor_on else " ")
	_body.text = t
	_hint.text = "[ CLICK SCREEN TO START NIGHTWIN 95 ]" if _cursor_on else "  CLICK SCREEN TO START NIGHTWIN 95  "
