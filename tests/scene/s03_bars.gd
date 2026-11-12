## Scene suite section: The bars over heads and in the HUD.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	# bars above heads and in the HUD
	var drone_views := game.get_children().filter(func(c): return c is DroneView)
	var dv: DroneView = drone_views[4]
	check(dv.get_node("Bars").get_child_count() == 15 and dv._bars._fills.size() == 4, "each NPC has four bars floating over its head: money, hunger, thirst, warmth, and a dark strip over the money for its orders of magnitude, each with a pale border and a backing")
	var drifter0: Drone = w.drones[4]
	drifter0.bars.hunger = 0.4
	for i in 3:
		await tree.process_frame
	check(absf(dv._bars._fills.hunger.scale.x - 0.4) < 0.02, "and they show the level (hunger about 40%)")
	check(absf(game.hud.player_panel.bars.hunger.value - w.player.bars.hunger * 100.0) < 1.0, "the HUD shows the player's own bars")
	check(is_equal_approx(dv._bars._fills.money.scale.x, maxf(0.001, Wealth.progress(drifter0.wallet))), "the green bar shows how much money they have")
	var their_money: float = drifter0.wallet
	drifter0.wallet = 0.0
	for i in 2:
		await tree.process_frame
	check(dv._bars._fills.money.scale.x <= 0.0011 and dv._bars._tier.scale.x <= 0.0011, "someone who is broke has an empty money bar and no dark notches: you can see it from across the street")
	drifter0.wallet = 250.0
	for i in 2:
		await tree.process_frame
	check(is_equal_approx(dv._bars._tier.scale.x, 2.0 / float(Wealth.MAX_TIER)) and is_equal_approx(dv._bars._fills.money.scale.x, Wealth.progress(250.0)), "$250 is two dark notches (the $10 and the $100) and the bar fills toward $1,000")
	drifter0.wallet = their_money  # (put back: money is conserved, and later checks count it)
	check(absf(game.hud.player_panel.bars.cash.value - minf(w.ledger.player_cash / Look.CASH_FULL, 1.0) * 100.0) < 1.0, "and the HUD has a cash bar for the player too")


	# the level bar is gone from the card and the HUD; the card lists reputation in points where the wallet used to be
	drifter0.rep = 0.37
	game.hud.card.show_target(drifter0, w)
	check(game.hud.card.info.text.begins_with("reputation 37 points") and not game.hud.card.info.text.contains("wallet") and not game.hud.card.bars.has("level"), "the card says 'reputation 37 points' and has no level bar")
	check(not game.hud.player_panel.bars.has("level") and game.hud.player_panel.bars.has("cash"), "and the player's own panel has no level bar either (its title still says the level)")
	game.hud.card.show_target(null, w)
