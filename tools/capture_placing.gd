## Windowed screenshots of putting things down (see Placing, PlacementController): a barrel fire and a tent bought at the tent
## city; right-clicked in the bag, the ghost on open ground (green), then against a wall (red); the fire put down; then the tent,
## and the new tent city with the newcomer who keeps it.
##   godot --path . --script tools/capture_placing.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var city: Machine = w.machine_of(game.scenario.cast.tent)
	w.ledger.player_cash += 40.0
	w.ledger.printed += 40.0
	var spot: Vector2 = city.pos + city.front * 2.5
	_stand(spot, city.pos, 1.0)
	game.advance(0.3)
	print(w.commerce.buy(city, "barrel_fire").text, " / ", w.commerce.buy(city, "tent").text)
	# Out in the street, across from the market: right-click the barrel in the bag.
	var street: Vector2 = game.scenario.offset_on_street(game.scenario.start, 14.0, 0.0)
	_stand(street, street + game.scenario.street_dir() * 4.0 + Vector2(0, 0), 0.0)
	game.interaction.open_player()
	await _shot("1_bag", 30)
	game.inventory.use_requested.emit("barrel_fire")
	await _frames(5)
	await _shot("2_ghost_ok", 20)
	_stand(city.pos + city.front * 4.0, city.pos, 0.0)  # (onto the tent city's row: no room)
	await _frames(5)
	await _shot("3_ghost_no", 20)
	_stand(street, street + game.scenario.street_dir() * 4.0, 0.0)
	await _frames(5)
	print("place the fire: ", game.placement.confirm().text)
	await _shot("4_fire_placed", 40)
	game.interaction.open_player()
	game.inventory.use_requested.emit("tent")
	_stand(street + game.scenario.street_dir() * -6.0, street + game.scenario.street_dir() * -10.0, 0.0)
	await _frames(5)
	await _shot("5_tent_ghost", 20)
	print("place the tent: ", game.placement.confirm().text)
	var mine: Machine = w.machines.back()
	game.advance(1.0)
	_stand(mine.pos + mine.front * 6.0, mine.pos, 1.0)
	await _shot("6_new_tent_city", 60)
	game.interaction.open(mine)
	await _shot("7_its_screen", 30)
	quit()
