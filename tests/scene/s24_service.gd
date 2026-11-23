## Scene suite section: home again. With the letter delivered nobody is stranded at the bank: the shuttle runs back and forth
## between the gate and the door, and the bus between the bank and its stop on Kaiserstraße, turning round where its way starts
## behind it. Last of all, for the rides take the clock on a good way (the bus's is 2.7 km, about five minutes).
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var p: PlayerController = game.player
	var qc: QuestController = game.quest_controller
	w.hero.stand()
	p.stand()
	p.controls_enabled = true
	w.player.make_needless()  # (the rides are long in the test's fast time, and this is not about the hero's needs)
	check(w.quests.done("rode_on") and w.quests.done("rode_shuttle") and w.quests.state.get(QuestBook.LETTER, "") == "done", "the letter has gone over: the quest's rides are done")

	# The shuttle, twice: from wherever it is to the other end, and back.
	var cart: ShuttleView = game.shuttle
	var plan: Dictionary = game.scenario.ecb_gate
	for trip in 2:
		await _stand_by(cart.kerb_point())
		check(qc.boardable() == "shuttle", "trip %d: by the shuttle the hero can get on" % (trip + 1))
		var at_door := w.shuttle.pos.distance_to(plan.entrance) <= QuestController.AT_END
		var facing := Vector2.from_angle(w.shuttle.heading)
		await qc.shuttle_service()
		var end: Vector2 = plan.pad if at_door else plan.entrance
		check(w.shuttle.state == Bus.State.ARRIVED and w.shuttle.pos.distance_to(end) < 0.5 and p.controls_enabled, "it goes to the other end: %s" % ("the gate, where it first waited" if at_door else "the bank's door"))
		var set_off := w.shuttle.path.dir_at(1.0).dot(facing)
		var swung := w.shuttle.path.dir_at(Transit.UTURN_RUN + PI * QuestController.SHUTTLE_UTURN * 0.5 + 2.0).dot(facing)
		check(set_off > 0.7 and swung < -0.7, "its way started behind it, so it set off forward and swung round, not spinning on the spot (%.2f, then %.2f)" % [set_off, swung])

	# The bus: at the bank's stop (s20 left it there), back to Kaiserstraße, and out to the bank again.
	var coach: BusView = game.bus
	var bank_stop: Vector2 = game.scenario.ecb_stop.bus
	await _stand_by(coach.kerb_point())
	check(w.bus.pos.distance_to(bank_stop) <= QuestController.AT_END and qc.boardable() == "bus", "the bus waits by the bank's stop (s20 pushed it about a little), and the hero can get on")
	var saved: Dictionary = Snapshot.new(w).capture()
	var fresh := Fixtures.scenario().build()
	Snapshot.new(fresh).apply(saved)
	check(fresh.bus.pos.distance_to(w.bus.pos) < 0.01, "a save keeps it there, not back at its first stop (Snapshot)")
	await qc.bus_service()
	var home: Vector2 = game.scenario.bus_stop.pos
	var across: float = float(game.scenario.bus_stop.width) * 0.5
	var off := w.bus.pos.distance_to(home)
	check(w.bus.state == Bus.State.ARRIVED and (off < 0.5 or absf(off - across) < 0.5), "it takes the hero back to its stop on Kaiserstraße (in one lane or the other: %.1f m from the stop)" % off)
	var right := Vector2.from_angle(w.bus.heading).rotated(PI * 0.5)
	check(right.dot(game.scenario.bus_stop.kerb_side if off < 0.5 else -(game.scenario.bus_stop.kerb_side as Vector2)) > 0.7, "pulled up with its door, on its right, toward the kerb of the lane it came in by")
	check(p.controls_enabled and p.ground_pos().distance_to(home) < 15.0 and w.player.care == "", "and they step off there, free")
	await _stand_by(coach.kerb_point())
	check(qc.boardable() == "bus", "and from there it goes back out to the bank")
	await qc.bus_service()
	check(w.bus.state == Bus.State.ARRIVED and w.bus.pos.distance_to(bank_stop) < 0.5 and p.controls_enabled, "it does: back at the bank's gate")


## Puts the hero on the ground at `at` (a vehicle's kerb point), and lets the world catch up.
func _stand_by(at: Vector3) -> void:
	game.player.teleport(Vector3(at.x, 0.1, at.z), 0.0)
	game.advance(0.2)
	await tree.process_frame
