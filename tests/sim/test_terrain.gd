## Sim tests: the lie of the land (Terrain), from Terrarium tiles made here (a tilted plane), so it runs offline.
extends TestCase

const RISE := 0.6  # metres up per pixel eastward in the made tiles


# The Terrarium tiles for a tile's square: each pixel `200 + RISE * its x on the whole zoom-14 grid`, minus the zoom-14 tile's
# own start so the numbers stay small.
func _tiles(frame: MapFrame, rect: Rect2) -> Dictionary:
	var out := {}
	var base := 0
	for t in Terrain.tiles_for(frame, rect):
		if base == 0:
			base = t.x * Terrain.PIXELS
		var img := Image.create(Terrain.PIXELS, Terrain.PIXELS, false, Image.FORMAT_RGB8)
		for y in Terrain.PIXELS:
			for x in Terrain.PIXELS:
				img.set_pixel(x, y, Terrain.encode(200.0 + RISE * float(t.x * Terrain.PIXELS + x - base)))
		out[t] = img.save_png_to_buffer()
	return out


func _metres_per_pixel(key: String) -> float:
	return TileKey.size_m(TileKey.region_of(key)) * float(1 << TileKey.ZOOM) / float(1 << Terrain.ZOOM) / float(Terrain.PIXELS)


func test_a_colour_is_a_height_and_back() -> void:
	for m in [-10.0, 0.0, 95.5, 1234.25, 4000.0]:
		check(absf(Terrain.decode(Terrain.encode(m)) - m) < 0.01, "%.2f m survives its colour" % m)
	var c := Color8(128, 5, 128)  # (the format's own example: 128*256 + 5 + 0.5 - 32768)
	check(is_equal_approx(Terrain.decode(c), 5.5), "R*256 + G + B/256 - 32768 is the format")


func test_a_tile_needs_one_to_four_relief_tiles() -> void:
	var key := Fixtures.tile_key()
	var frame := MapFrame.tile(key)
	var need := Terrain.tiles_for(frame, frame.rect, 60.0)
	check(need.size() >= 1 and need.size() <= 4, "a 390 m tile and its margin sit in %d relief tiles of 1.5 km" % need.size())
	check(Terrain.url(need[0]).begins_with("https://") and Terrain.url(need[0]).ends_with("/%d/%d.png" % [need[0].x, need[0].y]), "each has its address: %s" % Terrain.url(need[0]))


func test_the_ground_climbs_as_the_tiles_do() -> void:
	var key := Fixtures.tile_key()
	var frame := MapFrame.tile(key)
	var rect := frame.rect.grow(60.0)
	var here := frame.rect.get_center()
	var imgs := Terrain.images(_tiles(frame, rect))
	var h := Terrain.sea_level(frame, here, imgs)
	check(h > 150.0 and h < 400.0, "the middle of the tile is %.1f m above the sea, as its pixels say" % h)
	var east := Terrain.sea_level(frame, here + Vector2(100, 0), imgs) - h
	var want := 100.0 / _metres_per_pixel(key) * RISE
	check(absf(east - want) < 0.5, "100 m east is %.1f m up, as the pixels say (%.1f)" % [east, want])
	check(absf(Terrain.sea_level(frame, here + Vector2(0, 100), imgs) - h) < 0.5 and absf(Terrain.sea_level(frame, here - Vector2(100, 0), imgs) - h + want) < 0.5, "level north-south, down to the west")


func test_no_relief_is_no_height() -> void:
	var frame := MapFrame.tile(Fixtures.tile_key())
	check(is_nan(Terrain.sea_level(frame, frame.rect.get_center(), {})), "without tiles there is no height to read")
	check(Terrain.images({Vector2i(1, 1): PackedByteArray([1, 2, 3])}).is_empty(), "and a tile that is not a picture is no tile")
