## Windowed screenshots of the skate shop beside the bike shop: from the street, in the doorway and at the counter.
##   godot --path . --script tools/capture_skate_shop.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_skate"
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


func _shot(name: String, from: Vector2, at: Vector2, eye := 1.6) -> void:
	var to := at - from
	game.player.teleport(Vector3(from.x, 0.1, from.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(at.x, eye, at.y))
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


func _run() -> void:
	await _frames(20)
	game.sim_paused = true
	game.gun.set_enabled(false)
	var sc: Scenario = game.scenario
	var bike: Dictionary = sc.bike_shop
	var skate: Dictionary = sc.skate_shop
	var out: Vector2 = skate.out
	var mid: Vector2 = ((bike.door as Vector2) + (skate.door as Vector2)) * 0.5
	await _shot("1_the_two_shops", mid + out * 14.0, mid, 2.2)
	await _shot("2_the_skate_shop_door", (skate.door as Vector2) + out * 6.0, skate.door, 2.4)
	var inward: Vector2 = skate.inward
	await _shot("3_inside", (skate.door as Vector2) + inward * 1.5, (skate.door as Vector2) + inward * 10.0, 1.7)
	var owner: Drone = sc.cast.skate_shop
	await _shot("4_the_counter", (skate.door as Vector2) + inward * 3.0, owner.pos, 1.4)
	quit(0)
