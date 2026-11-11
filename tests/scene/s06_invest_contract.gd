## Scene suite section: Invest mode: hold to charge, release to spit a contract.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	# invest mode: hold to charge, release to spit a contract, which is never left on the ground
	game.gun.cycle_mode(1)
	check(game.gun.mode == "invest" and game.gun.rig.rolling(), "switching mode rolls the gun over")
	await tree.create_timer(0.6).timeout  # real time: the roll is a short animation
	check(not game.gun.rig.rolling() and game.gun.rig.mode == "invest", "and the roll finishes")
	game.player.teleport(Vector3(game.scenario.start.x, 0.1, game.scenario.start.y), game.scenario.start_yaw)
	game.player.look_toward(Vector3(game.scenario.start.x, 40.0, game.scenario.start.y) + Vector3(0, 0, 0))  # up at the sky: it will miss
	var printed1 := w.ledger.printed
	var bills1 := w.bills.size()
	game.gun.step(true, 0.35)
	var half_charge: float = game.gun.charge
	check(is_equal_approx(half_charge, 0.25) and game.gun.rig.charge == half_charge, "holding the trigger charges: %.2f after a quarter of a second" % half_charge)
	game.hud.show_charge(game.gun.charge, game.gun.contract_value(game.gun.charge))
	check(game.hud.crosshair.label.text.begins_with("$"), "the ring shows what the contract would be worth (%s)" % game.hud.crosshair.label.text)
	game.gun.step(true, 5.0)
	check(game.gun.charge == 1.0 and game.gun.contract_value(1.0) == GunController.CONTRACT_MAX, "a full charge is worth $%d" % GunController.CONTRACT_MAX)
	game.gun.step(false, 0.016)
	var in_flight := game.get_children().filter(func(c): return c is ContractProjectile)
	check(in_flight.size() == 1 and game.gun.charge == 0.0 and is_equal_approx(w.ledger.printed, printed1), "letting go spits a contract and nothing is printed yet")
	for i in 400:
		await tree.physics_frame
	check(game.get_children().filter(func(c): return c is ContractProjectile).is_empty() and w.bills.size() == bills1 and is_equal_approx(w.ledger.printed, printed1), "a contract that misses is void: nothing left on the ground, nothing printed")
	game.gun.step(true, 0.1)
	game.gun.step(false, 0.016)
	check(game.get_children().filter(func(c): return c is ContractProjectile).is_empty() and game.gun.charge == 0.0, "a trigger let go too early just jams")
	game.gun.cycle_mode(1)  # and back to gift
	await tree.create_timer(0.5).timeout
	check(game.gun.mode == "gift", "the wheel switches back to gift")

