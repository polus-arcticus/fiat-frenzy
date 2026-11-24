## How well a tile's Landform holds together, on the real cached elevation: how long it takes to make, how its streets sit
## (the pavements on a street's surface, the two sides of every kerb line at one height, the ground never up through a street),
## how steep its streets get, and, for two neighbouring tiles, whether they agree along the edge they share. Headless.
##   godot --headless --path . --script tools/probe_landform.gd -- [key=16/x/y ...] [pair=16/x/y,16/x/y]
extends SceneTree


func _initialize() -> void:
	var keys: Array[String] = []
	var pair: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			keys.append(a.trim_prefix("key="))
		elif a.begins_with("pair="):
			pair = a.trim_prefix("pair=").split(",")
	if keys.is_empty() and pair.is_empty():
		keys = ["16/10482/25324", "16/11725/21882", "16/34347/22195"]
		pair = ["16/34347/22195", "16/34348/22195"]
	for key in keys:
		_report(key)
	if pair.size() == 2:
		_border(pair[0], pair[1])
	quit()


func _make(key: String) -> Array:
	var district := TileSource.district(key)
	var t0 := Time.get_ticks_msec()
	var f := TileSource.landform(key, district)
	return [district, f, Time.get_ticks_msec() - t0]


func _report(key: String) -> void:
	var made := _make(key)
	var district: Dictionary = made[0]
	var f: Landform = made[1]
	print("%s: %s, %d x %d grid, %d streets, %d pads, made in %d ms; ground %.0f..%.0f m" % [key, "flat" if f.flat else "relief",
		f.cols, f.rows, f.streets.size(), f.pads.size(), made[2], f.span().x, f.span().y])
	var kerbs := Kerbs.of(district, {})
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# the pavements are on a street's surface
	var on := 0
	var tried := 0
	for i in 2000:
		var piece := kerbs.pieces[rng.randi() % kerbs.pieces.size()]
		var p := _inside(piece, rng)
		if p == Vector2.INF:
			continue
		tried += 1
		if not is_nan(f.street_at(p)):
			on += 1
	print("  pavement points on a street surface: %d of %d" % [on, tried])
	# each kerb line: the carriageway side and the pavement side at one height
	var worst := 0.0
	var off := 0
	for e in kerbs.edges:
		var mid: Vector2 = (e.a + e.b) * 0.5
		if not f.rect.has_point(mid):
			continue
		var a := f.street_at(mid - e.side * 0.15)
		var b := f.street_at(mid + e.side * 0.15)
		if is_nan(a) or is_nan(b):
			continue
		worst = maxf(worst, absf(a - b) / 0.3)
		if absf(a - b) > 0.3 * 0.35:  # (0.3 m apart: a step, not the street's own slope)
			off += 1
	print("  kerb lines: %d, %d with a step across them, the steepest across a kerb %.2f" % [kerbs.edges.size(), off, worst])
	# the ground under the streets
	var poke := 0.0
	var pokes := 0
	var worst_at := Vector2.ZERO
	var n := 0
	for st in f.streets:
		for k in st.knots.size() - 1:
			for s in 4:
				var p: Vector2 = (st.knots[k] as Vector2).lerp(st.knots[k + 1], rng.randf())
				var dir: Vector2 = ((st.knots[k + 1] as Vector2) - st.knots[k]).normalized()
				p += dir.orthogonal() * rng.randf_range(-st.reach[0], st.reach[1])
				var s_h := f.street_at(p)
				if is_nan(s_h) or not f.rect.has_point(p):  # (a road's line runs on past the map: its heights stop at the grid)
					continue
				n += 1
				var up := f.ground_at(p) - s_h
				if up > poke:
					worst_at = p
				poke = maxf(poke, up)
				if up > 0.02:
					pokes += 1
	print("  ground under streets: %d points, %d where the ground is more than 2 cm above the surface, worst %.3f m above" % [n, pokes, poke])
	if poke > 0.02:  # why: the worst point's street, and the corners of its grid cell with the street each was shaped to
		var w := f._nearest(worst_at)
		print("    worst at %s: street %.2f (road %d, gap %.2f), ground %.2f, land %.2f" % [worst_at, f.street_at(worst_at), w.road, w.gap, f.ground_at(worst_at), f.land_at(worst_at)])
		var g := ((worst_at - f.rect.position) / Landform.CELL).floor()
		for c in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var q := f.point(int(g.x + c.x), int(g.y + c.y))
			var nq := f._nearest(q)
			print("    corner %s: ground %.2f, land %.2f, nearest %s" % [q, f.ground_at(q), f.land_at(q), "none" if nq.is_empty() else "road %d h %.2f gap %.2f" % [nq.road, nq.h, nq.gap]])
	# how steep the streets are along them, and how much they fall across against the land under them
	var steep := 0.0
	var fall := 0.0
	var land_fall := 0.0
	var pieces := 0
	for st in f.streets:
		if st.bridge:
			continue
		for k in st.knots.size() - 1:
			var a: Vector2 = st.knots[k]
			var b: Vector2 = st.knots[k + 1]
			if a.distance_to(b) < 2.0 or not f.rect.has_point(a):
				continue
			steep = maxf(steep, absf(f.surface_at(b) - f.surface_at(a)) / a.distance_to(b))
			var dir := (b - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			var l: Vector2 = (a + b) * 0.5 - nrm * (float(st.reach[0]) - 0.2)
			var r: Vector2 = (a + b) * 0.5 + nrm * (float(st.reach[1]) - 0.2)
			pieces += 1
			fall += absf(f.surface_at(l) - f.surface_at(r)) / l.distance_to(r)
			land_fall += absf(f.land_at(l) - f.land_at(r)) / l.distance_to(r)
	print("  steepest street: %.2f (%.0f degrees); across, the streets fall %.1f%% where the land falls %.1f%%" % [steep, rad_to_deg(atan(steep)), 100.0 * fall / maxf(pieces, 1), 100.0 * land_fall / maxf(pieces, 1)])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shade="):  # (a folder: the land and the surface as hillshades, side by side to compare)
			var dir := a.trim_prefix("shade=")
			for field in ["land", "surface"]:
				_shade(f, field, "%s/%s_%s.png" % [dir, key.replace("/", "_"), field])


## A hillshade of one of `f`'s fields (lit from the north-west), a pixel a metre: to see the streets levelled into the hill.
func _shade(f: Landform, field: String, path: String) -> void:
	var size := Vector2i(f.rect.size)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var light := Vector3(-1.0, 1.4, -1.0).normalized()
	var at := func(p: Vector2) -> float: return f.call(field + "_at", p)
	for y in size.y:
		for x in size.x:
			var p := f.rect.position + Vector2(x, y)
			var dx: float = at.call(p + Vector2(0.5, 0)) - at.call(p - Vector2(0.5, 0))
			var dz: float = at.call(p + Vector2(0, 0.5)) - at.call(p - Vector2(0, 0.5))
			var v := clampf(Vector3(-dx, 1.0, -dz).normalized().dot(light), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.save_png(path)
	print("  wrote %s" % path)


func _border(ka: String, kb: String) -> void:
	var a: Array = _make(ka)
	var b: Array = _make(kb)
	var fa: Landform = a[1]
	var fb: Landform = b[1]
	var ra := TileKey.rect(ka)
	var rb := TileKey.rect(kb)
	var edge := ra.intersection(rb.grow(0.01))
	var land_off := 0.0
	var ground_off := 0.0
	var n := 0
	for k in 200:
		var p := edge.position + edge.size * (k / 199.0)
		land_off = maxf(land_off, absf(fa.land_at(p) - fb.land_at(p)))
		ground_off = maxf(ground_off, absf(fa.ground_at(p) - fb.ground_at(p)))
		n += 1
	var worst := Vector2.ZERO
	for k in 200:
		var p := edge.position + edge.size * (k / 199.0)
		if absf(fa.ground_at(p) - fb.ground_at(p)) >= ground_off - 0.0001:
			worst = p
	var na := fa._nearest(worst, true)
	var nb := fb._nearest(worst, true)
	print("  the ground differs most at %s: %.2f | %.2f; land %.2f; shaped to %s | %s" % [worst, fa.ground_at(worst), fb.ground_at(worst), fa.land_at(worst),
		"none" if na.is_empty() else "road %d h %.2f gap %.2f" % [na.road, na.h, na.gap], "none" if nb.is_empty() else "road %d h %.2f gap %.2f" % [nb.road, nb.h, nb.gap]])
	var street_off := 0.0
	var shared := 0
	for k in 200:
		var p := edge.position + edge.size * (k / 199.0)
		var sa := fa.street_at(p)
		var sb := fb.street_at(p)
		if not is_nan(sa) and not is_nan(sb):
			shared += 1
			street_off = maxf(street_off, absf(sa - sb))
	print("border %s | %s: land differs by at most %.4f m, ground %.4f m, streets (%d points on both) %.4f m" % [ka, kb, land_off, ground_off, shared, street_off])


func _inside(poly: PackedVector2Array, rng: RandomNumberGenerator) -> Vector2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	for i in 20:
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if Geometry2D.is_point_in_polygon(p, poly):
			return p
	return Vector2.INF
