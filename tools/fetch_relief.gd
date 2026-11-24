## Fetches a tile's relief (the Terrarium elevation PNGs, once: see TileSource) and says how hilly it is: where it is, the
## lowest and highest the ground gets over the tile and its margin, and the steepest slope. With `png=<file>` it also writes the
## terrain as a picture (dark low, light high, stretched to its own span) to look at.
##   godot --headless --path . --script tools/fetch_relief.gd -- key=16/x/y [png=/path/out.png] [offline]
extends SceneTree


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var key := _arg("key", "")
	if not TileKey.is_tile(key):
		print("give key=16/x/y")
		quit(1)
		return
	var mid: Array = TileKey.middle(key)
	var need := TileSource.relief_needed(key)
	print("tile %s at (%.4f, %.4f): %d relief tiles, %d not cached" % [key, mid[0], mid[1], need.size(), TileSource.relief_missing(key).size()])
	if not TileSource.relief_missing(key).is_empty():
		if "offline" in OS.get_cmdline_user_args():
			print("offline: not fetched")
			quit(1)
			return
		for t in TileSource.relief_missing(key):
			print("fetching %s ..." % Terrain.url(t))
		var fetcher := TileFetchController.new()
		root.add_child(fetcher)
		var r: Dictionary = await fetcher.fetch_relief(key)
		fetcher.queue_free()
		if not r.ok:
			print("FAILED: %s" % r.error)
			quit(1)
			return
	var land := TileSource.landform(key, TileSource.district(key))  # (the tile's streets where its map is cached, else the land)
	var mid := land.land_at(TileKey.rect(key).get_center())
	var lo := INF
	var hi := -INF
	for h in land.land:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	var steepest := 0.0
	for j in range(0, land.rows, 2):
		for i in range(0, land.cols, 2):
			steepest = maxf(steepest, land.slope_at(land.point(i, j)))
	print("land %.0f m above the sea at the middle; over %.0f m square it runs %.1f m down to %.1f m up; steepest slope %.2f (%.0f degrees)" % [
		mid, land.rect.size.x, lo - mid, hi - mid, steepest, rad_to_deg(atan(steepest))])
	var png := _arg("png", "")
	if png != "":
		var img := Image.create(land.cols, land.rows, false, Image.FORMAT_RGB8)
		for j in land.rows:
			for i in land.cols:
				var v := inverse_lerp(lo, maxf(hi, lo + 0.1), land.land[j * land.cols + i])
				img.set_pixel(i, j, Color(v, v, v))
		img.save_png(png)
		print("wrote %s" % png)
	quit(0)
