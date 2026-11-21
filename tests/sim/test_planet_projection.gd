## Sim tests: the new-game screen's planet (PlanetProjection, MapTiles, LandingScreen's rules). A pixel and a place go back
## and forth the same in the globe and the flat map over the north pole, and a click lands in the tile TileKey says.
extends TestCase


func _proj(mode: PlanetProjection.Mode, k := 0.0) -> PlanetProjection:
	var p := PlanetProjection.new()
	p.mode = mode
	p.size = Vector2(1180, 900)
	p.k = k if k > 0.0 else p.whole()
	p.look_at(Vector2(50.11, 8.68))
	return p


func test_a_place_and_its_pixel_go_both_ways() -> void:
	for mode in [PlanetProjection.Mode.GLOBE, PlanetProjection.Mode.FLAT]:
		for k in [0.0, 5000.0, 2.0e6]:
			var p := _proj(mode, k)
			var worst := 0.0
			for px in [Vector2(590, 450), Vector2(700, 380), Vector2(500, 520), Vector2(610, 455)]:
				var at := p.lat_lon_at(px)
				if at == Vector2.INF:
					continue
				worst = maxf(worst, p.screen_of(at.x, at.y).distance_to(px))
			# (a place is a 32-bit Vector2: about 0.4 m at Frankfurt, a fraction of a pixel even at street level)
			check(worst < 0.5, "%s at k %.0f: pixel -> place -> pixel within %.3f px" % [["globe", "flat"][mode], k, worst])


func test_the_middle_is_the_place_looked_at() -> void:
	for mode in [PlanetProjection.Mode.GLOBE, PlanetProjection.Mode.FLAT]:
		var p := _proj(mode, 1.0e6)
		var at := p.lat_lon_at(p.size * 0.5)
		check(absf(at.x - 50.11) < 1e-5 and absf(at.y - 8.68) < 1e-5, "%s: the middle pixel is 50.11, 8.68 (%s)" % [["globe", "flat"][mode], at])


func test_the_flat_map_is_over_the_north_pole() -> void:
	var p := _proj(PlanetProjection.Mode.FLAT)
	p.pan = Vector2.ZERO
	var mid := p.lat_lon_at(p.size * 0.5)
	check(absf(mid.x - 90.0) < 1e-6, "the pole in the middle")
	var ring := PlanetProjection.plane_of(0.0, 0.0).length()
	var south := PlanetProjection.plane_of(-90.0, 123.0).length()
	var down := PlanetProjection.plane_of(0.0, 0.0)
	check(is_equal_approx(ring, 0.5) and is_equal_approx(south, 1.0), "the equator a ring halfway out, the south pole the rim")
	check(down.y > 0.0 and absf(down.x) < 1e-9, "0 degrees east points down")
	var a := PlanetProjection.plane_of(40.0, 10.0).distance_to(PlanetProjection.plane_of(30.0, 10.0))
	var b := PlanetProjection.plane_of(-40.0, 10.0).distance_to(PlanetProjection.plane_of(-50.0, 10.0))
	check(is_equal_approx(a, b), "equidistant: 10 degrees of latitude is as long anywhere along a meridian")
	check(p.lat_lon_at(p.size * 0.5 + Vector2(p.k * PI * 1.01, 0)) == Vector2.INF, "past the rim is off the map")


func test_the_globe_hides_its_far_side() -> void:
	var p := _proj(PlanetProjection.Mode.GLOBE)
	check(p.screen_of(-50.11, 8.68 + 180.0) == Vector2.INF, "the other side of the Earth is out of sight")
	check(p.lat_lon_at(Vector2(0, 0)) == Vector2.INF, "a corner of the view is space")


func test_dragging_and_zooming_keep_hold_of_the_place() -> void:
	for mode in [PlanetProjection.Mode.GLOBE, PlanetProjection.Mode.FLAT]:
		var p := _proj(mode, 40000.0)
		var px := Vector2(700, 300)
		var at := p.lat_lon_at(px)
		p.zoom_at(px, 1.2)
		var moved := p.screen_of(at.x, at.y).distance_to(px)
		check(moved < 0.5, "%s: zooming keeps the place under the pointer (%.2f px off)" % [["globe", "flat"][mode], moved])
		at = p.lat_lon_at(px)
		p.drag(Vector2(30, -20))
		moved = p.screen_of(at.x, at.y).distance_to(px + Vector2(30, -20))
		check(moved < 1.0, "%s: dragging moves the planet with the pointer (%.2f px off)" % [["globe", "flat"][mode], moved])


func test_toggling_keeps_the_place_and_from_afar_shows_the_whole() -> void:
	var p := _proj(PlanetProjection.Mode.GLOBE, 1.0e6)
	p.toggle()
	check(p.mode == PlanetProjection.Mode.FLAT and p.middle().distance_to(Vector2(50.11, 8.68)) < 1e-6 and p.k == 1.0e6, "close in, the same place at the same scale")
	var q := _proj(PlanetProjection.Mode.GLOBE)
	q.toggle()
	check(q.pan == Vector2.ZERO and is_equal_approx(q.k, q.whole()), "from the whole globe to the whole disc")


func test_a_click_lands_in_the_tile_tilekey_names() -> void:
	var p := _proj(PlanetProjection.Mode.GLOBE, 2.0e6)
	var key := TileKey.of(50.11, 8.68)
	var m: Array = TileKey.middle(key)
	var at := p.lat_lon_at(p.screen_of(m[0], m[1]))
	check(TileKey.of(at.x, at.y) == key, "clicking a tile's middle chooses that tile (%s)" % key)
	var z := p.detail_zoom()
	check(p.tile_px(z) >= PlanetProjection.DETAIL_PX and p.tile_px(z + 1) < PlanetProjection.DETAIL_PX,
		"close in (a game tile %.0f px), the pictures are zoom %d, each %.0f px" % [p.tile_px(TileKey.ZOOM), z, p.tile_px(z)])
	check(_proj(PlanetProjection.Mode.GLOBE).detail_zoom() <= MapTiles.ATLAS_ZOOM, "the whole globe needs no more than the atlas")


func test_typed_places() -> void:
	check(LandingScreen.parse_lat_lon("50.1109, 8.6821") == Vector2(50.1109, 8.6821), "\"lat, lon\"")
	check(LandingScreen.parse_lat_lon(" -33.86 151.21 ") == Vector2(-33.86, 151.21), "\"lat lon\"")
	check(LandingScreen.parse_lat_lon("Frankfurt") == Vector2.INF and LandingScreen.parse_lat_lon("95, 8") == Vector2.INF, "not a place, or off the map: nothing")


func test_map_tiles() -> void:
	check(MapTiles.url(3, 4, 2) == "https://tile.openstreetmap.org/3/4/2.png", "the tile server's address")
	var a := MapTiles.anchor(1, 1, 1)
	check(is_equal_approx(a.x, 0.0) and is_equal_approx(a.y, 0.0), "zoom 1's south-east tile starts at 0 east on the equator")
	check(MapTiles.patch_origin(3, 7.5, 0.2) == Vector2i(0, 0), "a patch the size of a small zoom is the whole map")
	var o := MapTiles.patch_origin(16, 34348.5, 22194.5)
	check(o == Vector2i(34344, 22190), "a patch is laid round the middle tile")
	var dir := "user://test_tiles_mapped"
	DirAccess.make_dir_recursive_absolute(dir)
	FileAccess.open(dir.path_join("16_34347_22195.osm.json"), FileAccess.WRITE).store_string("{}")
	var listed := TileSource.mapped(dir)
	check(listed.size() == 1 and listed[0] == "16/34347/22195", "the tiles landed in on this machine are listed")
	DirAccess.remove_absolute(dir.path_join("16_34347_22195.osm.json"))
	DirAccess.remove_absolute(dir)
