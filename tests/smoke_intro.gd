## Plays the helicopter intro for real (in real time) and checks what it leaves behind, then does it again
## with a skip.   godot --headless --path . --script tests/smoke_intro.gd
extends SceneTree

var failures := 0
var checks := 0
## The number of checks a clean run makes; fewer means a script error stopped a test early. Raise it when
## tests are added.
const EXPECTED_CHECKS := 20


func check(ok: bool, what: String) -> void:
	checks += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failures += 1


func _initialize() -> void:
	Engine.time_scale = 4.0  # tweens and timers run four times faster: the cinematic takes 4 s, not 16
	await _natural_run()
	await _skip_run()
	if checks < EXPECTED_CHECKS:
		print("only %d of %d checks ran" % [checks, EXPECTED_CHECKS])
		failures += 1
	print("\n%s (%d checks)" % ["ALL PASSED" if failures == 0 else "%d FAILED" % failures, checks])
	quit(failures)


func _spawn() -> Node:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	return game


func _bankers(game: Node) -> Array:
	return game.world.drones.filter(func(d): return d.label == "Banker")


func _natural_run() -> void:
	print("the intro plays out on its own")
	var game: Node = await _spawn()
	check(game.get("intro") != null and game.intro.running, "the intro starts with the game")
	check(game.sim_paused and not game.player.controls_enabled and not game.gun.enabled, "the sim is paused, the player has no controls and no gun")
	check(game.tutorial.text().contains("money gun"), "and the tutorial's first step is to pick up the gun")
	check(game.intro.wreck.global_position.y > 20.0, "the helicopter is up in the sky (%.0f m)" % game.intro.wreck.global_position.y)
	var time0: float = game.world.clock.time
	await create_timer(1.2).timeout
	check(game.world.clock.time == time0 and game.world.clock.text() == "06:47", "time stands still while it plays, at 6:47")
	check(game.intro.running and game.intro.wreck.global_position.y < 40.0 + game.scenario.wreck_pos.y * 0.0 + 1.0, "it is falling")
	await create_timer(6.8).timeout
	var w: World = game.world
	check(not game.intro.running and game.player.controls_enabled and not game.sim_paused, "it ends itself: controls back, the town running")
	var rest := Vector3(game.scenario.wreck_pos.x, 0, game.scenario.wreck_pos.y)
	check(game.intro.wreck.global_position.distance_to(rest) < 0.2, "the wreck has come to rest on the street")
	var bankers := _bankers(game)
	check(bankers.size() == 3 and bankers.all(func(d): return d.look == "banker"), "three bankers landed, in banker suits")
	check(game.intro.pickup != null and is_instance_valid(game.intro.pickup) and not game.gun.enabled, "the gun is lying at the player's feet, and not yet in their hands")
	await create_timer(4.0).timeout
	check(w.ledger.printed >= 3 * 12.0 + 50.0, "the bankers' cash was printed into the world: $%.0f" % w.ledger.printed)
	check(w.bills.all(func(b): return b.loose), "every bill has come down")
	check(is_equal_approx(w.total_money(), w.ledger.printed), "and no money went missing")
	var dir: Vector2 = game.scenario.street_dir()
	var near: Vector2 = game.scenario.gun_rest - dir * 1.3
	game.player.teleport(Vector3(near.x, 0.1, near.y))
	game.player.look_toward(Vector3(game.scenario.gun_rest.x, 0.2, game.scenario.gun_rest.y))
	for i in 5:
		await physics_frame
	check(game.interaction.aimed_pickup() == game.intro.pickup, "aiming at the gun up close picks it out")
	game.intro.pickup.take()
	await process_frame
	await process_frame
	check(game.gun.enabled and game.tutorial.index >= 1, "picking it up puts it in the player's hands and moves the tutorial on")
	game.queue_free()
	await process_frame


func _skip_run() -> void:
	print("the intro can be skipped")
	var game: Node = await _spawn()
	await create_timer(0.5).timeout
	check(game.intro.running, "still playing half a second in")
	var skip := InputEventAction.new()
	skip.action = "skip"
	skip.pressed = true
	game.intro._unhandled_input(skip)
	check(not game.intro.running and game.player.controls_enabled and not game.sim_paused, "skipping ends it at once")
	check(_bankers(game).size() == 3 and game.intro.pickup != null, "with everything it would have left: three bankers and the gun")
	var rest := Vector3(game.scenario.wreck_pos.x, 0, game.scenario.wreck_pos.y)
	check(game.intro.wreck.global_position.distance_to(rest) < 0.2, "and the wreck on the ground")
	await create_timer(3.0).timeout
	check(is_equal_approx(game.world.total_money(), game.world.ledger.printed), "money is conserved after a skip too")
	game.queue_free()
	await process_frame
