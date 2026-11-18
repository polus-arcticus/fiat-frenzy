## Windowed screenshots of the first market's four stands: as they are at tier 0 (repaired), and after each owner has built
## theirs up to tier 1 (the hero gives each owner the money, and the next dawn they build: see Trades).
##   godot --path . --script tools/capture_trades.gd -- <output dir>
extends CaptureTool


## Stands the hero in the street in front of the stands, looking at them.
func _look(stands: Array) -> void:
	var mid := Vector2.ZERO
	for m in stands:
		mid += m.pos / stands.size()
	var spot: Vector2 = mid + (stands[0].front as Vector2) * 9.0
	_stand(spot, mid)
	game.advance(0.3)


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var cast: Dictionary = game.scenario.cast
	var stands: Array = ["hot_dog", "bakery", "lemonade", "tent"].map(func(k): return w.machine_of(cast[k]))
	for m in stands:
		w.gun.gift(w.drone(m.owner), m.repair_cost + Drone.RESERVE + 5.0)
	game.advance(30.0)  # (they walk round and repair)
	_look(stands)
	await _shot("1_tier0", 120)  # (real frames: a stand that was repaired takes a second to stand up)
	for m in stands:
		var up := Catalog.next_tier(m.kind)
		w.gun.gift(w.drone(m.owner), Catalog.machine(up).build + Trades.float_for(up) + 40.0)  # (and a little to live on till dawn)
	var day := w.clock.day()
	while w.clock.day() == day or w.clock.fraction() < 0.25:  # (to the next dawn, and on to the late morning: light to see by)
		game.advance(5.0)
		w.player.bars = {"hunger": 1.0, "thirst": 1.0, "warmth": 1.0}
	print("now: %s" % [stands.map(func(m): return m.kind)])
	_look(stands)
	await _shot("2_tier1", 120)
	quit()
