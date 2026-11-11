## Scene suite section: People get where they are going in the real town: the helicopter's bankers, who land east of the
## medical tent, can all reach the lemonade stand, the bakery and the hot dog stand to the west, past the tent.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	var sc: Scenario = game.scenario
	var arrived := 0
	var trips := 0
	for spot in IntroController.BANKER_SPOTS:
		for kind in ["lemonade_stand", "bakery", "hot_dog_stand"]:
			var m: Machine = null
			for candidate in w.machines:
				if candidate.kind == kind:
					m = candidate
			var goal: Vector2 = m.pos + m.front * 1.6
			var d := w.add_drifter(sc.offset_on_street(sc.wreck_pos, spot.x, spot.y), 0.0)
			trips += 1
			var steps := 0
			while d.pos.distance_to(goal) > 0.8 and steps < 3000:
				w.walking.step(d, goal, 0.1)
				steps += 1
			if d.pos.distance_to(goal) <= 0.8:
				arrived += 1
			w.drones.erase(d)  # these walkers were only for the trip
	w.zones.invalidate()
	check(trips == 9 and arrived == trips, "every banker landing spot has a way to the three stands, round the medical tent (%d of %d arrived)" % [arrived, trips])

	# ...and people who have drifted right beside the market's barrel fire still get past it to the food bank. (Two cart
	# runners once circled it for ever: the corner they steered for was only just beside it, so the line from where they
	# stood grazed its padding, was blocked, and the same corner was chosen again.)
	var fire: BarrelFire = w.fires[0]
	var bank: FoodBank = w.food_banks[0]
	var goal: Vector2 = bank.pos + bank.front * 1.6
	var passed := 0
	var from_fire := [Vector2(0.6, 0.4), Vector2(0.9, 0.2), Vector2(0.4, 0.7), Vector2(1.3, -0.3), Vector2(0.7, -0.5)]
	for off in from_fire:
		var d := w.add_drifter(fire.pos + off, 0.0)
		var steps := 0
		while d.pos.distance_to(goal) > 0.8 and steps < 3000:
			w.walking.step(d, goal, 0.1)
			steps += 1
		if d.pos.distance_to(goal) <= 0.8:
			passed += 1
		w.drones.erase(d)
	w.zones.invalidate()
	check(passed == from_fire.size(), "walkers right beside the market's barrel fire get past it to the food bank (%d of %d)" % [passed, from_fire.size()])
