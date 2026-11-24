## Sim tests: the city drawn on the shape of the land (CityBuilder on a Landform, through Drape), headless: the baked triangles
## are plain data. On rolling hills made here, every street, pavement and kerb lies on the land's surface field exactly, at its
## own height over it (so nothing pokes through and nothing floats), and on flat land the city is what it always was.
extends TestCase

const DATUM := 100.0


static func _hills() -> Landform:
	var o := TileKey.rect(Fixtures.tile_key()).position
	return Fixtures.landform(TileKey.rect(Fixtures.tile_key()).grow(200.0),
		func(p: Vector2) -> float: return 100.0 + 3.0 * sin(p.x / 23.0) + 2.0 * cos(p.y / 17.0) + 0.05 * (p.x - o.x))


# How far each vertex of `buf` is over the land's surface there (in the view's metres: above DATUM).
static func _over(buf: CityBuilder.Buf, land: Landform) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v in buf.v:
		out.append(v.y - (land.surface_at(Vector2(v.x, v.z)) - DATUM))
	return out


func test_on_flat_land_the_city_is_as_it_was() -> void:
	var d := Fixtures.tile_district()
	var kerbs := Kerbs.of(d, {})
	var a := CityBuilder.bake(d, {}, kerbs)
	var b := CityBuilder.bake(d, {}, kerbs, Landform.new())
	var same := true
	for layer in a.layers:
		same = same and a.layers[layer].v == b.layers[layer].v
	check(same and not a.hills, "a flat landform draws the very same triangles as none")
	check(a.layers.Ground.i.size() == 6, "and the ground is one quad")


func test_cutting_along_the_grid_keeps_every_square_metre() -> void:
	var drape := Drape.on(_hills(), DATUM)
	var c := TileKey.rect(Fixtures.tile_key()).get_center()
	var tri := PackedVector2Array([c, c + Vector2(37.3, 5.1), c + Vector2(11.2, 29.7)])
	var pieces := drape._cut(tri)
	var area := 0.0
	for piece in pieces:
		area += absf(CityBuilder._area2(piece))
	var whole := absf(CityBuilder._area2(tri))
	check(pieces.size() > 10 and absf(area - whole) < 0.01, "a 37 m triangle cut along the grid: %d pieces, %.3f of its %.3f square metres" % [pieces.size(), area, whole])


func test_pavements_and_kerbs_lie_on_the_surface() -> void:
	var land := _hills()
	var d := Fixtures.tile_district()
	var baked := CityBuilder.bake(d, {}, Kerbs.of(d, {}), land, DATUM)
	var heights := [0.0, Kerbs.HEIGHT, Kerbs.HEIGHT + 0.004]  # (a kerb's foot, the pavement's top, its kerb stone)
	var off := 0
	var worst := 0.0
	var over := _over(baked.layers.Pavements, land)
	for h in over:
		var nearest := INF
		for want in heights:
			nearest = minf(nearest, absf(h - want))
		worst = maxf(worst, nearest)
		if nearest > 0.001:
			off += 1
	check(over.size() > 10000 and off == 0, "every corner of the pavements, their sides and their kerb stones is on the surface at its own height (%d corners, worst %.4f m off)" % [over.size(), worst])


func test_the_streets_lie_on_the_surface() -> void:
	var land := _hills()
	var d := Fixtures.tile_district()
	var baked := CityBuilder.bake(d, {}, Kerbs.of(d, {}), land, DATUM)
	var heights := [0.015, 0.03, 0.034, 0.04, Kerbs.HEIGHT + 0.01]  # (paving, carriageway, lane lines, bike lanes and tracks)
	var off := 0
	var over := _over(baked.layers.Streets, land)
	for h in over:
		var nearest := INF
		for want in heights:
			nearest = minf(nearest, absf(h - want))
		if nearest > 0.001:
			off += 1
	check(over.size() > 5000 and off == 0, "and so is every corner of the streets (%d corners, %d off)" % [over.size(), off])
	var under := 0
	var ground: CityBuilder.Buf = baked.layers.Ground
	for v in ground.v:
		if v.y - (land.ground_at(Vector2(v.x, v.z)) - DATUM) <= 0.001:
			under += 1
	check(under == ground.v.size() and baked.hills, "the ground is drawn where the landform has it (%d of %d corners)" % [under, ground.v.size()])


func test_a_building_stands_at_its_floor() -> void:
	var land := _hills()
	var d := Fixtures.tile_district()
	var bd: Dictionary = {}
	for b in d.buildings:  # (an ordinary one: one piece, a flat roof)
		if Landmarks.pieces(int(b.id), MapSites.pts(b.poly)).size() == 1 and not b.has("roof") and Landmarks.pieces(int(b.id), MapSites.pts(b.poly))[0].style.is_empty():
			bd = b
			break
	var pts := MapSites.pts(bd.poly)
	var floor := land.surface_at(pts[0])
	land.pads[int(bd.id)] = floor
	var one := {"bounds": d.bounds, "roads": [], "buildings": [bd]}
	var baked := CityBuilder.bake(one, {}, Kerbs.of(one, {}), land, DATUM)
	var roofs: CityBuilder.Buf = baked.layers.Roofs
	var lowest_roof := INF
	for v in roofs.v:
		lowest_roof = minf(lowest_roof, v.y)
	check(absf(lowest_roof - (floor - DATUM + float(bd.h))) < 0.01, "its flat roof is its height over its floor (%.2f m over the datum, the floor %.2f)" % [lowest_roof, floor - DATUM])
	var walls: CityBuilder.Buf = baked.layers.Walls
	var foot := INF
	for v in walls.v:
		foot = minf(foot, v.y)
	var lo := INF
	for p in pts:
		lo = minf(lo, land.ground_at(p) - DATUM)
	check(lo < floor - DATUM - 0.1 and absf(foot - (lo - 0.3)) < 0.01, "on its slope its walls go down to the ground at its lowest corner, and a little more (%.2f; the ground there %.2f, its floor %.2f)" % [foot, lo, floor - DATUM])
