## Scene suite section: Chat bubbles.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var drone_views := game.get_children().filter(func(c): return c is DroneView)
	# talking: a gift makes someone say something, and the bubble over their head shows it
	var talker: Drone = game.scenario.cast.hot_dog
	var talker_view: DroneView = drone_views.filter(func(v): return v.drone == talker)[0]
	game.advance(3.0)  # past the throttle on money lines
	game.gun.mode = "gift"
	game.gun.apply(talker, 5.0)
	await tree.process_frame
	await tree.process_frame
	check(talker.speech in Lines.for_event(talker, Lines.GIFT) and talker_view._bubble.visible and talker_view._bubble.text == talker.speech, "a gift makes them say a line, and the bubble over their head shows it: \"%s\"" % talker.speech)

	# (back at the market after the trip to Battonnstraße)
	game.player.teleport(Vector3(game.scenario.start.x, 0.1, game.scenario.start.y), game.scenario.start_yaw)
	game.advance(0.2)

