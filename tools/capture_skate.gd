## Windowed screenshots of the skater's body (SkateController): a push with the foot (left click), and a bail into a kerb
## (rolling down, lying in the recovery position, getting up), seen from the side.
##   godot --path . --script tools/capture_skate.gd -- <out dir>
extends CaptureTool

var cam: Camera3D


func _run() -> void:
	await _frames(20)
	var k: Kerbs = game.kerbs
	var e := {}
	for i in k.edges_near(game.landing.start, 60.0):
		var c: Dictionary = k.edges[i]
		if e.is_empty() or c.a.distance_to(c.b) > e.a.distance_to(e.b):
			e = c
	var along: Vector2 = (e.b - e.a).normalized()
	var side: Vector2 = e.side
	game.world.player.make_needless()
	game.world.player.gear.add("skateboard", 1)
	# rolling along the road, a push
	var start: Vector2 = (e.a + e.b) * 0.5 - side * 3.0 - along * 6.0
	game.player.teleport(Vector3(start.x, 0.05, start.y), atan2(-along.x, -along.y))
	game.skate_controller.toggle()
	await _physics(10)
	cam = Camera3D.new()
	game.add_child(cam)
	cam.current = true
	_press("fire")
	await _physics(6)  # (the lean's deepest: KICK_TIME / 2)
	_side_view(side)
	await _shot("1_push", 1)
	await _physics(30)
	# into the kerb, fast, no ollie: a bail
	var at := game.player.ground_pos()
	game.player.teleport(Vector3(at.x, 0.05, at.y), atan2(side.x, side.y) + PI)
	game.world.skating.speed = 7.0
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_msec()
	while not game.world.skating.bailing and Time.get_ticks_msec() - t0 < 4000:
		await physics_frame
	Input.action_release("move_forward")
	print("bailed: ", game.world.skating.bailing)
	await _physics(16)
	_side_view(along)
	await _shot("2_bail_rolling", 1)
	await _physics(40)
	_side_view(along)
	await _shot("3_bail_lying", 1)
	while game.world.skating.bailing:
		await physics_frame
	await _physics(4)
	_side_view(along)
	await _shot("4_up_again", 1)
	quit()


# A camera off to one side of the hero, looking at them.
func _side_view(across: Vector2) -> void:
	var p := game.player.global_position
	cam.global_position = p + Vector3(across.x, 0.0, across.y) * 4.2 + Vector3(0, 1.3, 0)
	cam.look_at(p + Vector3(0, 0.6, 0))


func _press(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
