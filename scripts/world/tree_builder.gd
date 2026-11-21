class_name TreeBuilder
## Builds low-poly trees (faceted, PS1-style) as single meshes with two surfaces:
## trunk/branches and foliage. Both use the foliage shader so the whole tree
## sways in the wind; the bend increases with height.

static var _variants := {}
static var _foliage_shader: Shader


static func _shader() -> Shader:
	if _foliage_shader == null:
		_foliage_shader = load("res://shaders/foliage.gdshader")
	return _foliage_shader


static func _material(texture: String, tint: Color, height: float, stiffness: float, flutter: float, tex_scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader()
	m.set_shader_parameter("albedo_tex", MK.tex(texture))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("stiffness", stiffness)
	m.set_shader_parameter("flutter", flutter)
	m.set_shader_parameter("tex_scale", tex_scale)
	return m


## kind: "oak" (round clumps), "pine" (stacked cones), "bush"
static func make(kind: String, variant: int, height: float) -> MeshInstance3D:
	var key := "%s_%d_%.1f" % [kind, variant, height]
	if not _variants.has(key):
		_variants[key] = _build(kind, variant, height)
	var mi := MeshInstance3D.new()
	mi.mesh = _variants[key]
	return mi


static func _build(kind: String, variant: int, height: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + variant * 7919
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)

	match kind:
		"pine":
			var trunk_h := height * 0.95
			_cylinder(trunk, Vector3.ZERO, Vector3(0, trunk_h, 0), height * 0.035, height * 0.015, 6, Color(1, 1, 1))
			var tiers := 4 + variant % 2
			for i in tiers:
				var t := float(i) / tiers
				var y0 := height * (0.18 + t * 0.62)
				var r := height * (0.3 - t * 0.2) * rng.randf_range(0.9, 1.1)
				var h := height * 0.34
				_cone(leaves, Vector3(rng.randf_range(-0.1, 0.1), y0, rng.randf_range(-0.1, 0.1)), r, h, 7, rng, Color(0.75 + t * 0.35, 0.75 + t * 0.35, 0.75 + t * 0.35))
		"bush":
			for i in 4:
				var c := Vector3(rng.randf_range(-0.5, 0.5), height * rng.randf_range(0.35, 0.6), rng.randf_range(-0.5, 0.5))
				_blob(leaves, c, height * rng.randf_range(0.45, 0.6), rng, 6, 4)
		_:  # oak / deciduous
			var trunk_top := height * 0.55
			var lean := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			_cylinder(trunk, Vector3.ZERO, Vector3(0, trunk_top, 0) + lean, height * 0.05, height * 0.03, 6, Color(1, 1, 1))
			# Branches out to the clumps.
			var clumps := 4 + variant % 3
			for i in clumps:
				var ang := TAU * i / clumps + rng.randf_range(-0.4, 0.4)
				var out := rng.randf_range(0.18, 0.32) * height
				var c := Vector3(cos(ang) * out, height * rng.randf_range(0.6, 0.82), sin(ang) * out) + lean
				_cylinder(trunk, Vector3(0, trunk_top * 0.8, 0) + lean * 0.8, c * Vector3(0.7, 0.92, 0.7), height * 0.022, height * 0.01, 5, Color(1, 1, 1))
				_blob(leaves, c, height * rng.randf_range(0.17, 0.24), rng, 7, 5)
			_blob(leaves, Vector3(0, height * 0.86, 0) + lean, height * 0.22, rng, 7, 5)

	var mesh := ArrayMesh.new()
	if kind != "bush":
		trunk.generate_normals()
		trunk.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material("bark", Color(0.85, 0.8, 0.75), height, 0.5, 0.0, 1.2))
	leaves.generate_normals()
	leaves.commit(mesh)
	var leaf_tex := "pine" if kind == "pine" else "leaves"
	var tint := Color(0.75, 0.85, 0.8) if kind == "pine" else Color(0.85, 0.8, 0.62)
	mesh.surface_set_material(mesh.get_surface_count() - 1, _material(leaf_tex, tint, height, 1.0, 1.0 if kind != "pine" else 0.4, 1.0))
	return mesh


## Faceted, lumpy sphere for a clump of leaves. Vertex colour darkens the underside (fake AO).
static func _blob(st: SurfaceTool, center: Vector3, radius: float, rng: RandomNumberGenerator, segs: int, rings: int) -> void:
	var pts := []
	for r in rings + 1:
		var row := []
		var v := float(r) / rings
		var phi := v * PI
		for s in segs:
			var th := TAU * s / segs
			var p := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var jitter := 1.0 if r == 0 or r == rings else rng.randf_range(0.78, 1.18)
			p = p * radius * jitter
			p.y *= 0.8
			row.append(center + p)
		pts.append(row)
	for r in rings:
		for s in segs:
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][(s + 1) % segs]
			var c: Vector3 = pts[r + 1][s]
			var d: Vector3 = pts[r + 1][(s + 1) % segs]
			_tri(st, a, c, b, center, radius)
			_tri(st, b, c, d, center, radius)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3, radius: float) -> void:
	for p in [a, b, c]:
		var k := clampf(0.55 + 0.45 * (p.y - center.y) / radius, 0.35, 1.0)
		st.set_color(Color(k, k, k))
		st.add_vertex(p)


static func _cone(st: SurfaceTool, base: Vector3, radius: float, height: float, segs: int, rng: RandomNumberGenerator, col: Color) -> void:
	var tip := base + Vector3(0, height, 0)
	var ring := []
	for s in segs:
		var th := TAU * s / segs
		var rr := radius * rng.randf_range(0.85, 1.15)
		ring.append(base + Vector3(cos(th) * rr, rng.randf_range(-0.15, 0.1) * height, sin(th) * rr))
	for s in segs:
		var a: Vector3 = ring[s]
		var b: Vector3 = ring[(s + 1) % segs]
		st.set_color(col)
		st.add_vertex(tip)
		st.set_color(col * 0.6)
		st.add_vertex(a)
		st.add_vertex(b)
		# underside
		st.set_color(col * 0.35)
		st.add_vertex(base + Vector3(0, height * 0.1, 0))
		st.add_vertex(b)
		st.add_vertex(a)


static func _cylinder(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, segs: int, col: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	if absf(axis.y) > 0.9:
		side = Vector3.RIGHT
	var side2 := axis.cross(side).normalized()
	for s in segs:
		var t0 := TAU * s / segs
		var t1 := TAU * (s + 1) / segs
		var d0 := side * cos(t0) + side2 * sin(t0)
		var d1 := side * cos(t1) + side2 * sin(t1)
		var p0 := a + d0 * r0
		var p1 := a + d1 * r0
		var p2 := b + d0 * r1
		var p3 := b + d1 * r1
		st.set_color(col * 0.7)
		st.add_vertex(p0)
		st.set_color(col)
		st.add_vertex(p2)
		st.set_color(col * 0.7)
		st.add_vertex(p1)
		st.add_vertex(p1)
		st.set_color(col)
		st.add_vertex(p2)
		st.add_vertex(p3)
