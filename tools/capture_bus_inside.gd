## Windowed screenshots of the bus's inside and its door: from the kerb with the door shut and open, and from a seat.
##   godot --path . --script tools/capture_bus_inside.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_bus_inside"
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
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _look(from: Vector3, at: Vector3) -> void:
	var to := Vector2(at.x - from.x, at.z - from.z)
	game.player.teleport(Vector3(from.x, from.y - 1.5, from.z), atan2(-to.x, -to.y))
	game.player.look_toward(at)


func _run() -> void:
	await _frames(20)
	game.sim_paused = true
	game.gun.set_enabled(false)
	var bus: BusView = game.bus
	var kerb := bus.kerb_point()
	var door := bus.doorway_point()
	_look(kerb + Vector3(0, 1.6, 0) + (kerb - door).normalized() * 2.0, door + Vector3(0, 1.0, 0))
	await _shot("1_door_shut")
	await bus.open_door().finished
	await _shot("2_door_open")
	_look(door + Vector3(0, 1.6, 0), bus.to_global(Vector3(0, 1.2, -2.0)))
	await _shot("3_the_aisle")
	var seat := bus.seat_point()
	_look(seat + Vector3(0, 0.9, 0), bus.to_global(Vector3(0.8, 1.2, 8.0)))
	await _shot("4_from_the_seat")
	_look(bus.to_global(Vector3(6.5, 3.5, -9.0)), bus.to_global(Vector3(0, 1.2, 0)))
	await _shot("5_from_outside")
	quit(0)
