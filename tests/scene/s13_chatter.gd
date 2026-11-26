## Scene suite section: Chat bubbles.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var drone_views := game.get_children().filter(func(c): return c is DroneView)
	# talking: a gift makes someone say something, and the bubble over their head shows it
	game.advance(3.0)  # past the throttle on money lines
	var talker: Drone = game.scenario.cast.hot_dog
	if talker.unconscious() or talker.care != "":  # (someone down or in the medical tent says nothing: any vendor up and about will do)
		talker = game.world.drones.filter(func(d): return d.kind == "vendor" and not d.unconscious() and d.care == "" and not d.needless)[0]
	var talker_view: DroneView = drone_views.filter(func(v): return v.drone == talker)[0]
	game.gun.mode = "gift"
	game.gun.apply(talker, 5.0)
	await tree.process_frame
	await tree.process_frame
	var said: String = game.world.chatter.of(talker).line
	check(said in Lines.for_event(talker, Lines.GIFT) and talker_view._bubble.visible and talker_view._bubble.text == said, "a gift makes them say a line, and the bubble over their head shows it: \"%s\"%s" % [said, "" if talker.care == "" else " (but they are %s)" % talker.care])

	# (back at the market after the trip out)
	game.player.teleport(Vector3(game.scenario.start.x, 0.1, game.scenario.start.y), game.scenario.start_yaw)
	game.advance(0.2)

