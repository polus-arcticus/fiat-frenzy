## Windowed screenshots of a queue at the hot dog stand.
##   godot --path . --script tools/capture_queue.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/captures/queue"
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
	var hot: Drone = game.scenario.cast.hot_dog
	var m := w.machine_of(hot)
	m.working = true
	m.output.add(m.item, 20)
	m.refresh()
	for i in 10:
		var d := w.add_drifter(hot.pos + m.front * (12.0 + i * 0.7), 30.0)
		d.bars.hunger = 0.05
		game.add_drone_view(d)
	game.advance(9.0)
	var perp := Vector2(-m.front.y, m.front.x)
	var mid := m.pos + m.front * 4.0
	var spot := mid + perp * 9.0
	var dir := (mid - spot).normalized()
	game.player.teleport(Vector3(spot.x, 0.1, spot.y), atan2(-dir.x, -dir.y))
	game.advance(0.2)
	print("line: ", m.line.size())
	for d in m.line:
		print("  at %.1f m along the front, %.1f m across" % [(d.pos - m.pos).dot(m.front), (d.pos - m.pos).dot(Vector2(-m.front.y, m.front.x))])
	await _shot("1_queue", dir_out)
	game.advance(4.0)
	print("line: ", m.line.size())
	await _shot("2_queue_later", dir_out)
	quit()
