## Lands on a tile the way a player does (Launch.begin: the loading picture, the threaded bake) and reports whether the game
## finishes building, how long each step takes, where the hero ends up against the ground, and whether walking (W) and the pause
## key (Esc) do anything. For "the game took all my keys" reports. The tile's map must be cached.
##   godot --path . --script tools/probe_landing_input.gd -- <out dir> [key=16/11725/21882]
extends SceneTree

var out_dir := "/tmp/ff3d_probe"
var key := "16/11725/21882"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("key="):
			key = a.trim_prefix("key=")
		elif not a.contains("="):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	_run()


func _run() -> void:
	await process_frame
	var m: Array = TileKey.middle(key)
	var t0 := Time.get_ticks_msec()
	Launch.skip_intro = true
	_launch({"kind": "tile", "key": key, "lat": m[0], "lon": m[1]})  # (not awaited: it is watched from here)
	var built := false
	while Time.get_ticks_msec() - t0 < 60000:
		await process_frame
		var g := current_scene
		if g != null and g.get("is_built") == true:
			built = true
			break
	print("built: %s after %.1f s (scene %s, loading screen %s)" % [built, (Time.get_ticks_msec() - t0) / 1000.0, current_scene, Launch.loading])
	if not built:
		_shot("0_stuck")
		quit(1)
		return
	var game := current_scene
	for i in 60 * 5:  # (the loading picture plays out for LoadingScreen.OUT_AT after release)
		await physics_frame
	var p: PlayerController = game.player
	var at := p.ground_pos()
	print("hero at %s y %.2f, ground %.2f, on floor %s, controls %s, scripted %s, care '%s'" % [at, p.global_position.y, Ground.y(at), p.is_on_floor(), p.controls_enabled, p.scripted, game.world.player.care])
	print("open screens: %s; mouse mode %d; paused %s" % [game.screens.get("stack") if game.get("screens") != null else "?", Input.mouse_mode, paused])
	await _shot("1_landed")
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
	Input.action_release("move_forward")
	print("W held 1.5 s: moved %.2f m, y now %.2f, ground %.2f, on floor %s, on wall %s" % [p.ground_pos().distance_to(at), p.global_position.y, Ground.y(p.ground_pos()), p.is_on_floor(), p.is_on_wall()])
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	for i in 10:
		await process_frame
	esc.pressed = false
	root.push_input(esc)
	await process_frame
	print("after Esc: pause screen open %s" % [game.pause.visible if game.get("pause") != null else "?"])
	await _shot("2_after_esc")
	quit()


func _launch(spec: Dictionary) -> void:
	var error: String = await Launch.begin(self, "", spec)
	print("launch returned '%s'" % error)


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
