## Windowed screenshots of a park on a tile: the hero puts a camp kit down in it (Placing, Camp.found), the camp with its fire,
## and the park at night. The tile's land must be cached (tools/make_tile.gd).
##   godot --path . --script tools/capture_park.gd -- <out dir> [key=16/34347/22195]
extends CaptureTool

var key := "16/34347/22195"


func _configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	var m: Array = TileKey.middle(key)
	game.landing = TileLanding.new(key, TileSource.district(key), m[0], m[1])


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	print("parks: %d; camp at landing: %s" % [w.parks.size(), game.landing.camp])
	if w.parks.is_empty():
		quit()
		return
	# the biggest park: stand in it, a few metres from its middle
	var park: PackedVector2Array = w.parks[0]
	for p in w.parks:
		if p.size() > park.size():
			park = p
	var mid := Vector2.ZERO
	for p in park:
		mid += p
	mid /= park.size()
	var spot := mid
	for k in 40:  # (a spot in the park clear to put a camp: walk out from its middle till one fits)
		var at := mid + Vector2.from_angle(k * 0.7) * (2.0 + k)
		w.player.pos = at + Vector2(4.5, 0)
		if w.in_park(at) and w.placing.why_not("camp_kit", at) in ["", "You don't have one."]:
			spot = at
			break
	w.player.make_needless()
	w.player.carry.add("camp_kit", 1)
	_stand(spot + Vector2(5.0, 3.0), spot)
	await _frames(5)
	var r: Dictionary = w.placing.place("camp_kit", spot, (Vector2(5.0, 3.0)).normalized())
	print(r.text)
	game.player.set_third_person(true)
	await _shot("1_camp_in_park", 30)
	_stand(spot + Vector2(-7.0, 6.0), spot)
	await _shot("2_camp_by_its_fire", 10)
	w.clock.time = 0.62 * Clock.DAY_SECONDS  # night
	await _frames(30)
	print("cold spans now: %s (night in a park)" % w.player.cold_spans)
	await _shot("3_park_at_night", 10)
	quit()
