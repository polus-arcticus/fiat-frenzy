## Windowed screenshots of tram 11: the car at the station, its coloured way along the street, from a seat in it, at its next
## stops, and coming round from the start of its line.
##   godot --path . --script tools/capture_tram.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = false
	game.player.camera.far = 2500.0
	var w: World = game.world
	var tram := w.transit.vehicle("tram_east")
	var view := _view_of(tram)
	var line := tram.line
	var s: float = line.stops[tram.stop].s
	var dir := line.dir_at(s)
	var right := dir.rotated(PI * 0.5)
	_stand(tram.pos + dir * 17.0 + right * 7.0, tram.pos, 1.5)
	await _shot("1_at_the_station", 60)
	_stand(tram.pos - dir * 3.0 + right * 11.0, tram.pos, 1.5)
	await _shot("2_its_side", 40)
	_stand(line.pos_at(s + 130.0), line.pos_at(s + 170.0), 0.3)
	await _shot("3_the_colour_along_the_street", 40)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 260.0
	cam.far = 2000.0
	cam.position = Vector3(-250, 600, 120)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	game.add_child(cam)
	cam.make_current()
	await _shot("4_the_turn_from_above", 30)
	cam.queue_free()
	game.player.camera.make_current()
	# aboard: get on at its door as the hero would, and ride on to the Paulskirche's stop
	game.player.controls_enabled = true
	view.door_toward(Vector3(tram.pos.x + right.x * 5.0, 0.0, tram.pos.y + right.y * 5.0))
	var kerb := view.kerb_point()
	game.player.teleport(Vector3(kerb.x, 0.2, kerb.z), 0.0)
	await _frames(10)
	print("prompt: ", game._board_prompt())
	game.sim_paused = false
	game._board()
	await create_timer(8.0).timeout
	await _shot("5_aboard", 1)
	game.rides.fast = true
	await create_timer(6.0).timeout
	game.rides.fast = false
	await create_timer(4.0).timeout
	var names: Array = line.stops.map(func(x): return x.name)
	print("now at ", line.stops[tram.stop].name, ", side ", view.side)
	await _shot("6_off_at_the_next_stop", 30)
	var at: Vector2 = game.player.ground_pos()
	var from := at
	var eye := Camera3D.new()
	game.add_child(eye)
	var back := Vector2.from_angle(tram.heading)
	eye.position = Vector3(at.x + back.x * 16.0 - back.y * 7.0, 9.0, at.y + back.y * 16.0 + back.x * 7.0)
	eye.look_at(Vector3(at.x, 0.5, at.y))
	Look.box(game, Vector3(0.3, 3.5, 0.3), Vector3(at.x, 1.75, at.y), Color.BLACK)  # (where the hero stands)
	eye.make_current()
	await _shot("6b_where_they_stand", 20)
	# can they walk away? try each way for a second and say how far they get
	game.player.camera.make_current()
	var free: Array = []
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5]:
		game.player.teleport(Vector3(from.x, 0.2, from.y), yaw)
		await _frames(5)
		Input.action_press("move_forward")
		await create_timer(1.0).timeout
		Input.action_release("move_forward")
		free.append(snappedf(game.player.ground_pos().distance_to(from), 0.1))
	print("walked away, each of four ways (m): ", free)
	eye.queue_free()
	game.sim_paused = true
	for goal in ["Römer/Paulskirche", "Börneplatz", "Ostbahnhof/Sonnemannstraße"]:
		var k := names.find(goal)
		tram.stop = k
		tram.pos = line.stops[k].at
		tram.prev_pos = tram.pos
		tram.heading = line.heading_at(k, 1)
		tram.prev_heading = tram.heading
		dir = line.dir_at(line.stops[k].s)
		right = dir.rotated(PI * 0.5)
		_stand(tram.pos - dir * 22.0 + right * 8.0, tram.pos + dir * 4.0, 2.0)
		await _shot("7_%s" % goal.get_slice("/", 0), 60)
	quit()


func _view_of(model: Vehicle) -> TramView:
	for v in game.line_views:
		if v.model() == model:
			return v
	return null
