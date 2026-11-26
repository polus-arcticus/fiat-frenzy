## Sim tests: a district's railways (OsmRail: the tracks and stations from the land layer, cut to the tile, tunnels and viaducts left
## out) and their bed laid on the land (RailBuilder). A made-up Overpass answer stands in for the server.
extends TestCase


func _f(fx: float, fy: float) -> Vector2:
	var r := TileKey.rect(Fixtures.tile_key())
	return r.position + r.size * Vector2(fx, fy)


func _at(fx: float, fy: float) -> Dictionary:
	var ll: Array = TileKey.lat_lon(_f(fx, fy), TileKey.region_of(Fixtures.tile_key()))
	return {"lat": ll[0], "lon": ll[1]}


# A railway across the tile, one in a tunnel, one on a viaduct, a tram line, a disused siding, far off the tile, and two stations
# (one in the tile and one far away).
func _answer() -> Dictionary:
	return {"elements": [
		{"type": "way", "id": 1, "tags": {"railway": "rail"}, "geometry": [_at(-3.0, 0.4), _at(0.5, 0.4), _at(4.0, 0.45)]},
		{"type": "way", "id": 2, "tags": {"railway": "rail", "tunnel": "yes"}, "geometry": [_at(0.0, 0.6), _at(1.0, 0.6)]},
		{"type": "way", "id": 3, "tags": {"railway": "rail", "bridge": "yes", "layer": "1"}, "geometry": [_at(0.0, 0.7), _at(1.0, 0.7)]},
		{"type": "way", "id": 4, "tags": {"railway": "tram"}, "geometry": [_at(0.2, 0.9), _at(0.8, 0.9)]},
		{"type": "way", "id": 5, "tags": {"railway": "rail", "disused": "yes"}, "geometry": [_at(0.0, 0.1), _at(1.0, 0.1)]},
		{"type": "way", "id": 6, "tags": {"railway": "rail"}, "geometry": [_at(9.0, 0.5), _at(10.0, 0.5)]},
		{"type": "node", "id": 7, "tags": {"railway": "station", "name": "Hauptbahnhof"}, "lat": _at(0.5, 0.4).lat, "lon": _at(0.5, 0.4).lon},
		{"type": "node", "id": 8, "tags": {"railway": "halt", "name": "Far Away"}, "lat": _at(9.0, 0.5).lat, "lon": _at(9.0, 0.5).lon},
	]}


func test_the_tracks_are_the_ones_at_ground_level() -> void:
	var rail := OsmRail.tile(_answer(), Fixtures.tile_key())
	var ids := {}
	for t in rail.tracks:
		ids[t.id] = true
	check(ids.has(1) and ids.has(4), "the railway and the tram are in")
	check(not ids.has(2) and not ids.has(3), "the tunnel and the viaduct are not (nothing carries them yet)")
	check(not ids.has(5) and not ids.has(6), "nor the disused line, nor a line far off the tile")
	check(rail.tracks.any(func(t): return t.kind == "tram") and rail.tracks.any(func(t): return t.kind == "rail"), "each with its kind")


func test_a_track_is_cut_to_the_tile_and_a_little_past_it() -> void:
	var rail := OsmRail.tile(_answer(), Fixtures.tile_key())
	var reach := TileKey.rect(Fixtures.tile_key()).grow(OsmRail.REACH)
	var main: PackedVector2Array = rail.tracks.filter(func(t): return t.id == 1)[0].pts
	var inside := 0
	for p in main:
		inside += 1 if reach.has_point(p) else 0
	check(main.size() >= 3 and inside >= main.size() - 2, "it leaves at most the one point at each end beyond the reach (%d of %d)" % [inside, main.size()])
	check(reach.has_point(main[1]) and main[0].x < reach.position.x, "and that point is what carries it to the edge")


func test_stations_in_the_tile_are_kept() -> void:
	var rail := OsmRail.tile(_answer(), Fixtures.tile_key())
	check(rail.stops.size() == 1 and rail.stops[0].name == "Hauptbahnhof" and rail.stops[0].kind == "station", "the one in the tile, by its name")
	check((rail.stops[0].at as Vector2).distance_to(_f(0.5, 0.4)) < 0.5, "where it stands")


func test_the_district_carries_its_rail() -> void:
	var dir := "user://test_rail_tiles"
	TileSource.store(Fixtures.tile_key(), JSON.stringify(Fixtures.tile_raw()), dir)
	TileSource.store(Fixtures.tile_key(), JSON.stringify(_answer()), dir, "land")
	var d := TileSource.district(Fixtures.tile_key(), dir)
	check(d.has("rail") and d.rail.tracks.size() >= 2 and d.rail.stops.size() == 1, "a tile with its land has its rail in its district")
	DirAccess.remove_absolute(TileSource.path(Fixtures.tile_key(), dir))
	DirAccess.remove_absolute(TileSource.path(Fixtures.tile_key(), dir, "land"))


# ---------------------------------------------------------------- grinding the rails

func _line(pieces: Array, kind := "rail") -> Dictionary:
	return {"tracks": pieces.map(func(p): return {"id": 1, "kind": kind, "pts": PackedVector2Array(p), "service": false}), "stops": []}


# A rider on foot of an east-west track (its rails at y -0.72 and 0.72), coming down at x -40.
func _rider(rail: Dictionary) -> World:
	var w := World.new()
	w.add_player(Vector2(-40, 0.72), 0.0)
	w.player.gear.add("skateboard", 1)
	w.skating.kerbs = Kerbs.of({"roads": [], "buildings": [], "rail": rail})
	w.skating.mount()
	w.skating.speed = 8.0
	w.skating.in_air = true
	return w


func _down(height := 0.4, heading := Vector2.RIGHT) -> Dictionary:
	return {"height": height, "heading": heading, "falling": true}


func test_a_track_has_two_rails_to_grind_and_no_kerbs() -> void:
	var k := Kerbs.of({"roads": [], "buildings": [], "rail": _line([[Vector2(-60, 0), Vector2(60, 0)]])})
	check(k.grindable.size() == 2 and k.edges.is_empty(), "two lines for the two rails, and none of them a kerb (kerb stones and street furniture go by `edges`)")
	var apart := absf(k.grindable[0].a.y - k.grindable[1].a.y)
	check(absf(apart - float(OsmRail.KINDS.rail.gauge)) < 0.001 and absf(k.grindable[0].a.y + k.grindable[1].a.y) < 0.001, "a gauge apart, either side of the track")
	check(k.grindable.all(func(e): return e.kind == "rail" and is_equal_approx(e.top, OsmRail.HEAD)), "as high as the rail's head, which is where the steel is drawn")
	var tram := Kerbs.of({"roads": [], "buildings": [], "rail": _line([[Vector2(-60, 0), Vector2(60, 0)]], "tram")})
	check(tram.grindable.size() == 2 and is_equal_approx(tram.grindable[0].top, OsmRail.STREET_HEAD), "a tram's are low: flush in the street")
	check(Kerbs.of({"roads": [], "buildings": []}).grindable.is_empty(), "no rail, nothing")


func test_coming_down_on_a_rail_catches_it() -> void:
	var rail := _line([[Vector2(-60, 0), Vector2(60, 0)]])
	var w := _rider(rail)
	var out := w.skating.step(0.016, _down(), false, Vector2(-40, 0.72))
	check(out.grind and w.skating.grind_kind == "rail" and w.skating.last_trick == "Rail grind", "the board locks onto the rail")
	check(absf(float(out.grind_top) - OsmRail.HEAD) < 0.001 and absf(absf((out.grind_at as Vector2).y) - 0.7175) < 0.01, "up on its head, on its line")
	check(not _rider(rail).skating.step(0.016, _down(), false, Vector2(-40, 0.0)).grind, "not between the rails")
	check(not _rider(rail).skating.step(0.016, _down(1.2), false, Vector2(-40, 0.72)).grind, "not from high above it")
	check(not _rider(rail).skating.step(0.016, _down(0.05), false, Vector2(-40, 0.72)).grind, "not from under its top (it is a rail, not the ground)")
	check(not _rider(rail).skating.step(0.016, _down(0.4, Vector2.DOWN), false, Vector2(-40, 0.72)).grind, "not across it")


func test_a_rail_grind_pays_and_the_money_is_beside_the_track() -> void:
	var w := _rider(_line([[Vector2(-60, 0), Vector2(60, 0)]]))
	w.skating.speed = Skating.TOP_SPEED
	var printed := w.ledger.printed
	w.skating.step(0.016, _down(), false, Vector2(-50, 0.72))
	var out := {"grind": true}
	var steps := 0
	while out.grind and steps < 3000:
		out = w.skating.step(0.016, {}, false, Vector2.ZERO)
		steps += 1
	check(not w.skating.grinding and out.get("ended", false) and w.skating.grind_metres > 10.0, "it slides a good way (%.0f m) and ends by itself" % w.skating.grind_metres)
	check(w.skating.last_trick.begins_with("Rail grind  "), "and says so (%s)" % w.skating.last_trick)
	check(is_equal_approx(w.ledger.printed - printed, float(int(w.skating.grind_metres / Skating.GRIND_EVERY))) and w.bills.size() > 0, "$1 every %.0f m" % Skating.GRIND_EVERY)
	check(w.bills.all(func(b): return absf(b.pos.y) > 0.7), "lying on the ballast beside the track, none between the rails")


func test_a_rail_carries_on_into_the_next_piece_of_track() -> void:
	var w := _rider(_line([[Vector2(-60, 0), Vector2(0, 0)], [Vector2(0, 0), Vector2(60, 0)]]))
	w.skating.speed = Skating.TOP_SPEED
	w.skating.step(0.016, _down(), false, Vector2(-8, 0.72))
	var farthest := -INF
	var out := {"grind": true}
	var steps := 0
	while out.grind and steps < 3000:
		out = w.skating.step(0.016, {}, false, Vector2.ZERO)
		if out.has("grind_at"):
			farthest = maxf(farthest, out.grind_at.x)
		steps += 1
	check(farthest > 2.0, "over the join of two pieces and on (to x %.1f)" % farthest)


func test_a_bed_is_laid_under_the_steel() -> void:
	var rail := OsmRail.tile(_answer(), Fixtures.tile_key())
	var baked := RailBuilder.bake(rail)
	var buf: CityBuilder.Buf = baked.rails
	check(buf.i.size() > 600, "a long track makes a good many triangles (%d)" % [buf.i.size() / 3])
	var heights := {}
	for p in buf.v:
		heights[snappedf(p.y, 0.001)] = true
	check(heights.has(RailBuilder.BED_AT) and heights.has(RailBuilder.SLEEPER_AT) and heights.has(RailBuilder.STEEL_AT), "ballast, sleepers and steel, each at its own height")
	var tram := {"tracks": [{"id": 4, "kind": "tram", "pts": PackedVector2Array([_f(0.2, 0.9), _f(0.4, 0.9)])}], "stops": []}
	var steel := RailBuilder.bake(tram).rails as CityBuilder.Buf
	check(steel.i.size() > 0 and steel.i.size() < 100 and not steel.c.has(RailBuilder.BALLAST) and not steel.c.has(RailBuilder.SLEEPER), "a tram's is two steel lines and no bed")
	check(JSON.stringify(RailBuilder.bake(rail).rails.v) == JSON.stringify(baked.rails.v), "the same rails always give the same mesh")
	check(RailBuilder.bake({}).rails.i.is_empty(), "no rails, no mesh")


func test_on_a_slope_the_bed_lies_on_the_land() -> void:
	var rail := OsmRail.tile(_answer(), Fixtures.tile_key())
	var rect := TileKey.rect(Fixtures.tile_key()).grow(OsmRail.REACH + 20.0)
	var land := Fixtures.tilted(rect, Vector2(0.05, 0.0))  # (5% up to the east)
	var datum := 100.0
	var flat: CityBuilder.Buf = RailBuilder.bake(rail).rails
	var sloped: CityBuilder.Buf = RailBuilder.bake(rail, land, datum).rails
	var lo := INF
	var hi := -INF
	for p in flat.v:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var off := 0
	var rise := 0.0
	for p in sloped.v:
		var above := p.y - (land.surface_at(Vector2(p.x, p.z)) - datum)
		if above < lo - 0.05 or above > hi + 0.05:
			off += 1
		rise = maxf(rise, p.y)
	check(sloped.i.size() >= flat.i.size(), "at least the mesh it has on the flat (%d triangles, %d flat: draped strips are cut finer)" % [sloped.i.size() / 3, flat.i.size() / 3])
	check(off == 0 and rise > 5.0, "every vertex as high above the land under it as the flat mesh is above 0 (%.2f to %.2f m; %d off), up the slope as it goes (to %.1f m)" % [lo, hi, off, rise])


func test_a_frame_of_any_place_gets_its_rails_too() -> void:
	var key := Fixtures.tile_key()
	var r := TileKey.rect(key)
	var frame := MapFrame.tile(key)
	var by_tile := OsmRail.tile(_answer(), key)
	check(JSON.stringify(OsmRail.of(_answer(), frame)) == JSON.stringify(by_tile), "a tile's rails are those of its frame")
	var out: Array = []
	for t in by_tile.tracks:
		for k in range(1, t.pts.size() - 1):  # (each end may be the point past the edge that carries it on: _clip)
			if not frame.rect.grow(OsmRail.REACH + 0.01).has_point(t.pts[k]):
				out.append(t.pts[k])
	check(out.is_empty() and frame.rect == r, "within the frame and a little past it, but for the point each end leaves by (%d inside out)" % out.size())
