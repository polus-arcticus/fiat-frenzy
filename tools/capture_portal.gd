## Windowed screenshots of the teleporter rings: the one by the start and the one by Mr. Nobody.
##   godot --path . --script tools/capture_portal.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_portal"
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1200, 700)
	game = load("res://main.tscn").instantiate()
	game.skip_intro = true
	game.portals = true
	root.add_child(game)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _stand(at: Vector2, look_at: Vector2, eye := 1.5) -> void:
	var to := look_at - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, eye, look_at.y))


func _run() -> void:
	await _frames(20)
	var ring: Portal = game.world.portals.all[0]
	game.sim_paused = true
	game.hud.visible = false
	game.portal_controller.set_process(false)
	_stand(ring.exit_point() + ring.normal * 3.0, ring.pos)
	await _shot("1_home_ring")
	var far: Portal = ring.twin
	_stand(far.exit_point() + far.normal * 2.0, far.pos)
	await _shot("2_far_ring")
	_stand(game.scenario.cast.sage.pos + (game.scenario.sage_house.out as Vector2) * 9.0, far.pos, 1.5)
	await _shot("3_far_ring_wide")
	quit()
