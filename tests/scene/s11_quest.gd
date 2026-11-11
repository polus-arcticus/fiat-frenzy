## Scene suite section: The letter: the banker, the bus, the traffic jam.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var guard := 0
	var w: World = game.world
	# the letter: stands running and a fed banker, who asks (Q), and the bus that gets stuck outside Mr. Nobody's house
	var banker := w.add_drifter(game.scenario.start + Vector2(3, 3), 5.0)
	banker.look = "banker"
	banker.label = "Banker"
	game.add_drone_view(banker)
	for mach in w.machines:
		mach.working = true
	banker.bars.hunger = 0.2
	game.advance(0.2)
	banker.bars.hunger = 1.0
	game.advance(0.5)
	await tree.process_frame
	await tree.process_frame
	check(w.quests.state.get(QuestBook.LETTER, "") == "offered" and game.hud._objective.text.contains("press Q"), "the banker is fed and the stands run: he has a favour to ask, and the objective line says so")
	game.interaction.talk_requested.emit(banker)
	check(game.dialogue.visible and game.dialogue.mode == "read" and not game.player.controls_enabled and game.dialogue.speaker == "Banker with a letter", "Q at him opens his request, and takes the controls")
	guard = 0
	while game.dialogue.visible and guard < 10:
		game.dialogue.advance()
		guard += 1
	check(not game.dialogue.visible and game.player.controls_enabled and w.quests.active() == QuestBook.LETTER and w.player.carry.count("letter") == 1, "reading it through accepts the quest, gives the letter and gives the controls back")
	check(not game.quest_controller.can_board(), "you can't board the bus from over here")
	var stop: Vector2 = game.scenario.bus_stop.pos
	game.player.teleport(Vector3(stop.x, 0.1, stop.y + 4.0), 0.0)
	game.advance(0.2)
	await tree.process_frame
	await tree.process_frame
	check(game.quest_controller.can_board() and game.hud._objective.text.contains("bus"), "at the bus you can board")
	game.quest_controller.fast = true
	await game.quest_controller.ride()
	var jam: Dictionary = game.scenario.jam
	check(Vector2(game.bus.kerb_point().x, game.bus.kerb_point().z).distance_to(game.player.ground_pos()) < 1.0 and w.quests.done("rode_bus") and game.player.controls_enabled and not game.sim_paused and game.fade.alpha() == 0.0, "the ride ends on Battonnstraße, and you are free to move")
	check(game.bus.position.is_equal_approx(Vector3(jam.bus.pos.x, 0.0, jam.bus.pos.y)) and game.get_tree().get_nodes_in_group("stuck_cars").size() == jam.cars.size(), "the bus is in the road with the traffic jam around it")
	check(w.bus.state == Bus.State.ARRIVED and not w.bus.aboard and not game.player.is_seated() and not game.player.scripted, "the bus has stopped, the hero is off it and standing on their own feet again")
	check(not game.bus.door_open, "and the door has closed behind them")
	check(not game.quest_controller.can_board(), "and the bus doesn't take you again, yet")

	# Mr. Nobody has been met: say farewell, and the traffic clears and the bus is ready to go on.
	w.sage.tell(Stories.FIRST)
	check(not game.quest_controller.can_board() and not w.quests.done("jam_cleared"), "while the jam holds, the bus stays where it is")
	check(w.quests.farewell_to_sage(), "saying farewell to Mr. Nobody lets the traffic go")
	for i in 3:
		await tree.process_frame
	check(game.get_tree().get_nodes_in_group("stuck_cars").is_empty(), "and the stuck cars are gone from the road")
	check(game.hud._objective.text.contains("bus is waiting") or w.quests.objective().text.contains("bus is waiting"), "the objective says the bus is waiting")
	var kerb: Vector3 = game.bus.kerb_point()
	game.player.teleport(Vector3(kerb.x, 0.1, kerb.z), 0.0)
	game.advance(0.2)
	for need in Drone.NEEDS:
		w.player.bars[need] = 1.0  # (a long ride in the test's fast time, and the hero is not looking after themselves)
	check(game.quest_controller.can_board(), "back at the bus you can board it again")
	await game.quest_controller.ride_on()
	var gate: Dictionary = game.scenario.ecb_stop
	check(w.quests.done("rode_on") and w.bus.state == Bus.State.ARRIVED and w.bus.pos.distance_to(gate.bus) < 0.5 and not w.bus.aboard, "it drives on to the European Central Bank and stops at the gate")
	check(game.player.controls_enabled and not game.player.is_seated() and not game.sim_paused and not game.quest_controller.can_board(), "the hero is out and free, and the bus does not take them again")


	# The last leg: the doorman at the European Central Bank, a long way east of Mr. Nobody's house.
	var doorman: Drone = w.ecb_doorman
	check(doorman != null and doorman.pos.x > game.scenario.sage_house.door.x + 500.0, "the European Central Bank has a doorman, well east of Battonnstraße")
	w.sage.tell(Stories.FIRST)
	await game.get_tree().process_frame
	var toward: Vector2 = (doorman.face_to - doorman.pos).normalized()  # the way he faces: from the street
	game.player.teleport(Vector3(doorman.pos.x + toward.x * 2.0, 0.1, doorman.pos.y + toward.y * 2.0), 0.0)
	w.player.pos = game.player.ground_pos()
	check(w.quests.can_deliver(), "with the letter in the bag and the sage met, the doorman can take it")
	game.interaction.talk_requested.emit(doorman)
	check(game.dialogue.visible and game.dialogue.speaker == "ECB doorman" and not game.player.controls_enabled, "Q at him opens his reply")
	guard = 0
	while game.dialogue.visible and guard < 10:
		game.dialogue.advance()
		guard += 1
	check(w.quests.state[QuestBook.LETTER] == "done" and w.player.carry.count("letter") == 0 and game.player.controls_enabled and not game.sim_paused, "reading it through delivers the letter, completes the quest and returns the controls")
