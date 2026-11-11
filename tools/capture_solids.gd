## Windowed screenshots of a drifter walking round the field tent instead of through it. Needs a real window.
##   godot --path . --script tools/capture_solids.gd -- <output dir>
extends SceneTree

var out_dir := "/tmp/ff3d_solids"
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


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var m: Machine = w.machine_of(game.scenario.cast.tent)
	m.working = true
	m.refresh()
	game.sim_paused = true
	game.hud.visible = false
	await _frames(60)  # the tent stands up
	var f: Vector2 = m.front
	var side := Vector2(-f.y, f.x)
	var d: Drone = w.drones[4]
	d.pos = m.pos + side * 5.0 + f * 0.3
	var goal := m.pos - side * 5.0 + f * 0.3
	var eye := Camera3D.new()  # straight down on the tent
	root.add_child(eye)
	eye.global_position = Vector3(m.pos.x, 9.0, m.pos.y + 0.01)
	eye.look_at(Vector3(m.pos.x, 0.0, m.pos.y), Vector3.UP)
	eye.current = true
	var shots := {40: "1_round_the_front", 70: "2_past_the_tent", 100: "3_other_side"}
	for i in 140:
		w.walking.step(d, goal, 0.1)
		await process_frame
		if shots.has(i):
			await _shot("walk_%s" % shots[i])
	quit(0)
