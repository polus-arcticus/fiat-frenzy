## Scene suite section: the inspector (F3): a free camera over the live world, clicking someone, and leaving it all as it was.
extends SceneSection


func run() -> void:
	var ic: InspectorController = game.inspector
	var p: PlayerController = game.player
	var w: World = game.world
	var cash0: float = w.ledger.player_cash - w.ledger.stake_income  # (the hero's stakes go on paying while you look)
	var enabled0 := p.controls_enabled
	var time0: float = w.clock.time
	ic.toggle()
	await tree.process_frame
	check(ic.active and not p.controls_enabled and ic._cam.current and not game.gun.enabled, "F3: a free camera takes over, the hero's controls and gun are put away")
	# put the camera where it can see a banker or any drone, and click them
	# (someone near the hero with nobody else within 8 m south of them, between them and the camera, who would be clicked instead)
	var d: Drone = w.drones[0]
	for cand in w.drones:
		var in_the_way := w.drones.any(func(o): return o != cand and absf(o.pos.x - cand.pos.x) < 1.5 and o.pos.y > cand.pos.y - 0.5 and o.pos.y < cand.pos.y + 8.0)
		if cand.zone == "district" and cand.care == "" and not in_the_way and cand.pos.distance_to(Vector2(p.global_position.x, p.global_position.z)) < 60.0:
			d = cand
			break
	ic._cam.global_position = Vector3(d.pos.x, 3.0, d.pos.y + 6.0)
	ic._yaw = 0.0
	ic._pitch = atan2(-(3.0 - 0.9), 6.0)
	ic._apply_look()
	var middle: Vector2 = game.get_viewport().get_visible_rect().size * 0.5
	check(ic.pick(middle) == d, "a click on someone picks them")
	ic.select(d)
	check(ic._view._label.text.contains("#%s" % d.uid) and ic._view._label.text.contains("JOB:"), "and the panel says who they are and what their job is")
	ic.go_to_selected()
	check(ic._cam.global_position.distance_to(Vector3(d.pos.x, 7.0, d.pos.y + 9.0)) < 0.01, "G takes the camera to them")
	ic._cycle(1)
	check(ic.selected != d and ic.selected != null, "N picks the next one")
	var stood_by: float = w.clock.time
	await tree.create_timer(0.3).timeout
	check(w.clock.time > stood_by and w.clock.time > time0, "the sim keeps running while you look")
	ic.toggle()
	check(not ic.active and p.controls_enabled == enabled0 and p.camera.current and game.gun.enabled == (w.gun_owned or game.gun.enabled), "F3 again gives the hero their camera and controls back")
	check(is_equal_approx(w.ledger.player_cash - w.ledger.stake_income, cash0) and not ic._view.visible, "and nothing about the world changed")
