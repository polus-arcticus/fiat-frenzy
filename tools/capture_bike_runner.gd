## Windowed screenshots of a runner before and after trading up to the pedal bike with a trailer: pushing the cart, riding the
## bike from the side with a load, and the card that says what they haul with.
##   godot --path . --script tools/capture_bike_runner.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	game.gun.set_enabled(false)
	var w: World = game.world
	w.passersby.gates.clear()
	w.player.make_needless()
	Cluster.fund(w, Zones.HOME)
	game.sim_paused = true
	var runner: Drone = w.zones.runners_in(Zones.HOME)[0]
	await _look(runner, "1_with_the_cart")
	w.levels.give(runner, 100.0)
	w.trades.trade_up(runner)
	runner.runner.cart.add("leftovers", 25)
	game._views_for_arrivals()
	await _frames(60)
	var was := runner.pos
	runner.pos = game.scenario.offset_on_street(game.scenario.start, 6.0, -8.0)  # (out in the open, to be seen)
	await _frames(60)
	await _look(runner, "2_on_the_bike")
	runner.pos = was
	await _frames(30)
	game.sim_paused = false
	await create_timer(6.0).timeout
	game.sim_paused = true
	await _look(runner, "3_out_on_a_trip")
	print("bins out on the round: ", w.bins.filter(func(b): return b.far > 0.0).size(), " | ", w.events.back())
	quit()


## Stands beside the runner, a few metres off, and takes the picture.
func _look(d: Drone, called: String) -> void:
	var ahead := Vector2.from_angle(d.heading)
	var side := ahead.orthogonal()
	_stand(d.pos + side * 4.5 + ahead * 0.8, d.pos - ahead * 0.5, 1.0)
	await _shot(called, 60)
