## Windowed screenshots of a tile's hills (Terrain): the whole tile from the air at an angle, a street's slope at eye height, and
## the hero where they land. The tile's map and relief must be cached (tools/make_tile.gd, tools/fetch_relief.gd).
##   godot --path . --script tools/capture_hills.gd -- <out dir> [key=16/34347/22195]
extends CaptureTool

var key := "16/34347/22195"
var cam: Camera3D


func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	var m: Array = TileKey.middle(key)
	var d := TileSource.district(key)
	game.landing = TileLanding.new(key, d, m[0], m[1], TileSource.landform(key, d))


func _run() -> void:
	await _frames(20)
	var land := Ground.landform
	print("land: %s, ground %s m above the sea, drawn from %.1f m (the datum); hero y %.2f, ground under the hero %.2f" % [
		"flat" if land.flat else "hills", land.span(), Ground.datum, game.player.global_position.y, Ground.y(game.landing.start)])
	cam = Camera3D.new()
	cam.far = 2500.0
	game.add_child(cam)
	var mid := TileKey.rect(key).get_center()
	var size := TileKey.rect(key).size.x
	var top := land.span().y - Ground.datum  # (the view's metres: above the datum)
	_look(Vector3(mid.x, top + 330.0, mid.y + size * 0.9), Vector3(mid.x, Ground.land(mid), mid.y))
	await _shot("1_aerial", 10)
	_look(Vector3(mid.x - size * 0.9, top + 140.0, mid.y), Vector3(mid.x, Ground.land(mid), mid.y))
	await _shot("2_from_the_west", 10)
	var s: Vector2 = game.landing.start
	var p: Vector3 = game.player.global_position
	_look(p + Vector3(0, 1.6, 0), p + Vector3(-sin(game.landing.start_yaw) * 20.0, 1.6, -cos(game.landing.start_yaw) * 20.0))
	await _shot("3_the_hero_lands", 10)
	_look(Vector3(s.x + 40, Ground.y(s) + 45.0, s.y + 40), Vector3(s.x, Ground.y(s), s.y))
	await _shot("4_the_landing_from_above", 10)
	# the market and its people, close: are they standing on the pavement?
	var market: Vector2 = game.landing.market
	var site: Dictionary = game.landing.site
	var side: Vector2 = (site.along as Vector2) * 14.0 + (site.out as Vector2) * -6.0
	game.world.clock.time = 0.1 * Clock.DAY_SECONDS
	await _frames(30)
	_look(Vector3(market.x + side.x, Ground.y(market) + 2.2, market.y + side.y), Vector3(market.x, Ground.y(market) + 0.8, market.y))
	await _shot("5_the_market", 10)
	quit()


func _look(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
