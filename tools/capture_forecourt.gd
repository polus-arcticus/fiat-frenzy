## Windowed screenshots of the story's start at the station forecourt: from straight above (north up) for laying it out, and
## from the ground.
##   godot --path . --script tools/capture_forecourt.gd -- <output dir>
extends CaptureTool


func _run() -> void:
	await _frames(20)
	game.sim_paused = true
	game.gun.set_enabled(false)
	game.hud.visible = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 130.0
	cam.far = 2000.0
	cam.position = Vector3(-350, 600, 110)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	game.add_child(cam)
	cam.make_current()
	await _shot("0_above", 30)
	cam.queue_free()
	game.player.camera.make_current()
	game.player.camera.far = 2500.0
	var start: Vector2 = game.scenario.start
	_stand(start, start + Vector2.from_angle(-game.scenario.start_yaw - PI / 2.0) * 10.0, 2.0)
	await _shot("1_start", 60)
	_stand(Vector2(-320, 85), Vector2(-370, 115), 6.0)
	await _shot("2_toward_station", 40)
	var sc: Scenario = game.scenario
	var at: Vector2 = sc.start
	game.player.teleport(Vector3(at.x, 0.1, at.y), sc.start_yaw)
	game.intro.start()  # (the fall as the hero sees it, then the wreck where it comes down)
	await create_timer(IntroController.FALL_TIME * 0.6).timeout
	await _shot("2b_falling", 1)
	game.intro.finish()
	game.player.controls_enabled = true
	await _frames(90)
	_stand(sc.offset_on_street(sc.wreck_pos, -12.0, -8.0), sc.wreck_pos, 3.0)
	await _shot("3_wreck", 40)
	var hospital: Vector2 = sc.hospital.pos
	_stand(sc.offset_on_street(hospital, 4.0, 13.0), hospital, 1.5)
	await _shot("4_hospital", 40)
	var town: Vector2 = sc.market.pos
	_stand(sc.offset_on_street(town, -22.0, -16.0), town, 3.0)
	await _shot("5_market", 40)
	quit()
