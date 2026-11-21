extends Control
## One icon on the desktop (or in a folder window): picture above a caption.
## Click selects, double-click opens, right-click asks for a context menu.

const W95 := preload("res://scripts/desktop/w95.gd")

signal picked(icon)
signal opened(icon)
signal context(icon, pos)

var caption := ""
var picture: Texture2D
var action: Callable
var selected := false


func setup(p_caption: String, icon_name: String, p_action: Callable) -> void:
	caption = p_caption
	picture = W95.icon(icon_name)
	action = p_action
	custom_minimum_size = Vector2(72, 66)
	size = Vector2(72, 66)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_selected(s: bool) -> void:
	if s != selected:
		selected = s
		queue_redraw()


func _draw() -> void:
	var f := W95.font("sans")
	var px := (size.x - 32.0) / 2.0
	draw_texture(picture, Vector2(px, 3), Color(0.55, 0.55, 1.0) if selected else Color.WHITE)
	var lines := f.get_multiline_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2.0, W95.FONT_SIZE)
	var lh := 13.0
	var count := int(ceil(lines.y / lh))
	count = clampi(count, 1, 2)
	var ty := 38.0
	if selected:
		var tw := minf(lines.x, size.x - 2.0)
		var r := Rect2((size.x - tw) / 2.0 - 2.0, ty, tw + 4.0, lh * count + 1.0)
		draw_rect(r, W95.NAVY)
		draw_rect(r, W95.WHITE, false, 1.0)  # focus rectangle
		draw_rect(r.grow(-1.0), W95.NAVY, false, 1.0)
	draw_multiline_string(f, Vector2(1, ty + 11), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 2.0, W95.FONT_SIZE, 2, Color.WHITE)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(self)
			if ev.double_click:
				opened.emit(self)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			picked.emit(self)
			context.emit(self, ev.global_position)
		accept_event()
