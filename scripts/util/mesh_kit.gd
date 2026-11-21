class_name MK
## Small helpers for building low-poly geometry and PS1-style materials in code.

static var _tex_cache := {}
static var _mat_cache := {}


static func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/textures/%s.png" % name)
	return _tex_cache[name]


## Standard lit material. With a texture it uses world-space triplanar mapping,
## so texel density stays consistent across every box. `tile` = metres per texture repeat.
static func mat(color: Color, texture := "", roughness := 0.8, tile := 1.0, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [color, texture, roughness, tile, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if texture != "":
		m.albedo_texture = tex(texture)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / tile
	_mat_cache[key] = m
	return m


## Material using the mesh's own UVs (for quads showing a whole picture: signs, paper, clock).
static func picture(texture: String, roughness := 0.8, emission := 0.0, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(texture)
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if emission > 0.0:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = emission
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func emissive(color: Color, energy := 1.0, base := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


static func _add(parent: Node, mesh: Mesh, pos: Vector3, material: Material, rot_deg: Vector3, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if material:
		mi.material_override = material
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, name := "") -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, pos, material, rot_deg, name)


## Box given by min/max corners (easier for architecture).
static func box_from(parent: Node, a: Vector3, b: Vector3, material: Material, name := "") -> MeshInstance3D:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return box(parent, hi - lo, (lo + hi) * 0.5, material, Vector3.ZERO, name)


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, material: Material, segments := 8, rot_deg := Vector3.ZERO, name := "") -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = segments
	m.rings = 1
	return _add(parent, m, pos, material, rot_deg, name)


static func sphere(parent: Node, r: float, pos: Vector3, material: Material, segments := 8, rings := 5, name := "") -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segments
	m.rings = rings
	return _add(parent, m, pos, material, Vector3.ZERO, name)


static func quad(parent: Node, size: Vector2, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, name := "") -> MeshInstance3D:
	var m := QuadMesh.new()
	m.size = size
	return _add(parent, m, pos, material, rot_deg, name)


## A prism whose top face is narrower than its bottom along X (car cabins, phone bodies).
## size = bottom size; top_x = top length along X; top_shift = X offset of the top face.
static func taper(parent: Node, size: Vector3, top_x: float, top_shift: float, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, top_z := -1.0) -> MeshInstance3D:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var tz := hz if top_z < 0.0 else top_z * 0.5
	var tx := top_x * 0.5
	var v := [
		Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz),
		Vector3(-tx + top_shift, hy, -tz), Vector3(tx + top_shift, hy, -tz), Vector3(tx + top_shift, hy, tz), Vector3(-tx + top_shift, hy, tz),
	]
	var faces := [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		for idx in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(v[f[idx]])
	st.generate_normals()
	return _add(parent, st.commit(), pos, material, rot_deg, "")


## Static collider box for mouse picking / later walking.
static func collider(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.position = pos
	body.add_child(cs)
	parent.add_child(body)
	return body


static func omni(parent: Node, pos: Vector3, color: Color, energy: float, range_m: float, shadows := false, name := "") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = shadows
	if name != "":
		l.name = name
	parent.add_child(l)
	return l
