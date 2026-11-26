## VIEW. A district's railways (OsmRail) as meshes: a track's bed (ballast under sleepers under two steel lines) laid on the land
## the way the streets are (Drape), and a tram's two lines flush in its street. Only looked at: nobody collides with a track, a
## board rolls over it. In two halves, as the city is: `bake` (plain arrays: a worker thread may run it) and `assemble` (the node).
class_name RailBuilder
extends RefCounted

const BALLAST := Color(0.56, 0.54, 0.50)
const SLEEPER := Color(0.40, 0.32, 0.26)
const STEEL := Color(0.62, 0.64, 0.68)
const STREET_STEEL := Color(0.50, 0.51, 0.54)
const BED_AT := 0.04          # metres over the ground each layer lies (so none fights another)
const SLEEPER_AT := 0.07
const STEEL_AT := OsmRail.HEAD  # (a rail's top: where a board grinds, Kerbs.grindable)
const SLEEPER_EVERY := 0.65
const SLEEPER_WIDTH := 0.26
const SLEEPER_OVER := 0.55    # metres a sleeper's end sticks out past each steel line
const STEEL_WIDTH := 0.08
const ROUTE_HALF := 0.45      # half the width of a route's band
const ROUTE_AT := 0.037       # over the street and its painted lines, under a tram rail's head
const MITRE := 1.6            # most a bend widens a strip's corner: the sharpest turns don't spike


## {rails: Buf}: the beds, sleepers and steel of every track, as one set of triangles; and between the rails of each of
## `routes` (OsmRoute) that has a `colour`, a band of it all along its way.
static func bake(rail: Dictionary, landform: Landform = null, datum := 0.0, routes: Array = []) -> Dictionary:
	var drape := Drape.on(landform, datum)
	var buf := CityBuilder.Buf.new()
	for r in routes:
		if not r.has("colour"):
			continue
		var way := PackedVector2Array()
		for k in range(0, r.pts.size() - 1, 2):
			way.append(Vector2(r.pts[k], r.pts[k + 1]))
		if way.size() >= 2:
			_strip(drape, buf, way, _sides(way), -ROUTE_HALF, ROUTE_HALF, ROUTE_AT, r.colour)
	for t in rail.get("tracks", []):
		var kind: Dictionary = OsmRail.KINDS.get(str(t.kind), {})
		if kind.is_empty():
			continue
		var pts: PackedVector2Array = t.pts
		if pts.size() < 2:
			continue
		var sides := _sides(pts)
		var gauge: float = kind.gauge
		var half := gauge * 0.5
		if not bool(kind.street):
			_strip(drape, buf, pts, sides, -float(kind.bed) * 0.5, float(kind.bed) * 0.5, BED_AT, BALLAST)
			_sleepers(drape, buf, pts, half + SLEEPER_OVER)
		for s in [-1.0, 1.0]:
			var mid: float = s * half
			var street := bool(kind.street)
			_strip(drape, buf, pts, sides, mid - STEEL_WIDTH * 0.5, mid + STEEL_WIDTH * 0.5, float(kind.head), STREET_STEEL if street else STEEL)
			if not street:  # (the web under the head, so a rail stands up off its sleepers and a board has something to ride on)
				_web(drape, buf, pts, sides, mid - STEEL_WIDTH * 0.5, -1.0, float(kind.head))
				_web(drape, buf, pts, sides, mid + STEEL_WIDTH * 0.5, 1.0, float(kind.head))
	return {"rails": buf}


## The node: one mesh, drawn as the city's surfaces are, casting no shadow.
static func assemble(baked: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Rails"
	var mi := MeshInstance3D.new()
	mi.name = "Track"
	mi.mesh = (baked.rails as CityBuilder.Buf).to_mesh()
	mi.material_override = Watercolor.surface()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


## At each point of a line, the unit vector to its left that a strip's edge is offset along, widened at a bend (so adjacent
## quads meet there and leave no gap), by at most MITRE.
static func _sides(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in pts.size():
		var before := (pts[k] - pts[maxi(k - 1, 0)]).normalized()
		var after := (pts[mini(k + 1, pts.size() - 1)] - pts[k]).normalized()
		var dir := (before + after).normalized() if before + after != Vector2.ZERO else after
		var side := Vector2(-dir.y, dir.x)
		var leg := after if after != Vector2.ZERO else before  # (the last point has no way on: its own stretch's)
		var seg_side := Vector2(-leg.y, leg.x)
		out.append(side / maxf(side.dot(seg_side), 1.0 / MITRE))
	return out


## A strip along `pts` from `lo` to `hi` metres to the left of the line (negative: to its right), `above` the field.
static func _strip(drape: Drape, buf: CityBuilder.Buf, pts: PackedVector2Array, sides: PackedVector2Array, lo: float, hi: float, above: float, col: Color) -> void:
	for k in pts.size() - 1:
		drape.quad(buf, pts[k] + sides[k] * lo, pts[k + 1] + sides[k + 1] * lo, pts[k + 1] + sides[k + 1] * hi, pts[k] + sides[k] * hi, above, col)


## An upright face along `pts`, `off` metres to the left of the line, from the sleepers up to `top`, facing `toward` (+1: left, -1: right).
static func _web(drape: Drape, buf: CityBuilder.Buf, pts: PackedVector2Array, sides: PackedVector2Array, off: float, toward: float, top: float) -> void:
	for k in pts.size() - 1:
		var dir := (pts[k + 1] - pts[k]).normalized()
		var out := Vector3(-dir.y, 0.0, dir.x) * toward
		drape.wall(buf, pts[k] + sides[k] * off, pts[k + 1] + sides[k + 1] * off, SLEEPER_AT, top, out, STEEL.darkened(0.2))


## Sleepers across the line every SLEEPER_EVERY metres, `half` either side of it.
static func _sleepers(drape: Drape, buf: CityBuilder.Buf, pts: PackedVector2Array, half: float) -> void:
	var carry := SLEEPER_EVERY * 0.5
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var dir := (b - a) / length
		var side := Vector2(-dir.y, dir.x)
		var at := carry
		while at < length:
			var c := a + dir * at
			var w := dir * SLEEPER_WIDTH * 0.5
			drape.quad(buf, c - w - side * half, c + w - side * half, c + w + side * half, c - w + side * half, SLEEPER_AT, SLEEPER)
			at += SLEEPER_EVERY
		carry = at - length
