## Scene suite section: the skateboard in the real game: get on with B, roll, ollie and kickflip.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var p: PlayerController = game.player
	var sc: SkateController = game.skate_controller
	# on the road by the start, heading along the street (a board rolled at a kerb stops dead: see s23_kerbs)
	var e: Dictionary = {}
	for i in game.kerbs.edges_near(game.scenario.start, 40.0):
		var c: Dictionary = game.kerbs.edges[i]
		if e.is_empty() or c.a.distance_to(c.b) > e.a.distance_to(e.b):
			e = c
	var along: Vector2 = (e.b - e.a).normalized()
	var on_road: Vector2 = e.a + along * 1.0 - (e.side as Vector2) * 2.0
	p.teleport(Vector3(on_road.x, 0.1, on_road.y), atan2(-along.x, -along.y))
	for need in Drone.NEEDS:
		w.player.bars[need] = 1.0
	sc.toggle()
	check(not w.skating.mounted and not p.skating, "without a board in the loadout, B does nothing")
	w.player.gear.add("skateboard", 1)
	sc.toggle()
	for i in 4:
		await tree.physics_frame
	check(w.skating.mounted and p.skating and p.third_person and sc._board.visible and not game.gun.visible, "B gets on: third person, the board shows and the gun is put away")
	# roll forward
	var start := p.ground_pos()
	Input.action_press("move_forward")
	for i in 90:
		await tree.physics_frame
	Input.action_release("move_forward")
	check(p.ground_pos().distance_to(start) > 6.0 and w.skating.speed > 4.0, "W rolls the board along (%.1f m, %.1f m/s)" % [p.ground_pos().distance_to(start), w.skating.speed])
	# hold space and let go: an ollie
	var floor_y := p.global_position.y
	Input.action_press("jump")
	for i in 12:
		await tree.physics_frame
	check(w.skating.charge > 0.2 and p.is_on_floor(), "holding Space winds up the ollie, still on the ground")
	Input.action_release("jump")
	var peak := floor_y
	var up := false
	for i in 20:
		await tree.physics_frame
		peak = maxf(peak, p.global_position.y)
		up = up or not p.is_on_floor()
	check(up and peak > floor_y + 0.4, "letting go is an ollie: the board leaves the ground (%.2f m up)" % (peak - floor_y))
	# tap again in the air: a kickflip, its cash strewn on the ground
	var printed := w.ledger.printed - w.ledger.issued  # (what the gun and the board print: the deposit on bottles goes on meanwhile)
	var bills_before := w.bills.size()
	Input.action_press("jump")
	await tree.physics_frame
	Input.action_release("jump")
	await tree.physics_frame
	check(w.skating.kickflips == 1 and is_equal_approx(w.ledger.printed - w.ledger.issued - printed, Skating.KICKFLIP_CASH) and w.bills.size() > bills_before, "tapping Space in the air is a kickflip that strews $%d on the ground" % int(Skating.KICKFLIP_CASH))
	for i in 80:
		await tree.physics_frame
	check(p.is_on_floor() and not w.skating.in_air, "and it comes back down")
	# getting off
	sc.toggle()
	for i in 4:
		await tree.physics_frame
	check(not w.skating.mounted and not p.skating and not sc._board.visible and game.gun.visible, "B again gets off: the gun is back")
