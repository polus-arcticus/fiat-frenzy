## Windowed screenshots of the homeless camp in the first market (see Camp): the camp and its pile of scrap; its screen (E);
## then, its scrap filled by hand and built up, the bike camp.
##   godot --path . --script tools/capture_camp.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var camp: Machine = w.machine_of(game.scenario.cast.camp)
	game.advance(5.0)
	var pile: ScrapPile = w.scrap_piles[0]
	print("the camp: %s, %d boards, %d scrap; the pile %d" % [camp.display_name(), camp.stock(), camp.input.count("scrap"), pile.output.count("scrap")])
	print("pile %.1f m from the camp; camp front %s" % [pile.pos.distance_to(camp.pos), camp.front])
	var mid := (camp.pos + pile.pos) * 0.5
	_stand(mid + camp.front * 7.0, mid, 0.8)
	await _shot("1_camp", 90)
	_stand(camp.pos + camp.front * 2.0, camp.pos, 1.0)
	game.interaction.open(camp)
	await _shot("2_screen", 30)
	game.interaction.screen.close()
	camp.input.add("scrap", camp.input.room("scrap"))
	w.trades.day = -1
	w.trades.step(1.0)
	print("now: %s (%s)" % [camp.display_name(), w.events.back()])
	game.advance(1.0)
	_stand(mid + camp.front * 7.0, mid, 0.8)
	await _shot("3_bike_camp", 90)
	quit()
