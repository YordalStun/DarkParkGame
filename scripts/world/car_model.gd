class_name CarModel
extends Node3D
## Late-80s British road vehicles built from lofted cross-sections (not boxes): a curved
## lower body with real wheel arches, a tapered glasshouse with pillars, bumpers, lamps and
## trim. Glass is dark and reflective and the cabin is near-black, so at night you see at
## most a faint outline of whoever is sitting inside.
##
## Nose = local +Z, origin on the ground at the centre of the car.
## Ten designs (SPECS): saloon, hatch, supermini, estate, coupe, exec, 4x4, van, sports, mpv.
## Options: paint, style, driver_window_open (leave the right front glass down).

const STYLES := ["saloon", "hatch", "supermini", "estate", "coupe", "exec", "4x4", "van", "sports", "mpv"]

## Every number is in metres, local space. top = bonnet/waist/boot line; roof = glasshouse
## roof line from g0 (back of the glass) to g1 (base of the windscreen).
const SPECS := {
	"saloon": {"seat_drop": 0.03, "r": -2.2, "f": 2.22, "w": 0.86, "axles": [-1.36, 1.33], "belt": 0.96, "c1": -0.86,
		"top": [[-2.2, 0.78], [-2.14, 0.92], [-1.95, 0.95], [-1.3, 0.96], [0.55, 0.96], [1.95, 0.86], [2.15, 0.8], [2.22, 0.7]],
		"g0": -1.3, "g1": 0.62, "roof": [[-1.3, 0.97], [-0.92, 1.32], [-0.78, 1.37], [-0.6, 1.38], [0.05, 1.38], [0.62, 0.97]], "roof_w": 0.65,
		"lamps": "rect"},
	"hatch": {"seat_drop": 0.03, "r": -2.06, "f": 2.12, "w": 0.84, "axles": [-1.3, 1.28], "belt": 0.95, "c1": -1.28,
		"top": [[-2.06, 0.74], [-2.0, 0.93], [-1.7, 0.95], [0.55, 0.95], [1.85, 0.85], [2.05, 0.79], [2.12, 0.68]],
		"g0": -2.0, "g1": 0.6, "roof": [[-2.0, 0.94], [-1.75, 1.2], [-1.3, 1.36], [-1.0, 1.38], [0.05, 1.38], [0.6, 0.96]], "roof_w": 0.64,
		"lamps": "rect"},
	"supermini": {"r": -1.7, "f": 1.72, "w": 0.78, "axles": [-1.12, 1.12], "wr": 0.27, "belt": 0.95, "c1": -1.22, "door": 0.98,
		"top": [[-1.7, 0.74], [-1.64, 0.93], [-1.4, 0.95], [0.42, 0.95], [1.45, 0.86], [1.66, 0.8], [1.72, 0.68]],
		"g0": -1.64, "g1": 0.48, "roof": [[-1.64, 0.95], [-1.5, 1.28], [-1.25, 1.4], [-0.1, 1.41], [0.48, 0.96]], "roof_w": 0.6,
		"lamps": "round2"},
	"estate": {"r": -2.4, "f": 2.4, "w": 0.87, "axles": [-1.38, 1.45], "belt": 0.98, "c1": -2.16,
		"top": [[-2.4, 0.78], [-2.36, 0.97], [-2.2, 0.98], [0.7, 0.98], [2.05, 0.88], [2.32, 0.82], [2.4, 0.7]],
		"g0": -2.36, "g1": 0.75, "roof": [[-2.36, 0.98], [-2.31, 1.42], [-2.2, 1.44], [0.15, 1.44], [0.75, 0.99]], "roof_w": 0.7,
		"lamps": "square", "tail": "vertical", "rails": true},
	"coupe": {"seat_drop": 0.11, "r": -2.15, "f": 2.22, "w": 0.84, "axles": [-1.3, 1.27], "belt": 0.9, "c1": -1.05, "door": 1.22,
		"top": [[-2.15, 0.76], [-2.1, 0.89], [-1.85, 0.91], [0.3, 0.9], [2.0, 0.8], [2.17, 0.74], [2.22, 0.64]],
		"g0": -1.85, "g1": 0.32, "roof": [[-1.85, 0.91], [-1.0, 1.2], [-0.72, 1.27], [-0.2, 1.28], [0.32, 0.91]], "roof_w": 0.62,
		"lamps": "round4", "stripe": true},
	"exec": {"seat_drop": 0.03, "r": -2.42, "f": 2.46, "w": 0.9, "axles": [-1.46, 1.46], "wr": 0.31, "belt": 0.97, "c1": -0.97, "door": 1.1,
		"top": [[-2.42, 0.8], [-2.36, 0.94], [-2.1, 0.97], [-1.4, 0.97], [0.66, 0.97], [2.2, 0.86], [2.39, 0.8], [2.46, 0.7]],
		"g0": -1.4, "g1": 0.72, "roof": [[-1.4, 0.98], [-1.0, 1.33], [-0.85, 1.39], [-0.65, 1.4], [0.12, 1.4], [0.72, 0.98]], "roof_w": 0.68,
		"lamps": "round4", "chrome": true, "alloys": true},
	"4x4": {"r": -2.2, "f": 2.22, "w": 0.9, "axles": [-1.3, 1.28], "wr": 0.38, "sill": 0.46, "belt": 1.18, "c1": -1.95,
		"top": [[-2.2, 1.0], [-2.17, 1.17], [-2.0, 1.18], [0.75, 1.18], [1.95, 1.12], [2.17, 1.08], [2.22, 0.98]],
		"g0": -2.17, "g1": 0.78, "roof": [[-2.17, 1.18], [-2.14, 1.76], [-2.05, 1.78], [0.45, 1.78], [0.78, 1.19]], "roof_w": 0.8,
		"lamps": "square", "tail": "vertical", "lamp_y": 0.92, "bumper_y": 0.62, "rails": true},
	"van": {"r": -2.32, "f": 2.3, "w": 0.95, "axles": [-1.5, 1.42], "wr": 0.33, "sill": 0.36, "belt": 1.1, "door": 0.9, "rear_glass": false,
		"top": [[-2.32, 0.92], [-2.3, 1.09], [1.0, 1.1], [1.9, 1.02], [2.25, 0.96], [2.3, 0.82]],
		"g0": -2.3, "g1": 1.0, "roof": [[-2.3, 1.1], [-2.29, 2.0], [-2.2, 2.02], [0.55, 2.02], [1.0, 1.12]], "roof_w": 0.9,
		"lamps": "square", "tail": "vertical", "lamp_y": 0.86, "bumper_y": 0.5, "no_rear_windows": true},
	"sports": {"seat_drop": 0.16, "r": -2.0, "f": 2.05, "w": 0.84, "axles": [-1.2, 1.25], "wr": 0.29, "sill": 0.22, "belt": 0.86, "c1": -1.0, "door": 1.05,
		"top": [[-2.0, 0.74], [-1.96, 0.86], [-1.6, 0.88], [0.05, 0.86], [1.9, 0.62], [2.05, 0.52]],
		"g0": -1.6, "g1": 0.05, "roof": [[-1.6, 0.88], [-1.05, 1.15], [-0.8, 1.19], [-0.45, 1.19], [0.05, 0.87]], "roof_w": 0.6,
		"lamps": "popup", "lamp_y": 0.5, "bumper_y": 0.36, "alloys": true, "spoiler": true},
	"mpv": {"r": -2.15, "f": 2.2, "w": 0.88, "axles": [-1.3, 1.3], "belt": 1.0, "c1": -1.95,
		"top": [[-2.15, 0.82], [-2.12, 0.99], [-1.9, 1.0], [1.0, 1.0], [1.9, 0.9], [2.15, 0.78], [2.2, 0.7]],
		"g0": -2.12, "g1": 1.0, "roof": [[-2.12, 1.0], [-2.08, 1.6], [-1.95, 1.63], [0.25, 1.63], [1.0, 1.02]], "roof_w": 0.78,
		"lamps": "rect", "lamp_y": 0.72},
}

var paint := Color(0.4, 0.4, 0.42)
var style := "saloon"
var driver_window_open := false

var body_mat: StandardMaterial3D
var glass_mat: StandardMaterial3D
var head_mat: StandardMaterial3D     ## headlamp lenses (emission switched by the owner)
var tail_mat: StandardMaterial3D     ## rear lamp lenses
var front_plate_z := 2.25
var rear_plate_z := -2.25
var plate_y := 0.44
var head_points: Array[Vector3] = []   ## where the headlamps are (for spot lights)
var seat := Vector3(-0.37, 0.0, -0.22)  ## driver's hip, right-hand drive (local -X)
var window_hole := Vector2(-0.42, 0.62) ## z range of the front door glass
var half_width := 0.86

var S: Dictionary   ## the spec being built
var _rubber: StandardMaterial3D
var _plastic: StandardMaterial3D
var _chrome: StandardMaterial3D


## A random design (for the night's traffic).
static func random_style(rng: RandomNumberGenerator = null) -> String:
	if rng:
		return STYLES[rng.randi() % STYLES.size()]
	return STYLES.pick_random()


func build() -> Node3D:
	S = SPECS.get(style, SPECS["saloon"])
	half_width = S.w
	var door: float = S.get("door", 1.04)
	window_hole = Vector2(S.g1 - door, S.g1)
	# Low cars seat the driver lower (seat_drop) so their head stays under the roof.
	seat = Vector3(-S.w * 0.43, S.belt - 0.96 - S.get("seat_drop", 0.0), window_hole.x + 0.2)
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
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	head_mat = MK.emissive(Color(1.0, 0.95, 0.82), 0.0, Color(0.75, 0.75, 0.72))
	head_mat.roughness = 0.05
	tail_mat = MK.emissive(Color(1.0, 0.06, 0.03), 0.0, Color(0.35, 0.02, 0.02))
	tail_mat.roughness = 0.1
	_rubber = MK.mat(Color(0.02, 0.02, 0.02), "", 0.95)
	_plastic = MK.mat(Color(0.03, 0.03, 0.03), "", 0.55)
	_chrome = MK.mat(Color(0.7, 0.7, 0.7), "", 0.15, 1.0, 0.95)


# ------------------------------------------------------------------ profile helpers
func _top(z: float) -> float:
	return _pl(S.top, z)


func _roof(z: float) -> float:
	return _pl(S.roof, z)


func _half_w(z: float) -> float:
	var r: float = S.r
	var f: float = S.f
	var w: float = S.w
	return _pl([[r, w - 0.1], [r + 0.08, w - 0.03], [r + 0.3, w], [f - 0.3, w], [f - 0.07, w - 0.03], [f, w - 0.11]], z)


func _wr() -> float:
	return S.get("wr", 0.3)


## Bottom edge: the sill, cut up into arches over the wheels.
func _bottom(z: float) -> float:
	var sill: float = S.get("sill", 0.27)
	var wr := _wr()
	var y := sill
	var rz := wr + 0.12
	var top := wr * 2.0 + 0.06
	for c in S.axles:
		var d := absf(z - c) / rz
		if d < 1.0:
			y = maxf(y, sill + (top - sill) * sqrt(1.0 - d * d))
	var r: float = S.r
	var f: float = S.f
	y = maxf(y, _pl([[r, sill + 0.09], [r + 0.12, sill], [f - 0.12, sill], [f, sill + 0.11]], z))
	return y


func _pl(pts: Array, z: float) -> float:
	if z <= pts[0][0]:
		return pts[0][1]
	for i in range(1, pts.size()):
		if z <= pts[i][0]:
			var t: float = (z - pts[i - 1][0]) / maxf(pts[i][0] - pts[i - 1][0], 0.0001)
			return lerpf(pts[i - 1][1], pts[i][1], t)
	return pts[-1][1]


## Roof half-width at z: narrows from the waist toward the roof.
func _gw(z: float) -> Array:
	var belt: float = S.belt
	var y := _roof(z)
	var peak := _roof_peak()
	var t := clampf((y - belt) / maxf(peak - belt, 0.01), 0.0, 1.0)
	var wb: float = S.w - 0.06
	return [belt, y, wb, lerpf(wb - 0.01, S.roof_w, t)]


func _roof_peak() -> float:
	var m := 0.0
	for p in S.roof:
		m = maxf(m, p[1])
	return m


## Where the flat roof starts and ends (z).
func _roof_span() -> Vector2:
	var peak := _roof_peak()
	var a := 1e9
	var b := -1e9
	for p in S.roof:
		if p[1] >= peak - 0.025:
			a = minf(a, p[0])
			b = maxf(b, p[0])
	return Vector2(a, b)


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


## Evenly spaced stations between key z values (keeping the keys).
func _stations(keys: Array, step := 0.12) -> Array:
	var zs := []
	for i in keys.size() - 1:
		var span: float = keys[i + 1] - keys[i]
		if span < 0.001:
			continue
		var n := maxi(1, int(ceil(span / step)))
		for k in n:
			zs.append(lerpf(keys[i], keys[i + 1], float(k) / n))
	zs.append(keys[-1])
	return zs


# ------------------------------------------------------------------ body
func _lower_body() -> void:
	var r: float = S.r
	var f: float = S.f
	# The boot: a well cut into the top at the back, closed by a separate lid (see _boot_lid).
	var bl: float = clampf(S.g0 - r - 0.1, 0.55, 0.8)
	boot_zone = Vector2(r + 0.07, r + 0.07 + bl)
	boot_floor = maxf(S.get("sill", 0.27) + 0.16, _top(boot_zone.x + 0.1) - 0.3)   # ~30 cm deep: you can see in
	var zs := _stations([r, boot_zone.x, boot_zone.y, f], 0.07)
	var rings := []
	for zz in zs:
		var b := _bottom(zz)
		var t := _top(zz)
		var w := _half_w(zz)
		var ring := []
		# Up the left side, over the top, down the right side.
		# The side's creases sit at fixed heights on a full-depth panel; over a wheel arch
		# they squeeze up proportionally (so no two points ever collapse together).
		var s0: float = S.get("sill", 0.27)
		var full := maxf(t - s0, 0.05)
		var fr := [0.0, 0.09 / full, 0.23 / full, 1.0 - 0.2 / full, 1.0 - 0.06 / full, 1.0]
		var xs := [0.95, 0.985, 1.0, 1.0, 0.985, 0.93]
		var side := []
		for k in fr.size():
			side.append([xs[k], lerpf(b, t, clampf(fr[k], 0.0, 1.0))])
		for s in side:
			ring.append(Vector3(-w * s[0], s[1], zz))
		if zz > boot_zone.x + 0.001 and zz < boot_zone.y - 0.001:
			# Inside the boot: straight down from the rim to the boot floor and across.
			ring.append(Vector3(-w * 0.86, boot_floor, zz))
			ring.append(Vector3(0.0, boot_floor, zz))
			ring.append(Vector3(w * 0.86, boot_floor, zz))
		else:
			ring.append(Vector3(-w * 0.45, t + 0.018, zz))
			ring.append(Vector3(0.0, t + 0.024, zz))
			ring.append(Vector3(w * 0.45, t + 0.018, zz))
		for i in range(side.size() - 1, -1, -1):
			ring.append(Vector3(w * side[i][0], side[i][1], zz))
		rings.append(ring)
	_loft(rings, body_mat, "Body")
	_boot_lid()
	_fan(rings[0], Vector3(0, (_bottom(r) + _top(r)) * 0.5, r), body_mat, Vector3(0, 0, -1))
	_fan(rings[-1], Vector3(0, (_bottom(f) + _top(f)) * 0.5, f), body_mat, Vector3(0, 0, 1))
	# Inside the arches and under the car: black.
	var black := MK.mat(Color(0.015, 0.015, 0.015), "", 0.9)
	var sill: float = S.get("sill", 0.27)
	var top_min := 10.0
	for p in S.top:
		top_min = minf(top_min, p[1])
	var h := maxf(0.2, top_min - sill - 0.05)
	# (Stops short of the boot well, so what's in the boot isn't hidden inside it.)
	var z_start: float = boot_zone.y + 0.02 if boot_zone != Vector2.ZERO else r + 0.15
	MK.box(self, Vector3(S.w * 1.9, h, (f - 0.15) - z_start), Vector3(0, sill + h * 0.5, (f - 0.15 + z_start) * 0.5), black)
	MK.box(self, Vector3(S.w * 1.9, boot_floor - sill, boot_zone.y - r - 0.1), Vector3(0, (sill + boot_floor) * 0.5, (r + 0.08 + boot_zone.y) * 0.5), black)


func _glasshouse() -> void:
	var g0: float = S.g0
	var g1: float = S.g1
	var span := _roof_span()
	var b0 := window_hole.x - 0.07   # B pillar
	var b1 := window_hole.x
	var c1: float = b0 if S.get("no_rear_windows", false) else maxf(S.c1, g0)
	# --- top strip: rear screen (glass, or body on a van), roof (body), windscreen (glass)
	var parts := [[g0, span.x, glass_mat if S.get("rear_glass", true) else body_mat], [span.x, span.y, body_mat], [span.y, g1, glass_mat]]
	for p in parts:
		if p[1] - p[0] < 0.005:
			continue
		var rows := []
		for z in _stations([p[0], p[1]], 0.1):
			var g := _gw(z)
			var crown := 0.03 * clampf((g[1] - g[0]) / 0.4, 0.0, 1.0)
			rows.append([Vector3(-g[3], g[1], z), Vector3(0, g[1] + crown, z), Vector3(g[3], g[1], z)])
		_loft(rows, p[2])
	# --- sides: body (C/D pillar), glass, black (B pillar), glass or open (driver's window)
	var keys := [g0, c1, b0, b1, g1]
	var zs := _stations(keys, 0.12)
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
		if c1 < b0 - 0.001:
			bays["w"].push_front(c1)
		elif not bays["c"].is_empty() and bays["c"][-1] < b0 - 0.001:
			bays["c"].append(b0)
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
				mat = _rubber
			var rings := []
			for z in list:
				var g := _gw(z)
				var inset := 0.0 if k in ["c", "b"] else 0.012
				rings.append([Vector3(sgn * (g[2] - inset), g[0], z), Vector3(sgn * (g[3] - inset), g[1], z)])
			_loft(rings, mat, "", sgn > 0.0)
	# A pillars, rubbers along the waist and roof edge, wipers.
	var peak := _roof_peak()
	for sgn in [-1.0, 1.0]:
		var ga := _gw(span.y)
		_bar(Vector3(sgn * (S.w - 0.06), S.belt + 0.01, g1 - 0.02), Vector3(sgn * ga[3], peak - 0.005, span.y), Vector2(0.06, 0.05), body_mat)
		_bar(Vector3(sgn * (S.w - 0.045), S.belt + 0.006, g0 + 0.05), Vector3(sgn * (S.w - 0.045), S.belt + 0.006, g1 - 0.02), Vector2(0.03, 0.02), _rubber)
		_bar(Vector3(sgn * (S.roof_w + 0.01), peak - 0.008, span.x + 0.05), Vector3(sgn * (S.roof_w + 0.01), peak - 0.008, span.y), Vector2(0.02, 0.025), _rubber)
		if S.get("rails", false):
			_bar(Vector3(sgn * (S.roof_w - 0.08), peak + 0.06, span.x + 0.1), Vector3(sgn * (S.roof_w - 0.08), peak + 0.06, span.y - 0.05), Vector2(0.035, 0.03), _chrome if S.get("chrome", false) else _plastic)
	var wy: float = S.belt + 0.04
	for x in [-0.34 * S.w / 0.86, 0.2 * S.w / 0.86]:
		_bar(Vector3(x, wy, g1 - 0.02), Vector3(x + 0.38, wy + 0.02, g1 - 0.06), Vector2(0.015, 0.012), _rubber)


func _trim() -> void:
	var r: float = S.r
	var f: float = S.f
	var w: float = S.w
	var by: float = S.get("bumper_y", S.get("sill", 0.27) + 0.15)
	var bump: Material = _chrome if S.get("chrome", false) else _plastic
	front_plate_z = f + 0.075
	rear_plate_z = r - 0.075
	plate_y = by + 0.02
	# Wrap-around bumpers.
	for z in [f + 0.03, r - 0.03]:
		MK.box(self, Vector3(w * 2.0 + 0.04, 0.17, 0.12), Vector3(0, by, z), bump)
		for sgn in [-1.0, 1.0]:
			MK.box(self, Vector3(0.1, 0.16, 0.42), Vector3(sgn * (w - 0.02), by, z - signf(z) * 0.18), bump)
	if S.get("chrome", false):
		for z in [f + 0.05, r - 0.05]:
			MK.box(self, Vector3(w * 1.6, 0.05, 0.12), Vector3(0, by - 0.1, z), _plastic)  # rubber strip under the chrome
	var no_rear: bool = S.get("no_rear_windows", false)
	var doors4: bool = not no_rear and S.c1 > S.g0 + 0.3 and S.get("door", 1.04) < 1.15
	for sgn in [-1.0, 1.0]:
		# Rubbing strip (or a coach stripe on the coupe) and door shut lines.
		var strip_y: float = lerpf(S.get("sill", 0.27), S.belt, 0.5)
		if S.get("stripe", false):
			_bar(Vector3(sgn * (w + 0.006), strip_y + 0.08, r + 0.3), Vector3(sgn * (w + 0.006), strip_y + 0.08, f - 0.3), Vector2(0.008, 0.035), MK.mat(Color(0.85, 0.7, 0.2), "", 0.4))
		else:
			_bar(Vector3(sgn * (w + 0.012), strip_y, r + 0.45), Vector3(sgn * (w + 0.012), strip_y, f - 0.45), Vector2(0.025, 0.05), _plastic)
		var lines := [window_hole.x - 0.02, window_hole.y + 0.02]
		if doors4:
			lines.append(S.c1 - 0.02)
		if no_rear:
			lines.append(S.axles[0] + 0.5)   # sliding side door on the van
		for z in lines:
			_bar(Vector3(sgn * (w + 0.004), S.get("sill", 0.27) + 0.05, z), Vector3(sgn * (w + 0.004), S.belt - 0.01, z), Vector2(0.006, 0.008), _plastic)
		var handles := [window_hole.x + 0.12]
		if doors4:
			handles.append(S.c1 + 0.12)
		for z in handles:
			MK.box(self, Vector3(0.02, 0.03, 0.12), Vector3(sgn * (w + 0.008), S.belt - 0.1, z), _chrome)
		# Door mirror.
		MK.box(self, Vector3(0.05, 0.03, 0.06), Vector3(sgn * (w - 0.02), S.belt + 0.03, S.g1 - 0.1), _plastic)
		MK.box(self, Vector3(0.11, 0.075, 0.05), Vector3(sgn * (w + 0.04), S.belt + 0.06, S.g1 - 0.12), _plastic)
	# Grille.
	var ly: float = S.get("lamp_y", minf(_top(f - 0.1) - 0.1, 0.66))
	if S.lamps != "popup":
		MK.box(self, Vector3(0.62, 0.13, 0.03), Vector3(0, ly - 0.01, f + 0.005), _plastic)
		for i in 4:
			MK.box(self, Vector3(0.6, 0.008, 0.035), Vector3(0, ly - 0.05 + i * 0.033, f + 0.006), _chrome)
	else:
		MK.box(self, Vector3(0.7, 0.04, 0.03), Vector3(0, by + 0.11, f + 0.02), _plastic)   # air intake
	# Number plates (backing; the owner adds the text).
	MK.box(self, Vector3(0.53, 0.12, 0.012), Vector3(0, plate_y, front_plate_z - 0.006), MK.mat(Color(0.92, 0.92, 0.88), "", 0.5))
	MK.box(self, Vector3(0.53, 0.12, 0.012), Vector3(0, plate_y, rear_plate_z + 0.006), MK.mat(Color(0.96, 0.78, 0.12), "", 0.5))
	# Exhaust, aerial, spoiler, spare wheel.
	MK.cyl(self, 0.03, 0.03, 0.12, Vector3(w * 0.58, S.get("sill", 0.27) - 0.01, r - 0.02), MK.mat(Color(0.25, 0.25, 0.25), "", 0.5, 1.0, 0.6), 6, Vector3(90, 0, 0))
	MK.cyl(self, 0.003, 0.004, 0.75, Vector3(w * 0.8, _top(f - 0.6) + 0.35, f - 0.6), _chrome, 4, Vector3(-15, 0, 0))
	if S.get("spoiler", false):
		var ty := _top(r + 0.15)
		MK.box(self, Vector3(w * 1.7, 0.03, 0.2), Vector3(0, ty + 0.1, r + 0.12), body_mat, Vector3(-8, 0, 0))
		for sgn in [-0.6, 0.6]:
			MK.box(self, Vector3(0.04, 0.09, 0.08), Vector3(sgn * w, ty + 0.05, r + 0.12), _plastic)
	if style == "4x4":
		MK.cyl(self, 0.33, 0.33, 0.2, Vector3(0, 1.0, r - 0.12), MK.mat(Color(0.03, 0.03, 0.03), "", 0.9), 16, Vector3(90, 0, 0))
		MK.cyl(self, 0.2, 0.2, 0.21, Vector3(0, 1.0, r - 0.12), body_mat, 14, Vector3(90, 0, 0))


func _wheels() -> void:
	var wr := _wr()
	var tyre := MK.mat(Color(0.025, 0.025, 0.025), "", 0.9)
	var alloy: bool = S.get("alloys", false)
	var steel := MK.mat(Color(0.62, 0.63, 0.63) if alloy else Color(0.5, 0.51, 0.51), "", 0.3, 1.0, 0.8)
	var hub := MK.mat(Color(0.2, 0.2, 0.21), "", 0.4, 1.0, 0.6)
	for zc in S.axles:
		for sgn in [-1.0, 1.0]:
			var x: float = sgn * (S.w - 0.1)
			MK.cyl(self, wr, wr, 0.19, Vector3(x, wr, zc), tyre, 18, Vector3(0, 0, 90))
			MK.cyl(self, wr * 0.63, wr * 0.63, 0.012, Vector3(x + sgn * 0.093, wr, zc), steel, 16, Vector3(0, 0, 90))
			MK.cyl(self, wr * 0.23, wr * 0.23, 0.016, Vector3(x + sgn * 0.097, wr, zc), hub, 10, Vector3(0, 0, 90))
			var n := 5 if alloy else 6
			for k in n:
				var a := k * TAU / n
				if alloy:
					_bar(Vector3(x + sgn * 0.1, wr, zc), Vector3(x + sgn * 0.1, wr + sin(a) * wr * 0.58, zc + cos(a) * wr * 0.58), Vector2(0.012, 0.05), hub)
				else:
					MK.box(self, Vector3(0.01, 0.022, 0.022), Vector3(x + sgn * 0.1, wr + sin(a) * wr * 0.43, zc + cos(a) * wr * 0.43), hub)


func _lights() -> void:
	var f: float = S.f
	var r: float = S.r
	var w: float = S.w
	var ly: float = S.get("lamp_y", minf(_top(f - 0.1) - 0.1, 0.66))
	var amber := MK.emissive(Color(1.0, 0.55, 0.1), 0.2, Color(0.6, 0.35, 0.05))
	head_points.clear()
	for sgn in [-1.0, 1.0]:
		var lx: float = sgn * w * 0.58
		match S.lamps:
			"rect":
				MK.box(self, Vector3(0.34, 0.15, 0.02), Vector3(lx, ly, f + 0.002), _chrome)
				MK.box(self, Vector3(0.31, 0.12, 0.02), Vector3(lx, ly, f + 0.008), head_mat)
			"square":
				MK.box(self, Vector3(0.25, 0.22, 0.02), Vector3(lx, ly, f + 0.002), _chrome)
				MK.box(self, Vector3(0.22, 0.19, 0.02), Vector3(lx, ly, f + 0.008), head_mat)
			"round2":
				MK.cyl(self, 0.095, 0.095, 0.02, Vector3(lx, ly, f + 0.002), _chrome, 14, Vector3(90, 0, 0))
				MK.cyl(self, 0.08, 0.08, 0.02, Vector3(lx, ly, f + 0.01), head_mat, 14, Vector3(90, 0, 0))
			"round4":
				for dx in [-0.09, 0.09]:
					MK.cyl(self, 0.078, 0.078, 0.02, Vector3(lx + dx, ly, f + 0.002), _chrome, 12, Vector3(90, 0, 0))
					MK.cyl(self, 0.066, 0.066, 0.02, Vector3(lx + dx, ly, f + 0.01), head_mat, 12, Vector3(90, 0, 0))
			"popup":
				# Pop-up lamps, raised for the night.
				var py := _top(f - 0.35) + 0.07
				MK.box(self, Vector3(0.3, 0.12, 0.16), Vector3(lx, py, f - 0.35), body_mat)
				MK.box(self, Vector3(0.26, 0.09, 0.02), Vector3(lx, py, f - 0.265), head_mat)
				ly = py
		head_points.append(Vector3(lx, ly, f + 0.04 if S.lamps != "popup" else f - 0.2))
		# Indicators.
		MK.box(self, Vector3(0.1, 0.06, 0.02), Vector3(sgn * (w - 0.08), S.get("bumper_y", 0.42) + 0.12 if S.lamps == "popup" else ly, f - 0.005), amber)
		# Rear lamp clusters.
		if S.get("tail", "wide") == "vertical":
			var ty: float = (S.belt + S.get("sill", 0.27)) * 0.5 + 0.1
			MK.box(self, Vector3(0.14, 0.42, 0.02), Vector3(sgn * (w - 0.09), ty, r - 0.002), tail_mat)
			MK.box(self, Vector3(0.14, 0.1, 0.02), Vector3(sgn * (w - 0.09), ty + 0.27, r + 0.005), amber)
		else:
			var ty2: float = minf(_top(r + 0.05) - 0.12, S.belt - 0.18)
			MK.box(self, Vector3(0.42, 0.14, 0.02), Vector3(sgn * w * 0.64, ty2, r - 0.002), tail_mat)
			MK.box(self, Vector3(0.1, 0.14, 0.02), Vector3(sgn * (w - 0.04), ty2, r + 0.01), amber)


## The boot: something to click from outside, at the back of the car (night three on).
## story.gd decides what happens (needs the boot wedge; the owner reports it).
var boot_interact: Interactable
var boot_owner := ""        ## whose car (for the report), "" = nobody in particular
var boot_open := false


func add_boot() -> Interactable:
	if boot_interact:
		return boot_interact
	boot_interact = Interactable.new()
	boot_interact.prompt = "Open boot"
	boot_interact.add_box(Vector3(S.w * 1.7, 0.5, boot_zone.y - boot_zone.x + 0.15), Vector3(0, _top(boot_zone.x) - 0.05, (boot_zone.x + boot_zone.y) * 0.5 - 0.05))
	add_child(boot_interact)
	return boot_interact


## The boot lid: the top of the car over the boot well, hinged at its front edge.
var boot_zone := Vector2.ZERO   ## z range of the boot opening
var boot_floor := 0.4           ## height of the boot floor
var _lid: Node3D


func _boot_lid() -> void:
	var z0 := boot_zone.x
	var z1 := boot_zone.y
	var hinge_y := _top(z1) + 0.02
	_lid = Node3D.new()
	_lid.name = "BootLid"
	_lid.position = Vector3(0, hinge_y, z1)
	add_child(_lid)
	var rows := []
	for zz in _stations([z0 - 0.01, z1], 0.07):
		var t := _top(zz)
		var w := _half_w(zz)
		var row := []
		for p in [[-0.94, 0.0], [-0.45, 0.018], [0.0, 0.024], [0.45, 0.018], [0.94, 0.0]]:
			row.append(Vector3(w * p[0], t + p[1] + 0.006, zz) - _lid.position)
		rows.append(row)
	var lid_mat := body_mat.duplicate() as StandardMaterial3D
	lid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # seen from underneath once it's open
	var lid := _loft(rows, lid_mat, "Lid")
	lid.reparent(_lid, false)
	# Shut lines round the lid, and a lock.
	var line := MK.mat(Color(0.02, 0.02, 0.02), "", 0.8)
	MK.box(self, Vector3(S.w * 1.86, 0.008, 0.012), Vector3(0, _top(z1) + 0.012, z1), line)
	MK.box(self, Vector3(0.04, 0.03, 0.01), Vector3(0, _top(z0) - 0.04, z0 - 0.08), _chrome)
	# The well: carpet on the floor, dark walls.
	var carpet := MK.mat(Color(0.2, 0.18, 0.16), "", 1.0)
	MK.box(self, Vector3(S.w * 1.7, 0.012, z1 - z0 - 0.02), Vector3(0, boot_floor + 0.008, (z0 + z1) * 0.5), carpet)
	MK.box(self, Vector3(S.w * 1.7, maxf(0.05, _top(z1) - boot_floor), 0.012), Vector3(0, (boot_floor + _top(z1)) * 0.5, z1 - 0.008), carpet)
	for sx in [-1.0, 1.0]:   # side linings
		MK.box(self, Vector3(0.012, maxf(0.05, _top(z0) - boot_floor - 0.02), z1 - z0 - 0.02), Vector3(sx * S.w * 0.84, (boot_floor + _top(z0)) * 0.5, (z0 + z1) * 0.5), carpet)


## Break into the boot: the lid swings up on its hinge.
func open_boot_lid() -> void:
	if boot_open:
		return
	boot_open = true
	# The boot light comes on (so you can see what's in there at night).
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 1.1
	lamp.omni_range = 1.4
	lamp.light_volumetric_fog_energy = 0.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, _top(boot_zone.y) + 0.05, boot_zone.y - 0.12)
	add_child(lamp)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lid, "rotation:x", deg_to_rad(72.0), 0.8)


## Lay up to 5 items out on the boot floor in a grid, each scaled to fit its own space, so nothing
## overlaps. Returns the nodes.
func place_in_boot(models: Array) -> Array:
	var n := mini(models.size(), 5)
	var cols := 3 if n > 2 else n
	var rows := 2 if n > 3 else 1
	var width: float = S.w * 1.6
	var depth: float = boot_zone.y - boot_zone.x - 0.08
	var cw: float = width / cols
	var cd: float = depth / rows
	for i in n:
		var m: Node3D = models[i]
		add_child(m)
		# Whichever way round fits its space best (long things lie across the car).
		var box := _aabb(m)
		var k0: float = minf((cw * 0.9) / maxf(box.size.x, 0.01), (cd * 0.9) / maxf(box.size.z, 0.01))
		var k90: float = minf((cw * 0.9) / maxf(box.size.z, 0.01), (cd * 0.9) / maxf(box.size.x, 0.01))
		m.rotation_degrees.y = 0.0 if k0 >= k90 else 90.0
		var k: float = minf(1.0, maxf(k0, k90))
		m.scale = Vector3.ONE * k
		var col := i % cols
		var row := i / cols
		var x: float = -width * 0.5 + cw * (col + 0.5)
		var z: float = boot_zone.x + 0.04 + cd * (row + 0.5)
		m.position = Vector3(x, boot_floor + 0.015, z)
	return models.slice(0, n)


## The bounding box of everything under a node, in its own (unscaled, unrotated) space.
static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var bb := mi.get_aabb()
		bb = mi.transform * bb
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	return out


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
	var lift: float = seat.y
	var w: float = S.w
	MK.box(self, Vector3(w * 1.75, 0.22, 0.35), Vector3(0, S.belt - 0.08, S.g1 - 0.2), dark)   # dash
	for sx in [-w * 0.43, w * 0.43]:
		MK.box(self, Vector3(0.48, 0.12, 0.5), Vector3(sx, 0.5 + lift, seat.z), fabric)
		MK.box(self, Vector3(0.48, 0.6, 0.1), Vector3(sx, 0.82 + lift, seat.z - 0.26), fabric)
		MK.box(self, Vector3(0.26, 0.16, 0.08), Vector3(sx, 1.2 + lift, seat.z - 0.28), fabric)
	if seat.z - 0.8 > S.g0 + 0.2:
		MK.box(self, Vector3(w * 1.75, 0.5, 0.5), Vector3(0, 0.62 + lift, seat.z - 0.78), fabric)
	MK.box(self, Vector3(w * 1.75, 0.3, 0.9), Vector3(0, 0.45 + lift, seat.z + 0.2), dark)
	var wheel := MK.cyl(self, 0.19, 0.19, 0.025, Vector3(seat.x, S.belt + 0.02 - S.get("seat_drop", 0.0) * 0.6, seat.z + 0.44), dark, 14, Vector3(65, 0, 0))
	wheel.name = "SteeringWheel"
	var span := _roof_span()
	MK.box(self, Vector3(S.roof_w * 1.8, 0.02, maxf(0.2, span.y - span.x - 0.2)), Vector3(0, _roof_peak() - 0.04, (span.x + span.y) * 0.5), dark)
	for i in range(first, get_child_count()):
		to_cabin_layer(get_child(i))
