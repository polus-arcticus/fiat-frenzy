## Scene suite section: The gun in gift mode on the vendor.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var hot: Drone = game.scenario.cast.hot_dog
	# use the gun on the vendor, in gift mode
	var before := hot.wallet
	game.gun.apply(hot, 60.0)
	check(hot.wallet == before + 60.0 and w.ledger.printed >= 60.0, "a gift lands in the vendor's wallet")
	for i in 10:
		await tree.physics_frame
	for i in 40:
		w.tick(0.5)
	check(w.machine_of(hot).working, "and with the money he repairs his stand")
	var baker: Drone = game.scenario.cast.bakery
	game.gun.apply(baker, 60.0)
	for i in 40:
		w.tick(0.5)
	check(w.machine_of(baker).working, "the baker too")
	check(w.machine_of(hot).level == 2 and w.machine_of(baker).level == 2 and hot.growth.level == 2, "the $60 given to each filled the green bar: both stands levelled up to 2")
	check(w.machine_of(hot).rate_per_min == 7.5 and w.machine_of(baker).capacity() == 60, "and expanded: 7.5 a minute for the hot dogs, a 60-loaf shelf (6 slots) for the bakery")
	for i in 3:
		await tree.process_frame
	var hot_view: DroneView = game.get_children().filter(func(c): return c is DroneView and c.drone == hot)[0]
	var hot_stand_view: MachineView = game.get_children().filter(func(c): return c is MachineView and c.machine == w.machine_of(hot))[0]
	check(hot_view._last_level == 2, "the vendor's view noticed and celebrated (LEVEL UP floats over their head)")
	check(hot_stand_view._size_for(2) > hot_stand_view._size_for(1) and hot_stand_view._grown >= 1.0, "and the stall is growing: %.2f times its first size" % hot_stand_view._size_for(2))
	check(hot_view._caption().contains("Lv 2"), "the name over their head says Lv 2")
	for i in 3:
		await tree.physics_frame
	check(game.tutorial.index >= 3, "the tutorial moved on to the customers (step %d)" % (game.tutorial.index + 1))

