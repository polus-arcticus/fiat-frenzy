## Scene suite section: A few game days with the real controller loop.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	# run a few game days with the real controller loop
	var t_before := w.clock.time
	game.advance(800.0)
	check(w.clock.time > t_before + 600.0, "time runs: it is now day %d %s" % [w.clock.day() + 1, w.clock.text()])
	var runners: Array = game.scenario.cast.runners
	var delivered := 0
	var fees := 0.0
	for r in runners:
		delivered += r.delivered_total
		fees += r.fees_earned
	check(delivered > 0 and fees > 0.0, "the cart runners have delivered %d units and earned $%.2f in fees" % [delivered, fees])
	check(is_equal_approx(w.total_money(), w.ledger.printed), "money is conserved while the real scene runs")
	var moved := w.drones.filter(func(d): return d.pos.distance_to(game.scenario.start) > 5.0).size()
	check(moved > 0, "people have been walking around")
	print("    sold: %s | player cash flow $%.2f | events: %d" % [w.machines.map(func(m): return "%s %d" % [m.kind, m.sold_total]), w.ledger.player_cash, w.events.size()])
	for ev in w.events.slice(0, 12):
		print("      ", ev)
