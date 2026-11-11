## Scene suite section: The bars over heads and in the HUD.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:
	var w: World = game.world
	# bars above heads and in the HUD
	var drone_views := game.get_children().filter(func(c): return c is DroneView)
	var dv: DroneView = drone_views[4]
	check(dv.get_node("Bars").get_child_count() == 10 and dv._bars._fills.size() == 4, "each NPC has four bars floating over its head: level, hunger, thirst, warmth, and a dark strip over the level for the levels reached")
	var drifter0: Drone = w.drones[4]
	drifter0.bars.hunger = 0.4
	for i in 3:
		await tree.process_frame
	check(absf(dv._bars._fills.hunger.scale.x - 0.4) < 0.02, "and they show the level (hunger about 40%)")
	check(absf(game.hud.player_panel.bars.hunger.value - w.player.bars.hunger * 100.0) < 1.0, "the HUD shows the player's own bars")
	check(is_equal_approx(dv._bars._fills.level.scale.x, maxf(0.001, drifter0.growth.progress())), "the green bar shows their level progress")
	check(absf(game.hud.player_panel.bars.cash.value - minf(w.ledger.player_cash / Look.CASH_FULL, 1.0) * 100.0) < 1.0, "and the HUD has a cash bar for the player too")

