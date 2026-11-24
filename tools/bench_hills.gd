## Headless benchmark: what the hills cost the sim. A tile's town (TileLanding) with CROWD more drifters walking its streets, run
## in full detail for a game hour on flat land and on the tile's own hills (its cached relief); prints the wall time of each and
## how far the walkers got. Then the slope query a walker makes every tick, timed on its own.
##   godot --headless --path . --script tools/bench_hills.gd -- [key=16/10482/25324] [crowd=200] [minutes=60]
extends SceneTree


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.substr(name.length() + 1)
	return fallback


func _initialize() -> void:
	var key := _arg("key", "16/10482/25324")
	var crowd := _arg("crowd", "200").to_int()
	var minutes := _arg("minutes", "60").to_int()
	var district := TileSource.district(key)
	var land := TileSource.landform(key, district)
	var m: Array = TileKey.middle(key)
	for hills in [false, true]:
		seed(7)
		var landing := TileLanding.new(key, district, m[0], m[1], land if hills else Landform.new())
		var w := landing.build()
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var rect := TileKey.rect(key).grow(-40.0)
		for i in crowd:  # (spread over the tile, hungry and with money: they walk to the market's stalls)
			var d := w.add_drifter(Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y)), 20.0)
			d.bars = {"hunger": 0.3, "thirst": 0.3, "warmth": 1.0}
		w.begin_play()
		var spent := 0.0
		var walked := 0.0
		for s in minutes * 60 * 10:
			var before := PackedVector2Array()
			for d in w.drones:
				before.append(d.pos)
			var t0 := Time.get_ticks_usec()
			w.tick(0.1)
			spent += (Time.get_ticks_usec() - t0) / 1e6
			for k in mini(before.size(), w.drones.size()):
				walked += (w.drones[k].pos as Vector2).distance_to(before[k])
		print("%s: %d drones, %d game minutes in %.2f s of wall time (%.1f ms a game second); %.0f m walked, all told" % [
			"hills" if hills else "flat ", w.drones.size(), minutes, spent, spent * 1000.0 / (minutes * 60), walked])
	# the walker's slope query, alone
	var n := 100000
	var p0 := TileKey.rect(key).get_center()
	var t1 := Time.get_ticks_usec()
	var s1 := 0.0
	for i in n:
		s1 += land.grade(p0 + Vector2(i % 97, i % 89), Vector2.RIGHT)
	var full := (Time.get_ticks_usec() - t1) / float(n)
	t1 = Time.get_ticks_usec()
	var s2 := 0.0
	for i in n:
		s2 += land.walk_grade(p0 + Vector2(i % 97, i % 89), Vector2.RIGHT) if land.has_method("walk_grade") else 0.0
	var fast := (Time.get_ticks_usec() - t1) / float(n)
	t1 = Time.get_ticks_usec()
	var s3 := 0.0
	for i in n:
		s3 += land.height_at(p0 + Vector2(i % 197, i % 189))
	var height := (Time.get_ticks_usec() - t1) / float(n)
	t1 = Time.get_ticks_usec()
	var s4 := 0.0
	for i in n:
		s4 += land.street_at(p0 + Vector2(i % 197, i % 189))
	var street := (Time.get_ticks_usec() - t1) / float(n)
	print("queries: Landform.grade %.2f us, walk_grade %.2f us (walkers, every tick), height_at %.2f us (views, every frame), street_at %.2f us (its full search)" % [full, fast, height, street])
	quit()
