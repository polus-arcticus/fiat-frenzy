## VIEW. Lays the map's flat shapes (a street's strip, a pavement, a kerb stone, the water) onto the shape of the land
## (Landform) exactly. A field of a Landform is flat on each of its grid's triangles (the two of a cell, a-b-d and a-d-c), so a
## shape cut along the grid's lines and diagonals lies in pieces each on one plane: lifted corner by corner, each piece is the
## field itself, with nothing to poke through it and no step where two shapes meet. Upright faces (a kerb's side, a quay) are
## split where they cross the grid the same way, their foot on the field all along. A bridge's shapes follow its own deck
## (Landform.on_road), cut every DECK_STEP metres.
## Heights are drawn in the view's metres: above `datum` (the ground where the game is, Ground.datum), not the sea, so the views
## that still stand things at a fixed height stay near the ground. On flat land everything is laid at its own height, uncut,
## as the city always was.
class_name Drape
extends RefCounted

const DECK_STEP := 4.0  # metres: a bridge's shapes are cut this fine to follow its deck
const SLIVER := 0.0005  # square metres: a piece smaller than this is left out

var land: Landform
var datum := 0.0
var flat := true


static func on(landform: Landform, view_datum := 0.0) -> Drape:
	var d := Drape.new()
	d.land = landform if landform != null else Landform.new()
	d.flat = d.land.flat
	d.datum = view_datum
	return d


## How high `field` ("surface", "land" or "ground") is at `p`, in the view's metres; road `road`'s own surface where it is a
## bridge.
func height(p: Vector2, field := "surface", road := -1) -> float:
	if flat:
		return 0.0
	if road >= 0 and land.is_bridge(road):
		return land.on_road(road, p) - datum
	match field:
		"land":
			return land.land_at(p) - datum
		"ground":
			return land.ground_at(p) - datum
	return land.surface_at(p) - datum


## A triangle `above` metres over the field.
func tri(buf: CityBuilder.Buf, a: Vector2, b: Vector2, c: Vector2, above: float, col: Color, field := "surface", road := -1) -> void:
	if flat:
		buf.tri(Vector3(a.x, above, a.y), Vector3(b.x, above, b.y), Vector3(c.x, above, c.y), Vector3.UP, col)
		return
	if road >= 0 and land.is_bridge(road):
		_deck(buf, a, b, c, above, col, road, 0)
		return
	for piece in _cut(PackedVector2Array([a, b, c])):
		_emit(buf, piece, above, col, field, road)


## A quad (corners in order round it) `above` metres over the field.
func quad(buf: CityBuilder.Buf, a: Vector2, b: Vector2, c: Vector2, d: Vector2, above: float, col: Color, field := "surface", road := -1) -> void:
	tri(buf, a, b, c, above, col, field, road)
	tri(buf, a, c, d, above, col, field, road)


## Any polygon (convex or not) `above` metres over the field.
func poly(buf: CityBuilder.Buf, pts: PackedVector2Array, above: float, col: Color, field := "surface", road := -1) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	for k in range(0, tris.size(), 3):
		tri(buf, pts[tris[k]], pts[tris[k + 1]], pts[tris[k + 2]], above, col, field, road)


## An upright face along `a`-`b`, from `below` to `above` metres over the field, facing `out`.
func wall(buf: CityBuilder.Buf, a: Vector2, b: Vector2, below: float, above: float, out: Vector3, col: Color, field := "surface", road := -1) -> void:
	var cuts := _crossings(a, b, road)
	for k in cuts.size() - 1:
		var p := a.lerp(b, cuts[k])
		var q := a.lerp(b, cuts[k + 1])
		var hp := height(p, field, road)
		var hq := height(q, field, road)
		buf.quad(Vector3(p.x, hp + below, p.y), Vector3(q.x, hq + below, q.y), Vector3(q.x, hq + above, q.y), Vector3(p.x, hp + above, p.y), out, col)


## The ground over `extent` as a mesh on the grid's own lines (and the extent's edge beyond it, where the ground stays as at
## the grid's edge), smooth-shaded: two triangles a cell, a-b-d and a-d-c, as Landform reads them.
func ground(buf: CityBuilder.Buf, extent: Rect2, col: Color) -> void:
	var xs := _lines(extent.position.x, extent.end.x, land.rect.position.x, land.cols)
	var zs := _lines(extent.position.y, extent.end.y, land.rect.position.y, land.rows)
	var base := buf.v.size()
	for z in zs:
		for x in xs:
			var p := Vector2(x, z)
			var dx := land.ground_at(p + Vector2(2, 0)) - land.ground_at(p - Vector2(2, 0))
			var dz := land.ground_at(p + Vector2(0, 2)) - land.ground_at(p - Vector2(0, 2))
			buf.v.append(Vector3(x, land.ground_at(p) - datum, z))
			buf.n.append(Vector3(-dx, 4.0, -dz).normalized())
			buf.c.append(col)
	var w := xs.size()
	for j in zs.size() - 1:
		for k in w - 1:
			var a := base + j * w + k
			buf.i.append_array([a, a + 1, a + w + 1, a, a + w + 1, a + w])


## What is walked on, as collision faces: the surface over `extent` on the grid's triangles (the streets' surface, the land
## between them: never the ground's cuts, which are only for what is seen), but for the triangles whose middle is in one of
## `holes` (the buildings with a floor of their own inside).
func walk_faces(extent: Rect2, holes: Array) -> PackedVector3Array:
	var xs := _lines(extent.position.x, extent.end.x, land.rect.position.x, land.cols)
	var zs := _lines(extent.position.y, extent.end.y, land.rect.position.y, land.rows)
	var out := PackedVector3Array()
	var at := func(x: float, z: float) -> Vector3: return Vector3(x, land.surface_at(Vector2(x, z)) - datum, z)
	for j in zs.size() - 1:
		for k in xs.size() - 1:
			var a: Vector3 = at.call(xs[k], zs[j])
			var b: Vector3 = at.call(xs[k + 1], zs[j])
			var c: Vector3 = at.call(xs[k], zs[j + 1])
			var d: Vector3 = at.call(xs[k + 1], zs[j + 1])
			for t in [[a, b, d], [a, d, c]]:
				var mid := (Vector2(t[0].x, t[0].z) + Vector2(t[1].x, t[1].z) + Vector2(t[2].x, t[2].z)) / 3.0
				if holes.any(func(h): return Geometry2D.is_point_in_polygon(mid, h)):
					continue
				out.append_array(PackedVector3Array(t))
	return out


func _lines(lo: float, hi: float, origin: float, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array([lo])
	for k in count:
		var at := origin + k * Landform.CELL
		if at > lo + 0.01 and at < hi - 0.01:
			out.append(at)
	out.append(hi)
	return out


# ---------------------------------------------------------------- cutting along the grid

# A convex polygon (world metres) cut along the grid's lines and each cell's diagonal: pieces each on one of the field's planes.
func _cut(poly: PackedVector2Array) -> Array:
	var g := PackedVector2Array()
	for p in poly:
		g.append((p - land.rect.position) / Landform.CELL)
	var lo := g[0]
	var hi := g[0]
	for q in g:
		lo = lo.min(q)
		hi = hi.max(q)
	var pieces: Array = [g]
	for k in range(maxi(ceili(lo.x), 0), mini(floori(hi.x), land.cols - 1) + 1):  # (the columns' lines)
		if k > lo.x and k < hi.x:
			pieces = _split_all(pieces, Vector2(1, 0), k)
	for k in range(maxi(ceili(lo.y), 0), mini(floori(hi.y), land.rows - 1) + 1):  # (the rows')
		if k > lo.y and k < hi.y:
			pieces = _split_all(pieces, Vector2(0, 1), k)
	var out: Array = []
	for piece in pieces:
		var c := Vector2.ZERO
		for q in piece:
			c += q
		c /= piece.size()
		var i := floori(c.x)
		var j := floori(c.y)
		if i >= 0 and j >= 0 and i <= land.cols - 2 and j <= land.rows - 2:  # (a cell of the grid: its diagonal too)
			for half in _split(piece, Vector2(1, -1), i - j):
				if half.size() >= 3:
					out.append(half)
		else:
			out.append(piece)
	var world: Array = []
	for piece in out:
		var w := PackedVector2Array()
		for q in piece:
			w.append(land.rect.position + q * Landform.CELL)
		world.append(w)
	return world


func _split_all(pieces: Array, n: Vector2, d: float) -> Array:
	var out: Array = []
	for piece in pieces:
		for half in _split(piece, n, d):
			if half.size() >= 3:
				out.append(half)
	return out


# A convex polygon split by the line n.p = d: [the part below it, the part above] (either may be empty).
static func _split(poly: PackedVector2Array, n: Vector2, d: float) -> Array:
	var below := PackedVector2Array()
	var above := PackedVector2Array()
	var count := poly.size()
	for k in count:
		var p := poly[k]
		var q := poly[(k + 1) % count]
		var fp := n.dot(p) - d
		var fq := n.dot(q) - d
		if fp <= 0.0:
			below.append(p)
		if fp >= 0.0:
			above.append(p)
		if (fp < 0.0 and fq > 0.0) or (fp > 0.0 and fq < 0.0):
			var x := p.lerp(q, fp / (fp - fq))
			below.append(x)
			above.append(x)
	return [below, above]


# A piece (on one plane of the field) as a fan of triangles, lifted onto the field, lit as the slope it lies on.
func _emit(buf: CityBuilder.Buf, piece: PackedVector2Array, above: float, col: Color, field: String, road: int) -> void:
	var lifted := PackedVector3Array()
	for p in piece:
		lifted.append(Vector3(p.x, height(p, field, road) + above, p.y))
	for k in range(1, lifted.size() - 1):
		var a := lifted[0]
		var b := lifted[k]
		var c := lifted[k + 1]
		var cross := (b - a).cross(c - a)
		if cross.length() < SLIVER * 2.0:
			continue
		var nrm := cross.normalized()
		buf.tri(a, b, c, nrm if nrm.y > 0.0 else -nrm, col)


# A triangle on a bridge's deck: split until no edge is longer than DECK_STEP, each corner on the deck.
func _deck(buf: CityBuilder.Buf, a: Vector2, b: Vector2, c: Vector2, above: float, col: Color, road: int, depth: int) -> void:
	var ab := a.distance_squared_to(b)
	var bc := b.distance_squared_to(c)
	var ca := c.distance_squared_to(a)
	if maxf(ab, maxf(bc, ca)) > DECK_STEP * DECK_STEP and depth < 12:
		if ab >= bc and ab >= ca:
			_deck(buf, a, (a + b) * 0.5, c, above, col, road, depth + 1)
			_deck(buf, (a + b) * 0.5, b, c, above, col, road, depth + 1)
		elif bc >= ca:
			_deck(buf, a, b, (b + c) * 0.5, above, col, road, depth + 1)
			_deck(buf, a, (b + c) * 0.5, c, above, col, road, depth + 1)
		else:
			_deck(buf, a, b, (c + a) * 0.5, above, col, road, depth + 1)
			_deck(buf, (c + a) * 0.5, b, c, above, col, road, depth + 1)
		return
	_emit(buf, PackedVector2Array([a, b, c]), above, col, "surface", road)


# Where a-b crosses the grid's lines and diagonals (or, on a bridge, every DECK_STEP), as fractions of the way, 0 and 1 included.
func _crossings(a: Vector2, b: Vector2, road: int) -> PackedFloat32Array:
	var cuts := PackedFloat32Array([0.0, 1.0])
	if flat:
		return cuts
	if road >= 0 and land.is_bridge(road):
		var n := maxi(1, ceili(a.distance_to(b) / DECK_STEP))
		for k in range(1, n):
			cuts.append(float(k) / n)
		cuts.sort()
		return cuts
	var ga := (a - land.rect.position) / Landform.CELL
	var gb := (b - land.rect.position) / Landform.CELL
	for axis in 2:
		var lo := minf(ga[axis], gb[axis])
		var hi := maxf(ga[axis], gb[axis])
		var count := land.cols if axis == 0 else land.rows
		if hi - lo < 0.000001:
			continue
		for k in range(maxi(ceili(lo), 0), mini(floori(hi), count - 1) + 1):
			if k > lo and k < hi:
				cuts.append((k - ga[axis]) / (gb[axis] - ga[axis]))
	var da := ga.x - ga.y  # (the diagonals: u - v whole)
	var db := gb.x - gb.y
	if absf(db - da) > 0.000001:
		for k in range(ceili(minf(da, db)), floori(maxf(da, db)) + 1):
			var t := (k - da) / (db - da)
			if t > 0.0 and t < 1.0:
				cuts.append(t)
	cuts.sort()
	return cuts
