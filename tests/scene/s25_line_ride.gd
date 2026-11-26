## Scene suite section: riding a line (Line, LineRideController, RideController). Any map's vehicles that run on a line (a tile's
## train, its bus route, the story's trams) are ridden this way. This lays a short line of its own across the forecourt, rides
## it from its first stop to its second through the game's own boarding prompt, and takes it away again.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var sc: Scenario = game.scenario
	var p: PlayerController = game.player
	for need in Drone.NEEDS:
		w.player.bars[need] = 1.0
	var dir: Vector2 = sc.street_dir()
	var route := PackedVector2Array([sc.start - dir * 40.0, sc.start - dir * 240.0])
	var line := Line.through(route, [{"at": route[0], "name": "Markt"}, {"at": route[1], "name": "Ende"}], "Ende", 10.0, 40.0, 60.0)
	var model := w.transit.add_on("tram", "train", line)
	check(model != null and model.line == line and model.stop == 0, "a tram stands at the first stop of its line")
	var view := TramView.new()
	view.setup(model.pos, VehicleView._yaw_of(model.heading), {"sign": line.name})
	view.follow(model, game.sim)
	game.add_child(view)
	var rider := LineRideController.new().setup(w, p, game.rides, view, model)
	game.add_child(rider)
	game.line_riders.append(rider)
	var door := view.kerb_point()
	p.stand()
	p.controls_enabled = true
	p.teleport(Vector3(door.x, 0.1, door.z), 0.0)
	game.advance(0.2)
	await tree.process_frame
	check(game._board_prompt().contains("ride the train to Ende"), "at its door the prompt offers the ride to the next stop (%s)" % game._board_prompt())
	game.rides.fast = true
	await game._board()
	game.rides.fast = false
	check(model.stop == 1 and model.state == Vehicle.State.ARRIVED and not model.aboard and model.pos.distance_to(line.stops[1].at) < 0.5, "it takes the hero to Ende, and stops there")
	var out := view.kerb_point()
	var off := p.ground_pos().distance_to(Vector2(out.x, out.z))
	check(p.controls_enabled and not p.is_seated() and off < 1.0 and not game.rides.riding, "and they step out at its door, free (%.1f m from the kerb by it)" % off)
	check(w.transit.vehicle("tram_east") != null and w.transit.vehicle("tram_east") != model, "the story's own trams are still where they were")
	# (taken away again: the story's map has no line of its own)
	game.line_riders.erase(rider)
	rider.queue_free()
	view.queue_free()
	w.vehicles.erase(model)
	w.heating.vehicles.erase(model)
