## Windowed screenshot of a runner's card (see Hauling): the hero has invested in its cart, it has made a delivery or two, and the
## card shows its trips, its fees, what the cart is worth and the hero's share.
##   godot --path . --script tools/capture_runner.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var runner: Drone = w.drones.filter(func(d): return d.kind == "runner")[0]
	w.gun_owned = true
	w.gun.invest(runner, 10.0)
	for m in w.machines:
		m.working = true
	game.advance(240.0)
	print("runner: %d trips, $%.2f in fees, hero's pocket $%.2f" % [runner.runner.deliveries, runner.runner.fees_earned, w.ledger.player_cash])
	runner.job = {}
	runner.route = PackedVector2Array()
	runner.aloof = true  # (stands still for the picture)
	_stand(runner.pos + Vector2(0, 3.5), runner.pos, 1.0)
	for i in 30:
		game.hud.show_target(runner, w)
		await process_frame
	await _shot("1_runner_card", 1)
	quit()
