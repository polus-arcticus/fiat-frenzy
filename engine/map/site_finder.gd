## Where on a tile its atom goes: the same street every time, for everyone who lands there (so two players' tiles agree, and their
## saves can be merged). The rule: a straight stretch of a quiet street, long enough for the atom's layout, with a pavement wide
## enough for stalls at the kerb and tents against the wall, none of it inside a building, and as near the tile's middle as can
## be. Quieter streets come first (a pedestrian street before a residential one, before a through road; never a main road).
## Nothing fits (a park, the water): an open street through the tile's middle, the atom on it as everywhere.
class_name SiteFinder
extends RefCounted

## How much each kind of street is wanted (missing: not at all).
const RANK := {"pedestrian": 6, "living_street": 5, "residential": 4, "tertiary": 3, "unclassified": 2, "secondary": 1,
	"service": 0}
const MIN_LENGTH := 50.0     # metres of straight street the atom's layout takes (its stalls, and the tent row growing)
const MIN_PAVEMENT := 4.0    # metres from the kerb to the building line on the side the atom stands
const STRAIGHT := 0.966      # a bend sharper than about 15 degrees ends a stretch
const TENT_ROW := 16.0       # metres the tent row may grow along the wall, either way from the tent city
const EDGE := 8.0            # the layout stays this far inside the tile


## The site for `tile_key`'s atom in `district`: {point, along, out, width, line} (see Cluster.spot), plus "street" (its name,
## or "" for the open site).
static func pick(district: Dictionary, tile_key: String) -> Dictionary:
	var rect := TileKey.rect(tile_key)
	var inner := rect.grow(-EDGE)
	var middle := rect.get_center()
	var polys: Array[PackedVector2Array] = []
	for b in district.buildings:
		polys.append(MapSites.pts(b.poly))
	var best := {}
	var best_score := -INF
	for r in district.roads:
		if not RANK.has(r["class"]):
			continue
		for stretch in _stretches(MapSites.pts(r.pts)):
			var a: Vector2 = stretch[0]
			var b: Vector2 = stretch[1]
			var length := a.distance_to(b)
			if length < MIN_LENGTH:
				continue
			var site := _site(r, a, b)
			if site.is_empty() or not _fits(site, inner, polys):
				continue
			var score := float(RANK[r["class"]]) * 1000.0 - (site.point as Vector2).distance_to(middle)
			if score > best_score or (is_equal_approx(score, best_score) and _before(site.point, best.point)):
				best_score = score
				best = site
	if best.is_empty():
		best = Cluster.open_site(middle)
		best["street"] = ""
	return best


## The straight stretches of a street's line: [start, end] pairs, where it bends no more than STRAIGHT allows.
static func _stretches(pts: PackedVector2Array) -> Array:
	var out := []
	if pts.size() < 2:
		return out
	var start := pts[0]
	for i in range(1, pts.size()):
		var bends := i + 1 < pts.size() and (pts[i] - pts[i - 1]).normalized().dot((pts[i + 1] - pts[i]).normalized()) < STRAIGHT
		if bends or i == pts.size() - 1:
			out.append([start, pts[i]])
			start = pts[i]
	return out


## The site in the middle of the stretch a-b of street `r`, the atom on the side whose pavement is wider ({} if neither is wide
## enough).
static func _site(r: Dictionary, a: Vector2, b: Vector2) -> Dictionary:
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)  # (the street's right-hand side: its pave[1])
	var pave: Array = r.get("pave", [])
	var width := float(r.w)
	var left := float(pave[0]) if pave.size() == 2 else width * 0.5 + 1.7
	var right := float(pave[1]) if pave.size() == 2 else width * 0.5 + 1.7
	var side := 1.0 if right >= left else -1.0
	var line := maxf(left, right)
	if line - width * 0.5 < MIN_PAVEMENT:
		return {}
	return {"point": (a + b) * 0.5, "along": dir, "out": nrm * side, "width": width, "line": line, "street": str(r.get("name", ""))}


## Is every place the atom puts something (and its tent row, as far as it can grow) inside the tile and outside the buildings?
static func _fits(site: Dictionary, inner: Rect2, polys: Array[PackedVector2Array]) -> bool:
	var spots: Array[Vector2] = []
	for role in Atom.LAYOUT:
		var l: Array = Atom.LAYOUT[role]
		spots.append(Cluster.spot(site, l[0], l[1], l[2]))
	var tent: Array = Atom.LAYOUT.tent
	for shift in [-TENT_ROW, TENT_ROW]:
		spots.append(Cluster.spot(site, float(tent[0]) + shift, tent[1], tent[2]))
	for p in spots:
		if not inner.has_point(p):
			return false
		for poly in polys:
			if Geometry2D.is_point_in_polygon(p, poly):
				return false
	return true


## A fixed order for ties: west first, then north.
static func _before(p: Vector2, q: Vector2) -> bool:
	return p.x < q.x or (is_equal_approx(p.x, q.x) and p.y < q.y)
