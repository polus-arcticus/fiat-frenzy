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


func test_heights_follow_the_frankfurt_rules() -> void:
	var d := Fixtures.tile_district()
	var hs := {}
	for b in Fixtures.district().buildings:
		hs[int(b.id)] = [float(b.h), int(b.levels)]
	var same: int = d.buildings.filter(func(b): return hs.has(b.id) and is_equal_approx(hs[b.id][0], b.h) and hs[b.id][1] == b.levels).size()
	var known: int = d.buildings.filter(func(b): return hs.has(b.id)).size()
	check(known > 100 and same == known, "the heights and storeys are what tools/osm_to_district.py made (%d of %d)" % [same, known])


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


func test_the_query_asks_for_the_tile() -> void:
	var q := TileSource.query(Fixtures.tile_key())
	check(q.contains("way[\"building\"]") and q.contains("residential") and q.contains("out geom"), "the Overpass query asks for its buildings and streets")
	var dir := "user://test_tiles"
	check(not TileSource.store("16/1/1", "not a map", dir), "an answer that is not a map is not kept")
	check(TileSource.store(Fixtures.tile_key(), JSON.stringify(Fixtures.tile_raw()), dir) and TileSource.cached(Fixtures.tile_key(), dir), "a map is kept in the cache")
	check(TileSource.district(Fixtures.tile_key(), dir).buildings.size() == Fixtures.tile_district().buildings.size(), "and read back as the same tile")
	DirAccess.remove_absolute(TileSource.path(Fixtures.tile_key(), dir))
