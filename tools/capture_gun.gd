## Windowed screenshots of the money gun: idle, mid mode-switch, charging (half and full), and an investment
## contract in flight. Needs a real window and GPU.
##   godot --path . --script tools/capture_gun.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_gun"
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
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("saved ", name)


## Holds the trigger for `seconds` of real time, stepping the gun each frame.
func _hold(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		var dt := 1.0 / 60.0
		game.gun.step(true, dt)
		t += dt
		await process_frame


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var sc: Scenario = game.scenario
	var baker: Drone = sc.cast.bakery
	w.machine_of(baker).working = true
	game.sim_paused = true
	game.gun.set_process(false)  # this script holds the trigger itself; there is no real mouse here
	game.player.teleport(Vector3(sc.start.x, 0.1, sc.start.y), sc.start_yaw)  # in the street, the market ahead
	game.player.look_toward(Vector3(baker.pos.x, 1.2, baker.pos.y))
	game.hud.show_target(null, w)
	await _frames(30)
	await _shot("1_gift_idle")
	game.gun.cycle_mode(1)
	await create_timer(0.12).timeout
	await _shot("2_toggle_mid_roll")
	await create_timer(0.5).timeout
	await _shot("3_invest_idle")
	await _hold(0.7)
	game.hud.show_charge(game.gun.charge, game.gun.contract_value(game.gun.charge))
	await _shot("4_charging_half")
	await _hold(0.9)
	game.hud.show_charge(game.gun.charge, game.gun.contract_value(game.gun.charge))
	await _shot("5_charged_full")
	game.gun.step(false, 0.016)
	game.hud.show_charge(0.0, 0.0)
	await create_timer(0.12).timeout
	await _shot("6_contract_in_flight")
	await create_timer(0.7).timeout
	await _shot("7_after_the_hit")
	quit(0)
