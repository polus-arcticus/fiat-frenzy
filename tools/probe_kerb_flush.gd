## How far the raised pavements' tops are from where a walker stands on them: for points inside the kerbs' pavement pieces, the
## height of the drawn pavement top there against Ground.y (the land plus a kerb, what views stand things on). Prints the mean,
## the worst, and how many are off by more than 10 cm, and the same for the carriageway against the land. Headless.
##   godot --headless --path . --script tools/probe_kerb_flush.gd -- [key=16/10482/25324]
extends SceneTree


func _initialize() -> void:
	var key := "16/10482/25324"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	var m: Array = TileKey.middle(key)
	var district := TileSource.district(key)
	var land := TileSource.landform(key, district)
	var landing := TileLanding.new(key, district, m[0], m[1], land)
	var kerbs := Kerbs.of(district, {})
	Ground.landform = land
	Ground.datum = land.height_at(landing.market)
	Ground.kerbs = kerbs
	var t0 := Time.get_ticks_msec()
	var baked := CityBuilder.bake(district, {}, kerbs, land, Ground.datum)
	print("land %s; %d pavement pieces; baked in %d ms" % ["hills" if not land.flat else "flat", kerbs.pieces.size(), Time.get_ticks_msec() - t0])
	_measure("pavement top vs the land + kerb", baked.layers["Pavements"], kerbs, true, func(p): return Ground.land(p) + Kerbs.HEIGHT)
	_measure("carriageway vs the land", baked.layers["Streets"], kerbs, false, func(p): return Ground.land(p) + 0.03)
	quit()


# Samples points in the pavement pieces (`on_pavement`) or on the carriageway (in a piece's box but not in it), finds the drawn
# top face over each in `buf`, and compares its height with `want`.
func _measure(what: String, buf: CityBuilder.Buf, kerbs: Kerbs, on_pavement: bool, want: Callable) -> void:
	var tris := []
	for k in range(0, buf.i.size(), 3):
		var a := buf.v[buf.i[k]]
		var b := buf.v[buf.i[k + 1]]
		var c := buf.v[buf.i[k + 2]]
		if (b - a).cross(c - a).normalized().abs().y > 0.5:  # (a top, not a side)
			tris.append([a, b, c])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := 0
	var sum := 0.0
	var worst := 0.0
	var off := 0
	var tries := 0
	while n < 500 and tries < 20000:
		tries += 1
		var piece := kerbs.pieces[rng.randi() % kerbs.pieces.size()]
		var box := Rect2(piece[0], Vector2.ZERO)
		for p in piece:
			box = box.expand(p)
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if on_pavement != Geometry2D.is_point_in_polygon(p, piece):
			continue
		if not on_pavement and kerbs.height_at(p) != 0.0:
			continue
		var y := NAN
		for t in tris:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var c: Vector3 = t[2]
			if Geometry2D.point_is_inside_triangle(p, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)):
				var plane := Plane(a, b, c)
				var hit = plane.intersects_ray(Vector3(p.x, 1000.0, p.y), Vector3.DOWN)
				if hit != null:
					var h: float = (hit as Vector3).y
					if is_nan(y) or absf(h - float(want.call(p))) < absf(y - float(want.call(p))):
						y = h  # (the layer nearest to what is wanted: other layers' faces may lie over the same spot)
		if is_nan(y):
			continue
		var d := absf(y - float(want.call(p)))
		n += 1
		sum += d
		worst = maxf(worst, d)
		if d > 0.1:
			off += 1
	print("%s: %d points, mean off %.3f m, worst %.2f m, %d (%.0f%%) off by more than 10 cm" % [what, n, sum / maxf(n, 1), worst, off, 100.0 * off / maxf(n, 1)])
