## Sim tests: OpenStreetMap to a tile's district in the game (see OsmImport), offline, from the raw extract the Frankfurt map was
## made from.
extends TestCase


func test_a_tile_imports() -> void:
	var d := Fixtures.tile_district()
	check(d.tile == Fixtures.tile_key() and d.buildings.size() > 100 and d.roads.size() > 50, "the tile %s: %d buildings, %d streets" % [d.tile, d.buildings.size(), d.roads.size()])
	var rect := TileKey.rect(d.tile)
	var inside: bool = d.buildings.all(func(b): return rect.has_point(OsmImport._middle(MapSites.pts(b.poly))))
	check(inside, "every building's middle is in the tile, in its region's metres (%s)" % rect)
	check(d.roads.all(func(r): return r.pave.size() == 2 and r.pave[0] > float(r.w) * 0.5), "every street knows how far its pavements run")
	check(d.roads.any(func(r): return r.name == "Kaiserstraße"), "Kaiserstraße is in it")


func test_the_same_answer_gives_the_same_tile() -> void:
	check(JSON.stringify(Fixtures.tile_district()) == JSON.stringify(Fixtures.tile_district()), "imported twice, the same district")


func test_the_storys_station_is_drawn_in_its_parts() -> void:
	var station: Array = Fixtures.district().buildings.filter(func(b): return int(b.id) == 154495112)
	var parts: Array = station[0].get("parts", []) if not station.is_empty() else []
	var vaults := parts.filter(func(p): return p.get("roof", "") == "round")
	check(vaults.size() >= 3 and vaults.all(func(p): return p.h > 0.0 and p.rise > 5.0 and p.poly.size() >= 6), "the station's arched halls came with it, as parts (%d of %d parts round)" % [vaults.size(), parts.size()])
	check(CityBuilder.bake({"bounds": [-700, -100, -200, 450], "buildings": station, "roads": []}).layers.Roofs.v.size() > 500, "and the city draws them")


func test_parts_are_kept_only_when_they_cover_their_building() -> void:
	var ring := func(x0: float, y0: float, x1: float, y1: float) -> Array:
		return [[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]].map(func(p): return {"lat": p[1], "lon": p[0]})
	var way := func(id: int, tags: Dictionary, corners: Array) -> Dictionary:
		return {"type": "way", "id": id, "tags": tags, "geometry": corners}
	var metres := func(lat: float, lon: float) -> Vector2: return Vector2(lon, lat)
	var answer := {"elements": [
		way.call(1, {"building": "yes"}, ring.call(0.0, 0.0, 40.0, 20.0)),
		way.call(2, {"building:part": "yes", "height": "20", "roof:shape": "round", "roof:height": "8"}, ring.call(0.0, 0.0, 40.0, 20.0)),
		way.call(3, {"building": "yes"}, ring.call(100.0, 0.0, 140.0, 20.0)),
		way.call(4, {"building:part": "yes", "height": "20"}, ring.call(100.0, 0.0, 108.0, 20.0))]}
	var made := OsmImport.area(answer, metres)
	var full: Dictionary = made.buildings.filter(func(b): return b.id == 1)[0]
	var slight: Dictionary = made.buildings.filter(func(b): return b.id == 3)[0]
	check(full.get("parts", []).size() == 1 and full.parts[0].roof == "round" and is_equal_approx(full.parts[0].h, 12.0), "a part that covers its building is kept: walls to 12 m, an arch 8 m over them (its mapped height is to the roof's top)")
	check(not slight.has("parts"), "a part over a fifth of its building is not: the outline is drawn")


func test_a_pedestrian_area_is_paving() -> void:
	var ring := [[0.0, 0.0], [30.0, 0.0], [30.0, 20.0], [0.0, 20.0], [0.0, 0.0]].map(func(p): return {"lat": p[1], "lon": p[0]})
	var answer := {"elements": [{"type": "way", "id": 1, "tags": {"highway": "pedestrian", "area": "yes", "surface": "sett"}, "geometry": ring},
		{"type": "way", "id": 2, "tags": {"highway": "pedestrian"}, "geometry": ring}]}
	var made := OsmImport.area(answer, func(lat: float, lon: float) -> Vector2: return Vector2(lon, lat))
	check(made.squares.size() == 1 and made.squares[0].surface == "sett" and made.squares[0].poly.size() == 8, "an area is paved over; a street that only closes on itself is not")
	check(CityBuilder.bake({"bounds": [-10, -10, 50, 40], "buildings": [], "roads": [], "squares": made.squares}).layers.Streets.v.size() > 6, "and the city draws it, jointed")


func test_a_building_on_the_edge_is_one_tiles() -> void:
	var key := Fixtures.tile_key()
	var t := TileKey.parse(key)
	var west := TileKey.key(t.x - 1, t.y)  # (the extract reaches well into the tile to the west)
	var a := Fixtures.tile_district()
	var b := OsmImport.tile(Fixtures.tile_raw(), west)
	var ids := {}
	for x in a.buildings:
		ids[x.id] = true
	var both: int = b.buildings.filter(func(x): return ids.has(x.id)).size()
	check(b.buildings.size() > 0 and both == 0, "two neighbouring tiles share no building (%d in the next one west)" % b.buildings.size())


func test_civic_buildings_are_told_apart() -> void:
	check(OsmImport.civic({"building": "church"}) == "church" and OsmImport.civic({"building": "yes", "amenity": "place_of_worship", "religion": "christian"}) == "church", "a church, by its building or by its worship")
	check(OsmImport.civic({"building": "yes", "amenity": "place_of_worship", "religion": "muslim"}) == "", "a mosque is not a church")
	check(OsmImport.civic({"building": "train_station"}) == "station" and OsmImport.civic({"building": "yes", "railway": "station"}) == "station", "a station")
	check(OsmImport.civic({"building": "yes", "amenity": "fire_station"}) == "fire" and OsmImport.civic({"building": "yes", "amenity": "townhall"}) == "townhall", "a fire station, a town hall")
	check(OsmImport.civic({"building": "yes", "amenity": "police"}) == "police" and OsmImport.civic({"building": "hospital"}) == "hospital", "a police station, a hospital")
	check(OsmImport.civic({"building": "apartments"}) == "" and OsmImport.civic({"building": "yes", "amenity": "brothel"}) == "", "a house is none of them")
	var kinds := {}
	for b in Fixtures.tile_district().buildings:
		if b.has("civic"):
			kinds[b.civic] = true
	check(kinds.has("church"), "the Frankfurt tile has its churches marked (%s)" % [kinds.keys()])
	check(Fixtures.tile_raw().elements.any(func(e): return int(e.id) == 154495112 and OsmImport.civic(e.get("tags", {})) == "station"), "and the Hauptbahnhof, in another tile, is a station")


func test_the_query_asks_for_the_tile() -> void:
	var q := TileSource.query(Fixtures.tile_key())
	check(q.contains("way[\"building\"]") and q.contains("residential") and q.contains("out geom"), "the Overpass query asks for its buildings and streets")
	var dir := "user://test_tiles"
	check(not TileSource.store("16/1/1", "not a map", dir), "an answer that is not a map is not kept")
	check(TileSource.store(Fixtures.tile_key(), JSON.stringify(Fixtures.tile_raw()), dir) and TileSource.cached(Fixtures.tile_key(), dir), "a map is kept in the cache")
	check(TileSource.district(Fixtures.tile_key(), dir).buildings.size() == Fixtures.tile_district().buildings.size(), "and read back as the same tile")
	DirAccess.remove_absolute(TileSource.path(Fixtures.tile_key(), dir))
