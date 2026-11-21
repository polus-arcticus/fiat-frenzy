## Windowed screenshots of the thrift stall in the first market (see Catalog "clothing"): the stall and its pile of scrap; its screen
## (E); an old coat bought, in the loadout; then built up, the clothing shop.
##   godot --path . --script tools/capture_thrift.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var stall: Machine = w.machine_of(game.scenario.cast.thrift)
	game.advance(5.0)
	_stand(stall.pos + stall.front * 7.0 + Vector2(-stall.front.y, stall.front.x) * 2.0, stall.pos, 0.9)
	await _shot("1_thrift_stall", 90)
	w.ledger.player_cash += 50.0
	w.ledger.printed += 50.0
	_stand(stall.pos + stall.front * 2.0, stall.pos, 1.0)
	game.interaction.open(stall)
	await _shot("2_screen", 30)
	var r := w.commerce.buy(stall, "old_coat")
	game.interaction.screen.refresh(r.text)
	await _shot("3_bought", 10)
	game.interaction.screen.close()
	var owner := w.drone(stall.owner)
	owner.wallet += 500.0
	w.ledger.printed += 500.0
	w.trades.day = -1
	w.trades.step(1.0)
	game.advance(1.0)
	print("now: %s" % stall.display_name())
	_stand(stall.pos + stall.front * 7.0 + Vector2(-stall.front.y, stall.front.x) * 2.0, stall.pos, 0.9)
	await _shot("4_clothing_shop", 90)
	quit()
