## VIEW. The landmarks: a few real buildings drawn with more character than a flat-topped extrusion of their outline.
## OpenStreetMap has their outlines and, for some, a height, but not their shape, so each is given a style here: a
## height, colours, a roof (sloped top, hip, dome, gable) and sometimes a tower. CityBuilder asks `style(id)` for each
## building and draws it with that; anything not listed here is built as before.
##
## Style keys: height (metres, instead of the data's), walls and roof (colours), roof ("flat", "skillion", "hip", "dome",
## "gable"), drop (skillion: how much lower the low side is), rise (hip, dome, gable: how high the roof goes above the
## walls), tower ({size, height, spire, at: "west"|"east"|"north"|"south", or dir: a unit vector, the end toward it}), lantern (a small drum on a dome), strip
## (vaults: how wide each arch is). A building can also be cut in two across its long axis (split: {end, depth}) with
## a style for the `front` piece and one for the `rest`: the Hauptbahnhof's reception building and its halls.
## Styles for particular buildings, by their id, are handed in (`use`: the story's, LandmarkStyles); a building the map says is
## civic (OsmImport.civic) and has none is given one made from its footprint by Archetypes.
class_name Landmarks
extends RefCounted

## The hand-made styles, by building id, and the props at fixed places ({at: world x, z, kind ("monument"), label}).
static var styles := {}
static var props: Array = []


## Hands in the styles and props to draw with (the composition root: the story's, LandmarkStyles).
static func use(hand_made: Dictionary, placed: Array = []) -> void:
	styles = hand_made
	props = placed


static func style(id: int) -> Dictionary:
	return styles.get(id, {})


## The pieces a building is drawn as: [{pts, style}]. Usually one (its footprint and its style); a split building is cut
## across its long axis, the front piece at the `end` it names and the rest, each with its own style.
static func pieces(id: int, pts: PackedVector2Array, civic := "") -> Array:
	var st := style(id)
	if st.is_empty() and civic != "":  # (a hand-made style above always wins)
		st = Archetypes.style(civic, pts)
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
## roof is not one this draws (a flat or sloped top is the builder's own). A roof that rises to a ridge or an arch leaves its
## ends open above the walls: with `walls`, they are closed (`ends`, glazed under a tall arch).
static func roof(st: Dictionary, pts: PackedVector2Array, h: float, roofs: CityBuilder.Buf, col: Color, walls: CityBuilder.Buf = null, wall_col := Color.WHITE) -> bool:
	var rise: float = st.get("rise", 6.0)
	var shape := str(st.get("roof", "flat"))
	var ridge: Vector2 = st.get("ridge", Vector2.ZERO)  # (which way a gable's ridge runs: ZERO, along the footprint's length)
	if walls != null:
		var at: Callable
		if shape == "gable":
			at = _gable_height(pts, h, rise, ridge)
		elif shape == "stepped":
			stepped_ends(pts, h, rise, ridge, walls, wall_col)
		elif shape in ["vaults", "round"]:
			at = _vault_height(pts, h, rise, _strip_of(st))
		if at.is_valid():
			ends(pts, h, at, walls, wall_col, shape != "gable" and rise >= GLAZED_RISE)
	match shape:
		"hip":
			_rings(pts, h, rise, 1, roofs, col, false)
			return true
		"dome":
			_rings(pts, h, rise, 7, roofs, col, true)
			if st.get("lantern", false):
				var c := _centroid(pts)
				_prism(roofs, c, 2.2, h + rise - 0.3, 2.6, col.lightened(0.25))
			return true
		"gable", "stepped":
			_gable(pts, h, rise, roofs, col, ridge)
			return true
		"vaults", "round":
			_vaults(pts, h, rise, _strip_of(st), roofs, col)
			return true
	return false


const GLAZED_RISE := 8.0     # an arch rising this much (a train hall's) has its ends glazed, ribbed in the wall's colour
const END_STEP := 2.0        # metres between the points an end wall follows the roof at
const RIB_EVERY := 3         # every so many steps of a glazed end, a rib


## A vault's arches are this wide: a "round" roof is one arch over its whole width.
static func _strip_of(st: Dictionary) -> float:
	return 1.0e6 if st.get("roof", "") == "round" else float(st.get("strip", 38.0))


## The walls above `h` up to a roof of height `at(p)` along every edge of the footprint, seen from outside: a gable's ends, an
## arch's. `glazed`: panes with ribs, and a stone arch along the top.
static func ends(pts: PackedVector2Array, h: float, at: Callable, walls: CityBuilder.Buf, col: Color, glazed := false) -> void:
	var turn := signf(CityBuilder._area2(pts))
	for k in pts.size():
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		var length := p.distance_to(q)
		if length < 0.5:
			continue
		var dir := (q - p) / length
		var out := Vector3(dir.y, 0, -dir.x) * turn
		var steps := maxi(1, ceili(length / END_STEP))
		for s in steps:
			var a := p + dir * length * s / steps
			var b := p + dir * length * (s + 1) / steps
			var ta: float = at.call(a)
			var tb: float = at.call(b)
			if maxf(ta, tb) - h < 0.05:
				continue
			var fill := CityBuilder.GLASS.lightened(0.12) if glazed else col
			walls.quad(Vector3(a.x, h, a.y), Vector3(b.x, h, b.y), Vector3(b.x, maxf(tb, h), b.y), Vector3(a.x, maxf(ta, h), a.y), out, fill)
			if not glazed:
				continue
			var proud := out * 0.12
			walls.quad(Vector3(a.x, ta - 0.9, a.y) + proud, Vector3(b.x, tb - 0.9, b.y) + proud, Vector3(b.x, tb, b.y) + proud, Vector3(a.x, ta, a.y) + proud, out, col)
			if s % RIB_EVERY == 0:
				var w := a + dir * 0.35
				walls.quad(Vector3(a.x, h, a.y) + proud, Vector3(w.x, h, w.y) + proud, Vector3(w.x, maxf(at.call(w), h), w.y) + proud, Vector3(a.x, maxf(ta, h), a.y) + proud, out, col)
		if glazed:  # (a sill under the glass)
			walls.quad(Vector3(p.x, h - 0.4, p.y) + out * 0.15, Vector3(q.x, h - 0.4, q.y) + out * 0.15, Vector3(q.x, h + 0.4, q.y) + out * 0.15, Vector3(p.x, h + 0.4, p.y) + out * 0.15, out, col)


## A tower on the building: a square shaft with a pointed spire, at one end of the footprint.
static func tower(st: Dictionary, pts: PackedVector2Array, walls: CityBuilder.Buf, roofs: CityBuilder.Buf, wall_col: Color, roof_col: Color) -> void:
	var t: Dictionary = st.get("tower", {})
	if t.is_empty():
		return
	var size: float = t.size
	var c := _centroid(pts)
	var best := pts[0]
	for p in pts:
		if t.has("dir"):  # (the end of a footprint toward a direction: the way a generated church puts its tower)
			if p.dot(t.dir) > best.dot(t.dir):
				best = p
			continue
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
	for p in props:
		if p.kind == "monument":
			_monument(root, p.at, str(p.get("label", "")))
		elif p.kind == "fountain_statue":
			_fountain_statue(root, p.at, str(p.get("label", "")))


const PINNACLE_EVERY := 4.0  # metres between the little spires along a gothic roof's gallery


## A late-gothic roof gallery: a low parapet round the eaves with small spires along it.
static func pinnacles(pts: PackedVector2Array, h: float, walls: CityBuilder.Buf, col: Color) -> void:
	var turn := signf(CityBuilder._area2(pts))
	for k in pts.size():
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		var length := p.distance_to(q)
		if length < 1.0:
			continue
		var dir := (q - p) / length
		var out := Vector3(dir.y, 0, -dir.x) * turn
		var lift := out * 0.15
		walls.quad(Vector3(p.x, h, p.y) + lift, Vector3(q.x, h, q.y) + lift, Vector3(q.x, h + 0.9, q.y) + lift, Vector3(p.x, h + 0.9, p.y) + lift, out, col)
		var count := maxi(1, int(length / PINNACLE_EVERY))
		for s in count:
			var at := p + dir * length * (s + 0.5) / count
			_prism(walls, at, 0.28, h, 1.7, col)


const BASIN := 2.9          # a statue fountain's basin: its walls this far from the middle


## The ground a prop takes up, for those that people walk round (a polygon), or empty.
static func footprint(p: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if p.kind == "fountain_statue":
		for k in 8:
			var a := TAU * (k + 0.5) / 8.0
			out.append((p.at as Vector2) + Vector2(cos(a), sin(a)) * (BASIN + 0.25))
	return out


## A fountain with a statue: an eight-sided stone basin with water in it, a pillar with four spouts, and on it a figure of
## Justice: a gown, a sword raised in the right hand and a pair of scales held out in the left.
static func _fountain_statue(root: Node3D, at: Vector2, label: String) -> void:
	var node := Node3D.new()
	node.name = "Fountain"
	node.position = Ground.at(at)
	root.add_child(node)
	var stone := Color(0.78, 0.72, 0.62)
	var bronze := Color(0.32, 0.5, 0.44)
	var gilt := Color(0.9, 0.74, 0.3)
	for k in 8:
		var a := TAU * k / 8.0
		var mid := Vector3(cos(a), 0, sin(a)) * BASIN
		var side := 2.0 * BASIN * tan(PI / 8.0) + 0.12
		Look.box(node, Vector3(0.28, 0.75, side), mid + Vector3(0, 0.38, 0), stone, Vector3(0, -a, 0))
		Look.box(node, Vector3(0.44, 0.1, side + 0.1), mid + Vector3(0, 0.78, 0), stone.lightened(0.12), Vector3(0, -a, 0))
		Look.box(node, Vector3(2.0 * BASIN - 0.3, 0.04, side - 0.2), Vector3(0, 0.6 + 0.001 * k, 0), Color(0.42, 0.62, 0.72), Vector3(0, -a, 0))
	Look.box(node, Vector3(1.3, 0.9, 1.3), Vector3(0, 0.45, 0), stone)
	Look.box(node, Vector3(0.7, 2.0, 0.7), Vector3(0, 1.9, 0), stone.darkened(0.04))
	Look.box(node, Vector3(1.0, 0.2, 1.0), Vector3(0, 3.0, 0), stone.lightened(0.1))
	for k in 4:  # the spouts, with their jets
		var a := TAU * k / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		Look.box(node, Vector3(0.14, 0.14, 0.5), dir * 0.5 + Vector3(0, 1.4, 0), bronze, Vector3(0, -a + PI / 2.0, 0))
		Look.box(node, Vector3(0.05, 0.7, 0.05), dir * 0.86 + Vector3(0, 1.0, 0), Color(0.75, 0.88, 0.95), Vector3(0, -a, 0.0))
	# Justice
	Look.box(node, Vector3(0.62, 0.7, 0.5), Vector3(0, 3.45, 0), bronze)           # the gown
	Look.box(node, Vector3(0.44, 0.65, 0.34), Vector3(0, 4.1, 0), bronze)          # the body
	Look.box(node, Vector3(0.26, 0.28, 0.26), Vector3(0, 4.6, 0), bronze.lightened(0.1))
	Look.box(node, Vector3(0.12, 0.6, 0.12), Vector3(0.34, 4.45, 0), bronze, Vector3(0, 0, -0.35))   # the raised arm
	Look.box(node, Vector3(0.07, 1.2, 0.07), Vector3(0.55, 5.25, 0), gilt)           # the sword
	Look.box(node, Vector3(0.3, 0.07, 0.07), Vector3(0.55, 4.75, 0), gilt)
	Look.box(node, Vector3(0.55, 0.1, 0.1), Vector3(-0.4, 4.2, 0), bronze)           # the other arm, held out
	Look.box(node, Vector3(0.6, 0.04, 0.04), Vector3(-0.68, 4.15, 0), gilt)          # the scales' beam
	for end in [-0.26, 0.26]:
		Look.box(node, Vector3(0.02, 0.34, 0.02), Vector3(-0.68 + end, 3.98, 0), gilt)
		Look.box(node, Vector3(0.24, 0.05, 0.24), Vector3(-0.68 + end, 3.8, 0), gilt)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = BASIN + 0.2
	cyl.height = 0.85
	shape.shape = cyl
	shape.position = Vector3(0, 0.42, 0)
	body.add_child(shape)
	node.add_child(body)
	if label != "":
		var l := Look.label3d(node, label, Vector3(0, 6.6, 0), 28, 40.0)
		l.modulate = Color(1, 0.98, 0.92)


## A monument: a few tall stone slabs of different heights leaning together on a low plinth, a stylised stand-in (the data has
## only a point for it), with its name over it.
static func _monument(root: Node3D, at: Vector2, label: String) -> void:
	var node := Node3D.new()
	node.name = "Monument"
	node.position = Vector3(at.x, 0.0, at.y)
	root.add_child(node)
	var stone := Color(0.72, 0.70, 0.66)
	Look.box(node, Vector3(5.6, 0.5, 3.4), Vector3(0, 0.25, 0), stone.darkened(0.1))
	var heights := [4.6, 3.6, 5.4, 3.0]
	for k in heights.size():
		var x := -2.0 + k * 1.35
		Look.box(node, Vector3(0.7, heights[k], 0.9), Vector3(x, 0.5 + heights[k] * 0.5, 0.0), stone, Vector3(0, 0, deg_to_rad(-6.0 + k * 4.0)))
	if label != "":
		var l := Look.label3d(node, label, Vector3(0, 6.8, 0), 30, 40.0)
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
const STEP_WIDE := 1.1       # metres across each step of a stepped gable
const STEP_PROUD := 0.55     # how far a step stands above the roof it hides


## The stepped gables of a Römer house: at each end of the ridge, a parapet over the roof's slopes, cut in square steps, seen from
## both sides, with a cap on each step.
static func stepped_ends(pts: PackedVector2Array, h: float, rise: float, ridge: Vector2, walls: CityBuilder.Buf, col: Color) -> void:
	var slope := _gable_height(pts, h, rise, ridge)
	var c := _centroid(pts)
	var axis := ridge.normalized() if ridge != Vector2.ZERO else _long_axis(pts)
	var side := Vector2(-axis.y, axis.x)
	var turn := signf(CityBuilder._area2(pts))
	for k in pts.size():
		var p := pts[k]
		var q := pts[(k + 1) % pts.size()]
		var length := p.distance_to(q)
		if length < 1.5:
			continue
		var dir := (q - p) / length
		var out2 := Vector2(dir.y, -dir.x) * turn
		if absf(out2.dot(axis)) < 0.8:  # (only the walls the ridge ends on)
			continue
		var out := Vector3(out2.x, 0, out2.y)
		var steps := maxi(2, roundi(length / STEP_WIDE))
		for s in steps:
			var a := p + dir * length * s / steps
			var b := p + dir * length * (s + 1) / steps
			var top := maxf(float(slope.call(a)), float(slope.call(b))) + STEP_PROUD
			if absf((a.lerp(b, 0.5) - c).dot(side)) < STEP_WIDE * 0.7:
				top += STEP_PROUD * 1.6  # (a pinnacle at the middle)
			var a0 := Vector3(a.x, h, a.y)
			var b0 := Vector3(b.x, h, b.y)
			var a1 := Vector3(a.x, top, a.y)
			var b1 := Vector3(b.x, top, b.y)
			walls.quad(a0, b0, b1, a1, out, col)
			var back := out * -0.35
			walls.quad(a0 + back, b0 + back, b1 + back, a1 + back, -out, col.darkened(0.1))
			walls.quad(a1, b1, b1 + back, a1 + back, Vector3.UP, col.darkened(0.2))
			walls.quad(a0, a1, a1 + back, a0 + back, Vector3(-dir.x, 0, -dir.y), col.darkened(0.15))
			walls.quad(b0, b1, b1 + back, b0 + back, Vector3(dir.x, 0, dir.y), col.darkened(0.15))


static func _gable_height(pts: PackedVector2Array, h: float, rise: float, ridge := Vector2.ZERO) -> Callable:
	var c := _centroid(pts)
	var axis := ridge.normalized() if ridge != Vector2.ZERO else _long_axis(pts)
	var side := Vector2(-axis.y, axis.x)
	var half := 0.01
	for p in pts:
		half = maxf(half, absf((p - c).dot(side)))
	return func(p: Vector2) -> float: return h + rise * (1.0 - absf((p - c).dot(side)) / half)


static func _gable(pts: PackedVector2Array, h: float, rise: float, roofs: CityBuilder.Buf, col: Color, ridge := Vector2.ZERO) -> void:
	var c := _centroid(pts)
	var axis := ridge.normalized() if ridge != Vector2.ZERO else _long_axis(pts)
	var side := Vector2(-axis.y, axis.x)
	var height := _gable_height(pts, h, rise, ridge)
	var far := 5000.0
	for sign in [1.0, -1.0]:
		var rect := PackedVector2Array([c - axis * far, c + axis * far, c + axis * far + side * sign * far, c - axis * far + side * sign * far])
		for piece in Geometry2D.intersect_polygons(pts, rect):
			var tris := Geometry2D.triangulate_polygon(piece)
			for k in range(0, tris.size(), 3):
				var verts := []
				for j in 3:
					var p: Vector2 = piece[tris[k + j]]
					verts.append(Vector3(p.x, height.call(p), p.y))
				var nrm := ((verts[1] - verts[0]) as Vector3).cross(verts[2] - verts[0]).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				roofs.tri(verts[0], verts[1], verts[2], nrm, col)


## A row of arched roofs, side by side along the footprint's long axis, each `strip` metres wide: the roof's height is
## an arch across each strip. The footprint's triangles are cut small enough for the arches to curve.
static func _vaults(pts: PackedVector2Array, h: float, rise: float, strip: float, roofs: CityBuilder.Buf, col: Color) -> void:
	var height := _vault_height(pts, h, rise, strip)
	var tris := Geometry2D.triangulate_polygon(pts)
	for k in range(0, tris.size(), 3):
		_cut(pts[tris[k]], pts[tris[k + 1]], pts[tris[k + 2]], 4.0, height, roofs, col, 0)


static func _vault_height(pts: PackedVector2Array, h: float, rise: float, strip: float) -> Callable:
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
	var width := maxf(0.01, (hi - lo) / count)
	return func(p: Vector2) -> float:
		var l := clampf((p - c).dot(side) - lo, 0.0, hi - lo - 0.001)
		var u := fposmod(l, width) / width * 2.0 - 1.0
		return h + rise * sqrt(maxf(0.0, 1.0 - u * u))


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
