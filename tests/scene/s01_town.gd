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
	check(w.drones.size() == 12 and w.machines.size() == 5 and w.food_banks.size() == 1 and w.fires.size() == 1 and w.relief_trucks.size() == 1, "the starting cast: 4 vendors, 2 drifters, a food bank keeper, 2 cart runners, the bike shop owner, Mr. Nobody, the ECB doorman, a fire, the van")
	check(w.machines.all(func(m): return (m.kind == "bike_shop" or not m.working) and m.owner_id >= 0), "every stand starts wrecked, and only the bike shop is open")
	var views := 0
	for c in game.get_children():
		if c is DroneView or c is MachineView or c is FireView or c is ReliefView or c is FoodBankView or c is HospitalView or c is AmbulanceView:
			views += 1
	check(views == 12 + 5 + 1 + 1 + 1 + 2, "a view for each thing in the model (%d)" % views)
	var tent_view: MachineView = game.get_children().filter(func(c): return c is MachineView and c.machine.kind == "tent")[0]
	var tent_solid: StaticBody3D = tent_view.get_node("Solid")
	check(tent_solid.get_child_count() == 3 and tent_solid.collision_layer == 1, "the field tent has walls the player and bills run into: three wall colliders")
	var tent_bodies := tent_view.find_children("*", "StaticBody3D", true, false).filter(func(b): return b.name != "Solid")
	check(tent_bodies.size() >= 1, "and the imported tent and barrel models bring their own solid hulls, which hold the player out (%d)" % tent_bodies.size())
	var hospital_view: HospitalView = game.get_children().filter(func(c): return c is HospitalView)[0]
	check(hospital_view.get_node("Solid").get_child_count() == 3, "the medical tent has its three walls too")
	var runner_views := game.get_children().filter(func(c): return c is DroneView and c.drone.kind == "runner")
	check(runner_views.size() == 2 and runner_views.all(func(v): return v._cart != null and v._cart.slots() == 4), "both cart runners have a cart to push, with room for cargo")
	var fb_view: FoodBankView = game.get_children().filter(func(c): return c is FoodBankView)[0]
	check(fb_view.bank == w.food_banks[0] and fb_view.position.distance_to(Vector3(game.scenario.start.x, 0, game.scenario.start.y)) > 10.0, "the food bank stands a good way from where the player begins")
	var market_mid: Vector2 = w.machine_of(game.scenario.cast.hot_dog).pos
	check(w.food_banks[0].pos.distance_to(market_mid) > 30.0, "and about 40 m down the street from the market (%.0f m)" % w.food_banks[0].pos.distance_to(market_mid))
	var near := 0
	for m in w.machines:
		near += 1 if m.kind != "bike_shop" and m.pos.distance_to(game.scenario.start) < 70.0 else 0
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

