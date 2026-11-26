## Scene suite section: home again. With the letter delivered nobody is stranded at the bank: the shuttle runs back and forth
## between the gate and the door, and the trams are anyone's, the one that brought the hero among them. Last of all, for the
## rides take the clock on a good way.
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

	# The shuttle, twice: along its line from the end it is at to the other, and back.
	var cart: ShuttleView = game.shuttle
	var model: Vehicle = w.transit.vehicle("shuttle")
	for trip in 2:
		await _stand_by(cart.kerb_point())
		check(qc.boardable() == "shuttle", "trip %d: by the shuttle the hero can get on" % (trip + 1))
		var to := model.next_stop()
		await qc.shuttle_service()
		check(model.state == Vehicle.State.ARRIVED and model.stop == to and model.pos.distance_to(model.line.stops[to].at) < 0.5 and p.controls_enabled, "it goes to the other end of its line: %s" % model.line.stops[to].name)

	# The trams: the one that brought the hero goes on east; the one the other way goes back toward town.
	var saved: Dictionary = {}
	for called in ["tram_east", "tram_west"]:
		var tram: Vehicle = w.transit.vehicle(called)
		var rider: LineRideController = game.line_riders.filter(func(r): return r.model == tram)[0]
		rider.view.door_to_alight()
		await _stand_by(rider.view.kerb_point())
		var next: String = tram.line.stops[tram.next_stop()].name
		check(game._board_prompt() == "E   ride the tram to %s" % next, "%s: at its door the prompt offers the next stop (%s)" % [called, game._board_prompt()])
		game.rides.fast = true
		await game._board()
		game.rides.fast = false
		check(tram.state == Vehicle.State.ARRIVED and tram.line.stops[tram.stop].name == next and p.controls_enabled and w.player.care == "", "and it takes the hero there, to step off free")
		if called == "tram_east":
			saved = Snapshot.new(w).capture()
	var fresh := Fixtures.scenario().build()
	Snapshot.new(fresh).apply(saved)
	var east: Vehicle = w.transit.vehicle("tram_east")
	var again: Vehicle = fresh.transit.vehicle("tram_east")
	check(again.pos.distance_to(east.pos) < 0.01 and again.stop == east.stop and again.line != null, "a save keeps a tram where it was left, on its line (Snapshot; the line is the map's)")
	check(w.transit.vehicle("tram_west").line.stops[w.transit.vehicle("tram_west").stop].name == "Zobelstraße", "the way back toward town begins at Zobelstraße")


## Puts the hero on the ground at `at` (a vehicle's kerb point), and lets the world catch up.
func _stand_by(at: Vector3) -> void:
	game.player.teleport(Vector3(at.x, 0.1, at.z), 0.0)
	game.advance(0.2)
	await tree.process_frame
