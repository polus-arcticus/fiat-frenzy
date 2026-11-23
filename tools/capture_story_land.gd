## Windowed screenshots of the story's Frankfurt with its land (Scenario.load_district): from the hero's eyes where the story
## begins, from above the park nearest the start, and from above the European Central Bank on the Main.
##   godot --path . --script tools/capture_story_land.gd -- <output dir>
extends SceneTree


func _initialize() -> void:
	var out_dir := "/home/thdev/proto/ff3d/.godot/captures/story_land"
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
	var sc: Scenario = game.scenario
	w.player.make_needless()
	w.clock.time = 0.3 * Clock.DAY_SECONDS  # (by day)
	var waited := 0
	while (game.dressing == null or game.dressing.node == null) and waited < 600:
		await process_frame
		waited += 1
	print("dressed after %d frames: %s" % [waited, game.dressing != null and game.dressing.node != null])
	game.hud.visible = false
	# the hero's eyes, down Kaiserstraße
	await _shot("1_start", dir)
	# above the nearest park
	var best: Dictionary = {}
	var gap := INF
	for a in sc.district.green.areas:
		if a.kind != "green":
			continue
		var c := Vector2.ZERO
		for q in a.poly:
			c += q
		c /= a.poly.size()
		if c.distance_to(sc.start) < gap and a.poly.size() > 6:
			gap = c.distance_to(sc.start)
			best = {"at": c}
	var cam := Camera3D.new()
	cam.fov = 60.0
	game.add_child(cam)
	var park: Vector2 = best.at
	cam.global_position = Vector3(park.x, 55.0, park.y + 45.0)
	cam.look_at(Vector3(park.x, 0, park.y))
	cam.current = true
	await _shot("2_nearest_park_%.0f_m_off" % gap, dir)
	cam.global_position = Vector3(park.x + 8.0, 6.0, park.y + 22.0)
	cam.look_at(Vector3(park.x, 2.0, park.y))
	await _shot("3_in_the_park", dir)
	# above the bank and the river
	var door: Vector2 = sc.ecb.door
	cam.global_position = Vector3(door.x, 160.0, door.y - 120.0)
	cam.look_at(Vector3(door.x, 0, door.y + 60.0))
	await _shot("4_the_bank_and_the_main", dir)
	quit()
