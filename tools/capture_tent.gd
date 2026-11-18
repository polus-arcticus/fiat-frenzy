## Windowed screenshots of the first market's tent as the town's home (see Lodging): put back up, with a bed for each of its
## people; its screen (E); then with five beds added by the hero, and the newcomers who came for them.
##   godot --path . --script tools/capture_tent.gd -- <output dir>
extends CaptureTool


## Stands the hero in the street in front of the tent, far enough back to see all of it.
func _look(tent: Machine, back: float) -> void:
	var mid := tent.pos + Vector2(-tent.front.y, tent.front.x) * tent.wing * (tent.modules() - 1) * Machine.MODULE_WIDTH * 0.5
	_stand(mid + tent.front * back, mid, 1.0)
	game.advance(0.3)


func _run() -> void:
	await _frames(20)
	var w: World = game.world
	var tent: Machine = w.machine_of(game.scenario.cast.tent)
	w.gun.gift(w.drone(tent.owner), tent.repair_cost + Drone.RESERVE + 5.0)
	game.advance(20.0)
	print("the tent: working %s, %d beds, %d modules" % [tent.working, tent.beds, tent.modules()])
	_look(tent, 9.0)
	await _shot("1_tent", 90)
	game.interaction.open(tent)
	await _shot("2_screen", 90)
	for i in 5:
		game.tent_screen.add_requested.emit(tent)
	await _shot("3_screen_beds_added", 90)
	game.tent_screen.close()
	var before := w.drones.size()
	game.advance(Lodging.ARRIVE_EVERY * 5 + 5.0)
	print("now %d beds, %d modules; %d newcomers: %s" % [tent.beds, tent.modules(), w.drones.size() - before, w.drones.slice(before).map(func(d): return d.label)])
	_look(tent, 11.0)
	await _shot("4_grown", 90)
	quit()
