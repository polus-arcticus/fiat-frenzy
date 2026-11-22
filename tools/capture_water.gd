## Windowed screenshots of a tile's water (OsmWater): from above, on a bridge between its parapets, and at a quay wall looking
## over the river. The tile's water layer must be cached (tools/make_tile.gd fetches it).
##   godot --path . --script tools/capture_water.gd -- <out dir> [key=16/34347/22195]
extends CaptureTool

var key := "16/34347/22195"
var cam: Camera3D


func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	var m: Array = TileKey.middle(key)
	game.landing = TileLanding.new(key, TileSource.district(key), m[0], m[1])


func _run() -> void:
	await _frames(20)
	var d: Dictionary = game.landing.district
	var water: Dictionary = d.get("water", {})
	print("water: %d pieces, %d edges; bridges: %d" % [water.get("pieces", []).size(), water.get("edges", []).size(), d.roads.filter(func(r): return r.get("bridge", false)).size()])
	cam = Camera3D.new()
	cam.far = 2000.0
	game.add_child(cam)
	# 1: from above
	var mid := TileKey.rect(key).get_center()
	_look(Vector3(mid.x + 40, 300, mid.y + 360), Vector3(mid.x, 0, mid.y))
	await _shot("1_above", 6)
	# 2: on a bridge where it's over the water (water both sides of it), looking along it
	var over := {}
	for r in d.roads:
		if not r.get("bridge", false):
			continue
		var pts := MapSites.pts(r.pts)
		for k in pts.size() - 1:
			var dir := (pts[k + 1] - pts[k]).normalized()
			for f in [0.25, 0.5, 0.75]:
				var p := pts[k].lerp(pts[k + 1], f)
				var off := dir.orthogonal() * (float(r.w) * 0.5 + OsmWater.STREET_CUT + 3.0)
				if over.is_empty() and OsmWater.wet(water, p + off) and OsmWater.wet(water, p - off):
					over = {"at": p, "dir": dir, "w": float(r.w)}
	print("a bridge over the water: ", not over.is_empty())
	if not over.is_empty():
		var at: Vector2 = over.at
		var dir: Vector2 = over.dir
		var back := at - dir * 25.0
		_look(Vector3(back.x, 1.7, back.y), Vector3(at.x + dir.x * 30.0, 1.0, at.y + dir.y * 30.0))
		await _shot("2_bridge", 6)
		# 3: the hero walks off the side of the bridge: the parapet stops them
		var side := dir.orthogonal()
		var a := at - dir
		var b := at + dir
		game.player.teleport(Vector3(at.x, 0.2, at.y), atan2(-side.x, -side.y))
		game.player.level_gaze()
		game.player.camera.make_current()
		Input.action_press("move_forward")
		for i in 120:
			await physics_frame
		Input.action_release("move_forward")
		var p: Vector3 = game.player.global_position
		print("walked at the parapet: now %.1f m from the bridge's middle line, in the water: %s" % [
			Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b).distance_to(Vector2(p.x, p.z)), OsmWater.wet(water, Vector2(p.x, p.z))])
		await _shot("3_parapet", 4)
	quit()


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
