## Where on a tile its atom goes: the same street every time, for everyone who lands there (so two players' tiles agree, and their
## saves can be merged). The rule: a straight stretch of a quiet street, long enough for the atom's layout, with a pavement wide
## enough for stalls at the kerb and tents against the wall, none of it inside a building, and as near the tile's middle as can
## be. Quieter streets come first (a pedestrian street before a residential one, before a through road; never a main road).
## On a hill (a Landform) a site whose layout stands on ground steeper than MAX_GRADE anywhere is passed over; if every site is,
## the best of them is taken all the same (a mountain tile still gets its market).
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
const MAX_GRADE := 0.10      # the steepest ground (rise over run) a market's stalls and tents stand on: a 10% street
const CAMP_GRADE := 0.12     # and a camp's


## The site for `tile_key`'s atom in `district`: {point, along, out, width, line} (see Cluster.spot), plus "street" (its name,
## or "" for the open site). `land` is the tile's Landform (none: flat).
static func pick(district: Dictionary, tile_key: String, land: Landform = null) -> Dictionary:
	var best := _pick(district, tile_key, land, MAX_GRADE)
	if best.is_empty() and land != null and not land.flat:
		best = _pick(district, tile_key, land, INF)  # (nowhere level enough: the best street all the same)
	if best.is_empty():
		best = _open(district, tile_key, land)
		best["street"] = ""
	return best


## No street will do: an open site, in the tile's middle. On a hill, the open spot nearest the middle whose layout stands on
## ground no steeper than MAX_GRADE, or failing that the levelest.
const OPEN_STEP := 16.0  # metres between the open spots tried on a hill


static func _open(district: Dictionary, tile_key: String, land: Landform) -> Dictionary:
	var rect := TileKey.rect(tile_key)
	var middle := rect.get_center()
	if land == null or land.flat:
		return Cluster.open_site(middle)
	var inner := rect.grow(-EDGE)
	var polys: Array[PackedVector2Array] = []
	for b in district.buildings:
		polys.append(MapSites.pts(b.poly))
	var water: Dictionary = district.get("water", {})
	var best := {}
	var best_key := INF
	var y := inner.position.y
	while y <= inner.end.y:
		var x := inner.position.x
		while x <= inner.end.x:
			var site := Cluster.open_site(Vector2(x, y))
			if _fits(site, inner, polys, water):
				var steep := steepest(site, land)
				# (level enough: the nearest the middle; else the least steep, which no level one ever loses to)
				var key: float = (site.point as Vector2).distance_to(middle) if steep <= MAX_GRADE else 1.0e6 + steep * 1000.0
				if key < best_key:
					best_key = key
					best = site
			x += OPEN_STEP
		y += OPEN_STEP
	return best if not best.is_empty() else Cluster.open_site(middle)


static func _pick(district: Dictionary, tile_key: String, land: Landform, max_grade: float) -> Dictionary:
	var rect := TileKey.rect(tile_key)
	var inner := rect.grow(-EDGE)
	var middle := rect.get_center()
	var polys: Array[PackedVector2Array] = []
	for b in district.buildings:
		polys.append(MapSites.pts(b.poly))
	var best := {}
	var best_score := -INF
	var water: Dictionary = district.get("water", {})
	for r in district.roads:
		if not RANK.has(r["class"]) or r.get("bridge", false):  # (no market on a bridge)
			continue
		for stretch in _stretches(MapSites.pts(r.pts)):
			var a: Vector2 = stretch[0]
			var b: Vector2 = stretch[1]
			var length := a.distance_to(b)
			if length < MIN_LENGTH:
				continue
			var site := _site(r, a, b)
			if site.is_empty() or not _fits(site, inner, polys, water):
				continue
			if land != null and max_grade < INF and steepest(site, land) > max_grade:
				continue
			var score := float(RANK[r["class"]]) * 1000.0 - (site.point as Vector2).distance_to(middle)
			if score > best_score or (is_equal_approx(score, best_score) and _before(site.point, best.point)):
				best_score = score
				best = site
	return best


## The steepest ground under a site's layout (its stalls and tents, and its tent row as far as it can grow).
static func steepest(site: Dictionary, land: Landform) -> float:
	var most := 0.0
	for p in _layout(site):
		most = maxf(most, land.slope_at(p))
	return most


## Where a tile's homeless camp goes (Camp, with its own fire): in the park nearest the market, as near the market as it can be,
## on open ground (in the park, not in the water, not on a street, not in a building, inside the tile), its counter facing the
## nearest street; and no further from the market than CAMP_WALK on foot (`walk`: metres along the town's streets to a point),
## or its keeper and the runner hauling its scrap spend their day on the road and go down on the way. On a hill (`land`) no
## steeper than CAMP_GRADE. The same every time, for everyone. {at, toward} ({} if no park is big enough and near enough).
const MIN_PARK := 300.0     # square metres: a smaller patch of grass is not a park
const CAMP_WALK := 90.0     # metres on foot from the market, at most (a riverside park 100 m off was a 300 m walk round)
const CAMP_STEP := 3.0      # metres between the spots tried in a park
const CAMP_CLEAR := 4.0     # metres a camp keeps off a street's carriageway (and its pavement)
const CAMP_ROOM := 5.0      # metres round the camp that must be park too (its pile one side, its fire the other)


## Where a tile's bins are (WasteBin): at the real ones on its map (StreetThings' points), for each kind, the nearest to the
## market on foot first, at most RECYCLE_MOST of a kind and none further than RECYCLE_WALK. {bin kind: [{at, front}]} (front:
## where the runner stands, toward the street); a kind with none near enough is left out, and the atom keeps the one it lays
## out itself. Waste baskets are the garbage (the scrap), recycling containers the recycling (the bottles), those that take
## food or compost the organics, drinking fountains the fountain.
## (Further than a camp may be, CAMP_WALK: only the pick-up end of a runner's trip is far, the market's stalls are at the other.
## Measured: the tile by the Main, its two containers a 200 m walk off, 20 days in full detail, 0 collapses, nothing built.)
const RECYCLE_WALK := 220.0
const RECYCLE_MOST := 3
const PILE_OUT := 1.6       # metres in front of the container what it gathers lies
const ON_MAP := {"garbage": "bin", "recycling": "recycling", "organics": "organics", "fountain": "fountain"}  # bin kind -> point kind


## The recycling is walked to by whoever is short of cash, on foot, for their next meal (Collecting): it must be near, or they
## go down on the way. (At the tile by the Main its containers, a 200 m walk off, cost 8 collapses in 20 days; the runners
## wheel the rest on carts, the far end of a trip whose near end is the market.)
const BOTTLE_WALK := CAMP_WALK


static func bins(district: Dictionary, tile_key: String, market: Vector2, walk := Callable()) -> Dictionary:
	var out := {}
	for kind in ON_MAP:
		var found := _nearest(district, tile_key, market, walk, ON_MAP[kind], BOTTLE_WALK if kind == "recycling" else RECYCLE_WALK)
		if not found.is_empty():
			out[kind] = found
	return out


## The tile's recycling containers near the market (`bins`' recycling).
static func recycling(district: Dictionary, tile_key: String, market: Vector2, walk := Callable()) -> Array:
	return _nearest(district, tile_key, market, walk, "recycling", BOTTLE_WALK)


static func _nearest(district: Dictionary, tile_key: String, market: Vector2, walk: Callable, point_kind: String, reach := RECYCLE_WALK) -> Array:
	var rect := TileKey.rect(tile_key)
	var water: Dictionary = district.get("water", {})
	var found: Array = []
	for p in district.get("street", {}).get("points", []):
		if p.kind != point_kind or not rect.has_point(p.at) or market.distance_to(p.at) > reach or OsmWater.wet(water, p.at):
			continue  # (no walk is shorter than the straight line: the far ones are not walked out)
		var d: float = float(walk.call(p.at)) if walk.is_valid() else market.distance_to(p.at)
		if d <= reach:
			var front := _toward_street(p.at, district.roads)
			found.append({"at": p.at + front * PILE_OUT, "front": front, "walk": d})
	found.sort_custom(func(a, b): return a.walk < b.walk or (is_equal_approx(a.walk, b.walk) and _before(a.at, b.at)))
	return found.slice(0, RECYCLE_MOST)


const CAMP_APART := 8.0     # metres a camp keeps from anything already standing (`taken`: the atom's stalls, its tent row)


static func camp(district: Dictionary, tile_key: String, market: Vector2, walk := Callable(), taken: Array[Vector2] = [], land: Landform = null) -> Dictionary:
	var parks: Array = district.get("green", {}).get("areas", []).filter(func(a): return a.kind == "green" and _area(a.poly) >= MIN_PARK)
	if parks.is_empty():
		return {}
	parks.sort_custom(func(a, b): return _gap(a.poly, market) < _gap(b.poly, market))
	var inner := TileKey.rect(tile_key).grow(-EDGE)
	var walls: Array[PackedVector2Array] = []
	for b in district.buildings:
		walls.append(MapSites.pts(b.poly))
	var water: Dictionary = district.get("water", {})
	for park in parks:
		var poly: PackedVector2Array = park.poly
		var box := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			box = box.expand(p)
		var spots: Array[Vector2] = []
		var y := box.position.y
		while y <= box.end.y:
			var x := box.position.x
			while x <= box.end.x:
				spots.append(Vector2(x, y))
				x += CAMP_STEP
			y += CAMP_STEP
		spots.sort_custom(func(a, b): return a.distance_squared_to(market) < b.distance_squared_to(market) or (is_equal_approx(a.distance_squared_to(market), b.distance_squared_to(market)) and _before(a, b)))
		for at in spots:
			if taken.any(func(p): return p.distance_to(at) < CAMP_APART + CAMP_ROOM):
				continue
			if _camp_fits(at, poly, inner, walls, water, district.roads) and (land == null or land.slope_at(at) <= CAMP_GRADE):
				if walk.is_valid() and float(walk.call(at)) > CAMP_WALK:
					break  # (the nearest spot in this park is too far round: the next park)
				return {"at": at, "toward": _toward_street(at, district.roads)}
	return {}


static func _camp_fits(at: Vector2, park: PackedVector2Array, inner: Rect2, walls: Array[PackedVector2Array], water: Dictionary, roads: Array) -> bool:
	for off in [Vector2.ZERO, Vector2(CAMP_ROOM, 0), Vector2(-CAMP_ROOM, 0), Vector2(0, CAMP_ROOM), Vector2(0, -CAMP_ROOM)]:
		var p: Vector2 = at + off
		if not inner.has_point(p) or not Geometry2D.is_point_in_polygon(p, park) or OsmWater.wet(water, p):
			return false
		for w in walls:
			if Geometry2D.is_point_in_polygon(p, w):
				return false
	for r in roads:
		var pts := MapSites.pts(r.pts)
		for k in pts.size() - 1:
			if Geometry2D.get_closest_point_to_segment(at, pts[k], pts[k + 1]).distance_to(at) < float(r.w) * 0.5 + CAMP_CLEAR + CAMP_ROOM:
				return false
	return true


# Which way a camp at `at` faces: toward the nearest street.
static func _toward_street(at: Vector2, roads: Array) -> Vector2:
	var best := Vector2(INF, INF)
	for r in roads:
		var pts := MapSites.pts(r.pts)
		for k in pts.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(at, pts[k], pts[k + 1])
			if c.distance_to(at) < best.distance_to(at):
				best = c
	return (best - at).normalized() if best.is_finite() and best != at else Vector2(0, 1)


# How far `p` is from the polygon (0 inside it).
static func _gap(poly: PackedVector2Array, p: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for i in poly.size():
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p))
	return best


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5


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


## Every place the atom puts something at `site`, and its tent row as far as it can grow.
static func _layout(site: Dictionary) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for role in Atom.LAYOUT:
		var l: Array = Atom.LAYOUT[role]
		spots.append(Cluster.spot(site, l[0], l[1], l[2]))
	var tent: Array = Atom.LAYOUT.tent
	for shift in [-TENT_ROW, TENT_ROW]:
		spots.append(Cluster.spot(site, float(tent[0]) + shift, tent[1], tent[2]))
	return spots


## Is every place the atom puts something (and its tent row, as far as it can grow) inside the tile and outside the buildings?
static func _fits(site: Dictionary, inner: Rect2, polys: Array[PackedVector2Array], water := {}) -> bool:
	for p in _layout(site):
		if not inner.has_point(p) or OsmWater.wet(water, p):
			return false
		for poly in polys:
			if Geometry2D.is_point_in_polygon(p, poly):
				return false
	return true


## A fixed order for ties: west first, then north.
static func _before(p: Vector2, q: Vector2) -> bool:
	return p.x < q.x or (is_equal_approx(p.x, q.x) and p.y < q.y)
