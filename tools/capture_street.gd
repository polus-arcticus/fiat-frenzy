## Windowed screenshots of a tile's street detail: furniture (StreetThings) by day and by night (the lamps lit), the roofs
## and colours the map gives (OsmImport._looks) from above. The tile's land must be cached (tools/make_tile.gd).
##   godot --path . --script tools/capture_street.gd -- <out dir> [key=16/34347/22195]
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
	var things := StreetThings.of(game.landing.district, game.kerbs, key)
	cam = Camera3D.new()
	cam.far = 1500.0
	game.add_child(cam)
	for want in ["tram_stop", "bus_stop", "traffic_light", "bike_stand"]:
		var t: Array = things.things.filter(func(x): return x.kind == want)
		if t.is_empty():
			continue
		var at: Vector2 = t[0].at
		var facing := Vector2(-sin(float(t[0].yaw)), -cos(float(t[0].yaw)))  # (toward the road)
		var from := at + facing * 9.0 + facing.orthogonal() * 6.0
		_look(Vector3(from.x, 1.7, from.y), Vector3(at.x, 1.2, at.y))
		await _shot("1_%s_day" % want, 10)
		game.world.clock.time = 0.65 * Clock.DAY_SECONDS
		await _frames(20)
		_look(Vector3(from.x, 1.7, from.y), Vector3(at.x, 1.2, at.y))
		await _shot("2_%s_night" % want, 10)
		game.world.clock.time = 0.15 * Clock.DAY_SECONDS
		await _frames(10)
		break
	# the roofs and colours, from above
	var roofed: Array = game.landing.district.buildings.filter(func(b): return b.has("roof"))
	if not roofed.is_empty():
		var pts := MapSites.pts(roofed[0].poly)
		var c := Vector2.ZERO
		for p in pts:
			c += p
		c /= pts.size()
		_look(Vector3(c.x + 45, 55, c.y + 60), Vector3(c.x, 10, c.y))
		await _shot("3_roofs", 10)
	quit()


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
