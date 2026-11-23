## Windowed screenshots of a tile's bins where the map has them (TileLanding: SiteFinder.bins): each map bin with what has
## gathered in front of it, and the atom's own station for the kinds it has none of near the market. The tile's land must be
## cached at its current version (TileSource.VERSIONS).
##   godot --path . --script tools/capture_map_bins.gd -- <out dir> [key=16/34347/22195]
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
	var w: World = game.world
	w.clock.time = 0.3 * Clock.DAY_SECONDS  # (by day)
	cam = Camera3D.new()
	cam.far = 1500.0
	game.add_child(cam)
	print("from the map: %s" % [game.landing.bins.keys()])
	var shown := {}
	for b in w.bins.filter(func(x): return x.zone == key):
		var name := "%s_%s" % [b.kind, "map" if b.source == "map" else "atom"]
		if shown.has(name):
			continue
		shown[name] = true
		var side := Vector2(-b.front.y, b.front.x)
		var from: Vector2 = b.pos + b.front * 6.0 + side * 3.0
		_look(Vector3(from.x, 2.6, from.y), Vector3(b.pos.x, 0.6, b.pos.y))
		await _shot(name, 10)
	quit()


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
