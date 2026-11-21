## Windowed screenshots of the new-game screen (LandingScreen): the globe, the flat map over the north pole, and both zoomed
## in on a chosen tile with the grid showing. It fetches the map pictures it lacks from tile.openstreetmap.org (MapTiles),
## unless `offline`.
##   godot --path . --script tools/capture_globe.gd -- <out dir> [offline]
extends SceneTree

var out_dir := "/tmp/ff3d_capture"
var screen: LandingScreen


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1300, 750)
	screen = LandingScreen.new()
	screen.fetcher.online = not "offline" in args
	root.add_child(screen)
	_run()


func _run() -> void:
	await _settle(8.0)
	await _shot("1_globe_story")
	screen._toggle_view()
	await _settle(2.0)
	await _shot("2_flat_whole")
	screen._toggle_view()
	var at := Vector2(50.1109, 8.6821)  # Frankfurt's Römer
	screen._where.text = "%f, %f" % [at.x, at.y]
	screen._on_typed(screen._where.text)
	await _settle(10.0)
	await _shot("3_globe_tile")
	screen._toggle_view()
	await _settle(8.0)
	await _shot("4_flat_tile")
	screen.proj.zoom_at(screen.proj.size * 0.5, 1.0 / 14.0)
	await _settle(6.0)
	await _shot("5_flat_regions")
	screen._toggle_view()
	screen.proj.zoom_at(screen.proj.size * 0.5, 1.0 / 400.0)
	await _settle(3.0)
	await _shot("6_globe_whole_tile_chosen")
	print("fetches still waiting: ", screen.fetcher.waiting())
	quit()


## Real time for the view to fly and the pictures to come (at most `secs`).
func _settle(secs: float) -> void:
	var until := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		if screen._goal.is_empty() and screen.fetcher.waiting() == 0 and Time.get_ticks_msec() > until - int(secs * 700.0):
			break
	for i in 20:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)
