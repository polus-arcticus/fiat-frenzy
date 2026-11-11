## Windowed screenshots of the bike shop and the bicycle: the building from the street, the doorway, the inside,
## the buy screen, the parked bike and the view from the saddle. Needs a real window and GPU.
##   godot --path . --script tools/capture_bike.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_bike"
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1100, 650)
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


func _stand(at: Vector2, look_at: Vector2, eye := 1.0) -> void:
	var to := look_at - at
	game.player.teleport(Vector3(at.x, 0.1, at.y), atan2(-to.x, -to.y))
	game.player.look_toward(Vector3(look_at.x, eye, look_at.y))


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	var shop: Dictionary = sc.bike_shop
	var door: Vector2 = shop.door
	var inward: Vector2 = shop.inward
	game.sim_paused = true
	game.gun.set_enabled(false)
	_stand(door - inward * 12.0, door, 2.0)
	await _frames(20)
	await _shot("1_from_the_street")
	_stand(door - inward * 3.5, door + inward * 6.0, 1.3)
	await _shot("2_the_doorway")
	_stand(door + inward * 4.0, door + inward * 11.0, 1.2)
	await _shot("3_inside")
	var owner: Drone = sc.cast.bike_shop
	var m: Machine = w.machine_of(owner)
	_stand(m.pos + m.front * 3.0, m.pos, 1.2)
	game.hud.show_target(owner, w)
	await _shot("4_the_counter")
	w.ledger.player_cash = 3000.0
	w.ledger.printed += 3000.0
	game.interaction.open(m)
	await _frames(4)
	await _shot("5_buy_screen")
	var r := w.commerce.buy(m, "bicycle")
	game.interaction.screen.refresh(r.text)
	await _frames(4)
	await _shot("6_bought")
	game.interaction.screen.close()
	await _frames(10)
	_stand(w.player.pos, w.bike.pos, 0.8)
	await _frames(10)
	await _shot("7_parked_bike")
	game.bike_controller.toggle()
	_stand(door - inward * 2.0, door - inward * 30.0, 1.3)
	game.player.velocity = Vector3(0, 0, -9.0)
	await _frames(10)
	await _shot("8_riding")
	quit(0)
