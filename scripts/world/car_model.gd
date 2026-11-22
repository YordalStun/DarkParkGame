class_name CarModel
extends Node3D
## A late-80s family car built from lofted cross-sections (not boxes): a curved lower body
## with real wheel arches, a tapered glasshouse with pillars, bumpers, lights and trim.
## Glass is dark and reflective, the cabin inside is near-black, so at night you see at
## most a faint outline of whoever is sitting in it.
##
## Nose = local +Z, origin on the ground at the centre of the car.
## Styles: "saloon" (three-box) and "hatch" (sloping tail).
## Options: paint (Color), style, driver_window_open (bool: leave the right front glass down).

var paint := Color(0.4, 0.4, 0.42)
var style := "saloon"
var driver_window_open := false

var body_mat: StandardMaterial3D
var glass_mat: StandardMaterial3D
var head_mat: StandardMaterial3D     ## headlamp lenses (emission switched by the owner)
var tail_mat: StandardMaterial3D     ## rear lamp lenses
var front_plate_z := 2.25
var rear_plate_z := -2.25
var plate_y := 0.5
var head_points: Array[Vector3] = []   ## where the headlamps are (for spot lights)
var seat := Vector3(-0.37, 0.0, -0.22)  ## driver's hip, right-hand drive (local -X)
var window_hole := Vector2(-0.42, 0.62) ## z range of the front door glass

const W := 0.86          ## half width
const BELT := 0.96       ## waistline height


func build() -> Node3D:
	_materials()
	_lower_body()
	_glasshouse()
	_trim()
	_wheels()
	_lights()
	_interior()
	return self


func _materials() -> void:
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = paint
	body_mat.metallic = 0.45
	body_mat.roughness = 0.28
	body_mat.clearcoat_enabled = true
	body_mat.clearcoat = 1.0
	body_mat.clearcoat_roughness = 0.08
	glass_mat = StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.015, 0.02, 0.025, 0.9)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.metallic = 0.55
	glass_mat.roughness = 0.04
	glass_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	head_mat = MK.emissive(Color(1.0, 0.95, 0.82), 0.0, Color(0.75, 0.75, 0.72))
	head_mat.roughness = 0.05
	tail_mat = MK.emissive(Color(1.0, 0.06, 0.03), 0.0, Color(0.35, 0.02, 0.02))
	tail_mat.roughness = 0.1


# ------------------------------------------------------------------ helpers
## Height of the bonnet / beltline / boot top along the car.
func _top(z: float) -> float:
	var pts: Array
	if style == "hatch":
		pts = [[-2.12, 0.74], [-2.06, 0.94], [-1.7, 0.96], [0.55, BELT], [1.9, 0.86], [2.1, 0.8], [2.17, 0.7]]
	else:
		pts = [[-2.2, 0.78], [-2.14, 0.92], [-1.95, 0.95], [-1.3, BELT], [0.55, BELT], [1.95, 0.86], [2.15, 0.8], [2.22, 0.7]]
	return _pl(pts, z)


func _half_w(z: float) -> float:
	var r := -2.12 if style == "hatch" else -2.2
	var f := 2.17 if style == "hatch" else 2.22
	return _pl([[r, 0.76], [r + 0.08, 0.83], [r + 0.3, W], [f - 0.3, W], [f - 0.07, 0.83], [f, 0.75]], z)


## Bottom edge: the sill, cut up into arches over the wheels.
func _bottom(z: float) -> float:
	var y := 0.27
	for c in [-1.36, 1.33]:
		var d := absf(z - c) / 0.42
		if d < 1.0:
			y = maxf(y, 0.27 + 0.39 * sqrt(1.0 - d * d))
	var r := -2.12 if style == "hatch" else -2.2
	var f := 2.17 if style == "hatch" else 2.22
	y = maxf(y, _pl([[r, 0.36], [r + 0.12, 0.27], [f - 0.12, 0.27], [f, 0.38]], z))
	return y


func _pl(pts: Array, z: float) -> float:
	if z <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if z <= pts[i][0]:
			var t: float = (z - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0])
			return lerpf(pts[i - 1][1], pts[i][1], t)
	return pts[-1][1]


## Builds a smooth-shaded skin through a grid of rings (rings[i][j]).
func _loft(rings: Array, mat: Material, name := "", flip := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_r := rings.size()
	var n_p: int = rings[0].size()
	var normals := []
	for i in n_r:
		var row := []
		for j in n_p:
			var a: Vector3 = rings[i][mini(j + 1, n_p - 1)] - rings[i][maxi(j - 1, 0)]
			var b: Vector3 = rings[mini(i + 1, n_r - 1)][j] - rings[maxi(i - 1, 0)][j]
			var n := b.cross(a).normalized()
			if flip:
				n = -n
			row.append(n)
		normals.append(row)
	for i in n_r - 1:
		for j in n_p - 1:
			var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			var order := [0, 2, 1, 0, 3, 2] if not flip else [0, 1, 2, 0, 2, 3]
			for k in order:
				var ij: Array = quad[k]
				st.set_normal(normals[ij[0]][ij[1]])
				st.set_uv(Vector2(float(ij[1]) / n_p, float(ij[0]) / n_r))
				st.add_vertex(rings[ij[0]][ij[1]])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if name != "":
		mi.name = name
	add_child(mi)
	return mi


func _fan(points: Array, center: Vector3, mat: Material, normal: Vector3) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		var tri := [center, points[i], points[i + 1]]
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0])
		if n.dot(normal) > 0.0:
			tri = [center, points[i + 1], points[i]]
		for v in tri:
			st.set_normal(normal)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## A thin bar between two points (pillars, trims, wipers).
func _bar(a: Vector3, b: Vector3, thick: Vector2, mat: Material) -> MeshInstance3D:
	var d := b - a
	var m := MK.box(self, Vector3(thick.x, thick.y, d.length()), (a + b) * 0.5, mat)
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	m.basis = Basis.looking_at(d.normalized(), up)
	return m


# ------------------------------------------------------------------ body
func _lower_body() -> void:
	var zs := []
	var r := -2.12 if style == "hatch" else -2.2
	var f := 2.17 if style == "hatch" else 2.22
	var z := r
	while z < f:
		zs.append(z)
		z += 0.07
	zs.append(f)
	var rings := []
	for zz in zs:
		var b := _bottom(zz)
		var t := _top(zz)
		var w := _half_w(zz)
		var ring := []
		# Up the left side, over the top, down the right side.
		var side := [[0.95, b], [0.985, maxf(b, 0.36)], [1.0, maxf(b, 0.5)], [1.0, maxf(b, t - 0.2)], [0.985, maxf(b, t - 0.06)], [0.93, t]]
		for s in side:
			ring.append(Vector3(-w * s[0], s[1], zz))
		ring.append(Vector3(-w * 0.45, t + 0.018, zz))
		ring.append(Vector3(0.0, t + 0.024, zz))
		ring.append(Vector3(w * 0.45, t + 0.018, zz))
		for i in range(side.size() - 1, -1, -1):
			ring.append(Vector3(w * side[i][0], side[i][1], zz))
		rings.append(ring)
	_loft(rings, body_mat, "Body")
	# End caps (front and rear panels).
	_fan(rings[0], Vector3(0, (_bottom(r) + _top(r)) * 0.5, r), body_mat, Vector3(0, 0, -1))
	_fan(rings[-1], Vector3(0, (_bottom(f) + _top(f)) * 0.5, f), body_mat, Vector3(0, 0, 1))
	# Inside the arches and under the car: black.
	var black := MK.mat(Color(0.015, 0.015, 0.015), "", 0.9)
	MK.box(self, Vector3(W * 1.9, 0.5, (f - r) - 0.3), Vector3(0, 0.55, (f + r) * 0.5), black)


## Glasshouse profile along the car: belt y, roof y, belt half-width, roof half-width.
func _gh(z: float) -> Array:
	var roof: Array
	if style == "hatch":
		roof = [[-2.06, 0.95], [-1.75, 1.2], [-1.3, 1.36], [-1.0, 1.38], [0.05, 1.38], [0.62, 0.97]]
	else:
		roof = [[-1.3, 0.97], [-0.92, 1.32], [-0.78, 1.37], [-0.6, 1.38], [0.05, 1.38], [0.62, 0.97]]
	var y := _pl(roof, z)
	var t := clampf((y - BELT) / (1.38 - BELT), 0.0, 1.0)
	return [BELT, y, 0.8, lerpf(0.79, 0.65, t)]


func _glasshouse() -> void:
	var r0 := -2.06 if style == "hatch" else -1.3
	var r1 := 0.62
	var b0 := window_hole.x - 0.07   # B pillar
	var b1 := window_hole.x
	var c1 := -1.28 if style == "hatch" else -0.86   # end of the C pillar
	var keys := [r0, c1, b0, b1, r1]
	if style == "hatch":
		keys = [r0, -1.75, c1, b0, b1, r1]
	# Sample the profile densely, keeping the key stations.
	var zs := []
	for i in keys.size() - 1:
		var n := maxi(1, int(ceil((keys[i + 1] - keys[i]) / 0.12)))
		for k in n:
			zs.append(lerpf(keys[i], keys[i + 1], float(k) / n))
	zs.append(r1)
	# Top strip (rear screen, roof, windscreen) in glass; the roof is painted over it.
	var top := []
	for z in zs:
		var g := _gh(z)
		top.append([Vector3(-g[3], g[1], z), Vector3(0, g[1] + 0.03 * clampf((g[1] - BELT) / 0.4, 0, 1), z), Vector3(g[3], g[1], z)])
	_loft(top, glass_mat, "Screens")
	var roof := []
	for z in zs:
		var g := _gh(z)
		if g[1] >= 1.355:
			roof.append([Vector3(-g[3] - 0.01, g[1] + 0.006, z), Vector3(0, g[1] + 0.04, z), Vector3(g[3] + 0.01, g[1] + 0.006, z)])
	if roof.size() >= 2:
		_loft(roof, body_mat, "Roof")
	# Sides: each bay between stations gets glass, body (C pillar), black (B pillar) or nothing (open window).
	var rubber := MK.mat(Color(0.02, 0.02, 0.02), "", 0.95)
	for sgn in [-1.0, 1.0]:
		var bays := {"c": [], "w": [], "b": [], "f": []}
		for z in zs:
			var key := "f"
			if z <= c1 + 0.001:
				key = "c"
			elif z <= b0 + 0.001:
				key = "w"
			elif z <= b1 + 0.001:
				key = "b"
			bays[key].append(z)
		# Share the boundary stations.
		bays["w"].push_front(c1)
		bays["b"].push_front(b0)
		bays["f"].push_front(b1)
		for k in bays:
			var list: Array = bays[k]
			if list.size() < 2:
				continue
			if k == "f" and sgn < 0.0 and driver_window_open:
				continue
			var mat: Material = glass_mat
			if k == "c":
				mat = body_mat
			elif k == "b":
				mat = rubber
			var rings := []
			for z in list:
				var g := _gh(z)
				# Inset the glass a touch so the pillars stand proud.
				var inset := 0.0 if k in ["c", "b"] else 0.012
				rings.append([Vector3(sgn * (g[2] - inset), g[0], z), Vector3(sgn * (g[3] - inset), g[1], z)])
			_loft(rings, mat, "", sgn > 0.0)
	# A pillars and the window rubbers along the waist.
	for sgn in [-1.0, 1.0]:
		var ga := _gh(0.05)
		_bar(Vector3(sgn * 0.8, BELT + 0.01, r1 - 0.02), Vector3(sgn * ga[3], 1.375, 0.05), Vector2(0.06, 0.05), body_mat)
		_bar(Vector3(sgn * 0.815, BELT + 0.006, r0 + 0.05), Vector3(sgn * 0.815, BELT + 0.006, r1 - 0.02), Vector2(0.03, 0.02), rubber)
		_bar(Vector3(sgn * 0.66, 1.372, -0.6 if style != "hatch" else -1.0), Vector3(sgn * 0.66, 1.372, 0.05), Vector2(0.02, 0.025), rubber)
	# Wipers.
	for x in [-0.32, 0.22]:
		_bar(Vector3(x, 1.0, 0.6), Vector3(x + 0.38, 1.02, 0.56), Vector2(0.015, 0.012), rubber)


func _trim() -> void:
	var plastic := MK.mat(Color(0.03, 0.03, 0.03), "", 0.55)
	var chrome := MK.mat(Color(0.7, 0.7, 0.7), "", 0.15, 1.0, 0.95)
	var r := -2.12 if style == "hatch" else -2.2
	var f := 2.17 if style == "hatch" else 2.22
	front_plate_z = f + 0.075
	rear_plate_z = r - 0.075
	# Wrap-around bumpers.
	for z in [f + 0.03, r - 0.03]:
		MK.box(self, Vector3(W * 2.0 + 0.04, 0.17, 0.12), Vector3(0, 0.42, z), plastic)
		for sgn in [-1.0, 1.0]:
			MK.box(self, Vector3(0.1, 0.16, 0.42), Vector3(sgn * (W - 0.02), 0.42, z - signf(z) * 0.18), plastic)
	# Side rubbing strip and door shut lines.
	for sgn in [-1.0, 1.0]:
		_bar(Vector3(sgn * (W + 0.012), 0.6, r + 0.45), Vector3(sgn * (W + 0.012), 0.6, f - 0.45), Vector2(0.025, 0.05), plastic)
		for z in [window_hole.x - 0.02, window_hole.y + 0.02, -1.25 if style != "hatch" else -1.2]:
			if style == "hatch" and z < -1.0:
				continue
			_bar(Vector3(sgn * (W + 0.004), 0.32, z), Vector3(sgn * (W + 0.004), 0.95, z), Vector2(0.006, 0.008), plastic)
		# Door handles.
		for z in [window_hole.x + 0.12, -1.05]:
			if style == "hatch" and z < -1.0:
				continue
			MK.box(self, Vector3(0.02, 0.03, 0.12), Vector3(sgn * (W + 0.008), 0.86, z), chrome)
		# Door mirror.
		MK.box(self, Vector3(0.05, 0.03, 0.06), Vector3(sgn * 0.84, 0.99, 0.52), plastic)
		MK.box(self, Vector3(0.11, 0.075, 0.05), Vector3(sgn * 0.9, 1.02, 0.5), plastic)
	# Grille.
	MK.box(self, Vector3(0.62, 0.13, 0.03), Vector3(0, 0.64, f + 0.005), plastic)
	for i in 4:
		MK.box(self, Vector3(0.6, 0.008, 0.035), Vector3(0, 0.59 + i * 0.033, f + 0.006), chrome)
	# Number plates (backing; the text is added by the owner).
	plate_y = 0.44
	MK.box(self, Vector3(0.53, 0.12, 0.012), Vector3(0, plate_y, front_plate_z - 0.006), MK.mat(Color(0.92, 0.92, 0.88), "", 0.5))
	MK.box(self, Vector3(0.53, 0.12, 0.012), Vector3(0, plate_y, rear_plate_z + 0.006), MK.mat(Color(0.96, 0.78, 0.12), "", 0.5))
	# Exhaust and aerial.
	MK.cyl(self, 0.03, 0.03, 0.12, Vector3(0.5, 0.26, r - 0.02), MK.mat(Color(0.25, 0.25, 0.25), "", 0.5, 1.0, 0.6), 6, Vector3(90, 0, 0))
	MK.cyl(self, 0.003, 0.004, 0.75, Vector3(0.7, 1.3, 0.75), chrome, 4, Vector3(-15, 0, 0))


func _wheels() -> void:
	var tyre := MK.mat(Color(0.025, 0.025, 0.025), "", 0.9)
	var steel := MK.mat(Color(0.55, 0.56, 0.56), "", 0.3, 1.0, 0.8)
	var hub := MK.mat(Color(0.2, 0.2, 0.21), "", 0.4, 1.0, 0.6)
	for zc in [-1.36, 1.33]:
		for sgn in [-1.0, 1.0]:
			var x: float = sgn * (W - 0.1)
			MK.cyl(self, 0.3, 0.3, 0.19, Vector3(x, 0.3, zc), tyre, 18, Vector3(0, 0, 90))
			MK.cyl(self, 0.19, 0.19, 0.012, Vector3(x + sgn * 0.093, 0.3, zc), steel, 16, Vector3(0, 0, 90))
			MK.cyl(self, 0.07, 0.07, 0.016, Vector3(x + sgn * 0.097, 0.3, zc), hub, 10, Vector3(0, 0, 90))
			for k in 6:
				var a := k * TAU / 6.0
				MK.box(self, Vector3(0.01, 0.022, 0.022), Vector3(x + sgn * 0.1, 0.3 + sin(a) * 0.13, zc + cos(a) * 0.13), hub)


func _lights() -> void:
	var f := 2.17 if style == "hatch" else 2.22
	var r := -2.12 if style == "hatch" else -2.2
	var amber := MK.emissive(Color(1.0, 0.55, 0.1), 0.2, Color(0.6, 0.35, 0.05))
	var chrome := MK.mat(Color(0.7, 0.7, 0.7), "", 0.15, 1.0, 0.95)
	head_points.clear()
	for sgn in [-1.0, 1.0]:
		# Wide rectangular headlamps in a chrome surround, amber indicators outboard.
		MK.box(self, Vector3(0.34, 0.15, 0.02), Vector3(sgn * 0.5, 0.65, f + 0.002), chrome)
		MK.box(self, Vector3(0.31, 0.12, 0.02), Vector3(sgn * 0.5, 0.65, f + 0.008), head_mat)
		MK.box(self, Vector3(0.1, 0.12, 0.02), Vector3(sgn * 0.75, 0.65, f - 0.01), amber)
		head_points.append(Vector3(sgn * 0.5, 0.65, f + 0.04))
		# Rear clusters.
		MK.box(self, Vector3(0.42, 0.14, 0.02), Vector3(sgn * 0.56, 0.78, r - 0.002), tail_mat)
		MK.box(self, Vector3(0.1, 0.14, 0.02), Vector3(sgn * 0.82, 0.78, r + 0.01), amber)


## Visual layer for things inside the cabin: the booth floodlight skips it, so the
## inside of a car stays dark even with the window down.
const CABIN_LAYER := 2


static func to_cabin_layer(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = 1 << (CABIN_LAYER - 1)
	for c in n.get_children():
		to_cabin_layer(c)


func _interior() -> void:
	var first := get_child_count()
	var dark := MK.mat(Color(0.012, 0.012, 0.014), "", 0.95)
	var fabric := MK.mat(Color(0.04, 0.038, 0.035), "", 1.0)
	# Dash, seats, rear bench, parcel shelf: all near-black so the cabin reads as darkness.
	MK.box(self, Vector3(1.5, 0.22, 0.35), Vector3(0, 0.88, 0.42), dark)
	for sx in [-0.37, 0.37]:
		MK.box(self, Vector3(0.48, 0.12, 0.5), Vector3(sx, 0.5, -0.2), fabric)
		MK.box(self, Vector3(0.48, 0.6, 0.1), Vector3(sx, 0.82, -0.48), fabric)
		MK.box(self, Vector3(0.26, 0.16, 0.08), Vector3(sx, 1.2, -0.5), fabric)
	MK.box(self, Vector3(1.5, 0.5, 0.5), Vector3(0, 0.62, -1.0), fabric)
	MK.box(self, Vector3(1.5, 0.3, 0.9), Vector3(0, 0.45, 0.0), dark)
	# Steering wheel on the right (local -X).
	var wheel := MK.cyl(self, 0.19, 0.19, 0.025, Vector3(-0.37, 0.98, 0.22), dark, 14, Vector3(65, 0, 0))
	wheel.name = "SteeringWheel"
	# Headlining (so the roof isn't see-through from below).
	MK.box(self, Vector3(1.2, 0.02, 0.6), Vector3(0, 1.34, -0.28), dark)
	for i in range(first, get_child_count()):
		to_cabin_layer(get_child(i))
