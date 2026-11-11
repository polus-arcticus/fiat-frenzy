## Scene suite section: The debug teleporter rings.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var sage: Drone = game.scenario.cast.sage
	var w: World = game.world
	# the teleporter: walk into the ring by the start and come out by Mr. Nobody, facing him
	var home_ring: Portal = w.portals.all[0]
	check(w.portals.all.size() == 2 and game.get_children().filter(func(c): return c is PortalView).size() == 2, "there are two rings, both drawn")
	game.player.teleport(Vector3(home_ring.pos.x, 0.1, home_ring.pos.y), 0.0)
	game.advance(0.2)
	check(game.player.ground_pos().distance_to(home_ring.twin.exit_point()) < 0.5, "walking into the first ring puts you out of the other")
	check(game.player.ground_pos().distance_to(sage.pos) < 8.0 and w.portals.at(game.player.ground_pos()) == null, "close to Mr. Nobody, and clear of the ring")
	for i in 60:
		await tree.physics_frame
	check(game.player.global_position.y > -0.5 and game.player.is_on_floor(), "and the ground holds you up out there (y %.2f)" % game.player.global_position.y)
	game.player.teleport(Vector3(home_ring.twin.pos.x, 0.1, home_ring.twin.pos.y), 0.0)
	game.advance(0.2)
	check(game.player.ground_pos().distance_to(home_ring.exit_point()) < 0.5, "and the same ring takes you back")
	game.advance(60.0)  # let him settle again

