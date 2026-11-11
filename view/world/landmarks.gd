## VIEW. The landmarks: a few real buildings drawn with more character than a flat-topped extrusion of their outline.
## OpenStreetMap has their outlines and, for some, a height, but not their shape, so each is given a style here: a
## height, colours, a roof (sloped top, hip, dome, gable) and sometimes a tower. CityBuilder asks `style(id)` for each
## building and draws it with that; anything not listed here is built as before.
##
## Style keys: height (metres, instead of the data's), walls and roof (colours), roof ("flat", "skillion", "hip", "dome",
## "gable"), drop (skillion: how much lower the low side is), rise (hip, dome, gable: how high the roof goes above the
## walls), tower ({size, height, spire, at: "west"|"east"|"north"|"south"}), lantern (a small drum on a dome), strip
## (vaults: how wide each arch is). A building can also be cut in two across its long axis (split: {end, depth}) with
## a style for the `front` piece and one for the `rest`: the Hauptbahnhof's reception building and its halls.
class_name Landmarks
extends RefCounted

const STYLES := {
	# The European Central Bank's towers: one outline in the data, 185 m, a sloping top. Glass-blue.
	156432555: {"height": 185.0, "walls": Color(0.50, 0.66, 0.72), "roof": "skillion", "drop": 24.0, "roof_col": Color(0.40, 0.50, 0.56)},
	# ...and its Grossmarkthalle, the old market hall: a long low hall under a shallow gable.
	300429302: {"height": 23.0, "walls": Color(0.88, 0.80, 0.62), "roof": "gable", "rise": 5.0, "roof_col": Color(0.46, 0.50, 0.50)},
	# The Paulskirche: an oval rotunda of red sandstone under a shallow dome.
	11526375: {"height": 21.0, "walls": Color(0.74, 0.46, 0.37), "roof": "dome", "rise": 7.0, "roof_col": Color(0.42, 0.55, 0.48), "lantern": true},
	# The Hauptbahnhof: one outline for the whole station. Its eastern end, toward the city, is the reception building; the
	# rest are the train halls under rows of arched glass roofs.
	154495112: {"split": {"end": "east", "depth": 55.0},
		"front": {"height": 26.0, "walls": Color(0.82, 0.74, 0.60), "roof": "gable", "rise": 8.0, "roof_col": Color(0.40, 0.55, 0.48)},
		"rest": {"height": 13.0, "walls": Color(0.76, 0.72, 0.66), "roof": "vaults", "rise": 10.0, "strip": 38.0, "roof_col": Color(0.58, 0.72, 0.76)}},
	# The Kaiserdom: a long red sandstone church with its tall tower at the west end.
	11018815: {"height": 25.0, "walls": Color(0.70, 0.42, 0.34), "roof": "hip", "rise": 9.0, "roof_col": Color(0.40, 0.52, 0.46),
		"tower": {"size": 17.0, "height": 66.0, "spire": 28.0, "at": "west"}},
}

## Stone props at fixed places: {at: world x, z, kind}.
const PROPS := [
	{"at": Vector2(885.2, -257.0), "kind": "einheitsdenkmal"},
]


static func style(id: int) -> Dictionary:
	return STYLES.get(id, {})


## The pieces a building is drawn as: [{pts, style}]. Usually one (its footprint and its style); a split building is cut
## across its long axis, the front piece at the `end` it names and the rest, each with its own style.
static func pieces(id: int, pts: PackedVector2Array) -> Array:
	var st := style(id)
	if not st.has("split"):
		return [{"pts": pts, "style": st}]
	var axis := _long_axis(pts)
	var c := _centroid(pts)
	var split: Dictionary = st.split
	var toward: Vector2 = Vector2.RIGHT if split.get("end", "east") == "east" else Vector2.LEFT
	if axis.dot(toward) < 0.0:
		axis = -axis
	var side := Vector2(-axis.y, axis.x)
	var far := 0.0
	for p in pts:
		far = maxf(far, (p - c).dot(axis))
	var cut := far - float(split.depth)
	var big := 6000.0
	var front := PackedVector2Array([c + axis * cut - side * big, c + axis * big - side * big, c + axis * big + side * big, c + axis * cut + side * big])
	var clockwise := Geometry2D.is_polygon_clockwise(pts)
	var out: Array = []
	for part in [["front", Geometry2D.intersect_polygons(pts, front)], ["rest", Geometry2D.clip_polygons(pts, front)]]:
		for piece in part[1]:
			if piece.size() < 3 or Geometry2D.is_polygon_clockwise(piece):
				continue  # (the pieces come back counter-clockwise; a clockwise one is a hole in one)
			out.append({"pts": piece if not clockwise else _reversed(piece), "style": st.get(part[0], {})})  # drawn the way the footprint is wound
	return out


static func _reversed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(pts.size() - 1, -1, -1):
		out.append(pts[k])
	return out


## The long axis of a footprint, for a sloping top: {c: its middle, axis: unit vector along it, half: half its length}.
static func skew(pts: PackedVector2Array) -> Dictionary:
	var c := _centroid(pts)
	var axis := _long_axis(pts)
	var half := 0.0
	for p in pts:
		half = maxf(half, absf((p - c).dot(axis)))
	return {"c": c, "axis": axis, "half": maxf(half, 1.0)}


static func _long_axis(pts: PackedVector2Array) -> Vector2:
	var axis := Vector2.ZERO
	for k in pts.size():
		var e := pts[(k + 1) % pts.size()] - pts[k]
		if e.length() < 0.01:
			continue
		var d := e.normalized()
		if d.dot(axis) < 0.0:
			d = -d
		axis += d * e.length() * e.length()
	return axis.normalized() if axis.length() > 0.001 else Vector2.RIGHT


## The roof of a walled building: `pts` is the footprint and `h` the height of the walls. Returns false if the style's
## roof is not one this draws (a flat or sloped top is the builder's own).
static func roof(st: Dictionary, pts: PackedVector2Array, h: float, roofs: CityBuilder.Buf, col: Color) -> bool:
	var rise: float = st.get("rise", 6.0)
	match st.get("roof", "flat"):
		"hip":
			_rings(pts, h, rise, 1, roofs, col, false)
			return true
		"dome":
			_rings(pts, h, rise, 7, roofs, col, true)
			if st.get("lantern", false):
				var c := _centroid(pts)
				_prism(roofs, c, 2.2, h + rise - 0.3, 2.6, col.lightened(0.25))
			return true
		"gable":
			_gable(pts, h, rise, roofs, col)
			return true
		"vaults":
			_vaults(pts, h, rise, st.get("strip", 38.0), roofs, col)
			return true
	return false


## A tower on the building: a square shaft with a pointed spire, at one end of the footprint.
static func tower(st: Dictionary, pts: PackedVector2Array, walls: CityBuilder.Buf, roofs: CityBuilder.Buf, wall_col: Color, roof_col: Color) -> void:
	var t: Dictionary = st.get("tower", {})
	if t.is_empty():
		return
	var size: float = t.size
	var c := _centroid(pts)
	var best := pts[0]
	for p in pts:
		match t.get("at", "west"):
			"west":
				if p.x < best.x:
					best = p
			"east":
				if p.x > best.x:
					best = p
			"north":
				if p.y < best.y:
					best = p
			_:
				if p.y > best.y:
					best = p
	var centre: Vector2 = best + (c - best).normalized() * size * 0.5
	var half := size * 0.5
	var base := 0.0
	var top: float = t.height
	var corners := [centre + Vector2(-half, -half), centre + Vector2(half, -half), centre + Vector2(half, half), centre + Vector2(-half, half)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var out := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		walls.quad(Vector3(a.x, base, a.y), Vector3(b.x, base, b.y), Vector3(b.x, top, b.y), Vector3(a.x, top, a.y), out, wall_col)
		# a darker belfry band near the top, and a ledge
		var band := top - 9.0
		walls.quad(Vector3(a.x, band, a.y) + out * 0.1, Vector3(b.x, band, b.y) + out * 0.1, Vector3(b.x, top - 3.0, b.y) + out * 0.1, Vector3(a.x, top - 3.0, a.y) + out * 0.1, out, wall_col.darkened(0.25))
	var apex := Vector3(centre.x, top + float(t.spire), centre.y)
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var mid := Vector3((a.x + b.x) * 0.5 - centre.x, 0, (a.y + b.y) * 0.5 - centre.y).normalized()
		roofs.tri(Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), apex, (mid + Vector3.UP).normalized(), roof_col)


## Props built apart from the buildings, under `root`.
static func add_props(root: Node3D) -> void:
	for p in PROPS:
		if p.kind == "einheitsdenkmal":
			_einheitsdenkmal(root, p.at)


## The Einheitsdenkmal: a few tall stone slabs of different heights leaning together on a low plinth, a stylised
## monument (the data has only a point for it).
static func _einheitsdenkmal(root: Node3D, at: Vector2) -> void:
	var node := Node3D.new()
	node.name = "Einheitsdenkmal"
	node.position = Vector3(at.x, 0.0, at.y)
	root.add_child(node)
	var stone := Color(0.72, 0.70, 0.66)
	Look.box(node, Vector3(5.6, 0.5, 3.4), Vector3(0, 0.25, 0), stone.darkened(0.1))
	var heights := [4.6, 3.6, 5.4, 3.0]
	for k in heights.size():
		var x := -2.0 + k * 1.35
		Look.box(node, Vector3(0.7, heights[k], 0.9), Vector3(x, 0.5 + heights[k] * 0.5, 0.0), stone, Vector3(0, 0, deg_to_rad(-6.0 + k * 4.0)))
	var l := Look.label3d(node, "Einheitsdenkmal", Vector3(0, 6.8, 0), 30, 40.0)
	l.modulate = Color(1, 0.98, 0.92)


# --------------------------------------------------------------------------------------------- roof shapes

static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()


## A roof made of rings of the footprint shrunk toward its middle: `steps` rings, rising along a dome profile (or a
## straight pyramid when `round` is false), closed by a cap at the top.
static func _rings(pts: PackedVector2Array, h: float, rise: float, steps: int, roofs: CityBuilder.Buf, col: Color, round_profile: bool) -> void:
	var c := _centroid(pts)
	var n := pts.size()
	var prev: Array = []
	for p in pts:
		prev.append(Vector3(p.x, h, p.y))
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		var scale := cos(t * PI * 0.5) if round_profile else 1.0 - t
		var lift := sin(t * PI * 0.5) if round_profile else t
		if s == steps:
			scale = 0.0
		var ring: Array = []
		for p in pts:
			var q := c + (p - c) * scale
			ring.append(Vector3(q.x, h + rise * lift, q.y))
		for k in n:
			var a: Vector3 = prev[k]
			var b: Vector3 = prev[(k + 1) % n]
			var d: Vector3 = ring[(k + 1) % n]
			var e: Vector3 = ring[k]
			var nrm := (b - a).cross(e - a).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			roofs.quad(a, b, d, e, nrm, col.lightened(0.04 * t))
		prev = ring


## A prism (a little drum) on the roof.
static func _prism(roofs: CityBuilder.Buf, c: Vector2, radius: float, y: float, height: float, col: Color) -> void:
	var sides := 8
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(c.x + cos(a0) * radius, y, c.y + sin(a0) * radius)
		var p1 := Vector3(c.x + cos(a1) * radius, y, c.y + sin(a1) * radius)
		var out := Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		roofs.quad(p0, p1, p1 + Vector3(0, height, 0), p0 + Vector3(0, height, 0), out, col)
		roofs.tri(p0 + Vector3(0, height, 0), p1 + Vector3(0, height, 0), Vector3(c.x, y + height + 0.8, c.y), Vector3.UP, col.darkened(0.15))


## A gable roof: the ridge runs along the footprint's long axis, and the roof falls away on each side. The footprint is
## cut along the ridge so each half slopes evenly.
static func _gable(pts: PackedVector2Array, h: float, rise: float, roofs: CityBuilder.Buf, col: Color) -> void:
	var c := _centroid(pts)
	var axis := _long_axis(pts)
	var side := Vector2(-axis.y, axis.x)
	var half := 0.0
	for p in pts:
		half = maxf(half, absf((p - c).dot(side)))
	var far := 5000.0
	for sign in [1.0, -1.0]:
		var rect := PackedVector2Array([c - axis * far, c + axis * far, c + axis * far + side * sign * far, c - axis * far + side * sign * far])
		for piece in Geometry2D.intersect_polygons(pts, rect):
			var tris := Geometry2D.triangulate_polygon(piece)
			for k in range(0, tris.size(), 3):
				var verts := []
				for j in 3:
					var p: Vector2 = piece[tris[k + j]]
					var lat := absf((p - c).dot(side))
					verts.append(Vector3(p.x, h + rise * (1.0 - lat / half), p.y))
				var nrm := ((verts[1] - verts[0]) as Vector3).cross(verts[2] - verts[0]).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				roofs.tri(verts[0], verts[1], verts[2], nrm, col)


## A row of arched roofs, side by side along the footprint's long axis, each `strip` metres wide: the roof's height is
## an arch across each strip. The footprint's triangles are cut small enough for the arches to curve.
static func _vaults(pts: PackedVector2Array, h: float, rise: float, strip: float, roofs: CityBuilder.Buf, col: Color) -> void:
	var c := _centroid(pts)
	var axis := _long_axis(pts)
	var side := Vector2(-axis.y, axis.x)
	var lo := INF
	var hi := -INF
	for p in pts:
		var l := (p - c).dot(side)
		lo = minf(lo, l)
		hi = maxf(hi, l)
	var count := maxi(1, roundi((hi - lo) / strip))
	var width := (hi - lo) / count
	var height := func(p: Vector2) -> float:
		var u := fposmod((p - c).dot(side) - lo, width) / width * 2.0 - 1.0
		return h + rise * sqrt(maxf(0.0, 1.0 - u * u))
	var tris := Geometry2D.triangulate_polygon(pts)
	for k in range(0, tris.size(), 3):
		_cut(pts[tris[k]], pts[tris[k + 1]], pts[tris[k + 2]], 4.0, height, roofs, col, 0)


## A triangle, cut into smaller ones until no edge is longer than `edge`, each lifted by `height`.
static func _cut(a: Vector2, b: Vector2, c: Vector2, edge: float, height: Callable, roofs: CityBuilder.Buf, col: Color, depth: int) -> void:
	var ab := a.distance_to(b)
	var bc := b.distance_to(c)
	var ca := c.distance_to(a)
	var longest := maxf(ab, maxf(bc, ca))
	if longest > edge and depth < 9:
		if ab >= bc and ab >= ca:
			var m := (a + b) * 0.5
			_cut(a, m, c, edge, height, roofs, col, depth + 1)
			_cut(m, b, c, edge, height, roofs, col, depth + 1)
		elif bc >= ca:
			var m2 := (b + c) * 0.5
			_cut(a, b, m2, edge, height, roofs, col, depth + 1)
			_cut(a, m2, c, edge, height, roofs, col, depth + 1)
		else:
			var m3 := (c + a) * 0.5
			_cut(a, b, m3, edge, height, roofs, col, depth + 1)
			_cut(m3, b, c, edge, height, roofs, col, depth + 1)
		return
	var va := Vector3(a.x, height.call(a), a.y)
	var vb := Vector3(b.x, height.call(b), b.y)
	var vc := Vector3(c.x, height.call(c), c.y)
	var nrm := (vb - va).cross(vc - va).normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	roofs.tri(va, vb, vc, nrm, col)
