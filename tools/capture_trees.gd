## Windowed screenshots of a tile's trees (DressingBuilder: each crown one of the Solids), close up among them, once the
## dressing has come in (from the cache, or fetched).
##   godot --path . --script tools/capture_trees.gd -- <out dir> [key=16/34347/22195]
extends CaptureTool

var key := "16/34347/22195"


func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	var m: Array = TileKey.middle(key)
	game.landing = TileLanding.new(key, TileSource.district(key), m[0], m[1])


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while (game.dressing == null or game.dressing.node == null) and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	if game.dressing.node == null:
		print("no dressing came")
		quit()
		return
	var spots: Array[Vector3] = []
	for crowns in game.dressing.node.get_node("Trees").get_children():
		var mm: MultiMesh = crowns.multimesh
		print("  %s: %d" % [crowns.name, mm.instance_count])
		for k in mini(mm.instance_count, 3):
			spots.append(mm.get_instance_transform(k).origin)
	# the middle of the trees nearest the first: stand back from it and look
	var a: Vector3 = spots[0]
	spots.sort_custom(func(p, q): return p.distance_to(a) < q.distance_to(a))
	var mid := Vector3.ZERO
	for p in spots.slice(0, 6):
		mid += p
	mid /= mini(spots.size(), 6)
	var from := Vector2(mid.x + 11.0, mid.z + 7.0)
	_stand(from, Vector2(mid.x, mid.z), 3.0)
	await _shot("1_trees", 20)
	_stand(Vector2(mid.x + 4.0, mid.z + 3.0), Vector2(mid.x, mid.z), 3.4)
	await _shot("2_trees_close", 10)
	quit()
