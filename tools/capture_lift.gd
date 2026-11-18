## Windowed screenshots of the bank's lift in the plaza and the instrument room upstairs. Needs a window.
##   godot --path . --script tools/capture_lift.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_lift"
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1200, 700)
	game = load("res://main.tscn").instantiate()
	game.skip_intro = true
	root.add_child(game)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	game.gun.set_enabled(false)
	await game.dev_stages.go("lift")
	game.sim.speed = 1.0
	var lift := w.cast.lift
	game.player.teleport(Vector3(lift.pos.x + lift.normal.x * 6.0, 0.1, lift.pos.y + lift.normal.y * 6.0), 0.0)
	game.player.look_toward(Vector3(lift.pos.x, 1.5, lift.pos.y))
	await _frames(10)
	await _shot("1_lift_plaza")
	await game.dev_stages.go("room")
	var room: Dictionary = game.scenario.lift
	var c: Vector2 = room.centre
	var t := w.cast.technician
	game.player.teleport(Vector3(c.x + 3.0, 0.1, c.y + 5.0), 0.0)
	game.player.look_toward(Vector3(c.x, 1.3, c.y - 4.0))
	await _frames(10)
	await _shot("2_room_toward_bench")
	game.player.look_toward(Vector3(c.x, 1.5, c.y + 7.0))
	await _frames(5)
	await _shot("3_room_toward_lift")
	quit()
