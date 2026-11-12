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


	# Buildings stop bills: a ray from above lands on a roof, and a bill that comes down inside a building is put in the street.
	var hollow: Dictionary = game.scenario.openings()
	var chosen: PackedVector2Array
	var chosen_height := 0.0
	var best_d := INF
	for bd in game.scenario.district.buildings:
		if hollow.has(int(bd.id)) or float(bd.h) < 10.0:
			continue
		var poly := MapSites.pts(bd.poly)
		var c := Vector2.ZERO
		for p in poly:
			c += p
		c /= poly.size()
		if Geometry2D.is_point_in_polygon(c, poly) and c.distance_to(game.scenario.start) < best_d and Geometry2D.triangulate_polygon(poly).size() >= 3:
			best_d = c.distance_to(game.scenario.start)
			chosen = poly
			chosen_height = float(bd.h)
	var middle := Vector2.ZERO
	for p in chosen:
		middle += p
	middle /= chosen.size()
	var query := PhysicsRayQueryParameters3D.create(Vector3(middle.x, 300.0, middle.y), Vector3(middle.x, 0.5, middle.y), 1)
	var roof_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	check(not roof_hit.is_empty() and roof_hit.position.y > chosen_height - 1.0, "a ray dropped from above a building stops on its roof (%.1f m of %.1f)" % [roof_hit.position.y if not roof_hit.is_empty() else -1.0, chosen_height])
	var printed_before: float = w.ledger.printed
	var dropped: Bill = w.gun.land(w.gun.fire(5.0, "cash"), middle)
	check(not w.nav.unreachable("district", dropped.pos) and dropped.pos.distance_to(middle) > 1.0, "and a bill that comes down inside it is put on open ground (%.0f m away)" % dropped.pos.distance_to(middle))
	w.bills.erase(dropped)  # (it is only for this check: take it, and what it printed, back out)
	w.ledger.printed = printed_before
