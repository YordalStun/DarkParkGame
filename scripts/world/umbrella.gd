extends RefCounted
## Umbrella designs for people walking in the rain. Low-poly, flat-shaded wedges so they sit
## with the PS1 look. build(style) returns a Node3D with the pole's bottom at y=0 (the hand holds
## it about 0.35 up) and the canopy about 0.95 above that. Open the canopy towards +Y.

const STYLES := {
	"classic":  {"label": "Classic black",      "colors": [Color(0.06, 0.06, 0.07)], "radius": 0.52, "rise": 0.2,  "pole": Color(0.15, 0.15, 0.17)},
	"striped":  {"label": "Red and white",      "colors": [Color(0.72, 0.1, 0.08), Color(0.9, 0.88, 0.8)], "radius": 0.55, "rise": 0.22, "pole": Color(0.5, 0.35, 0.18)},
	"clear":    {"label": "Clear dome",         "colors": [Color(0.75, 0.85, 0.9, 0.3)], "radius": 0.5, "rise": 0.3, "pole": Color(0.1, 0.1, 0.1), "clear": true},
	"golf":     {"label": "Big golf brolly",    "colors": [Color(0.08, 0.16, 0.4), Color(0.1, 0.35, 0.2)], "radius": 0.72, "rise": 0.22, "pole": Color(0.2, 0.2, 0.22), "panels": 10},
	"tattered": {"label": "Old and tattered",   "colors": [Color(0.22, 0.2, 0.17)], "radius": 0.5, "rise": 0.18, "pole": Color(0.3, 0.28, 0.25), "torn": true},
	"yellow":   {"label": "Yellow",             "colors": [Color(0.95, 0.75, 0.12)], "radius": 0.5, "rise": 0.2, "pole": Color(0.35, 0.3, 0.2)},
}


static func build(style: String) -> Node3D:
	var d: Dictionary = STYLES[style]
	var root := Node3D.new()
	root.name = "Umbrella_" + style
	var radius: float = d.radius
	var rise: float = d.rise
	var panels: int = d.get("panels", 8)
	var cols: Array = d.colors
	var top := 0.95

	# Canopy: apex, a mid ring and the rim, one coloured wedge per panel.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var torn_panel := 3 if d.get("torn", false) else -1
	for i in panels:
		var a0 := TAU * i / panels
		var a1 := TAU * (i + 1) / panels
		var am := (a0 + a1) * 0.5
		var c: Color = (cols[i % cols.size()] as Color).srgb_to_linear()
		var apex := Vector3(0, top + rise, 0)
		var m0 := Vector3(cos(a0) * radius * 0.62, top + rise * 0.55, sin(a0) * radius * 0.62)
		var m1 := Vector3(cos(a1) * radius * 0.62, top + rise * 0.55, sin(a1) * radius * 0.62)
		# The rim sags between the ribs, like real fabric.
		var r0 := Vector3(cos(a0) * radius, top, sin(a0) * radius)
		var r1 := Vector3(cos(a1) * radius, top, sin(a1) * radius)
		var rm := Vector3(cos(am) * radius * 0.97, top + 0.025, sin(am) * radius * 0.97)
		if i == torn_panel:
			# A torn panel: just the top triangle, with a ragged hole below it.
			_tri(st, apex, m0, m1, c)
			_tri(st, m0, rm * Vector3(0.8, 1, 0.8) + Vector3(0, 0.12, 0), m1, c)
			continue
		_tri(st, apex, m0, m1, c)
		_tri(st, m0, r0, rm, c)
		_tri(st, m0, rm, m1, c)
		_tri(st, m1, rm, r1, c)
	var mesh := st.commit()
	# The canopy and ribs hang off a pivot so the whole thing can fold shut and spring open.
	var canopy := Node3D.new()
	canopy.name = "Canopy"
	root.add_child(canopy)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if d.get("clear", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.15
	mi.material_override = m
	canopy.add_child(mi)

	# Pole, ferrule on top, ribs, and a crook handle.
	var pole := MK.mat(d.pole, "", 0.4, 1.0, 0.4)
	MK.cyl(root, 0.011, 0.011, top + rise, Vector3(0, (top + rise) * 0.5, 0), pole, 6)
	MK.cyl(root, 0.004, 0.012, 0.07, Vector3(0, top + rise + 0.03, 0), pole, 6)
	var rib := MK.mat(Color(0.12, 0.12, 0.13), "", 0.4, 1.0, 0.6)
	for i in panels:
		var a := TAU * i / panels
		var from := Vector3(0, top + rise * 0.95, 0)
		var to := Vector3(cos(a) * radius * 0.98, top + 0.005, sin(a) * radius * 0.98)
		_rod(canopy, from, to, 0.005, rib)
	var handle := MK.mat(Color(0.2, 0.13, 0.08) if style != "clear" else Color(0.05, 0.05, 0.05), "", 0.5)
	MK.cyl(root, 0.016, 0.016, 0.14, Vector3(0, 0.07, 0), handle, 6)
	MK.cyl(root, 0.016, 0.016, 0.09, Vector3(0.045, -0.0, 0), handle, 6, Vector3(0, 0, 90))
	MK.cyl(root, 0.016, 0.016, 0.07, Vector3(0.09, 0.03, 0), handle, 6)
	if d.get("torn", false):
		# One bent rib poking out through the hole.
		_rod(canopy, Vector3(cos(0.0) * 0.1, top + 0.14, 0.0), Vector3(0.3, top - 0.1, 0.32), 0.006, rib)
	return root


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)


## A thin rod between two points.
static func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var len := a.distance_to(b)
	var n := MK.cyl(parent, r, r, len, (a + b) * 0.5, m, 4)
	n.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	n.rotate_object_local(Vector3.RIGHT, PI * 0.5)


## 0 = furled tight against the pole, 1 = fully open.
static func set_open(um: Node3D, t: float) -> void:
	var canopy := um.get_node_or_null("Canopy") as Node3D
	if canopy:
		var r := lerpf(0.1, 1.0, t)
		canopy.scale = Vector3(r, lerpf(1.25, 1.0, t), r)


## Springs the umbrella open after `delay` seconds: it starts furled and pointed forward (the way
## you carry it), swings up over the head and the canopy pops open with a small overshoot.
## `rest_tilt` is the sideways lean it ends at (degrees).
static func open_up(um: Node3D, delay := 0.0, rest_tilt := 17.0, duration := 0.55) -> void:
	set_open(um, 0.0)
	um.rotation_degrees = Vector3(-70.0, 0.0, rest_tilt * 0.3)
	var tw := um.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(um, "rotation_degrees", Vector3(-12.0, 0.0, rest_tilt * 0.6), duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float): set_open(um, t), 0.0, 1.0, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(um, "rotation_degrees", Vector3(0.0, 0.0, rest_tilt), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
