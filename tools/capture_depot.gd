## Windowed screenshots of the bottle depot on Kaiserstraße: the kiosk with its PFAND board, and later, once someone short of
## cash has walked bottles over, its tally.
##   godot --path . --script tools/capture_depot.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/.godot/captures/depot"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	var game: Node = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run(game, out_dir)


func _shot(name: String, dir: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)


func _run(game: Node, dir: String) -> void:
	for i in 20:
		await physics_frame
	var w: World = game.world
	w.player.make_needless()
	w.clock.time = 0.3 * Clock.DAY_SECONDS  # (by day)
	var depot: BottleDepot = w.deposit.depot_in(Zones.HOME)
	var side := Vector2(-depot.front.y, depot.front.x)
	var spot := depot.pos + depot.front * 5.5 + side * 2.5
	var look := depot.pos - spot
	game.player.teleport(Vector3(spot.x, 0.1, spot.y), atan2(-look.x, -look.y))
	game.player.look_toward(Vector3(depot.pos.x, 1.6, depot.pos.y))
	game.advance(0.3)
	await _shot("1_the_depot", dir)
	var waited := 0.0
	while depot.taken_in == 0 and waited < 600.0:
		game.advance(5.0)
		waited += 5.0
	game.player.teleport(Vector3(spot.x, 0.1, spot.y), atan2(-look.x, -look.y))
	game.player.look_toward(Vector3(depot.pos.x, 1.6, depot.pos.y))
	game.advance(0.3)
	print("after %.0f s: %d bottles taken in, $%.2f paid out, $%.2f new" % [waited, depot.taken_in, depot.paid_out, w.ledger.issued])
	await create_timer(0.7).timeout  # (the board's tally is read twice a second)
	await _shot("2_bottles_taken_in", dir)
	quit()
