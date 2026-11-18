## Windowed screenshots of the welfare office on the landing street: on the first morning, and after the first pass go.
##   godot --path . --script tools/capture_welfare.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/welfare"
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
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)


func _run(game: Node, dir_out: String) -> void:
	for i in 20:
		await physics_frame
	var w: World = game.world
	var office: WelfareOffice = w.welfare_offices[0]
	var spot := office.pos + office.front * 6.0 + Vector2(-office.front.y, office.front.x) * 2.0
	var dir := (office.pos - spot).normalized()
	game.player.teleport(Vector3(spot.x, 0.1, spot.y), atan2(-dir.x, -dir.y))
	game.advance(0.5)
	await _shot("1_welfare_office", dir_out)
	game.advance(Clock.DAY_SECONDS)  # through the first dawn: pass go
	game.player.teleport(Vector3(spot.x, 0.1, spot.y), atan2(-dir.x, -dir.y))
	game.advance(0.5)
	print("issued $%.2f, given out $%.2f, loose bills %d" % [w.ledger.issued, office.given_out, w.bills.filter(func(b): return b.loose).size()])
	await _shot("2_after_pass_go", dir_out)
	quit()
