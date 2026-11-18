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


	# The last leg: the doorman at the bank's gate, the shuttle, and the receptionist at the door. A long way east of Mr. Nobody's house.
	var doorman: Drone = w.cast.doorman
	check(doorman != null and doorman.pos.x > game.scenario.sage_house.door.x + 500.0, "the European Central Bank has a doorman, well east of Battonnstraße")
	check(doorman.look == "guard" and game.scenario.ecb_gate.guard.distance_to(doorman.pos) < 0.01, "he stands in front of the guard's booth at the gate, in a hi-vis vest")
	w.sage.tell(Stories.FIRST)
	await game.get_tree().process_frame
	check(not w.quests.can_deliver() and w.quests.can_clear_gate() and not SecurityGate.is_open(w), "at the bank the gate is shut, and the doorman is the first to see (the desk can't take the letter yet)")
	check(not game.quest_controller.can_board(), "and the shuttle is not yours to board yet")
	var toward: Vector2 = (doorman.face_to - doorman.pos).normalized()  # the way he faces: from the street
	game.player.teleport(Vector3(doorman.pos.x + toward.x * 2.0, 0.1, doorman.pos.y + toward.y * 2.0), 0.0)
	w.player.pos = game.player.ground_pos()
	game.player.look_toward(Vector3(doorman.pos.x, 1.4, doorman.pos.y))
	for i in 3:
		await game.get_tree().physics_frame
	check(game.story_verbs.aimed_doorman() == doorman and game.interaction._verbs.any(func(v): return v.action == "chat" and v.prompt.call() == "Q   show the doorman the letter"), "aiming at him at the gate shows the Q prompt (the real path, not a signal)")
	check(game.interaction._do("chat"), "and Q does something")
	check(game.dialogue.visible and game.dialogue.speaker == "ECB doorman" and not game.player.controls_enabled, "Q at him opens his check of the letter")
	guard = 0
	while game.dialogue.visible and guard < 10:
		game.dialogue.advance()
		guard += 1
	check(SecurityGate.is_open(w) and w.quests.done("cleared_gate") and game.player.controls_enabled and not game.sim_paused and w.quests.state[QuestBook.LETTER] == "active", "reading it through opens the gate and gives the controls back; the quest is not over")
	for i in 300:  # (the barrier lifts in a second or two and the gate takes three seconds to slide)
		await game.get_tree().physics_frame
	var gv: SecurityGateView = game.get_node("SecurityGate")
	check(gv.is_open and gv._barrier.rotation.z > 1.3 and gv._barrier_shape.disabled and gv._panel_shapes.all(func(s): return s.disabled), "the barrier lifts and the gate slides open, and neither is solid any more")
	check(w.quests.objective().text.contains("shuttle"), "the objective says to hop on the shuttle")
	var cart: ShuttleView = game.shuttle
	game.player.teleport(Vector3(cart.kerb_point().x, 0.1, cart.kerb_point().z), 0.0)
	game.advance(0.2)
	await game.get_tree().process_frame
	check(game.quest_controller.boardable() == "shuttle" and game.quest_controller.board_prompt().contains("shuttle"), "next to the shuttle you can hop on, and the prompt says so")
	w.player.bars.hunger = 1.0
	w.player.bars.thirst = 1.0
	await game.quest_controller.ride_shuttle()
	var plan: Dictionary = game.scenario.ecb_gate
	check(w.quests.done("rode_shuttle") and w.shuttle.state == Bus.State.ARRIVED and w.shuttle.pos.distance_to(plan.entrance) < 0.5 and not w.shuttle.aboard, "the shuttle takes them round to the main entrance and stops")
	check(game.player.controls_enabled and not game.player.is_seated() and game.player.ground_pos().distance_to(plan.entrance) < 3.5 and not game.sim_paused, "and they step out onto the plaza by the door, free again")
	var desk: Drone = w.cast.receptionist
	check(desk != null and desk.pos.distance_to(plan.reception) < 0.01 and game.get_node(("Drone_" + desk.uid).validate_node_name()) != null, "the receptionist waits just out from the door")
	game.player.teleport(Vector3(desk.pos.x + (desk.face_to - desk.pos).normalized().x * 2.0, 0.1, desk.pos.y + (desk.face_to - desk.pos).normalized().y * 2.0), 0.0)
	w.player.pos = game.player.ground_pos()
	check(w.quests.can_deliver(), "with the letter in the bag and through the gate, the receptionist can take it")
	game.player.look_toward(Vector3(desk.pos.x, 1.4, desk.pos.y))
	for i in 3:
		await game.get_tree().physics_frame
	check(game.story_verbs.aimed_receptionist() == desk and game.interaction._do("chat"), "aiming at the receptionist shows the prompt and Q works")
	check(game.dialogue.visible and game.dialogue.speaker == "ECB receptionist" and not game.player.controls_enabled, "Q at them opens their reply")
	guard = 0
	while game.dialogue.visible and guard < 10:
		game.dialogue.advance()
		guard += 1
	check(w.quests.state[QuestBook.LETTER] == "done" and w.player.carry.count("letter") == 0 and game.player.controls_enabled and not game.sim_paused, "reading it through delivers the letter, completes the quest and returns the controls")
