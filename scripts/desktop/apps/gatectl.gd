extends Control
## Gate Control: opens and closes the real barrier gate in the car park.

const W95 := preload("res://scripts/desktop/w95.gd")

var os: Node
var _open := false
var _status: Label
var _t := 0.0


func setup(p_os: Node, _win: Control, _args: Dictionary) -> void:
	os = p_os
	_status = Label.new()
	_status.position = Vector2(110, 18)
	_status.add_theme_font_override("font", W95.font("sansb"))
	add_child(_status)
	var l2 := Label.new()
	l2.position = Vector2(110, 38)
	l2.text = "Remote link: " + ("OK" if os.world != null else "NO LINK")
	add_child(l2)
	var ob: Button = os.button("Open Gate")
	ob.position = Vector2(110, 80)
	ob.size = Vector2(85, 26)
	ob.pressed.connect(func(): os.set_gate(true))
	add_child(ob)
	var cb: Button = os.button("Close Gate")
	cb.position = Vector2(200, 80)
	cb.size = Vector2(85, 26)
	cb.pressed.connect(func(): os.set_gate(false))
	add_child(cb)
	var note := Label.new()
	note.position = Vector2(10, 122)
	note.text = "Log every vehicle that enters after 22:00."
	add_child(note)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.25:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	var o: bool = os.gate_is_open()
	_open = o
	_status.text = "Barrier: " + ("OPEN" if o else "CLOSED")
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(10, 14, 90, 90), W95.BLACK)
	draw_rect(Rect2(11, 15, 88, 88), Color(0.05, 0.1, 0.05))
	draw_rect(Rect2(20, 70, 10, 30), W95.SHADOW)
	var pivot := Vector2(25, 72)
	var ang := deg_to_rad(-70.0) if _open else 0.0
	var tip := pivot + Vector2(cos(ang), sin(ang)) * 62.0
	draw_line(pivot, tip, Color(0.9, 0.1, 0.1), 5.0)
	draw_line(pivot + (tip - pivot) * 0.33, pivot + (tip - pivot) * 0.5, Color.WHITE, 5.0)
	draw_line(pivot + (tip - pivot) * 0.66, pivot + (tip - pivot) * 0.83, Color.WHITE, 5.0)
	draw_circle(Vector2(88, 24), 4.0, Color(0, 1, 0) if _open else Color(1, 0, 0))
