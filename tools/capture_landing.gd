## Windowed screenshots of a game landed on a tile with no story (see TileLanding): the tile round the Bahnhofsviertel, made
## offline from the raw OpenStreetMap extract (as the tests make it). Where the hero sets foot, the market on the street the
## rule picked, the map screen, and the tent city's screen.
##   godot --path . --script tools/capture_landing.gd -- <output dir>
extends CaptureTool


## `key=16/x/y` lands on that tile from the cache (fetch it first with tools/make_tile.gd); otherwise the offline Frankfurt tile.
func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			var key := a.trim_prefix("key=")
			var mid: Array = TileKey.lat_lon(TileKey.rect(key).get_center(), TileKey.region_of(key))
			game.landing = TileLanding.new(key, TileSource.district(key), mid[0], mid[1])
			return
	game.landing = Fixtures.tile_landing()


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var landing: TileLanding = game.landing
	print("tile %s, the market on %s at %s; the hero at %s (%.0f m off), %d buildings" % [landing.key, landing.site.street, landing.market, landing.start, landing.start.distance_to(landing.market), landing.district.buildings.size()])
	print("story pieces: scenario %s, quests %s, tutorial %s" % [game.scenario, game.quest_controller, game.tutorial.get_script().get_global_name()])
	await _shot("1_landed", 60)
	var site: Dictionary = landing.site
	var view: Vector2 = landing.market - (site.out as Vector2) * 9.0 - (site.along as Vector2) * 4.0
	_stand(view, landing.market + (site.along as Vector2) * 4.0, 1.2)
	game.advance(0.5)
	await _shot("2_market", 60)
	game.map_screen.open()
	await _shot("3_map", 30)
	game.map_screen.close()
	var city: Machine = w.machines.filter(func(m): return m.shelter != null)[0]
	_stand(city.pos + city.front * 2.5, city.pos, 1.0)
	game.advance(0.3)
	game.interaction.open(city)
	await _shot("4_tent_city", 30)
	game.interaction.screen.close()
	var medic: Drone = w.drones.filter(func(d): return d.kind == "medic")[0]
	medic.aloof = true
	medic.job = {}
	medic.route = PackedVector2Array()
	var front := medic.pos + Vector2.from_angle(medic.heading) * 2.6
	_stand(front, medic.pos, 1.3)
	await _shot("5_medic", 40)
	quit()
