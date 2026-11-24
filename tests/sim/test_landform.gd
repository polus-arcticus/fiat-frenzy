## Sim tests: the shape of the land (Landform), on elevation made here so they run offline: a tilted plane strewn with sharp
## 8 m spikes (the noise in a real source), or a dome. The streets and buildings are the test tile's (Fixtures), and its
## neighbour to the west, made from the same extract.
extends TestCase

const EAST := 0.3    # metres up per elevation pixel eastward (about 6 m a pixel here: a 5% grade)...
const SOUTH := 0.15  # ...and southward (2.5%)
const SPIKE := 8.0   # what a spike adds, on about one pixel in 41

static var _made := {}  # (the made elevation and landforms, kept across tests: they take a moment)


# The elevation of a zoom-14 pixel, by its place on the whole grid. `base` is a pixel near the test tile, so the numbers stay
# small; "plane" is the tilted plane with its spikes, "dome" a round hill on the tile's middle.
static func _height(gx: int, gy: int, base: Vector2i, mode: String) -> float:
	if mode == "dome":
		var d := Vector2(gx - base.x, gy - base.y).length()
		return 100.0 + 25.0 * exp(-pow(d / 20.0, 2.0))
	var h := 100.0 + EAST * (gx - base.x) + SOUTH * (gy - base.y)
	if absi((gx * 73856093) ^ (gy * 19349663)) % 41 == 0:
		h += SPIKE
	return h


# The elevation pictures (Images) covering the landforms of `keys`.
static func _relief(keys: Array, mode: String) -> Dictionary:
	var id := mode + ",".join(keys)
	if _made.has(id):
		return _made[id]
	var mid: Array = TileKey.middle(Fixtures.tile_key())  # (one planet for every tile: `base` is the same pixel for all)
	var w := TileKey.web(mid[0], mid[1], Terrain.ZOOM)
	var base := Vector2i(floori(w[0] * Terrain.PIXELS), floori(w[1] * Terrain.PIXELS))
	var imgs := {}
	for key in keys:
		for t in Terrain.tiles_for(MapFrame.tile(key), TileSource.relief_rect(key)):
			if imgs.has(t):
				continue
			var img := Image.create(Terrain.PIXELS, Terrain.PIXELS, false, Image.FORMAT_RGB8)
			for y in Terrain.PIXELS:
				for x in Terrain.PIXELS:
					img.set_pixel(x, y, Terrain.encode(_height(t.x * Terrain.PIXELS + x, t.y * Terrain.PIXELS + y, base, mode)))
			imgs[t] = img
	_made[id] = imgs
	return imgs


static func _form(key: String, district: Dictionary, mode := "plane") -> Landform:
	var id := "form" + key + mode + str(district.get("roads", []).size())
	if not _made.has(id):
		var imgs := _relief([key, TileKey.key(TileKey.parse(key).x - 1, TileKey.parse(key).y)], mode)
		_made[id] = Landform.of(MapFrame.tile(key), TileSource.relief_rect(key).grow(-Landform.INSET), district, imgs)
	return _made[id]


static func _tile() -> Array:
	if not _made.has("tile"):
		var d := Fixtures.tile_district()
		_made["tile"] = [d, _form(Fixtures.tile_key(), d)]
	return _made["tile"]


func test_without_relief_it_is_flat() -> void:
	var d := Fixtures.tile_district()
	var f := Landform.of(MapFrame.tile(Fixtures.tile_key()), TileKey.rect(Fixtures.tile_key()), d, {})
	var mid := TileKey.rect(Fixtures.tile_key()).get_center()
	check(f.flat and f.ground_at(mid) == 0.0 and f.span() == Vector2.ZERO, "with no elevation the ground is flat, at 0")
	var on_streets: bool = f.streets.all(func(st): return Array(st.h).all(func(h): return h == 0.0))
	check(on_streets and f.pads.values().all(func(h): return h == 0.0), "and so are its streets and floors: the game as it was")


func test_heights_are_metres_above_the_sea() -> void:
	var f: Landform = _tile()[1]
	var key := Fixtures.tile_key()
	var mid: Array = TileKey.middle(key)
	var w := TileKey.web(mid[0], mid[1], Terrain.ZOOM)
	var want := 100.0 + EAST * (w[0] * Terrain.PIXELS - floori(w[0] * Terrain.PIXELS) - 0.5) + SOUTH * (w[1] * Terrain.PIXELS - floori(w[1] * Terrain.PIXELS) - 0.5)
	var got := f.land_at(TileKey.rect(key).get_center())
	check(absf(got - want) < 1.0, "the land in the middle of the tile is %.1f m above the sea, as the elevation says (%.1f, give or take a spike)" % [got, want])


func test_the_noise_is_smoothed_and_the_hills_kept() -> void:
	var f: Landform = _tile()[1]
	var steepest := 0.0
	for st in f.streets:
		for k in st.knots.size() - 1:
			var run: float = st.d[k + 1] - st.d[k]
			if run > 2.0 and f.rect.has_point(st.knots[k]):
				steepest = maxf(steepest, absf(st.h[k + 1] - st.h[k]) / run)
	var hill := Vector2(EAST, SOUTH).length() / 6.1  # (rise over run of the plane: a pixel is about 6.1 m here)
	check(steepest < hill + 0.06, "the streets are no steeper than the hill under them, give or take: %.3f (the hill %.3f; an 8 m spike on a 6 m pixel would be 1.3)" % [steepest, hill])
	var a := TileKey.rect(Fixtures.tile_key()).position + Vector2(20, 200)
	var b := a + Vector2(300, 0)
	var rise := f.land_at(b) - f.land_at(a)
	check(absf(rise - 300.0 * EAST / 6.1) < 1.5, "and the hill is kept: 300 m east is %.1f m up (%.1f)" % [rise, 300.0 * EAST / 6.1])


func test_a_street_is_level_across_and_its_pavements_flush() -> void:
	var t := _tile()
	var d: Dictionary = t[0]
	var f: Landform = t[1]
	var kerbs := Kerbs.of(d, {})
	# across: how much a street falls from one pavement's edge to the other, against how much the land under it does
	var street_fall := 0.0
	var land_fall := 0.0
	var pieces := 0
	for st in f.streets:
		for k in st.knots.size() - 1:
			var a: Vector2 = st.knots[k]
			var b: Vector2 = st.knots[k + 1]
			if a.distance_to(b) < 4.0 or not f.rect.has_point(a) or st.bridge:
				continue
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)  # (the right-hand side: reach[1])
			var l: Vector2 = mid - nrm * (float(st.reach[0]) - 0.2)
			var r: Vector2 = mid + nrm * (float(st.reach[1]) - 0.2)
			if is_nan(f.street_at(l)) or is_nan(f.street_at(r)):
				continue
			pieces += 1
			street_fall += absf(f.street_at(l) - f.street_at(r)) / l.distance_to(r)
			land_fall += absf(f.land_at(l) - f.land_at(r)) / l.distance_to(r)
	check(pieces > 300 and street_fall < land_fall * 0.5, "a street is levelled across: it falls %.1f%% from one side to the other where the land falls %.1f%% (%d pieces)" % [100.0 * street_fall / pieces, 100.0 * land_fall / pieces, pieces])
	# one surface: no step anywhere on the streets, at junctions neither
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var steepest := 0.0
	var pairs := 0
	for i in 4000:
		var st: Dictionary = f.streets[rng.randi() % f.streets.size()]
		if st.bridge or st.knots.size() < 2:
			continue
		var k: int = rng.randi() % (st.knots.size() - 1)
		var p: Vector2 = (st.knots[k] as Vector2).lerp(st.knots[k + 1], rng.randf()) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 8.0)
		var q := p + Vector2.from_angle(rng.randf() * TAU) * 0.5
		var hp := f.street_at(p)
		var hq := f.street_at(q)
		if is_nan(hp) or is_nan(hq) or not f.rect.has_point(p):
			continue
		pairs += 1
		steepest = maxf(steepest, absf(hp - hq) / 0.5)
	check(pairs > 1000 and steepest < 0.15, "and the streets are one surface, with no step anywhere, junctions too: half a metre apart, at most %.3f m apart in height a metre (%d pairs)" % [steepest, pairs])
	var flush := 0
	var lines := 0
	for e in kerbs.edges:
		var mid: Vector2 = (e.a + e.b) * 0.5
		var x := f.street_at(mid - e.side * 0.15)
		var y := f.street_at(mid + e.side * 0.15)
		if is_nan(x) or is_nan(y) or not f.rect.has_point(mid):
			continue
		lines += 1
		if absf(x - y) <= 0.3 * 0.15:  # (0.3 m apart on one surface: no more than its slope there, no step)
			flush += 1
	check(lines > 100 and flush == lines, "the carriageway and the pavement meet without a step along every kerb (%d of %d lines)" % [flush, lines])


func test_the_ground_keeps_under_the_streets() -> void:
	var f: Landform = _tile()[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var n := 0
	var under := 0
	var worst := 0.0
	for st in f.streets:
		for k in st.knots.size() - 1:
			var a: Vector2 = st.knots[k]
			var b: Vector2 = st.knots[k + 1]
			for s in 3:
				var p := a.lerp(b, rng.randf()) + (b - a).normalized().orthogonal() * rng.randf_range(-st.reach[1], st.reach[0])
				var h := f.street_at(p)
				if is_nan(h) or not f.rect.has_point(p):
					continue
				n += 1
				worst = maxf(worst, f.ground_at(p) - h)
				if f.ground_at(p) <= h + 0.001:
					under += 1
	check(n > 500 and under == n, "the ground is never above the streets' surface (%d of %d points; worst %.3f m above)" % [under, n, worst])
	var own := 0
	var away := 0
	for j in f.rows:
		for i in f.cols:
			var p := f.point(i, j)
			var near_street := false
			for o in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2.ZERO, Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
				near_street = near_street or not f._nearest(p + o * Landform.CELL, true).is_empty()  # (the settling reaches a cell)
			if near_street or _near_a_building(_tile()[0], p, Landform.FLOOR_CUT + 0.1):
				continue
			away += 1
			if absf(f.ground_at(p) - f.land_at(p)) < 0.001:
				own += 1
	check(away > 100 and own == away, "and away from the streets and buildings it is the land's own shape (%d of %d grid points)" % [own, away])


func _near_a_building(d: Dictionary, p: Vector2, reach: float) -> bool:
	for b in d.buildings:
		var poly := MapSites.pts(b.poly)
		if Geometry2D.is_point_in_polygon(p, poly) or Landform._within(p, poly, reach):
			return true
	return false


func test_a_building_stands_level_with_its_street() -> void:
	var t := _tile()
	var d: Dictionary = t[0]
	var f: Landform = t[1]
	var met := 0
	var asked := 0
	for b in d.buildings:
		var poly := MapSites.pts(b.poly)
		var mid := Vector2.ZERO
		for q in poly:
			mid += q
		mid /= poly.size()
		# the wall nearest a street, and just outside it
		var best := Vector2.INF
		var best_d := INF
		for k in poly.size():
			var q := (poly[k] + poly[(k + 1) % poly.size()]) * 0.5
			var out := q + (q - mid).normalized() * 0.4
			if not is_nan(f.street_at(out)) and q.distance_to(mid) < best_d:
				best = out
				best_d = q.distance_to(mid)
		if best == Vector2.INF:
			continue
		asked += 1
		if absf(f.street_at(best) - float(f.pads[int(b.id)])) < 0.3:
			met += 1
	check(asked > 30 and met >= asked * 0.85, "a building's floor is at the height of the pavement outside its wall (%d of %d)" % [met, asked])
	var inside := 0
	var floors := 0
	for b in d.buildings:
		var poly := MapSites.pts(b.poly)
		var p := Vector2.ZERO
		for q in poly:
			p += q
		p /= poly.size()
		var box := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			box = box.expand(q)
		if not Geometry2D.is_point_in_polygon(p, poly) or not f.owned.grow(-Landform.FLOOR_CUT - Landform.CELL * 1.42).encloses(box):
			continue  # (a building near the tile's edge leaves the ground to agree with the neighbour's)
		floors += 1
		if f.ground_at(p) <= float(f.pads[int(b.id)]) and is_equal_approx(f.height_at(p), float(f.pads[int(b.id)])) or not is_nan(f.street_at(p)):
			inside += 1
	check(floors > 30 and inside == floors, "inside, it is its floor, with the ground under it (%d of %d)" % [inside, floors])


func test_a_bridge_goes_straight_over_and_never_into_the_land() -> void:
	var key := Fixtures.tile_key()
	var c := TileKey.rect(key).get_center()
	var road := {"name": "Brücke", "class": "residential", "w": 7.0, "bridge": true,
		"pts": [c.x - 200.0, c.y, c.x + 200.0, c.y]}
	var f := _form(key, {"roads": [road], "buildings": []}, "dome")
	var st: Dictionary = f.streets[0]
	var into := 0
	for k in st.knots.size():
		if st.h[k] < f.land_at(st.knots[k]) - 0.001:
			into += 1
	var ends: float = (st.h[0] + st.h[st.h.size() - 1]) * 0.5
	check(into == 0 and st.h[st.h.size() / 2] > ends + 5.0, "over a hill a bridge's deck rises with the land, never into it (%.1f m in the middle, %.1f at the ends)" % [st.h[st.h.size() / 2], ends])
	var flat_land := _form(key, {"roads": [road], "buildings": []}, "plane")
	var line: Dictionary = flat_land.streets[0]
	var straight := true
	for k in line.knots.size():
		var want := lerpf(line.h[0], line.h[line.h.size() - 1], line.d[k] / line.d[line.d.size() - 1])
		if line.h[k] > want + 0.4:  # (only where a spike lifts the land above the line)
			straight = false
	var under := 0
	var n := 0
	for k in st.knots.size() - 1:
		var p: Vector2 = (st.knots[k] as Vector2).lerp(st.knots[k + 1], 0.5)
		if not f.rect.has_point(p):
			continue
		n += 1
		if f.ground_at(p) <= f.street_at(p) + 0.001:
			under += 1
	check(straight and n > 10 and under == n, "over even ground it runs straight end to end, and the ground stays under its deck (%d of %d)" % [under, n])


func test_neighbouring_tiles_agree_where_they_meet() -> void:
	var key := Fixtures.tile_key()
	var t := TileKey.parse(key)
	var west := TileKey.key(t.x - 1, t.y)
	var a: Landform = _tile()[1]
	var b := _form(west, OsmImport.tile(Fixtures.tile_raw(), west))
	var edge := TileKey.rect(key).intersection(TileKey.rect(west).grow(0.01))
	var land_off := 0.0
	var ground_off := 0.0
	var street_off := 0.0
	var shared := 0
	for k in 400:
		var p := edge.position + edge.size * (k / 399.0)
		land_off = maxf(land_off, absf(a.land_at(p) - b.land_at(p)))
		ground_off = maxf(ground_off, absf(a.ground_at(p) - b.ground_at(p)))
		var sa := a.street_at(p)
		var sb := b.street_at(p)
		if not is_nan(sa) and not is_nan(sb):
			shared += 1
			street_off = maxf(street_off, absf(sa - sb))
	check(land_off < 0.001, "the land is the same both sides of the border (%.4f m apart at most)" % land_off)
	check(shared > 5 and street_off < 0.001, "so are the streets that cross it (%d points, %.4f m)" % [shared, street_off])
	var worst := edge.position
	var most := -1.0
	for k in 400:
		var p := edge.position + edge.size * (k / 399.0)
		if absf(a.ground_at(p) - b.ground_at(p)) > most:
			most = absf(a.ground_at(p) - b.ground_at(p))
			worst = p
	var na := a._nearest(worst, true)
	var nb := b._nearest(worst, true)
	note("ground differs most at %s: %.3f | %.3f; surface %.3f | %.3f; land %.3f; pad %s | %s; nearest %s | %s" % [worst, a.ground_at(worst), b.ground_at(worst),
		a.surface_at(worst), b.surface_at(worst), a.land_at(worst), a.pad_at(worst), b.pad_at(worst),
		"none" if na.is_empty() else "road %d gap %.1f" % [na.road, na.gap], "none" if nb.is_empty() else "road %d gap %.1f" % [nb.road, nb.gap]])
	check(ground_off < 0.01, "and the ground (%.4f m)" % ground_off)


func test_the_quick_answers_are_the_full_ones() -> void:
	var f: Landform = _tile()[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var mid := TileKey.rect(Fixtures.tile_key()).get_center()
	var same := 0
	var plain := 0
	var n := 3000
	for i in n:
		var p := mid + Vector2(rng.randf_range(-250, 250), rng.randf_range(-250, 250))
		var full := f.street_at(p)  # (height_at without its short cut: a street's surface, a floor, the ground)
		if is_nan(full):
			full = f.pad_at(p)
		if is_nan(full):
			full = f.ground_at(p)
		if absf(f.height_at(p) - full) < 0.0001:
			same += 1
		var g := ((p - f.rect.position) / Landform.CELL).floor()
		plain += f._plain[int(g.y) * (f.cols - 1) + int(g.x)]
	check(same == n and plain > n / 4, "height_at's one look-up on a plain cell is the full answer, everywhere (%d of %d points; %d on plain cells)" % [same, n, plain])
	var close := 0
	var tried := 0
	for st in f.streets:
		if st.bridge:
			continue
		for k in st.knots.size() - 1:
			var a: Vector2 = st.knots[k]
			var b: Vector2 = st.knots[k + 1]
			if a.distance_to(b) < 4.0 or not f.rect.has_point(a):
				continue
			var dir := (b - a).normalized()
			var p := a.lerp(b, rng.randf_range(0.2, 0.8))
			tried += 1
			if absf(f.walk_grade(p, dir) - f.grade(p, dir)) < 0.02:
				close += 1
	check(tried > 300 and close >= tried * 0.95, "and on the streets a walker's quick grade is the full one, give or take 2%% (%d of %d)" % [close, tried])
