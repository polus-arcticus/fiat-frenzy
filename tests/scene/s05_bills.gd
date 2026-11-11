## Scene suite section: Bills are real: they fly, hit people, or land in the street.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var screen: InventoryScreen = game.inventory
	var drone_views := game.get_children().filter(func(c): return c is DroneView)
	# bills are real: they fly, hit people, or land in the street
	var target: Drone = w.drones[5]
	for i in 3:
		await tree.physics_frame
	var tv: DroneView = drone_views[5]
	var above: Vector3 = tv.global_position + Vector3(0, 3.0, 0)
	var wallet0 := target.wallet
	var shot := w.gun.fire(2.0, "gift")
	game.add_child(BillProjectile.new().launch(shot, w, above, Vector3(0, -14, 0), func(_d, _r): pass))
	for i in 20:
		await tree.physics_frame
	check(is_equal_approx(target.wallet, wallet0 + 2.0) and not w.bills.has(shot), "a bill flown into an NPC is delivered: their wallet went up $2")
	var spot := Vector3(game.scenario.start.x + 4.0, 3.0, game.scenario.start.y)
	var miss := w.gun.fire(2.0, "gift")
	game.add_child(BillProjectile.new().launch(miss, w, spot, Vector3(0, -10, 0), func(_d, _r): pass))
	for i in 30:
		await tree.physics_frame
	check(miss.loose and w.bills.has(miss) and miss.pos.distance_to(Vector2(spot.x, spot.z)) < 1.5, "a bill that misses lands in the street as loose cash")
	await tree.process_frame
	check(game.bills_view._piles.size() >= 1, "and shows as a pile of paper on the ground")
	var cash_before_pickup := w.ledger.player_cash
	game.player.teleport(Vector3(miss.pos.x, 0.1, miss.pos.y))
	for i in 3:
		await tree.process_frame
	check(is_equal_approx(w.ledger.player_cash, cash_before_pickup + 2.0) and not w.bills.has(miss), "walking over it picks it up: cash went up $2")
	for i in 2:
		await tree.process_frame
	check(game.bills_view._piles.is_empty(), "and the pile is gone")
	game.player.teleport(Vector3(game.scenario.start.x, 0.1, game.scenario.start.y), game.scenario.start_yaw)
	var printed0 := w.ledger.printed
	var fired: Bill = game.gun.shoot()
	check(game.gun.bill_value == 1.0 and is_equal_approx(w.ledger.printed, printed0 + 1.0) and w.bills.has(fired) and not fired.loose, "firing the gun prints a real $1 bill into the world")
	for i in 340:
		await tree.physics_frame
	check(w.bills.all(func(b): return b.loose), "every bill in the air eventually comes down (%d lying about)" % w.bills.size())
	check(is_equal_approx(w.total_money(), w.ledger.printed), "and no money went missing on the way")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	var mode0: String = game.gun.mode
	game._unhandled_input(wheel)
	var mode1: String = game.gun.mode
	game._unhandled_input(wheel)
	check(mode1 != mode0 and game.gun.mode == mode0, "the scroll wheel changes the gun mode (%s, then back to %s)" % [mode1, game.gun.mode])
	game.player.controls_enabled = false
	game._unhandled_input(wheel)
	check(game.gun.mode == mode0, "but not while a screen is open")
	game.player.controls_enabled = true

