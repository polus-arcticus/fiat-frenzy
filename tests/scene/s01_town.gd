## Scene suite section: The town as built: the city, the cast, the views, the first tutorial step.
## Runs in order with the others (tests/smoke_scene.gd), on the same game, so it starts from where the last left off.
extends SceneSection


func run() -> void:

	var city: Node3D = game.city
	var walls: MeshInstance3D = city.get_node("Walls")
	check(walls.mesh.get_surface_count() == 1 and walls.mesh.surface_get_array_len(0) > 5000, "the city has walls (%d vertices)" % walls.mesh.surface_get_array_len(0))
	check((city.get_node("Windows") as MeshInstance3D).mesh.surface_get_array_len(0) > 10000, "and windows, and lit windows for the night")
	check(city.get_node("Collision").get_child_count() == 1 and city.get_node("GroundCollision").get_child_count() == 1, "and collision for the walls, and a slab of ground of its own")
	var w: World = game.world
	check(w.roads != null and w.roads.point_count() > 500, "the street graph has %d points" % w.roads.point_count())
	check(w.drones.size() == 25 and w.machines.size() == 11 and w.bins.size() == 10 and w.fires.size() == 9 and w.relief_trucks.size() == 1 and w.bottle_depots.size() == 2, "the starting cast: 4 vendors, 2 drifters, 2 cart runners, the bike shop owner, Mr. Nobody, the ECB doorman, the skate shop owner, the ECB receptionist, the van; 9 barrel fires (7 down Kaiserstraße, 2 at the bank); and at the bank 3 vendors, a runner, 3 visitors; the technician upstairs; a bottle depot's attendant at each market; and the camp keeper and the thrift seller, each by a garbage bin; and a station of bins and a fountain at each market")
	check(w.machines.all(func(m): return (m.kind in ["bike_shop", "skate_shop", "tent", "scrap_camp", "thrift_stall"] or not m.working) and m.owner != ""), "every stand starts wrecked: only the two shops, the tent city, the homeless camp and the thrift stall are open")
	var tents := w.machine_of(game.scenario.cast.tent)
	var scripted := [w.cast.sage, w.cast.doorman, w.cast.receptionist, w.cast.technician]
	var townsfolk := w.zones.drones_in(Zones.HOME).filter(func(d): return not d in scripted)
	check(tents.residence.tents == townsfolk.size() and townsfolk.all(func(d): return d.bed == tents.uid), "a tent each for everyone in the town but the story's scripted cast (%d tents)" % tents.residence.tents)
	var views := 0
	for c in game.get_children():
		if c is DroneView or c is MachineView or c is FireView or c is ReliefView or c is HospitalView or c is AmbulanceView or c is BottleDepotView or c is WasteBinView:
			views += 1
	check(views == 25 + 11 + 9 + 1 + 4 + 2 + 10,"a view for each thing in the model (%d)" % views)
	var tent_view: MachineView = game.get_children().filter(func(c): return c is MachineView and c.machine.kind == "tent")[0]
	var tent_solid: StaticBody3D = tent_view.get_node("Solid")
	check(tent_solid.get_child_count() == 3 and tent_solid.collision_layer == 1, "the field tent has walls the player and bills run into: three wall colliders")
	var tent_bodies := tent_view.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.name != "Solid")
	check(tent_bodies.size() >= 1, "and the imported tent and barrel models bring their own solid hulls, which hold the player out (%d)" % tent_bodies.size())
	var hospital_view: HospitalView = game.get_children().filter(func(c): return c is HospitalView)[0]
	check(hospital_view.get_node("Solid").get_child_count() == 3, "the medical tent has its three walls too")
	var runner_views := game.get_children().filter(func(c): return c is DroneView and c.drone.kind == "runner")
	check(runner_views.size() == 3 and runner_views.all(func(v): return v._cart != null and v._cart.slots() == 4), "all three cart runners have a cart to push, with room for cargo")
	var organics: WasteBin = w.bins.filter(func(b): return b.kind == "organics" and b.zone == Zones.HOME)[0]
	var bin_view: WasteBinView = game.get_children().filter(func(c): return c is WasteBinView and c.bin == organics)[0]
	check(bin_view.position.distance_to(Vector3(game.scenario.start.x, 0, game.scenario.start.y)) > 10.0, "the bins stand a good way from where the player begins")
	var market_mid: Vector2 = w.machine_of(game.scenario.cast.hot_dog).pos
	check(organics.pos.distance_to(market_mid) > 30.0, "and about 40 m down the street from the market (%.0f m)" % organics.pos.distance_to(market_mid))
	var near := 0
	for m in w.machines:
		near += 1 if not m.kind in ["bike_shop", "skate_shop", "scrap_camp", "thrift_stall"] and m.pos.distance_to(game.scenario.start) < 70.0 else 0
	check(near == 4, "all four stands are within 70 m of where the player starts")
	check(game.player.global_position.distance_to(Vector3(game.scenario.start.x, 0, game.scenario.start.y)) < 1.0, "the player starts on the street")

	for i in 30:
		await tree.physics_frame
	check(game.tutorial.index == 0, "the tutorial starts at step 1")
	var hot: Drone = game.scenario.cast.hot_dog
	game.player.teleport(Vector3(hot.pos.x + 3, 0.1, hot.pos.y))
	for i in 5:
		await tree.physics_frame
	check(game.tutorial.index == 1, "walking to the hot dog vendor advances it")

