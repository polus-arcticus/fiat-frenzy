## Windowed screenshots of starting a new game the way a player does: the title, New Game (the landing picker), a tile chosen,
## Land here, and the game it starts. The tile should be in the cache (tools/make_tile.gd), or it is fetched from Overpass.
##   godot --path . --script tools/capture_newgame.gd -- <out dir> [key=16/34347/22195] [offline] [story]
extends SceneTree

var out_dir := "/tmp/ff3d_capture"
var key := "16/34347/22195"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	for a in args:
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	change_scene_to_file("res://title.tscn")
	_run("offline" in args)


func _run(offline: bool) -> void:
	await _frames(30)
	var title: TitleScreen = current_scene
	await _shot("1_title")
	title._show_landing()
	await _frames(5)
	var picker: LandingScreen = title.get_children().filter(func(c): return c is LandingScreen)[0]
	picker.fetcher.online = not offline
	var m: Array = TileKey.middle(key)
	if "story" in OS.get_cmdline_user_args():
		picker._choose_story()
	else:
		picker.choose(Vector2(m[0], m[1]))
		picker._fly(picker.pick, picker._k_for_tile_px(160.0, m[0]))
	await _real(6.0)
	await _shot("2_picker_tile")
	picker._on_go()
	var t0 := Time.get_ticks_msec()
	var counted := {}
	while Time.get_ticks_msec() - t0 < 60000:
		await process_frame
		if Launch.loading != null and not counted.has(Launch.loading.caption):  # (each step the loading picture counts)
			counted[Launch.loading.caption] = Time.get_ticks_msec() - t0
			if Launch.loading.caption.begins_with("2 /"):
				await _shot("3_loading_step")
		if current_scene != null and current_scene.get("is_built") == true:
			break
	for c in counted:
		print("  %6d ms  %s" % [counted[c], c])
	print("built after %d ms" % (Time.get_ticks_msec() - t0))
	await _real(6.0)
	var game := current_scene
	print("landed on: ", game.landing.spec(), " story: ", game.landing.story())
	await _shot("4_landed")
	if game.dressing != null:
		t0 = Time.get_ticks_msec()
		while game.dressing.node == null and Time.get_ticks_msec() - t0 < 120000:
			await process_frame
		print("dressing in after %d ms: %s" % [Time.get_ticks_msec() - t0, game.dressing.node != null])
		if game.dressing.node != null:
			for crowns in game.dressing.node.get_node("Trees").get_children():
				print("  trees, %s: %d" % [crowns.name, crowns.multimesh.instance_count])
			await _real(1.0)
			await _shot("5_dressed")
			var mid := TileKey.rect(game.landing.key).get_center()
			var cam := Camera3D.new()
			game.add_child(cam)
			cam.global_position = Vector3(mid.x + 40, 260, mid.y + 330)
			cam.look_at(Vector3(mid.x, 0, mid.y))
			cam.current = true
			await _real(1.0)
			await _shot("6_dressed_above")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _real(secs: float) -> void:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
