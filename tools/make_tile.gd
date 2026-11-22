## Makes a tile from anywhere: fetches its map from the Overpass API into the tile cache (once: see TileSource), imports it,
## puts its atom on the street SiteFinder picks, funds the atom, and runs it in summary to see that it keeps itself going. Prints
## what it made. This is the command the MCP server (step 2 of the agentic plan) will wrap.
##   godot --headless --path . --script tools/make_tile.gd -- lat=50.11 lon=8.67 [days=30] [offline]
##   (or key=16/x/y; `offline` uses only the cache)
extends SceneTree


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame  # (the tree is not up yet during _initialize: the request needs it)
	var lat := _arg("lat", "nan").to_float()
	var lon := _arg("lon", "nan").to_float()
	var key := _arg("key", "")
	if key == "":
		key = TileKey.of(lat, lon)
	else:
		var mid: Array = TileKey.lat_lon(TileKey.rect(key).get_center(), TileKey.region_of(key))
		lat = mid[0]
		lon = mid[1]
	print("tile %s (%.5f, %.5f), %.0f m across; ready: %s" % [key, lat, lon, TileKey.size_m(TileKey.region_of(key)), TileSource.ready(key)])
	for layer in TileSource.BEFORE_LANDING:
		if TileSource.cached(key, TileSource.CACHE, layer):
			continue
		if "offline" in OS.get_cmdline_user_args():
			print("its %s layer is not in the cache, and offline" % layer)
			quit(1)
			return
		print("fetching its %s layer from %s ..." % [layer, TileSource.OVERPASS])
		var fetcher := TileFetchController.new()
		root.add_child(fetcher)
		var started := Time.get_ticks_msec()
		var r: Dictionary = await fetcher.fetch(key, TileSource.CACHE, layer)
		fetcher.queue_free()
		print("  %s in %.1f s%s" % ["fetched" if r.ok else "FAILED", (Time.get_ticks_msec() - started) / 1000.0, "" if r.ok else ": " + r.error])
		if not r.ok:
			quit(1)
			return
	var district := TileSource.district(key)
	var landing := TileLanding.new(key, district, lat, lon)
	var w := landing.build()
	print("map: %d buildings, %d streets (%d bridges), water in %d pieces with %d m of bank" % [district.buildings.size(), district.roads.size(),
		district.roads.filter(func(r): return r.get("bridge", false)).size(), district.get("water", {}).get("pieces", []).size(),
		roundi(district.get("water", {}).get("edges", []).reduce(func(s, e): return s + e.a.distance_to(e.b), 0.0))])
	print("atom: on %s at %s (along %s); the hero lands %.0f m from the market" % [landing.site.get("street", "(an open site)"), landing.site.point, landing.site.along, landing.start.distance_to(landing.market)])
	print("people: %s" % ", ".join(w.drones.map(func(d): return "%s (%s)" % [d.label, w.profession_of(d)])))
	var days := _arg("days", "30").to_int()
	w.begin_play()
	Cluster.fund(w, key)
	var down := 0
	var seen := 0
	for day in days:
		for s in int(Clock.DAY_SECONDS):
			w.tick(1.0)
		for i in range(seen, w.events.size()):
			if "collapsed" in w.events[i]:
				down += 1
			elif "built up" in w.events[i]:
				print("  day %d: %s" % [day + 1, w.events[i]])
		seen = w.events.size()
	var money := 0.0
	for d in w.drones:
		money += d.wallet
	print("%d days, funded once: %d collapses, %d sold, residents' money $%.0f, issued $%.0f" % [days, down, Fixtures.sold(w, key), money, w.ledger.issued])
	quit()
