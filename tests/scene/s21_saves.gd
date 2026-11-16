## Scene suite section: saving and loading in the real game. A save written mid-game and loaded again puts back the money, the
## hero and the people who turned up later, with views for them, and a menu on Esc holds the game still.
extends SceneSection


func run() -> void:
	var p: PlayerController = game.player
	var w: World = game.world
	p.teleport(Vector3(w.player.pos.x + 3.0, 0.1, w.player.pos.y), 1.25)
	game.advance(0.2)
	var late := w.add_drifter(w.player.pos + Vector2(4, 4), 9.0)
	late.label = "Latecomer"
	game.add_drone_view(late)
	var cash := w.ledger.player_cash
	var where: Vector2 = p.ground_pos()
	var drones := w.drones.size()
	check(game.save_game("scene_test"), "the game saves where the hero stands")
	w.ledger.player_cash = 0.0
	p.teleport(Vector3(where.x + 200.0, 0.1, where.y), 0.0)
	w.drones.pop_back()
	check(game.load_game("scene_test"), "and loads again")
	await tree.process_frame
	check(is_equal_approx(w.ledger.player_cash, cash), "the money is back (%.2f)" % w.ledger.player_cash)
	check(p.ground_pos().distance_to(where) < 0.5 and is_equal_approx(p.rotation.y, 1.25), "so is the hero, facing the way they were")
	check(w.drones.size() == drones and w.drones[-1].label == "Latecomer", "and the latecomer")
	var views := 0
	for c in game.get_children():
		if c is DroneView and c.drone == w.drones[-1]:
			views += 1
	check(views >= 1, "who has a body in the street again")
	SaveStore.delete("scene_test")
	check(SaveStore.read("scene_test").is_empty(), "a deleted save is gone")
	var esc := InputEventAction.new()
	esc.action = "release"
	esc.pressed = true
	game._unhandled_input(esc)
	game.screens._unhandled_input(esc)
	check(game.pause.visible and game.sim.paused(), "Esc opens the pause menu, and the sim waits")
	game.pause.close()
	check(not game.sim.paused() and p.controls_enabled, "closing it sets the game going again")
